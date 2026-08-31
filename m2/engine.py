# -*- coding: utf-8 -*-
"""
Rogue Dealership - M2 engine. The negotiation model. Pure rules core.

No I/O, no printing, no input: play.py drives it, and a simulator could drive
the same object later without the two drifting apart. Deterministic given a
seed.

The model in one breath: every live OFFER has two numbers moving in opposite
directions - APPEAL climbing toward their LINE, MARGIN falling as you
concede - and the game is deciding when to stop. Appeal opens at
appeal_step x (9 - their rank) for the interest a product answers, so a bad
read is never a refusal, only an expensive starting position. PLACING a product
costs a tick and shows you only a band; OFFERING it is free, reveals the exact
gap, and is what provokes them. Nothing is yours until you CLOSE: a customer
who runs out of patience walks out with the whole unsigned deal.
"""
import json
import os
import random

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")

CHAIR_KEYS = "ABCDEFGH"


def _load(name, data_dir=None):
    path = os.path.join(data_dir or DATA_DIR, name)
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


class Catalog(object):
    """Everything loaded from data/. Read-only once built, except config."""

    def __init__(self, data_dir=None):
        interests = _load("interests.json", data_dir)
        products = _load("products.json", data_dir)
        cards = _load("cards.json", data_dir)
        archetypes = _load("archetypes.json", data_dir)

        self.categories = interests["categories"]
        self.interests = interests["interests"]
        self.interest_ids = list(self.interests.keys())

        # kind is stamped on load so a hand can hold both without play.py or
        # the engine ever having to ask which list a dict came from.
        self.products = [dict(p, kind="product") for p in products["products"]]
        self.products_by_id = {p["id"]: p for p in self.products}
        self.cards = {}
        for c in cards["cards"]:
            self.cards[c["id"]] = dict(c, kind="support")

        self.archetypes = {a["id"]: a for a in archetypes["archetypes"]}
        self.base = archetypes["base"]
        self.names = list(archetypes["names"])

        self.objections = _load("objections.json", data_dir)
        self.config = _load("config.json", data_dir)

    def card(self, cid):
        """Either kind, by id - the hand holds both."""
        if cid in self.cards:
            return self.cards[cid]
        return self.products_by_id[cid]

    def starter_deck(self):
        out = []
        for p in self.products:
            if p.get("starter"):
                out.extend([p] * p.get("copies", 1))
        for c in self.cards.values():
            if c.get("starter"):
                out.extend([c] * c.get("copies", 1))
        return out

    def product_for(self, interest_id):
        for p in self.products:
            if p["interest"] == interest_id:
                return p
        raise KeyError(interest_id)

    def interest_name(self, iid):
        return self.interests[iid]["name"]

    def category_of(self, iid):
        return self.interests[iid]["category"]

    def category_name(self, cid):
        return self.categories[cid]["name"]

    def objection_for(self, gap):
        """First band whose max_gap covers this shortfall. Bands are sorted
        ascending and the last is unreachable-high, so this never misses."""
        for band in self.objections["bands"]:
            if gap <= band["max_gap"]:
                return band
        return self.objections["bands"][-1]


class Result(object):
    """Outcome of one attempted action.

    ok=False means the rules refused the attempt and NOTHING was spent - not
    the tick, not the card. ok=True means it happened, which may still have
    gone badly for you.
    """

    def __init__(self, ok, msg, kind="invalid", **data):
        self.ok = ok
        self.msg = msg
        self.kind = kind
        self.data = data

    def __repr__(self):
        return "Result(%s, %r, %r)" % (self.ok, self.kind, self.msg)


class Offer(object):
    """One product on the table, mid-negotiation. Persists untouched while you
    go work someone else - leaving costs you the tick and your memory, nothing
    more.

    `revealed` is False until you actually OFFER it: until then you know only
    the band, which is what stops placing products from being a free way to
    read their whole priority list."""

    def __init__(self, product, appeal, margin):
        self.product = product
        self.appeal = appeal
        self.opened_at = appeal
        self.margin = margin
        self.list_margin = margin
        self.revealed = False
        self.applied = []          # card names, in the order you played them


class Customer(object):
    def __init__(self, key, name, archetype, ranks, patience, max_patience, cfg):
        self.key = key
        self.name = name
        self.archetype = archetype
        self.cfg = cfg

        self.ranks = ranks                  # interest id -> 1..9, hidden
        self.threshold = archetype["threshold"]
        self.start_threshold = archetype["threshold"]
        self.threshold_per_sale = archetype.get("threshold_per_sale",
                                                cfg["threshold_per_sale"])
        self.max_patience = max_patience
        self.patience = patience

        self.offer = None
        self.unsigned = []                  # [{"product":..., "margin":...}]
        self.refused = []                   # products you gave up on

        # What the PLAYER knows. The hidden information in this game is the
        # priority list; the arithmetic of an offer already made never is.
        self.known_ranks = set()
        self.known_threshold = False
        self.known_top_category = None

        # The Karen: they will not sign until they have bought from the
        # category they came in for. Announced on arrival - a free read, and
        # then they charge the whole floor rent until you act on it.
        self.demands = None

        self.state = "floor"                # floor | signed | walked
        self.sales = 0
        self.ticks_on_floor = 0
        self.action_state = {}              # action id -> when it last fired

    def appeal_for(self, interest_id):
        """appeal_step x (interest_count - rank). Rank 1 opens at 40, rank 9 at
        0 - which is not a refusal, just eight places of concession you will
        not want to pay for."""
        n = len(self.ranks)
        return self.cfg["appeal_step"] * (n - self.ranks[interest_id])

    @property
    def unsigned_margin(self):
        return sum(u["margin"] for u in self.unsigned)

    @property
    def top_interest(self):
        for iid, rank in self.ranks.items():
            if rank == 1:
                return iid
        return None

    def owns(self, product_id):
        return any(u["product"]["id"] == product_id for u in self.unsigned)

    def owns_category(self, category):
        return any(u["product"]["category"] == category for u in self.unsigned)

    @property
    def leaving_soon(self):
        return self.patience <= self.cfg["leaving_soon_at"]


class Shift(object):
    def __init__(self, catalog=None, seed=None, floor=None):
        self.cat = catalog or Catalog()
        self.cfg = self.cat.config
        self.rng = random.Random(seed)
        self.seed = seed

        self.tick = 0
        self.tick_budget = self.cfg["shift_ticks"]
        self.quota = self.cfg["quota"]
        self.margin_banked = 0

        size = self.cfg["floor_size"]
        self.chairs = [None] * size
        self.walk_up = [0] * size
        self.at = None                      # chair index you are standing at
        self.last_customer = None           # who you were last standing with

        self._forced = list(floor) if floor else None
        self._forced_next = 0
        self._name_pool = []
        self.served = 0

        self.events = []
        self.action_log = []     # what customers DID to you, drained by the UI
        self.reshuffles = 0
        self.lost_to_walks = 0
        self.stat = {
            "cards_played": 0, "offers": 0, "failed_offers": 0,
            "offers_dropped": 0, "sales": 0, "places": 0,
            "digs": 0, "approaches": 0, "actions_fired": 0,
            "ticks_cards": 0, "ticks_place": 0, "ticks_digs": 0,
            "ticks_approach": 0,
            "margin_conceded": 0, "margin_padded": 0, "margin_bonus": 0,
            "customers_signed": 0, "customers_walked": 0,
        }

        self.draw, self.discard, self.hand = self._build_deck(), [], []
        self.deck_size = len(self.draw)
        self._draw_up()

        for i in range(size):
            self._spawn(i)

    # ----------------------------------------------------------------- setup
    def _build_deck(self):
        deck = self.cat.starter_deck()
        self.rng.shuffle(deck)
        return deck

    def _next_name(self):
        if not self._name_pool:
            self._name_pool = list(self.cat.names)
            self.rng.shuffle(self._name_pool)
        return self._name_pool.pop()

    def _pick_archetype(self):
        if self._forced:
            aid = self._forced[self._forced_next % len(self._forced)]
            self._forced_next += 1
            return aid
        ids = list(self.cat.archetypes.keys())
        if self.cfg.get("unique_archetypes_on_floor", True):
            seated = set(c.archetype["id"] for c in self.chairs if c)
            fresh = [a for a in ids if a not in seated]
            if fresh:
                ids = fresh
        return self.rng.choice(ids)

    def _make_ranks(self, arch):
        """Seed the archetype's priors into the top and bottom thirds, shuffle
        the rest. prior_slip is what keeps a prior from being a lookup table:
        each seeded interest has that chance of being left to the shuffle
        instead, so 'a Tech Enthusiast cares about Security' is usually true
        and occasionally teaches you something."""
        slip = self.cfg.get("prior_slip", 0.0)
        top = [i for i in arch.get("top", []) if self.rng.random() >= slip]
        bottom = [i for i in arch.get("bottom", []) if self.rng.random() >= slip]
        top, bottom = top[:3], bottom[:3]

        rest = [i for i in self.cat.interest_ids
                if i not in top and i not in bottom]
        self.rng.shuffle(rest)

        n = len(self.cat.interest_ids)
        slots = [None] * n
        for pos, iid in zip(self.rng.sample([0, 1, 2], len(top)), top):
            slots[pos] = iid
        for pos, iid in zip(self.rng.sample([n - 3, n - 2, n - 1], len(bottom)),
                            bottom):
            slots[pos] = iid
        for i in range(n):
            if slots[i] is None:
                slots[i] = rest.pop()
        return dict((iid, pos + 1) for pos, iid in enumerate(slots))

    def _spawn(self, chair):
        cfg = self.cfg
        arch = self.cat.archetypes[self._pick_archetype()]
        jitter = cfg.get("patience_jitter", 0)
        top = max(1, arch["patience"] + self.rng.randint(-jitter, jitter))

        # Nobody is guaranteed to walk in fresh - some are already partway to
        # the door, which is triage pressure from the moment they sit down.
        # Floored so that an arrival is never dead on arrival.
        start = int(round(top * self.rng.uniform(
            cfg["arrival_patience_min_fraction"], 1.0)))
        start = max(min(top, cfg["arrival_patience_floor"]), start)

        cust = Customer(CHAIR_KEYS[chair], self._next_name(), arch,
                        self._make_ranks(arch), start, top, cfg)

        if arch.get("demands_category"):
            cust.demands = self.cat.category_of(cust.top_interest)
            cust.known_top_category = cust.demands   # she tells you, loudly

        self.chairs[chair] = cust
        self.walk_up[chair] = 0
        self.served += 1
        self.events.append("[%s] %s walks up - %s."
                           % (cust.key, cust.name, arch["name"]))
        return cust

    # ------------------------------------------------------------------ deck
    def _draw_up(self):
        while len(self.hand) < self.cfg["hand_size"]:
            if not self.draw:
                if not self.discard:
                    break
                self.draw = self.discard
                self.discard = []
                self.rng.shuffle(self.draw)
                self.reshuffles += 1
            self.hand.append(self.draw.pop())

    # -------------------------------------------------------------- the tick
    def seated(self):
        return [c for c in self.chairs if c is not None]

    def _burn(self, n, kind):
        """The single choke point for time. Effects have ALREADY resolved by
        the time this runs - m0's discovered rule, that you close during your
        turn and the damage lands after. Small Talk can therefore save someone
        at 1 patience, and a sale can land on the tick that would have walked
        them."""
        if n <= 0:
            return
        self.tick += n
        self.stat["ticks_" + kind] = self.stat.get("ticks_" + kind, 0) + n

        # Chairs already empty when the tick started are the only ones whose
        # walk-up timer moves; a chair emptied BY this tick starts its wait now.
        for i, cust in enumerate(self.chairs):
            if cust is None:
                self.walk_up[i] -= n

        for cust in self.seated():
            cust.patience -= n
            cust.ticks_on_floor += n

        # Cadenced actions fire on the clock, after the burn, so a customer who
        # was already leaving does not get a parting shot.
        for cust in list(self.seated()):
            if cust.patience > 0:
                self._fire("every", cust)
                self._fire("patience_below", cust)

        self._settle_patience()

        if not self.over:
            for i, cust in enumerate(self.chairs):
                if cust is None and self.walk_up[i] <= 0:
                    self._spawn(i)

    def _settle_patience(self):
        """Anything that touches patience outside a tick still has to check the
        door. Every patience mutation in the engine ends here."""
        for i, cust in enumerate(self.chairs):
            if cust is not None and cust.patience <= 0:
                self._walk(i)

    def _walk(self, chair):
        cust = self.chairs[chair]
        cust.patience = 0
        cust.state = "walked"
        lost = cust.unsigned_margin
        self.lost_to_walks += lost
        self.stat["customers_walked"] += 1
        if cust.offer is not None:
            self.discard.append(cust.offer.product)
            cust.offer = None
        self.events.append(
            "[%s] %s walks out%s." % (cust.key, cust.name,
                                      " with $%s unsigned" % _money(lost)
                                      if lost else ""))
        self._vacate(chair)

    def _vacate(self, chair):
        self.chairs[chair] = None
        self.walk_up[chair] = self.cfg["walk_up_ticks"]
        if self.at == chair:
            self.at = None

    # --------------------------------------------------------------- actions
    def _fire(self, ttype, cust, ctx=None):
        """The objection engine. Everything a customer does to you comes
        through here, so an archetype is a data edit."""
        ctx = ctx or {}
        fired = []
        for act in cust.archetype.get("actions", []):
            trig = act["trigger"]
            if trig["type"] != ttype:
                continue

            if ttype == "every":
                last = cust.action_state.get(act["id"], 0)
                if cust.ticks_on_floor - last < trig["ticks"]:
                    continue
                cust.action_state[act["id"]] = cust.ticks_on_floor
            else:
                if not self._matches(trig, cust, ctx):
                    continue
                last = cust.action_state.get(act["id"])
                if trig.get("once") and last is not None:
                    continue
                cd = act.get("cooldown", 0)
                if cd and last is not None and self.tick - last < cd:
                    continue
                cust.action_state[act["id"]] = self.tick

            self._apply_effect(act, cust, ctx)
            self.stat["actions_fired"] += 1
            fired.append(act)
            # Announced, not logged: an action can fire while you are across
            # the floor with someone else, and a floor-wide one has to be
            # impossible to miss.
            self.action_log.append({
                "key": cust.key, "customer": cust.name,
                "name": act["name"], "line": act.get("line", ""),
                "effect": dict(act["effect"]),
                "here": self.chairs[self.at] is cust if self.at is not None
                        else False,
            })
        return fired

    def _matches(self, trig, cust, ctx):
        t = trig["type"]
        if t == "on_offer":
            if "short_at" in trig and ctx.get("short", 0) < trig["short_at"]:
                return False
            if "rank_worse_than" in trig and \
                    ctx.get("rank", 0) <= trig["rank_worse_than"]:
                return False
            return True
        if t == "on_sale":
            if "rank_better_than" in trig and \
                    ctx.get("rank", 99) >= trig["rank_better_than"]:
                return False
            return True
        if t == "patience_below":
            return cust.patience < trig["at"]
        return False

    def _apply_effect(self, act, cust, ctx):
        eff = act["effect"]
        if "threshold" in eff:
            cust.threshold += eff["threshold"]
        if "appeal" in eff and cust.offer is not None:
            cust.offer.appeal += eff["appeal"]
        if "margin" in eff and cust.offer is not None:
            cust.offer.margin += eff["margin"]
        if "patience_self" in eff:
            cust.patience = min(cust.max_patience,
                                cust.patience + eff["patience_self"])
        if "patience_floor" in eff:
            for other in self.seated():
                if other is not cust:
                    other.patience = min(other.max_patience,
                                         other.patience + eff["patience_floor"])
        if "discard_hand" in eff:
            for _ in range(abs(eff["discard_hand"])):
                if self.hand:
                    self.discard.append(
                        self.hand.pop(self.rng.randrange(len(self.hand))))
            self._draw_up()
        if "margin_bonus" in eff and ctx.get("sale") is not None:
            ctx["sale"]["margin"] += eff["margin_bonus"]
            ctx["sale"]["bonus"] = ctx["sale"].get("bonus", 0) + eff["margin_bonus"]
            self.stat["margin_bonus"] += eff["margin_bonus"]

    # ---------------------------------------------------------------- moving
    def approach(self, chair):
        """Going back to whoever you were last with is free. Only changing your
        mind about who to work costs the floor a tick."""
        if self.over:
            return Result(False, "The floor is closed.")
        if not (0 <= chair < len(self.chairs)):
            return Result(False, "No such chair.")
        if self.chairs[chair] is None:
            return Result(False, "Nobody is sitting there.")
        if self.at == chair:
            return Result(False, "You are already standing with %s."
                          % self.chairs[chair].name)

        cust = self.chairs[chair]
        cost = 0 if cust is self.last_customer else self.cfg["approach_ticks"]
        self.at = chair
        self.last_customer = cust
        self.stat["approaches"] += 1
        if cost:
            self._burn(cost, "approach")
        return Result(True, "You %s %s."
                      % ("go back to" if not cost else "walk over to",
                         cust.name), kind="move", free=not cost)

    def leave(self):
        if self.at is None:
            return Result(False, "You are already out on the floor.")
        self.at = None
        return Result(True, "You step back out onto the floor.", kind="move")

    # ----------------------------------------------------------------- cards
    def _here(self):
        """(customer, refusal). Every action with a customer starts here."""
        if self.over:
            return None, Result(False, "The floor is closed.")
        if self.at is None:
            return None, Result(False, "You have to go stand with someone first.")
        cust = self.chairs[self.at]
        if cust is None:
            return None, Result(False, "Nobody is sitting there.")
        return cust, None

    def play_card(self, index):
        cust, refusal = self._here()
        if refusal:
            return refusal
        if not (0 <= index < len(self.hand)):
            return Result(False, "No such card.")
        if self.hand[index]["kind"] == "product":
            return self.place(index)
        return self._support(cust, index)

    def place(self, index):
        """Costs a tick and shows you only a BAND. Placing is the price of
        information here - reading a priority list by putting products in front
        of people costs the same as any other read in the game."""
        cust, refusal = self._here()
        if refusal:
            return refusal
        if not (0 <= index < len(self.hand)):
            return Result(False, "No such card.")
        card = self.hand[index]
        if card["kind"] != "product":
            return Result(False, "%s is not a product." % card["name"])
        if cust.offer is not None:
            return Result(False, "The %s is already on the table - offer it or "
                                 "drop it." % cust.offer.product["name"])
        if cust.owns(card["id"]):
            return Result(False, "%s already took the %s."
                          % (cust.name, card["name"]))

        appeal = cust.appeal_for(card["interest"])
        cust.offer = Offer(card, appeal, card["margin"])
        band = self.cat.objection_for(cust.threshold - appeal)["label"]

        self.hand.pop(index)
        self.stat["places"] += 1
        self._draw_up()
        self._burn(self.cfg["place_ticks"], "place")
        return Result(True, "You put the %s in front of %s."
                      % (card["name"], cust.name), kind="place", band=band)

    def _support(self, cust, index):
        card = self.hand[index]
        if card.get("needs_offer") and cust.offer is None:
            return Result(False, "%s needs something on the table."
                          % card["name"])

        offer = cust.offer
        if offer is not None:
            bump = card.get("appeal", 0)
            if card.get("appeal_per_sale"):
                bump += card["appeal_per_sale"] * len(cust.unsigned)
            offer.appeal += bump
            delta = card.get("margin", 0)
            offer.margin += delta
            if delta < 0:
                self.stat["margin_conceded"] -= delta
            elif delta > 0:
                self.stat["margin_padded"] += delta
            offer.applied.append(card["name"])

        pat = card.get("patience", 0)
        if pat:
            cust.patience = min(cust.max_patience, cust.patience + pat)

        revealed = None
        if card.get("reveal") == "room":
            cust.known_threshold = True
            cust.known_top_category = self.cat.category_of(cust.top_interest)
            revealed = cust.known_top_category

        self.hand.pop(index)
        self.discard.append(card)
        self.stat["cards_played"] += 1
        self._draw_up()
        self._settle_patience()
        self._burn(card.get("ticks", 1), "cards")

        if revealed:
            return Result(True, "%s. Their line is %d, and their number one is a %s "
                                "interest." % (card["name"], cust.threshold,
                                               self.cat.category_name(revealed)),
                          kind="reveal", category=revealed)
        return Result(True, card["name"] + ".", kind="support")

    # ---------------------------------------------------------------- offer
    def offer(self):
        """Free in time. What it costs is exposure: a short offer bruises their
        patience and is what provokes whatever this archetype does."""
        cust, refusal = self._here()
        if refusal:
            return refusal
        if cust.offer is None:
            return Result(False, "There is nothing on the table to offer.")

        o = cust.offer
        iid = o.product["interest"]
        rank = cust.ranks[iid]
        gap = max(0, cust.threshold - o.appeal)

        o.revealed = True
        cust.known_ranks.add(iid)
        cust.known_threshold = True
        self.stat["offers"] += 1

        # She evaluates at the threshold she had when you ASKED. A Hawk's
        # reaction to being asked cannot retroactively sink an offer that
        # already cleared.
        sale = self._settle(cust)
        if sale is not None:
            self._fire("on_sale", cust, {"rank": rank, "sale": sale})
        else:
            self.stat["failed_offers"] += 1
            cust.patience -= self.cfg["failed_offer_patience"]

        self._fire("on_offer", cust,
                   {"short": gap, "rank": rank, "sale": sale})
        self._settle_patience()

        if sale is not None:
            return Result(True, "%s takes the %s - $%s%s."
                          % (cust.name, sale["product"]["name"],
                             _money(sale["margin"]),
                             " (+$%s)" % _money(sale["bonus"])
                             if sale.get("bonus") else ""),
                          kind="sale", rank=rank, margin=sale["margin"],
                          bonus=sale.get("bonus", 0))
        return Result(True, "%d SHORT." % gap, kind="miss", short=gap, rank=rank)

    def _settle(self, cust):
        """Accept the moment appeal reaches the LINE - never above it, so a
        card that overshoots is margin you threw away."""
        o = cust.offer
        if o is None or o.appeal < cust.threshold:
            return None
        sale = {"product": o.product, "margin": o.margin, "bonus": 0}
        cust.unsigned.append(sale)
        cust.sales += 1
        cust.threshold += cust.threshold_per_sale
        cust.patience = min(cust.max_patience,
                            cust.patience + self.cfg["patience_per_sale"])
        cust.offer = None
        self.discard.append(sale["product"])
        self.stat["sales"] += 1
        self.events.append("[%s] agrees to %s - unsigned."
                           % (cust.key, sale["product"]["name"]))
        return sale

    def drop_offer(self):
        """Free. The ticks that built this offer are already spent - charging
        again for admitting it failed would just tax you for being wrong."""
        cust, refusal = self._here()
        if refusal:
            return refusal
        if cust.offer is None:
            return Result(False, "There is nothing on the table.")
        name = cust.offer.product["name"]
        cust.refused.append(cust.offer.product)
        self.discard.append(cust.offer.product)
        cust.offer = None
        self.stat["offers_dropped"] += 1
        return Result(True, "You take the %s back off the table." % name,
                      kind="drop")

    def dig(self, index):
        """Rummage for the right pitch. The floor pays for it either way."""
        if self.over:
            return Result(False, "The floor is closed.")
        if not (0 <= index < len(self.hand)):
            return Result(False, "No such card.")
        card = self.hand.pop(index)
        self.discard.append(card)
        self.stat["digs"] += 1
        self._draw_up()
        self._burn(self.cfg["dig_ticks"], "digs")
        return Result(True, "You set aside the %s." % card["name"], kind="dig")

    def close(self):
        """Sign it. The only thing in the game that banks margin."""
        cust, refusal = self._here()
        if refusal:
            return refusal

        if cust.demands and not cust.owns_category(cust.demands):
            return Result(False, "%s came in for %s protection and is not "
                                 "signing anything until they get it."
                          % (cust.name, self.cat.category_name(cust.demands)))

        chair = self.at
        if cust.offer is not None:
            self.discard.append(cust.offer.product)
            cust.offer = None

        banked = cust.unsigned_margin
        self.margin_banked += banked
        cust.state = "signed"
        self.stat["customers_signed"] += 1
        self.events.append(
            "[%s] %s signs%s." % (cust.key, cust.name,
                                  " for $%s" % _money(banked) if banked else
                                  " - no F&I, no margin"))
        if self.last_customer is cust:
            self.last_customer = None
        self._vacate(chair)
        return Result(True,
                      "%s signs for $%s." % (cust.name, _money(banked))
                      if banked else
                      "%s drives off with no F&I at all." % cust.name,
                      kind="close", margin=banked)

    # ---------------------------------------------------------------- status
    @property
    def over(self):
        return self.tick >= self.tick_budget

    @property
    def ticks_left(self):
        return max(0, self.tick_budget - self.tick)

    @property
    def margin_at_risk(self):
        return sum(c.unsigned_margin for c in self.seated())

    def report(self):
        lost_at_bell = (sum(c.unsigned_margin for c in self.seated())
                        if self.over else 0)
        return {
            "margin_banked": self.margin_banked,
            "quota": self.quota,
            "made_quota": self.margin_banked >= self.quota,
            "ticks": self.tick,
            "tick_budget": self.tick_budget,
            "customers_seen": self.served,
            "customers_signed": self.stat["customers_signed"],
            "customers_walked": self.stat["customers_walked"],
            "sales": self.stat["sales"],
            "offers": self.stat["offers"],
            "failed_offers": self.stat["failed_offers"],
            "places": self.stat["places"],
            "offers_dropped": self.stat["offers_dropped"],
            "close_rate": (float(self.stat["sales"]) / self.stat["offers"]
                           if self.stat["offers"] else 0.0),
            "margin_conceded": self.stat["margin_conceded"],
            "margin_padded": self.stat["margin_padded"],
            "margin_bonus": self.stat["margin_bonus"],
            "margin_lost_to_walks": self.lost_to_walks,
            "margin_lost_to_closing": lost_at_bell,
            "actions_fired": self.stat["actions_fired"],
            "digs": self.stat["digs"],
            "approaches": self.stat["approaches"],
            "ticks_cards": self.stat["ticks_cards"],
            "ticks_place": self.stat["ticks_place"],
            "ticks_digs": self.stat["ticks_digs"],
            "ticks_approach": self.stat["ticks_approach"],
        }


def _money(n):
    """1600 -> '1,600'. Negative margins keep their sign in front."""
    sign = "-" if n < 0 else ""
    return sign + "{:,}".format(abs(int(n)))

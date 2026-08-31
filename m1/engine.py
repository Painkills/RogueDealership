# -*- coding: utf-8 -*-
"""
Rogue Dealership - M1 engine (v3). Pure rules core.

No I/O, no printing, no input: play.py drives it, and a simulator can drive the
same object later without the two drifting apart. Deterministic given a seed.

The model in one breath: build TRUST and their hidden needs reveal themselves at
thresholds, spend Trust to buy PATIENCE when someone is about to walk, and pitch
what you know - or gamble on what you don't. Patience burns at a rate that
differs per customer, which is what forces you to triage the floor.
"""
import json
import math
import os
import random

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")


def _load(name, data_dir=None):
    path = os.path.join(data_dir or DATA_DIR, name)
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


class Catalog(object):
    """Everything loaded from data/. Read-only once built, except config."""

    def __init__(self, data_dir=None):
        needs = _load("needs.json", data_dir)
        products = _load("products.json", data_dir)
        cards = _load("cards.json", data_dir)
        archetypes = _load("archetypes.json", data_dir)

        self.needs = needs["needs"]
        self.need_ids = list(self.needs.keys())

        # The tray: always visible, always playable, never shuffled into the deck.
        self.tray = list(products["products"])
        self.products = {p["id"]: p for p in self.tray}

        self.cards = {c["id"]: c for c in cards["cards"]}
        self.archetypes = {a["id"]: a for a in archetypes["archetypes"]}
        self.base = archetypes["base"]
        self.config = _load("config.json", data_dir)

    def card(self, cid):
        return self.cards[cid]

    def need_name(self, nid):
        return self.needs[nid]["name"]

    def product_for(self, nid):
        for p in self.tray:
            if p["needs"][0] == nid:
                return p
        raise KeyError(nid)


class Result(object):
    """Outcome of one attempted action.

    ok=False means the rules refused the attempt and nothing was spent - not
    even the action. ok=True with kind 'miss' means it happened and it went
    badly, which costs plenty.
    """

    def __init__(self, ok, msg, kind="invalid", **data):
        self.ok = ok
        self.msg = msg
        self.kind = kind
        self.data = data

    def __repr__(self):
        return "Result(%s, %r, %r)" % (self.ok, self.kind, self.msg)


class Customer(object):
    def __init__(self, key, archetype, needs, patience, top_patience, budget, cfg):
        self.key = key
        self.archetype = archetype
        self.name = archetype["name"]

        self.reveal1 = archetype["reveal1"]
        self.reveal2 = archetype["reveal2"]
        self.decay = archetype.get("decay", cfg["patience_decay_per_round"])

        # max_patience is where this customer's bar TOPS OUT; patience is where
        # they actually walked in, which is often already partway down it.
        self.max_patience = top_patience
        self.patience = patience
        self.trust = cfg["starting_trust"]

        # The wallet. Denominated in the same units as margin, so a customer's
        # budget reads directly as "what this customer is worth to you" - which
        # is what makes it a triage input and not just a second clock.
        self.budget = budget
        self.start_budget = budget

        self.needs = list(needs)          # the two hidden slots
        self.revealed = [False, False]    # permanent once fired

        self.sold = []
        self.missed = []
        self.eliminated = set()           # needs a miss proved they do NOT have

        self.state = "floor"              # floor | away | gone
        self.exit_reason = None           # walked | tapped
        self.walks = 0
        self.walked_on_round = None

    @property
    def playable(self):
        return self.state == "floor"

    @property
    def rounds_left(self):
        """Whole rounds before they walk, ignoring anything you might do."""
        if self.decay <= 0:
            return 99
        return int(math.ceil(float(self.patience) / self.decay))

    @property
    def next_threshold(self):
        """The Trust that fires the next reveal, or None if both are known.

        Keyed to HOW MANY needs you already know, not to slot index. Learning
        one need by a lucky blind pitch must not make the expensive second
        reveal cheap - that would erase Reserved's entire axis.
        """
        known = sum(1 for r in self.revealed if r)
        if known == 0:
            return self.reveal1
        if known == 1:
            return self.reveal2
        return None

    def known_needs(self):
        return [self.needs[i] for i in (0, 1) if self.revealed[i]]

    def known_absent(self, nid):
        """Provably not one of their needs - a miss proved it, or you know both."""
        if nid in self.eliminated:
            return True
        return all(self.revealed) and nid not in self.needs


class Game(object):
    def __init__(self, catalog=None, seed=None, floor=None):
        self.cat = catalog or Catalog()
        self.cfg = self.cat.config
        self.rng = random.Random(seed)
        self.seed = seed

        self.round_no = 1
        self.margin = 0
        self.actions_left = self.cfg["actions_per_round"]
        self.reshuffles = 0
        self.events = []
        self.offers = 0
        self.blind_offers = 0
        self.stat_actions_unspent = 0
        self.stat_cards_unplayed = 0
        self.first_margin_action = None   # actions spent before the first sale
        self.actions_taken = 0

        self.customers = self._build_floor(floor)
        self.draw_pile, self.discard_pile, self.hand = self._build_deck(), [], []
        self.deck_size = len(self.draw_pile)
        self._draw_up()

    # ---------------------------------------------------------------- setup
    def _build_floor(self, floor):
        ids = list(self.cat.archetypes.keys())
        if floor is None:
            n = min(self.cfg["floor_size"], len(ids))
            picked = (self.rng.sample(ids, n) if self.cfg.get("unique_archetypes", True)
                      else [self.rng.choice(ids) for _ in range(self.cfg["floor_size"])])
        else:
            picked = list(floor)

        out = []
        cfg = self.cfg
        jitter = cfg["patience_jitter"]
        for i, aid in enumerate(picked):
            arch = self.cat.archetypes[aid]
            decay = arch.get("decay", cfg["patience_decay_per_round"])
            # Two DISTINCT needs out of six.
            needs = self.rng.sample(self.cat.need_ids, 2)

            # Where their bar tops out - jittered, so the triage ORDER differs
            # even on a floor you have seen before.
            top = max(cfg["patience_floor"],
                      arch["patience"] + self.rng.randint(-jitter, jitter))

            # Nobody is guaranteed to walk in fresh. Some are already partway to
            # the door, which is pressure from the very first round. Floored so
            # that a fast burner still gets a usable number of rounds - starting
            # someone at 2 Patience with decay 3 is not pressure, it is a loss.
            start = int(round(top * self.rng.uniform(
                cfg["start_patience_min_fraction"], 1.0)))
            start = max(start, cfg["patience_floor"],
                        cfg["start_patience_min_rounds"] * decay)
            start = min(start, top)

            budget = self.rng.randint(cfg["budget_min"], cfg["budget_max"])
            out.append(Customer(chr(ord("A") + i), arch, needs, start, top,
                                budget, cfg))
        return out

    def _build_deck(self):
        deck = []
        for card in self.cat.cards.values():
            deck.extend([card] * card["copies"])
        self.rng.shuffle(deck)
        return deck

    # ----------------------------------------------------------------- deck
    def _draw_up(self):
        while len(self.hand) < self.cfg["hand_size"]:
            if not self.draw_pile:
                if not self.discard_pile:
                    break
                self.draw_pile = self.discard_pile
                self.discard_pile = []
                self.rng.shuffle(self.draw_pile)
                self.reshuffles += 1
            self.hand.append(self.draw_pile.pop())

    # -------------------------------------------------------------- reveals
    def _check_reveals(self, cust):
        """Thresholds fire on CURRENT Trust, but a fired reveal is permanent -
        Reassure can drop you back below a threshold without ever un-teaching
        you what you already learned."""
        fired = []
        while True:
            bar = cust.next_threshold
            if bar is None or cust.trust < bar:
                break
            slot = cust.revealed.index(False)
            cust.revealed[slot] = True
            fired.append(slot)
        return fired

    def _reveal_text(self, cust, fired):
        if not fired:
            return ""
        names = ", ".join(self.cat.need_name(cust.needs[i]) for i in fired)
        return " They open up: %s." % names

    # ----------------------------------------------------------- play a card
    def play_card(self, card_index, customer_index=None):
        if self.over:
            return Result(False, "The shift is over.")
        if not (0 <= card_index < len(self.hand)):
            return Result(False, "No such card.")

        card = self.hand[card_index]
        cost = card.get("actions", 1)
        if self.actions_left < cost:
            return Result(False, "No actions left this round - end the round.")
        floor_wide = card.get("targets") == "floor"

        cust = None
        if not floor_wide:
            if customer_index is None:
                return Result(False, "%s has to target a customer." % card["name"])
            if not (0 <= customer_index < len(self.customers)):
                return Result(False, "No such customer.")
            cust = self.customers[customer_index]
            if cust.state == "gone":
                return Result(False, "%s has left the floor." % cust.key)
            if cust.state == "away":
                return Result(False, "%s stepped away and is not listening." % cust.key)

        if card["type"] == "convert":
            res = self._play_reassure(card, cust)
        elif floor_wide:
            res = self._play_floor_wide(card)
        else:
            res = self._play_rapport(card, cust)

        if res.ok:
            self.hand.pop(card_index)
            self.discard_pile.append(card)
            self._spend_action(cost)
            self.events.append(("[%s] " % cust.key if cust else "[floor] ") + res.msg)
        return res

    def _play_rapport(self, card, cust):
        cust.trust += card["trust"]
        fired = self._check_reveals(cust)
        return Result(True, "%s. Trust %d.%s" % (card["name"], cust.trust,
                                                 self._reveal_text(cust, fired)),
                      kind="reveal" if fired else "rapport", fired=fired)

    def _play_floor_wide(self, card):
        touched = [c for c in self.customers if c.playable]
        if not touched:
            return Result(False, "Nobody is on the floor to hear it.")
        bits = []
        any_fired = False
        for c in touched:
            c.trust += card["trust"]
            fired = self._check_reveals(c)
            any_fired = any_fired or bool(fired)
            bits.append("%s %d%s" % (c.key, c.trust,
                                     "*" if fired else ""))
            if fired:
                self.events.append("[%s]%s" % (c.key, self._reveal_text(c, fired)))
        return Result(True, "%s - Trust now %s." % (card["name"], ", ".join(bits)),
                      kind="reveal" if any_fired else "rapport")

    def _play_reassure(self, card, cust):
        cost = self.cfg["reassure_trust_cost"]
        if cust.trust < cost:
            return Result(False, "Reassure costs %d Trust; %s only trusts you %d."
                          % (cost, cust.key, cust.trust))
        gain = self.cfg["reassure_patience_gain"]
        cust.trust -= cost
        cust.patience += gain
        # Trust only went down, so no reveal can fire - and none can un-fire.
        return Result(True, "You reassure %s: %d Trust becomes %d Patience (now %d, %s)."
                      % (cust.key, cost, gain, cust.patience,
                         self._eta(cust)), kind="rapport")

    # --------------------------------------------------------------- pitch
    def pitch(self, product_index, customer_index):
        if self.over:
            return Result(False, "The shift is over.")
        if self.actions_left <= 0:
            return Result(False, "No actions left this round - end the round.")
        if not (0 <= product_index < len(self.cat.tray)):
            return Result(False, "No such product.")
        if not (0 <= customer_index < len(self.customers)):
            return Result(False, "No such customer.")

        product = self.cat.tray[product_index]
        cust = self.customers[customer_index]
        need = product["needs"][0]

        if cust.state == "gone":
            return Result(False, "%s has left the floor." % cust.key)
        if cust.state == "away":
            return Result(False, "%s stepped away and is not listening." % cust.key)
        if product["id"] in cust.sold:
            return Result(False, "%s already bought the %s." % (cust.key, product["name"]))
        if cust.known_absent(need):
            return Result(False, "You already know %s does not need %s."
                          % (cust.key, self.cat.need_name(need)))

        # No Trust gate. Pitching blind is always legal - that is the gamble.
        blind = need not in cust.known_needs()
        self.offers += 1
        if blind:
            self.blind_offers += 1

        if need in cust.needs:
            slot = cust.needs.index(need)
            # A lucky blind hit is also informative: you just proved what it is.
            cust.revealed[slot] = True
            self.margin += product["margin"]
            cust.patience -= self.cfg["pitch_patience"]
            cust.sold.append(product["id"])
            # The wallet is never a gate - m0's rule. A sale bigger than what is
            # left goes through and they stretched for it; the wallet emptying
            # ends the interaction AFTER the sale, it never blocks one.
            cust.budget -= product["margin"]
            if self.first_margin_action is None:
                self.first_margin_action = self.actions_taken + 1
            self._spend_action()
            tapped = self._check_tapped(cust)
            if not tapped:
                self._check_walk(cust)
            self.events.append("[%s] SOLD %s for %d." % (cust.key, product["name"],
                                                         product["margin"]))
            return Result(True, "SOLD - %s for %d margin.%s%s"
                          % (product["name"], product["margin"],
                             " Blind, and it landed." if blind else "",
                             " TAPPED OUT - wallet empty, they are done."
                             if tapped else " Budget %d left." % cust.budget),
                          kind="sale", blind=blind, gain=product["margin"],
                          tapped=tapped)

        cust.patience -= self.cfg["pitch_patience"] + self.cfg["miss_patience_extra"]
        cust.missed.append(product["id"])
        cust.eliminated.add(need)   # a miss is information, bought with Patience
        self._spend_action()
        self._check_walk(cust)
        left = self._candidates_left(cust)
        self.events.append("[%s] REFUSED %s." % (cust.key, product["name"]))
        return Result(True, "REFUSED - not %s. Patience %d, and %s."
                      % (self.cat.need_name(need), max(0, cust.patience), left),
                      kind="miss", blind=blind)

    def _candidates_left(self, cust):
        unknown_slots = sum(1 for r in cust.revealed if not r)
        if not unknown_slots:
            return "you now know both"
        pool = [n for n in self.cat.need_ids
                if not cust.known_absent(n) and n not in cust.known_needs()]
        return "%d of %d left for the last %s" % (
            unknown_slots, len(pool), "need" if unknown_slots == 1 else "two needs")

    def _eta(self, cust):
        return "~%d rnd" % cust.rounds_left

    def _spend_action(self, cost=1):
        # actions_taken counts PLAYS, not action points, because it feeds the
        # "how long before something happens" metric - a free card is still a
        # thing you did.
        self.actions_left -= cost
        self.actions_taken += 1

    # ---------------------------------------------------------------- rounds
    def end_round(self):
        if self.cfg.get("discard_hand_each_round", True):
            self.stat_cards_unplayed += len(self.hand)
            self.discard_pile.extend(self.hand)
            self.hand = []
        else:
            self.stat_cards_unplayed += len(self.hand)
        self.stat_actions_unspent += max(0, self.actions_left)

        for cust in self.customers:
            if cust.state == "floor":
                cust.patience -= cust.decay      # per-customer burn rate
                self._check_walk(cust)

        self.round_no += 1

        for cust in self.customers:
            if cust.state == "away":
                # Away for walk_return_rounds full rounds, back on the one after.
                missed = self.round_no - cust.walked_on_round - 1
                if missed >= self.cfg["walk_return_rounds"]:
                    cust.state = "floor"
                    cust.patience = self.cfg["walk_return_patience"]
                    self.events.append("[%s] %s is back - Patience %d, not restored."
                                       % (cust.key, cust.name, cust.patience))

        self.actions_left = self.cfg["actions_per_round"]
        self._draw_up()
        return Result(True, "Round %d." % self.round_no, kind="round")

    def _check_tapped(self, cust):
        """Wallet empty. This is the GOOD ending - you took everything they had,
        as opposed to walking, where you ran out of time."""
        if cust.budget > 0 or cust.state != "floor":
            return False
        cust.state = "gone"
        cust.exit_reason = "tapped"
        self.events.append("[%s] %s is TAPPED OUT - nothing left to spend."
                           % (cust.key, cust.name))
        return True

    def _check_walk(self, cust):
        if cust.patience > 0 or cust.state != "floor":
            return
        cust.patience = 0
        cust.walks += 1
        cust.walked_on_round = self.round_no
        if self.cfg.get("walk_returns", False) and cust.walks == 1:
            cust.state = "away"
            self.events.append("[%s] %s walks off - they may come back." % (cust.key, cust.name))
        else:
            cust.state = "gone"
            cust.exit_reason = "walked"
            self.events.append("[%s] %s is done with you." % (cust.key, cust.name))

    @property
    def stalled(self):
        """Hit the safety valve rather than emptying the floor."""
        return self.round_no > self.cfg.get("max_rounds", 40)

    @property
    def over(self):
        # Reassure can out-pace decay forever, so "everyone walked" is not on
        # its own a guaranteed terminator. max_rounds is a backstop, not a
        # clock - careful play ends around round 14 and never reaches it.
        return self.stalled or all(c.state == "gone" for c in self.customers)

    # ---------------------------------------------------------------- report
    def report(self):
        sales = sum(len(c.sold) for c in self.customers)
        misses = sum(len(c.missed) for c in self.customers)
        rounds = max(1, self.round_no - 1)
        return {
            "margin": self.margin,
            "sales": sales,
            "misses": misses,
            "offers": self.offers,
            "blind_offers": self.blind_offers,
            "close_rate": (float(sales) / self.offers) if self.offers else 0.0,
            "rounds": rounds,
            "stalled": self.stalled,
            "first_margin_action": self.first_margin_action,
            "actions_unspent": self.stat_actions_unspent,
            "cards_unplayed": self.stat_cards_unplayed,
            "actions_unspent_per_round": float(self.stat_actions_unspent) / rounds,
            "cards_unplayed_per_round": float(self.stat_cards_unplayed) / rounds,
            "tapped_out": sum(1 for c in self.customers if c.exit_reason == "tapped"),
            "walked": sum(1 for c in self.customers if c.exit_reason == "walked"),
            "customers": [{
                "key": c.key,
                "name": c.name,
                "state": c.state,
                "exit_reason": c.exit_reason,
                "decay": c.decay,
                "budget": c.budget,
                "start_budget": c.start_budget,
                "needs": [self.cat.need_name(n) for n in c.needs],
                "diagnosed": sum(1 for r in c.revealed if r),
                "sold": [self.cat.products[p]["name"] for p in c.sold],
                "missed": [self.cat.products[p]["name"] for p in c.missed],
                "trust": c.trust,
                "patience": c.patience,
            } for c in self.customers],
        }

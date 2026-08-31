# -*- coding: utf-8 -*-
"""
Auto Sales Executive - M0 rules core.

One model, driven by both play.py (a human) and sim.py (a policy), so the game you
play and the game the simulator measures cannot drift apart.

THE MODEL
    Buy-In is how close the customer is to saying yes.
    Pitching raises it. Charging more lowers it. They have a hidden number - find it.

  - Each line is a STACK of products sold one at a time, cheapest first.
  - Buy-In is visible and resets for each new product.
  - Each LINE has one hidden Threshold T, constant for the whole encounter.
      Buy-In >  T  -> SOLD, and you learn T <= Buy-In   (ceiling)
      Buy-In <  T  -> REFUSED: patience cost, the product is LOST, and
                      you learn T > Buy-In (floor)
      Buy-In == T  -> PERFECT PITCH: sold, T revealed, bonus
  - A refusal costs you the product, so every offer is a commitment. That is what
    spreads the search across the stack: product one buys information with real
    money at stake, products two and three spend it.
  - Pitching is unbounded - the cost of over-pitching is TEMPO. Energy wasted getting
    a product further above their number than it needed to be is energy you no longer
    have for the next product. Knowledge (Key Question) is simply the most efficient
    buy-in in the game: one card for what would take two or three Pitches.
  - Markup is the only way to earn above sticker and it is paid for in Buy-In:
      +10% of sticker  ->  -2 x Balk buy-in
  - BUDGET is a visible wallet shared by all three lines. Sales draw it down. An offer
    bigger than what is left still goes through - they stretch - but the moment the
    wallet is empty the sale is over. Draining it is a win, not a failure.
  - Rapport is a persistent pool. Objection damage eats Rapport before Patience, and
    Key Questions spend it. Armour or discovery: pick one.
"""
import json
import os

LINES = ("vehicle", "protection", "financing")
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")

DEFAULT_CFG = {
    "energy_per_turn": 3,
    "max_turns": 10,
    "hand_size": 5,
    "offer_energy": 1,          # making the pitch costs you - you cannot spam offers
    "refusal_patience": 8,     # patience lost when they say no
    "markup_step": 0.10,        # one "step" of markup
    "buyin_per_step": 2.0,      # buy-in cost of one step, before Balk
    "max_buyin": 30,
    # Each turn rolls a severity. Most are ordinary, some sting, a few carry a rider,
    # and sometimes they just listen - which is a free turn you can spend how you like.
    "severity_weights": {"quiet": 15, "standard": 45, "heavy": 25, "rider": 15},
    "heavy_multiplier": 1.5,
    "markup_max": 0.60,         # how far above sticker you may push
    "markup_min": -0.30,        # how far you may discount
    "commission_rate": 0.15,
    "perfect_bonus": 0.10,      # extra commission on a perfect pitch
    "objection_escalation": 0.05,
}


# ------------------------------------------------------------------ records
class Rec(object):
    """Tiny attribute bag built from a dict."""
    def __init__(self, d):
        self.__dict__.update(d)

    def get(self, k, default=None):
        return self.__dict__.get(k, default)

    def __repr__(self):
        return "<%s>" % self.__dict__.get("id", "rec")


def load_data(path=DATA):
    with open(os.path.join(path, "products.json")) as fh:
        raw = json.load(fh)
    products = {}
    stacks = {}
    for line in LINES:
        stacks[line] = []
        for p in raw[line]:
            p = dict(p)
            p["line"] = line
            products[p["id"]] = Rec(p)
            stacks[line].append(p["id"])

    with open(os.path.join(path, "cards.json")) as fh:
        cards = [Rec(c) for c in json.load(fh) if "id" in c]
    with open(os.path.join(path, "objections.json")) as fh:
        objections = dict((o["id"], Rec(o)) for o in json.load(fh) if "id" in o)
    with open(os.path.join(path, "customers.json")) as fh:
        customers = []
        for c in json.load(fh):
            if "id" not in c:
                continue
            c = dict(c)
            c["knowledge"] = [Rec(k) for k in c["knowledge"]]
            customers.append(Rec(c))
    return {"products": products, "stacks": stacks, "cards": cards,
            "objections": objections, "customers": customers}


def starter_deck(cards, copies=2):
    """Deck ratio is a design choice: pitch cards need to be common enough that a hand
    is never dead. A card may declare its own `copies`."""
    starters = [c for c in cards if c.get("starter")]
    if not starters:
        raise ValueError("no cards flagged starter")
    out = []
    for c in starters:
        out.extend([c] * int(c.get("copies", copies)))
    return out


# -------------------------------------------------------------- line state
class Line(object):
    """Runtime state for one line: its stack, the current product, and what you know."""

    def __init__(self, name, product_ids, products, max_buyin):
        self.name = name
        self.stack = [products[i] for i in product_ids]
        self.idx = 0
        self.pitch = 0.0            # generic pitch on the current product (CAPPED)
        self.kpitch = 0.0           # buy-in from knowledge cards (UNCAPPED)
        self.markup = 0.0           # fraction above sticker
        self.lo = 0                 # T > lo   (from refusals)
        self.hi = max_buyin         # T <= hi  (from sales)
        self.known = None           # exact T, once revealed
        self.threshold_mod = 0      # riders can push T up
        self.sold = []              # [(product, price, perfect)]
        self.lost = []              # products they refused outright
        self.refusals = 0
        self.locked_turn = -1       # lock_line rider

    @property
    def product(self):
        return self.stack[self.idx] if self.idx < len(self.stack) else None

    @property
    def done(self):
        return self.idx >= len(self.stack)

    def advance(self):
        self.idx += 1
        self.pitch = 0.0
        self.kpitch = 0.0
        self.markup = 0.0

    def revenue(self):
        return sum(p for _, p, _ in self.sold)

    def potential(self):
        """Sticker value of this whole stack - the denominator for 'how am I doing'."""
        return sum(p.sticker for p in self.stack)

    def remaining(self):
        return sum(p.sticker for p in self.stack[self.idx:])


# --------------------------------------------------------------- encounter
class Encounter(object):
    """One negotiation. Subclass and override choose_action to drive it."""

    def __init__(self, customer, deck, data, cfg=None, rng=None, seed_shuffle=True):
        self.c = customer
        self.data = data
        self.cfg = dict(DEFAULT_CFG)
        if cfg:
            self.cfg.update(cfg)
        import random as _r
        self.rng = rng or _r.Random()

        self.lines = dict((l, Line(l, data["stacks"][l], data["products"], self.cfg["max_buyin"]))
                          for l in LINES)
        self.patience = float(customer.patience)
        self.rapport = 0
        self.turn = 0
        self.energy = 0
        self.drain_next = 0
        self.deck = list(deck)
        if seed_shuffle:
            self.rng.shuffle(self.deck)
        self.discard = []
        self.hand = []
        self.knowledge_deck = list(customer.knowledge)
        self.rng.shuffle(self.knowledge_deck)
        self.perfect_pitches = 0
        self.spent = 0
        self.severity = "standard"
        self.log = []
        self._ended = False

    # ---------------------------------------------------------- deck plumbing
    def draw(self, n):
        for _ in range(int(n)):
            if not self.deck:
                if not self.discard:
                    return
                self.deck = self.discard
                self.discard = []
                self.rng.shuffle(self.deck)
            self.hand.append(self.deck.pop())

    def roll_severity(self):
        """How hard is this turn? Rolled independently of which objection comes up, so an
        objection that HAS a rider usually lands as plain damage."""
        w = self.cfg["severity_weights"]
        keys = list(w.keys())
        total = float(sum(w[k] for k in keys))
        r = self.rng.random() * total
        acc = 0.0
        for k in keys:
            acc += w[k]
            if r < acc:
                return k
        return keys[-1]

    # ------------------------------------------------------------- buy-in math
    def threshold(self, line):
        """The hidden number for this line, including any rider that pushed it up."""
        return self.c.thresholds[line.name] + line.threshold_mod

    def markup_penalty(self, line):
        steps = line.markup / self.cfg["markup_step"]
        return steps * self.cfg["buyin_per_step"] * self.c.balk

    def buyin(self, line):
        """Visible Buy-In for the product on top of this line's stack."""
        if line.product is None:
            return 0
        raw = (line.product.base_buyin + line.pitch + line.kpitch
               - self.markup_penalty(line))
        return int(round(max(0.0, min(float(self.cfg["max_buyin"]), raw))))

    def sticker(self, product):
        """One price for everyone. What differs per customer is the WALLET."""
        return product.sticker

    def remaining_budget(self):
        return max(0, self.c.budget - self.spent)

    def price(self, line):
        if line.product is None:
            return 0
        return int(round(self.sticker(line.product) * (1.0 + line.markup)))

    def locked(self, line):
        return line.locked_turn == self.turn

    def workable(self, line):
        return (not line.done) and (not self.locked(line))

    # ----------------------------------------------------------- the offer
    def offer(self, line):
        """Offer the current product. Returns (result, price, buyin, threshold_if_revealed)."""
        eff = self.buyin(line)
        T = self.threshold(line)
        product = line.product
        price = self.price(line)

        if eff == T:
            result = "PERFECT"
            line.known = T
            line.lo = max(line.lo, T - 1)
            line.hi = min(line.hi, T)
            self.perfect_pitches += 1
            line.sold.append((product, price, True))
            self.spent += price
            line.advance()
        elif eff > T:
            result = "SOLD"
            line.hi = min(line.hi, eff)
            line.sold.append((product, price, False))
            self.spent += price
            line.advance()
        else:
            # A refusal is not a retry. They said no to THIS product and you move on -
            # which is what makes each offer a real commitment, and what spreads the
            # search for T across the stack instead of collapsing it into one item.
            result = "REFUSED"
            line.lo = max(line.lo, eff)
            line.refusals += 1
            self.patience -= self.cfg["refusal_patience"]
            line.lost.append(product)
            line.advance()

        self.on_offer_result(line, result, product, price, eff, T)
        return result, price, eff, (T if result == "PERFECT" else None)

    def adjust_markup(self, line, steps):
        """Move the price up or down by whole steps. Free - setting your price is a
        decision, not a card you have to draw. The cost is paid in Buy-In."""
        step = self.cfg["markup_step"]
        want = line.markup + steps * step
        line.markup = max(self.cfg["markup_min"], min(self.cfg["markup_max"], want))
        return line.markup

    def set_markup(self, line, markup):
        """Set the price directly. The offer screen picks a price off a ladder, so the
        whole money-vs-buy-in tradeoff is one decision instead of a fiddly slider."""
        line.markup = max(self.cfg["markup_min"], min(self.cfg["markup_max"], markup))
        return line.markup

    def markup_ladder(self, line):
        """Every price you could offer this at, and what it does to Buy-In."""
        step = self.cfg["markup_step"]
        lo = int(round(self.cfg["markup_min"] / step))
        hi = int(round(self.cfg["markup_max"] / step))
        keep = line.markup
        out = []
        for n in range(lo, hi + 1):
            line.markup = n * step
            out.append((n * step, self.price(line), self.buyin(line)))
        line.markup = keep
        return out

    def skip(self, line):
        """Give up on the current product and move to the next in the stack."""
        line.advance()

    def narrow(self, line):
        """Read The Room: one bit of information about where T sits in the open range."""
        if line.known is not None:
            return None
        T = self.threshold(line)
        lo, hi = line.lo, line.hi
        if hi - lo <= 1:
            return None
        mid = (lo + 1 + hi) // 2
        if T <= mid:
            line.hi = min(line.hi, mid)
            return ("<=", mid)
        line.lo = max(line.lo, mid)
        return (">", mid)

    # ------------------------------------------------------- playing a card
    def can_play(self, card, line_name):
        if card.cost > self.energy:
            return False
        if card.get("rapport_cost", 0) > self.rapport:
            return False
        if self.needs_target(card):
            if line_name is None:
                return False
            line = self.lines[line_name]
            if not self.workable(line):
                return False
            if card.get("line") and card.get("line") != line_name:
                return False
        if card.get("knowledge") and not self.knowledge_deck:
            return False
        return True

    def needs_target(self, card):
        return bool(card.get("buyin") or card.get("markup") or card.get("narrow"))

    def play(self, card, line_name=None):
        self.energy -= card.cost
        self.hand.remove(card)
        self.discard.append(card)
        line = self.lines[line_name] if line_name else None
        note = None

        if card.get("buyin"):
            line.pitch += card.get("buyin")
        if card.get("markup"):
            line.markup = max(-0.5, line.markup + card.get("markup"))
        if card.get("narrow"):
            note = self.narrow(line)
        if card.get("rapport"):
            self.rapport += card.get("rapport")
        if card.get("rapport_cost"):
            self.rapport -= card.get("rapport_cost")
        if card.get("knowledge"):
            note = self.take_knowledge()
        if card.get("draw"):
            self.draw(card.get("draw"))
        if card.get("patience_cost"):
            self.patience -= card.get("patience_cost")
        return note

    def take_knowledge(self):
        """Key Question: pull a customer-specific knowledge card and apply it."""
        if not self.knowledge_deck:
            return None
        k = self.knowledge_deck.pop()
        line = self.lines[k.line]
        if not line.done:
            line.kpitch += k.buyin   # bypasses the pitch ceiling
        return k

    # --------------------------------------------------------------- scoring
    def revenue(self):
        return sum(l.revenue() for l in self.lines.values())

    def potential(self):
        """Their wallet is the real ceiling on revenue - so `take` reads as the share of
        their money you got, and can pass 100% on a sale they stretched for."""
        return int(self.c.budget)

    def commission(self):
        base = self.revenue() * self.cfg["commission_rate"]
        return base * (1.0 + self.cfg["perfect_bonus"] * self.perfect_pitches)

    def products_sold(self):
        return sum(len(l.sold) for l in self.lines.values())

    def products_total(self):
        return sum(len(l.stack) for l in self.lines.values())

    def all_done(self):
        return all(l.done for l in self.lines.values())

    def markup_captured(self):
        """Average markup fraction actually banked, across sold products."""
        got, base = 0, 0
        for l in self.lines.values():
            for p, price, _ in l.sold:
                got += price
                base += self.sticker(p)
        return (float(got) / base - 1.0) if base else 0.0

    def counters_it(self, card, objection):
        """A counter card answers an objection CATEGORY, not one specific objection.
        Add a new 'price' objection and every price answer already in the game covers
        it - no card silently becomes uncounterable."""
        c = card.get("counters")
        if not c or objection is None:
            return False
        return c == objection.get("category") or c == objection.id

    def can_act(self):
        """Is there anything left worth doing this turn? Used to auto-end the turn."""
        for card in self.hand:
            if self.needs_target(card):
                if any(self.can_play(card, n) for n in LINES):
                    return True
            elif self.can_play(card, None):
                return True
        if self.energy >= self.cfg["offer_energy"]:
            if any(self.workable(l) for l in self.lines.values()):
                return True
        return False

    # ------------------------------------------------------------ hooks
    def choose_action(self, objection, damage):
        """Return one of:
             ("card",   card, line_name_or_None)
             ("markup", steps, line_name)      # +1 / -1 step of price. Free.
             ("offer",  line_name)
             ("skip",   line_name)
             ("end",    None)
        """
        raise NotImplementedError

    def on_turn_start(self, objection, damage):
        pass

    def on_turn_end(self, objection, damage, absorbed, taken, countered):
        pass

    def on_offer_result(self, line, result, product, price, buyin, threshold):
        pass

    def on_action(self, action, card, line_name, note):
        pass

    # --------------------------------------------------------------- main loop
    def run(self):
        cfg = self.cfg
        for turn in range(1, int(cfg["max_turns"]) + 1):
            self.turn = turn
            self.energy = max(0, int(cfg["energy_per_turn"]) - self.drain_next)
            self.drain_next = 0

            self.severity = self.roll_severity()
            objection = None
            damage = 0.0
            if self.severity != "quiet" and self.c.objection_pool:
                objection = self.data["objections"][self.rng.choice(self.c.objection_pool)]
                damage = objection.damage * (1.0 + cfg["objection_escalation"] * (turn - 1))
                if self.severity == "heavy":
                    damage *= cfg["heavy_multiplier"]

            self.discard.extend(self.hand)
            self.hand = []
            self.draw(cfg["hand_size"])
            self.countered = False
            self.on_turn_start(objection, damage)

            actions_left = 200          # guard: a policy that stalls must not hang
            self._turns_taken = getattr(self, '_turns_taken', 0) + 1
            while True:
                actions_left -= 1
                if actions_left <= 0:
                    break
                action, card, line_name = self._normalise(self.choose_action(objection, damage))
                if action == "end":
                    break
                if action == "card":
                    if not self.can_play(card, line_name):
                        continue
                    if objection and self.counters_it(card, objection):
                        self.countered = True
                    note = self.play(card, line_name)
                    self.on_action(action, card, line_name, note)
                elif action == "markup":
                    line = self.lines[line_name]
                    if self.workable(line):
                        self.adjust_markup(line, card)      # `card` slot carries the steps
                elif action == "offer":
                    line = self.lines[line_name]
                    if self.workable(line) and self.energy >= self.cfg["offer_energy"]:
                        self.energy -= self.cfg["offer_energy"]
                        self.offer(line)
                        if self.spent >= self.c.budget:
                            # they are tapped out. You got everything they had.
                            return self._finish("MAXED_OUT")
                elif action == "skip":
                    line = self.lines[line_name]
                    if self.workable(line):
                        self.skip(line)
                if self.patience <= 0:
                    return self._finish("WALKED")
                if self.all_done():
                    return self._finish("CLEARED")

            # ------------- end of turn: the customer acts -------------
            absorbed = taken = 0.0
            if objection:
                absorbed = min(self.rapport, damage)
                self.rapport -= int(round(absorbed))
                taken = damage - absorbed
                self.patience -= taken
                if objection.get("rider") and self.severity == "rider":
                    self._apply_rider(objection)
            self._unspent = getattr(self, '_unspent', 0) + self.energy
            self._hand_left = getattr(self, '_hand_left', 0) + len(self.hand)
            self.on_turn_end(objection, damage, absorbed, taken, self.countered)

            if self.patience <= 0:
                return self._finish("WALKED")
            if self.all_done():
                return self._finish("CLEARED")

        return self._finish("TIME")

    def _normalise(self, a):
        if a is None:
            return ("end", None, None)
        if len(a) == 2:
            return (a[0], None, a[1]) if a[0] in ("offer", "skip") else (a[0], a[1], None)
        return a

    def _apply_rider(self, o):
        rider = o.get("rider")
        line = self.lines.get(o.get("line")) if o.get("line") else None
        if rider == "raise_threshold" and line:
            line.threshold_mod += int(o.get("amount", 1))
        elif rider == "lock_line" and line:
            line.locked_turn = self.turn + 1
        elif rider == "drain_energy":
            self.drain_next = int(o.get("amount", 1))
        elif rider == "knock_buyin" and line:
            line.pitch = max(0.0, line.pitch - o.get("amount", 1))

    def _finish(self, outcome):
        self._ended = True
        return {
            "outcome": outcome,
            "turns": self.turn,
            "revenue": self.revenue(),
            "commission": self.commission(),
            "sold": self.products_sold(),
            "total": self.products_total(),
            "perfect": self.perfect_pitches,
            "markup": self.markup_captured(),
            "refusals": sum(l.refusals for l in self.lines.values()),
            "potential": self.potential(),
            "take": (float(self.revenue()) / self.potential()) if self.potential() else 0.0,
            "unspent_energy": getattr(self, "_unspent", 0) / float(max(1, getattr(self, "_turns_taken", 1))),
            "cards_left": getattr(self, "_hand_left", 0) / float(max(1, getattr(self, "_turns_taken", 1))),
            "log": self.log,
        }

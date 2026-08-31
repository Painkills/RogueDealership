# Rogue Dealership — Design Document v2

> **Working title:** (unset) · **Genre:** Card-based sales-floor roguelike
> **Status:** concept / pre-prototype — not yet built, not yet playtested even on paper
> **Version:** v2.0 — **supersedes the approach in [`DESIGN.md`](DESIGN.md)**

This document does not build on `DESIGN.md` or [`m0/README.md`](m0/README.md). Those describe
an earlier design lineage — a Slay-the-Spire-style deck-builder with Energy/lanes/Resistance/
Objections, later evolved into a "Buy-In" hidden-number model — and remain valuable as a
historical record of real playtesting findings (rejected models, durable lessons about refusal
costs and core-verb ceilings). **v2 is a clean pivot**, not a merge: it starts from a different
premise and does not carry forward any mechanic from v1 or the m0 prototype.

---

## 1. The pitch

You are a Finance & Insurance (F&I) rep on a car dealership sales floor. At any moment, 2-3
customers are waiting, each carrying hidden **needs** — things they're seeking reassurance
about (reliability, security, affordability, and so on) — that only surface if you ask the
right questions. Your job each "shift" is to diagnose what a customer actually needs and offer
the product that answers it, before their patience runs out, while building rapport carefully
enough that they'll trust you enough to say yes at all. Do this across a run of shifts —
days, weeks, months — under shifting conditions (market pressure, seasonal effects, a boss's
quota mandate) that change what's easy and what's rewarded from one stretch to the next.

---

## 2. Design philosophy — why this shape

**Trust and Patience are two separate resources with distinct jobs, on purpose.**
Patience answers "how long will this customer stay and listen" — it only decays, it's spent by
the big-commitment action (pitching a product), and it's the hard limit on the whole
interaction. Trust answers "will they say yes to what I ask or offer" — it's built by Rapport
cards and spent by Question cards. Keeping these separate means a hard customer can be hard in
one of two very different ways (they won't sit still, or they won't open up), rather than
everything collapsing into a single generic "difficulty" number. The one deliberate exception
is **Offer a Discount**, which crosses the line on purpose (buys Patience at the cost of
margin, builds no Trust) — the exception exists because it's useful, not because the separation
is soft.

**Needs are organized as 3 categories × 3 needs, not a flat list.**
Vehicle / Deal / Person map onto the three real anchors of an F&I conversation: the car itself,
the financial structure of the deal, and the buyer's personal circumstances. This gives the
diagnosis minigame real structure (a two-tier reveal — category, then specific) instead of a
flat guess among nine options, and it gives every one of the nine needs a dedicated, pure
single-need product, plus exactly one cross-category dual per pair of categories (Vehicle↔Deal,
Vehicle↔Person, Deal↔Person) — no category pairing is skipped, and no dual repeats a category
with itself.

**"Needs," not "fears" — reframed on purpose, mechanics unchanged.**
The design started from fear-matching (loss aversion: what is this customer afraid of) and was
deliberately reframed to needs (positive framing: what is this customer seeking). This is a
relabeling, not a mechanical change — the same 9 slots, the same categories, the same matching
logic. A couple of terms were already neutral in either framing (Health) and needed no
translation at all.

**Product margin is the main stat; customer-facing cost is deliberately not tracked.**
Early iterations gave every product a "budget requirement" gate. That was cut: it double-counted
what the **Affordability** need already represents, and it diluted focus away from the actual
puzzle (does this product match this need, and does this customer trust me enough to accept
it). Margin is what you're optimizing; dual products are deliberately capped below the flagship
single's margin, because their reward is flexibility (matching either of two needs), not raw
payout — letting a flexible card also pay the best would make precise single-need diagnosis
pointless.

**"Mandate" is a run-level modifier, not a property of any one card.**
Which product your boss is pushing this shift should vary run to run (alongside other run
modifiers like tariffs or a tough season) — hardcoding it onto one specific product would make
that card's design and the run-variety system fight each other.

---

## 3. Needs taxonomy

| Category | Needs |
|---|---|
| **Vehicle** | Reliability, Durability, Security |
| **Deal** | Equity, Affordability, Value Retention |
| **Person** | Health, Stability, Convenience |

**Design provenance** (not shown to the player — internal reference only, mapping the original
fear-framed working terms to their needs-framed replacements):

| Original (fear-framed) | Current (need-framed) |
|---|---|
| Mechanical | Reliability |
| Wear | Durability |
| Loss | Security |
| Upside-down | Equity |
| Strain | Affordability |
| Depreciation | Value Retention |
| Job | Stability |
| Health | Health *(unchanged — already neutral)* |
| Hassle | Convenience |

---

## 4. Product roster (12)

**9 single-need products** — each is the dedicated, pure answer to exactly one need:

| Product | Need | Margin |
|---|---|---|
| Vehicle Service Contract | Reliability | 7 |
| Life and Disability Protection | Health | 6 |
| Involuntary Unemployment Protection | Stability | 6 |
| Trade-In Value Protection | Value Retention | 5 |
| GAP Insurance | Equity | 5 |
| Tire & Wheel Protection | Durability | 4 |
| Payment Flex Plan | Affordability | 3 |
| Concierge Service Plan | Convenience | 3 |
| Key Replacement | Security | 2 |

**3 cross-category dual products** — one per category-pair, patience cost **3** to pitch
(vs. 1 for singles), margin capped below the flagship single:

| Product | Needs matched | Margin | Category pair |
|---|---|---|---|
| Appearance / Value Retention Package | Value Retention + Durability | 5 | Deal↔Vehicle |
| Maintenance & Roadside Plan | Convenience + Reliability | 5 | Person↔Vehicle |
| Value Bundle | Affordability + Convenience | 4 | Deal↔Person |

**Perfect-match bonus**: if a dual product matches *both* of a customer's two hidden needs
exactly, it earns **+1 margin** on top of its base value.

---

## 5. Resource system

### Patience — "how long will they stay and listen"
- Base **15** at encounter start (varies by archetype, see §7)
- Decays **1 per turn**, passively, regardless of action
- Pitching a product costs **1 Patience** (single) or **3 Patience** (dual) — paid whether the
  pitch hits or misses
- A **failed/mismatched offer** costs an additional **3 Patience**
- Patience is the *only* limit on how many products one customer can accept — there is no
  separate cap on sale count. A customer who walks (Patience hits 0 mid-interaction) becomes
  unplayable for a turn or two, then returns with reduced Patience rather than being gone for
  good.

### Trust — "do they accept my offers and questions"
- Built only by **Rapport cards**
- Gates two separate thresholds:
  - **Ask threshold** (base **1**) — current Trust must meet/exceed this for a Question card to
    succeed
  - **Pitch threshold** (base **2**) — current Trust must meet/exceed this to attempt a product
    offer (a gate only — pitching itself does not spend Trust)
- Spent by Question cards: **1 Trust** for General Inquiry and Read the Room, **3 Trust** for
  Direct Probe
- Never spent by pitching — that cost lives entirely in Patience

---

## 6. Card catalog

### Question cards
| Card | Cost | Effect |
|---|---|---|
| **General Inquiry** | 1 Trust | Progressively reveals a need's category, then its specific value, on the targeted slot. Requires current Trust ≥ Ask threshold to succeed; below it, fails but gives bracketing feedback (closest passing/failing guess), letting the threshold be narrowed over repeated attempts if Read the Room hasn't been used |
| **Read the Room** | 1 Trust | Reveals the customer's exact Ask threshold number outright, removing the guessing game |
| **Direct Probe** | 3 Trust | Guarantees a full need reveal on the targeted slot, bypassing the Ask-threshold check entirely. No Patience cost — the cost is paid entirely in Trust, and it's steep enough to potentially drop the player below the Pitch threshold in one use |

### Rapport cards
| Card | Cost | Effect | Copies |
|---|---|---|---|
| **Small Talk** | 0 | +2 Trust | 1 (rare/emergency) |
| **Genuine Connection** | standard | +4 Trust | 3 (bread-and-butter) |
| **Offer a Discount** | standard | +4 Patience immediately; **-2 margin** on the very next offer made to this customer only (single-use); builds **no Trust** | 1 |

### Product cards
As listed in §4. Each customer holds **2 independent need slots** (duplicate categories
allowed — e.g. two Vehicle needs — but not the exact same need twice). Each slot is revealed
independently: there is no shortcut where learning one slot's category reveals a same-category
second slot's category for free.

---

## 7. Customer archetypes (starter 4)

Each non-baseline archetype isolates exactly one resource axis as its challenge, via additive
deltas on top of the base values (Ask 1 / Pitch 2 / Patience 15) — cards themselves are never
weakened, only the bar a given customer sets is raised:

| Archetype | Ask threshold | Pitch threshold | Patience | Axis stressed |
|---|---|---|---|---|
| **Easygoing** | 1 | 2 | 15 | None — baseline/tutorial |
| **Rushed** | 1 | 2 | 7 | Patience only |
| **Guarded** | 5 | 3 | 15 | Ask only — hard to get information, easy to close once trusted |
| **Picky** | 2 | 9 | 15 | Pitch only — easy to read, hard to actually close |

---

## 8. Floor / encounter structure

- **2-3 customers** occupy the floor simultaneously
- Each round, the player has a **shared action budget** spendable on any customer on the floor
  — this is the core triage puzzle: diagnosing one customer fully costs actions and rounds you
  aren't spending on the others, while every customer's Patience decays regardless
- A customer whose Patience hits 0 **walks** — they become unplayable for a turn or two, then
  **return** with their Patience still at its reduced level (not restored)
- **Multiple sales per customer are allowed** in one encounter — a successful close does not
  end the interaction. The customer stays on the floor and can accept further offers until
  Patience runs out. This is what makes the diagnostic investment (revealing both of a
  customer's need slots) pay off repeatedly rather than once.

---

## 9. Run / meta layer *(conceptual only — not numerically specced)*

This layer was discussed but not given concrete numbers; treat everything below as direction
for the next design pass, not as locked rules:

- **Shift** = one floor session (§8) with a fixed number of rounds or until all customers
  resolve
- **Run** = a sequence of shifts (days/weeks/months), with:
  - Customer archetype/need distribution shifting by period (e.g. a "winter" stretch skewing
    toward Vehicle-Durability-flavored anxieties)
  - **Run-level modifiers** as buffs/debuffs layered on top of the base system — e.g. a
    "tariffs" period tightening customer Affordability, a "dealership in a bad spot" period
    weakening starting Trust, a rotating **mandate** (see §2) requiring a specific product be
    pushed a minimum number of times regardless of need-fit
  - Persistent meta-resources across shifts (cumulative margin, a reputation stat, unlockable
    cards) as a progression system
- **Scoring** across a run should weigh three axes, not just total margin: total margin earned,
  mandate-quota compliance, and average Trust/close-rate as a proxy for sustainable play — a run
  that maximizes margin by wrecking trust and missing quota should score worse than a balanced
  one

---

## 10. Open items

- **No turn-by-turn pacing has been playtested**, even on paper — the Patience/Trust numbers in
  §5–§7 are a first-pass model, not validated numbers (contrast with `m0/README.md`, where the
  v1 lineage's numbers came from actual paper-prototype measurement)
- **The run/calendar layer (§9) has no concrete numbers** — shift length, run length, modifier
  magnitudes, and scoring weights are all undecided
- **No technical/engine architecture has been discussed for v2** — v1's Godot-specific sections
  (`DESIGN.md` §7, §9) do not apply here and have no v2 equivalent yet
- **Card counts beyond the 12 products + 6 named cards above are undecided** — how many actions
  per round, hand size, and total deck size have not been set

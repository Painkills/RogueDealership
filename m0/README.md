# M0 — Auto Sales Executive prototype

The pre-engine milestone from [`DESIGN.md`](../DESIGN.md) §12. Its job is to find out whether
the negotiation loop is fun **before** any Godot code exists. This file is the project's
memory: what the game currently is, what we tried, what failed, and what is still open.

> ⚠️ **`AutoSalesExecutive_M0.xlsx` is stale** (models the abandoned resistance design) and
> **`DESIGN.md` is out of date from §6 onward.** Both describe mechanics that no longer exist.
> This README is the accurate one.

---

## The model

> **Buy-In is how close the customer is to saying yes. Pitching raises it, charging more
> lowers it, and they have a hidden number. Find it.**

Three lines — **Vehicle / Protection / Financing** — each a **stack of 2 products sold one at
a time**, cheapest first. Buy-In resets per product; **the line's hidden threshold does not**.

**Offering** (costs 1 energy):

| | Result |
|---|---|
| Buy-In **>** their number | **SOLD.** You learn it was *this or less* (a ceiling). |
| Buy-In **<** their number | **REFUSED.** Patience cost, **the product is gone**, and you learn it is *above this* (a floor). |
| Buy-In **==** their number | **PERFECT PITCH.** Sold, number revealed, commission bonus. |

**Budget** is a visible wallet shared across all three lines. One sticker price for everyone;
what differs per customer is how much money they have. Sales draw it down. **Offers are never
blocked** — a sale bigger than what's left goes through, they stretched — but the moment the
wallet is empty, **the sale is over** (`TAPPED OUT`, a win). `take` can read over 100%.

**Patience** only ever falls. **Rapport** is a persistent pool that absorbs objection damage
before Patience, and that Key Questions spend — armour or discovery, pick one.

**Markup** is paid for in Buy-In: `+10% price = −2 × Balk buy-in`. Balk is a visible
per-customer multiplier on how much price rises sting.

**Each turn rolls an objection severity**, telegraphed before you commit:

| Severity | Weight | Effect |
|---|---|---|
| They just listen | 15% | Nothing. A free turn. |
| Standard | 45% | Normal patience damage |
| Heavy | 25% | 1.5× damage |
| Rider | 15% | Normal damage **+** the objection's rider |

Riders always land when they fire: `raise_threshold`, `lock_line`, `drain_energy`,
`knock_buyin`.

**Four ways an encounter ends:** patience gone (walked), wallet gone (tapped out), turns gone,
or every product resolved.

---

## Files

| File | What it is |
|---|---|
| `play.py` | **The playable prototype.** The fun test. |
| `engine.py` | Pure rules core. `play.py` and `sim.py` both drive it, so they cannot drift. |
| `test_engine.py` | 70 checks, including that every pitch card obeys the design budget. |
| `sim.py` | Monte Carlo. Controls: `--naive`, `--no-bracket`. |
| `sweep.py` | One lever at a time. |
| `data/*.json` | Products, cards, customers, objections, knowledge. Each opens with its `_DESIGN_RULE`. |

```bash
python m0/play.py
```

```bash
python m0/test_engine.py && python m0/sim.py
```

---

## Current numbers

**Engine config** — 3 energy/turn · 10 turns · 5-card hand · offering costs 1 energy ·
refusal costs 8 patience · markup step 10% at 2×Balk buy-in · markup range −30%…+60% ·
commission 15% · perfect-pitch bonus +10% · objection escalation 5%/turn.

**Deck — 14 cards, 7 types.** Nothing is line-restricted.

| Card | Cost | Effect | Copies |
|---|---|---|---|
| Pitch | 1e | +5 buy-in, −1 patience | 3 |
| Hard Pitch | 1e | +9 buy-in, −5 patience | 2 |
| Small Talk | 0e | +3 rapport | 1 |
| Build Rapport | 1e | +7 rapport | 2 |
| Markup | 0e | price +25% | 2 |
| Goodwill Discount | 0e | price −25% | 2 |
| Key Question | 0e | spend 4 rapport → big buy-in on the line it speaks to | 2 |

**Products — $11,400 catalogue, same price for everyone.** Vehicle: Roof Rack $900 → Tow
Package $3,600. Protection: Paint Protection $900 → Extended Warranty $2,800. Financing:
Doc Fee $600 → Term Extension $2,600. All start at 6 base buy-in.

**Customers**

| | Wallet | Patience | Balk | Thresholds (V/P/F) | Objection pool |
|---|---|---|---|---|---|
| Budget Buyer | $6,500 | 50 | 2.0× | 14 / 9 / 19 | price, doubt, stall |
| Family First | $10,000 | 55 | 1.4× | 15 / 8 / 18 | doubt, stall, price |
| Tech Enthusiast | $13,000 | 50 | 1.0× | 7 / 19 / 13 | price, stall, doubt |

---

## Design rules for adding content

Stated in each data file and enforced where possible by `test_engine.py`.

**Pitch cards are priced off one budget:** `1 energy = +4 buy-in`, plus `+1 buy-in per point
of patience spent`. Pitch (+5, −1 patience) and Hard Pitch (+9, −5 patience) both sit exactly
on it. **Every pitch costs patience** — that is what makes over-pitching expensive: buy-in
built above their hidden number is clock burned for nothing.

**Counters answer a CATEGORY, not a specific objection.** Objections carry `price`, `doubt` or
`stall`. Add a new price objection and every price answer already in the game covers it —
nothing silently becomes uncounterable. *(No counter cards are in the lean deck; the matcher
and the tags remain for when they return.)*

**Price is set by cards**, competing for the same energy and hand slots as pitching.

**The budget is a wallet, not a discount.** Products cost the same for everyone; the customer
differs by how much money they have.

---

## How we got here

Each of these was built, measured, and either kept or thrown away. The failures are the
useful part.

### 1. Resistance model — rejected on design grounds
Three lanes accumulating Deal Value against a hidden per-lane **Resistance %**, draining a
budget. Measured too easy (Max Close fired 100% / 97% / 45%). Also found a structural bug:
thresholds were a *percentage of budget* while card values were *absolute dollars*, so budget
secretly doubled as the difficulty dial and the Budget Buyer was the easiest customer.

**Killed by a design objection, not the numbers:** resistance-as-a-multiplier is fiction. "The
customer accepts 70% of an extended warranty" is meaningless — products are binary, they take
it or they don't. That made lines feel artificial and resistance feel irrelevant.

### 2. Customer objections — kept, still core
The customer was passive: a resistance number that sat there. That turned out to be *why*
nothing was ever tight — energy had no competing demand, so it was solitaire with a scoreboard.
Adding telegraphed objections gave energy a rival claim.

This pass also found a **missing rule**: you close *during* your turn, before that turn's
objection lands. Without it you could build to 100% and lose them at the buzzer with nothing
banked. That is the push-your-luck decision the design had promised and never had.

Rapport-as-shield later became **Rapport-as-persistent-pool** so one resource could serve both
defence and Key Questions instead of running two near-identical meters.

### 3. Perceived Value / Surplus — rejected before building
`Surplus = PV − Ask`, sale when surplus ≥ hidden threshold. Rejected on the same grounds as
resistance: it asks the player to hold **three quantities and a threshold on the difference
between two of them.** Too abstract to explain, let alone play.

### 4. Buy-In — the current core
Collapsed everything to one visible number. Two rules had to be *discovered* by measurement:

- **A refusal must cost you the product.** When it was only a patience hit, the policy simply
  re-offered the same item until it landed, so the entire search collapsed into the first
  product and the stack taught nothing.
- **Pitching had a ceiling** (+10 cap) so knowledge cards would matter. **This was a mistake**
  and was later removed — it made the game's core verb feel futile. "You push and nothing
  moves" is not worth whatever it protects.

### 5. The testing failure — worth remembering
A build was reported as balanced. It was trivially easy. Three causes:

1. **The simulator played a game a human wouldn't.** Its policy carefully targeted a buy-in
   and stopped; it never dumped the whole hand, which is what a human does when there's no
   reason not to.
2. **It measured the economy, not the decisions.** Commission and walk rate were tracked;
   *unspent energy* and *cards left unplayed* were not — and those are exactly what "I just
   play every card" looks like as a number.
3. **The controls compared two AIs to each other**, proving one policy beat another while
   saying nothing about whether a human faces a choice.

Underneath all three: **nobody had played it.** Fixes: the `--naive` control (a player who
dumps their hand), decision-density metrics, and actually playing the thing.

### 6. The lean pass
Ceiling removed, deck cut to 7 types, 9 products → 6, 15 turns → 10, objection severity roll
added. Pacing fixed (7.8–9.3 turns). But removing the ceiling killed the learning loop — and
measurement showed **the real cause was 2-deep stacks**, not the ceiling.

### 7. The budget
`price_scale` (per-customer sticker scaling) was **the wrong fix** to "how is budget
balanced?" — it made products cheaper for a Budget Buyer instead of making their wallet
smaller, so the same roof rack cost $585 for one customer and $1,305 for another. Replaced
with a real shared wallet.

---

## Durable lessons

1. **A refusal must cost the product**, or price discovery collapses into one item.
2. **Never cap the core verb.** A ceiling on pitching made the main action feel pointless.
3. **Offering must cost energy**, or spamming offers beats thinking.
4. **Energy must be scarce against hand size**, or you play every card and there is no turn.
5. **Measure decision density**, not just the economy.
6. **Always run the naive control.** If dumping your hand scores the same, the game asks
   nothing.
7. **Play it before calling it balanced.**

---

## Where the balance sits

Careful play vs. a player who just dumps their hand (1,200 encounters each):

| | Budget Buyer | Family First | Tech Enthusiast |
|---|---|---|---|
| **Careful play** | **$1,167** | **$1,592** | **$1,507** |
| Dumping your hand | $895 | $1,128 | $1,049 |
| Products sold | 4.5/6 | 5.2/6 | 5.1/6 |

Thinking beats not-thinking by 30–44%. Decision density holds: ~0.3 energy unspent and ~1.7
of 5 cards left unplayed per turn. Encounters run 7.8–9.3 turns.

**Each archetype fails its own way** — the best thing the wallet bought:

| | Out of money | Walked out | Cleared |
|---|---|---|---|
| Budget Buyer | **77%** | 23% | — |
| Family First | 63% | 25% | 8% |
| Tech Enthusiast | 6% | **43%** | 48% |

The Budget Buyer runs out of *money*; the Tech Enthusiast runs out of *patience* and his wallet
barely binds. Budget Buyer's take runs 118% — routinely stretched past what they walked in with.

---

## Open problems

**1. The hidden threshold is decoration.** A policy that ignores everything it learned scores
identically to one that uses it ($860 vs $859, $1,601 vs $1,557, $1,666 vs $1,673). Cause: you
need **two offers on the same line** to bracket a number — one gives a floor or a ceiling,
never both — and 2-deep stacks give roughly one. Measured: only **~5% of lines** end with a
usable bracket.

Three fixes were tried and none worked: a tighter clock, patience-per-pitch, and a much larger
markup payoff. This is not a tuning problem.

**Proposed answer (unbuilt):** move the learning to the **run** level. Make thresholds a
property of the *archetype*, persisting across the 5-day cycle — your first Family First is
expensive tuition, and every one after that is where it pays off. Keeps 8-turn encounters and
the lean deck, needs no ceiling and no 3-deep stacks, and makes the run structure carry the
learning, which is what a roguelike is for.

**2. `[k] skip` has no purpose.** The hope was that a tight wallet would make skipping the
cheap opener correct — save the $900 for the $3,600 item behind it. Measured, it is a wash
($7,634 vs $7,497). Cheap products are only ~10% of a wallet, so skipping saves too little to
offset losing a sale *and* the probe's information.

**3. Markup by stack position rises but stays small** (~+6% → +9%). It scales with knowledge as
designed, but is not yet a dramatic payoff.

**4. Small Talk sits at 1 copy** while everything else is 2–3. No stated reason; may be
deliberate, may be a slip. 6.5% of hands currently have no way to build buy-in.

---

## The question none of this answers

Whether it is **fun**. Everything above measures whether the numbers work. Play it and judge:

1. Does the offer feel like a real gamble inside your own uncertainty?
2. Does losing a product to a refusal sting the right amount, or feel arbitrary?
3. Is spending rapport on a Key Question — and eating an objection bare for it — a decision
   you enjoy making?
4. Do the three archetypes feel like different people?

If those land, it is worth building in Godot. If not, that is the finding, and it cost a few
scripts instead of a half-built engine project.

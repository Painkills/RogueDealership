# M1 — Rogue Dealership prototype (v3)

The playable build. Its job is the same as [`m0/`](../m0/README.md)'s was: find out whether the
loop is fun **before** any engine project exists. This file is m1's memory.

```bash
python m1/play.py
```

```bash
python m1/test_engine.py
```

> ⚠️ **This build has diverged substantially from [`DESIGN_V2.md`](../DESIGN_V2.md)** — see
> [What changed and why](#what-changed-and-why). DESIGN_V2 is now the *historical* record of the
> design that v3 replaced, the way `DESIGN.md` is for v2. This README is the accurate one.

---

## The model

> **Build Trust and their needs reveal themselves. Spend Trust to buy Patience. Pitch what you
> know, or gamble on what you don't.**

**Trust** has exactly two jobs, and no others:

1. **Crossing a threshold reveals a need, automatically.** There is no "ask" action — building
   Trust *is* asking. The first need surfaces cheaply; the second costs much more.
2. **Reassure cashes it out into Patience.** 3 Trust becomes 5 Patience.

Trust never gates an offer. **Pitching is always legal**, at zero Trust, knowing nothing.

**Patience** is the whole clock. It is spent by pitching (1, plus 3 more on a miss) and it
**burns at a per-customer rate**. Hit 0 and they walk.

**Starting Patience and burn rate are two independent axes**, and that is the triage puzzle. A
customer can start with the fullest bar on the floor and still be the one you must handle first.
Nobody is guaranteed to walk in fresh, either — most start partway down their own bar, so the
pressure is there from round one. The UI always shows all of it — `10/17  -3/rnd  ~4r` — because
a hidden burn rate would make that a gotcha instead of a trap.

**Budget is their wallet, and it reads as what they are worth to you.** A sale draws it down by
that product's margin. It never blocks an offer — a sale bigger than what is left goes through
and they stretched for it — but an empty wallet ends them, **TAPPED OUT**, which is the good way
to lose someone. A thin wallet means one sale however well you read them, so checking it before
you spend three actions diagnosing is a real decision. This is the third triage axis, alongside
urgency and difficulty: *is this customer even worth my actions?*

**A reveal is permanent, but thresholds read current Trust.** Reassure never un-teaches you
something you already learned; what it costs is progress toward the *next* reveal. That trade is
the core tension.

**The gamble.** Two needs out of six is a 1-in-3 blind pitch. Every miss costs 4 Patience but
rules a need out, so the odds climb as the clock burns: 2/5, then 2/4, then 2/3. A blind hit also
reveals the slot it landed on — a lucky guess is informative, not just lucky.

---

## Files

| File | What it is |
|---|---|
| `play.py` | **The playable prototype.** The fun test. |
| `engine.py` | Pure rules core — no I/O. A simulator can drive the same object later, so the two cannot drift. |
| `test_engine.py` | 1474 checks. Pins the rules so retuning `data/` cannot silently change them. |
| `data/*.json` | Needs, products, cards, archetypes, config. Each opens with its `_DESIGN_RULE`. |

---

## Current numbers

**Config** — 3 customers · 5-card hand · 3 actions/round · starting Trust 0 · pitch 1 Patience,
miss +3 · Reassure 3 Trust → 5 Patience · Patience tops out at the archetype value ±4 and they
walk in at 50–100% of that · wallets roll 3–14.

**Deck — 14 cards, Trust only.** Genuine Connection ×5 (+4), Small Talk ×3 (+2, **free — costs
no action**), Common Ground ×3 (+2 to **everyone** on the floor), Reassure ×3.

Small Talk is the one deliberate 0-action card. Note what that is and is not: it is never a
question of *whether* to play it, only of *who* gets it — so it stays weak enough that the who is
the whole decision. A free card strong enough to be your main Trust engine would delete the
triage puzzle outright.

**Tray — 6 products, always visible, never shuffled in.** Margins form a deliberate 7-6-5-4-3-2
ladder, so *which* need you reveal is itself a result worth caring about.

| Product | Need | Margin |
|---|---|---|
| Vehicle Service Contract | Reliability | 7 |
| Life and Disability Protection | Health | 6 |
| GAP Insurance | Equity | 5 |
| Tire & Wheel Protection | Durability | 4 |
| Payment Flex Plan | Affordability | 3 |
| Key Replacement | Security | 2 |

**Archetypes.** Each non-baseline archetype isolates exactly one axis, so you can always tell
which resource you are failing at.

| Archetype | reveal 1 | reveal 2 | patience | decay | Axis |
|---|---|---|---|---|---|
| Easygoing | 3 | 9 | 14 | 1 | none — baseline |
| Rushed | 3 | 9 | 14 | **3** | Patience, via burn rate |
| Guarded | **6** | **13** | 14 | 1 | hard to read at all |
| Reserved | 3 | **14** | 14 | 1 | second need is buried |

Everything above is a first-pass guess. Retune `data/config.json`, or for one run:

```bash
python m1/play.py --set actions_per_round=4 --set hand_size=6
```

---

## What changed and why

v3 was a response to playing v2 and finding it wasn't fun, for two specific reasons.

**Product cards clogged the hand.** 12 of 26 deck cards were products you could not legally play
until you had diagnosed something, so for most of an encounter they were dead weight occupying
slots that should have held cards that advance you. **Fix:** products left the deck entirely for
an always-visible tray.

**Too many actions passed before anything happened.** The chain was rapport → ask → ask again →
pitch, spread over several rounds before a single point of margin landed. **Fix:** Question cards
deleted; crossing a Trust threshold reveals a need by itself. Measured below: first margin now
lands on **action 2.9** instead of 4+.

Also gone, and why:

- **9 needs → 6, categories deleted.** Categories existed in DESIGN_V2 purely to power a
  two-tier category-then-specific reveal. That reveal is gone, so they were decoration. 6 is now
  load-bearing on the blind-pitch odds.
- **Dual products, and the perfect-match bonus.** 6 products map 1:1 onto 6 needs.
- **The Pitch threshold.** Trust gating offers was a third job for Trust and re-created the wait.
- **Offer a Discount.** Reassure owns the Trust→Patience valve; two Patience sources were
  redundant.

Then added back, after playing it:

- **Customer wallets**, from m0's lineage — margins double as prices, so a budget reads directly
  as what a customer is worth. This gives customers a second way to end other than the clock,
  and stops every one of them stopping at the same "2 needs, 2 products" wall.
- **Partial starting Patience** — not everyone walks in fresh, so there is pressure from round
  one. Floored by *rounds* as well as raw Patience, because starting a decay-3 customer at 2 is
  not pressure, it is a loss you cannot act on.
- **Small Talk at 0 actions**, restoring m0's 0-energy Small Talk.

**One rule worth stating explicitly**, because it is subtle and a test pins it: reveal thresholds
are keyed to **how many needs you already know**, not to slot index. Learning one need by a lucky
blind pitch must not make the buried second need cost the cheap price — that would erase
Reserved's entire axis.

---

## Where the balance sits

**Not measured properly.** There is no simulator, per m0's lesson #7 — the question is whether
it's fun, and only playing answers that. A throwaway greedy bot (built to check the game is
reachable, then deleted — **not** a balance claim) over 60 shifts each:

| | Careful play | Just dumping your hand |
|---|---|---|
| Margin (median) | **23** | 16 |
| Sales | 5.0 | 3.7 |
| First margin on action | **2.9** | 8.1 |
| Rounds | 8.3 | 27.3 |
| Tapped out / walked per shift | **1.5 / 1.5** | 1.2 / 1.1 |
| Wallet drained | **89%** | 66% |

Thinking beats not-thinking by 44%, and the loop compression worked. Wallets did what they were
added for: shifts dropped from 13.7 rounds to 8.3, and customers now end **half by being drained
and half by the clock** rather than everyone stopping at the same "2 needs, 2 products" wall.

---

## Open problems

1. **The blind pitch is still never taken.** The careful bot took **0.0** blind offers per shift,
   across every version so far: only pitching what you already know is strictly safer, so the
   gamble the design is built around never gets played. This is the same failure mode as v2's
   100% close rate and m0's decorative hidden threshold, and adding wallets did not shift it. If
   a human also never gambles, the whole risk ladder (2/5 → 2/4 → 2/3) is dead weight and needs
   either a carrot (bonus margin on a blind hit?) or a stick (thresholds that rise as the shift
   wears on). **This is the oldest unfixed problem in the project.**
2. **1.4 of 3 actions go unused per round** — better than v3's 1.7 now that Small Talk is free,
   but still well above the ~0.3 m0 considered healthy. Partly a limitation of the bot, which
   idles once a customer is fully read and sold out.
3. **Stalling is possible.** Reassure can out-pace decay indefinitely — 2 Trust cards plus 1
   Reassure nets +5 Patience against a −1 to −3 burn. `max_rounds: 40` is a **safety valve, not a
   clock**; careful play ends around round 8 and never reaches it. Wallets made this much less
   reachable (the naive control fell from 40 rounds to 27), but the hole is still there.
4. **Budget and the Affordability need may double-count.** DESIGN_V2 §2 cut budgets for exactly
   this reason. They are back by choice, for differentiation — but if "this customer is poor"
   and "this customer needs Affordability" start feeling like the same fact, that objection was
   right and one of the two should go.
5. **Starting Trust 0 makes every opening move a Trust card.** A forced first move is not a
   decision — though it now costs one action instead of three. Try `--set starting_trust=1`.
6. **Only 4 card types.** A hand of 5 drawn from 4 types risks feeling samey.
7. **The run/meta layer is entirely absent.** m1 is one shift, by design.

---

## The question none of this answers

Whether it is **fun**. Play it and judge:

1. Does watching two different Patience curves across three customers create real triage
   pressure, or do you just work them left to right?
2. Is a need surfacing on its own a satisfying payoff, or does it feel like it happened *to* you
   rather than because of you?
3. Is trading Trust for Patience a decision you enjoy making, knowing it costs you the next
   reveal?
4. Do you ever actually gamble on a blind pitch? If not, why not — and would anything make you?
5. Do the four archetypes feel like different people, or like the same person with a different
   number?

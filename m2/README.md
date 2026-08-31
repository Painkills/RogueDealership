# M2 — Rogue Dealership prototype (the negotiation model)

The playable build. Its job is the same as [`m0/`](../m0/README.md)'s and
[`m1/`](../m1/README.md)'s was: find out whether the loop is fun **before** any engine project
exists. This file is m2's memory.

```bash
python m2/play.py
```

```bash
python m2/test_engine.py
```

> ⚠️ **m2 is a clean pivot, not an iteration on m1.** It carries forward m0's and m1's *lessons*
> and none of their mechanics. Trust, needs, reveal thresholds, wallets and the hit-or-miss pitch
> are all gone. `DESIGN_V2.md` and both earlier READMEs are now historical record.

---

## The model

> **Every offer has two numbers moving in opposite directions: Appeal climbing toward their
> Line, Margin falling as you concede. The game is deciding when to stop.**

**Interests.** Every customer ranks nine interests 1–9, privately, and every product answers
exactly one of them.

| | | | |
|---|---|---|---|
| **Vehicle** | Reliability | Security | Power |
| **Deal** | Affordability | Equity | Value Retention |
| **Person** | Stability | Convenience | Status |

**Appeal opens at `5 × (9 − their rank)`.** Their number one opens at 40, their last at 0. A bad
read is therefore **never a refusal — only an expensive starting position.** This is the single
most important property of the design: there is no coin flip to dodge, so the gamble m1 spent
three versions failing to get anyone to take (open problem #1, "the blind pitch is still never
taken") simply does not exist here. It was replaced by a price gradient.

**No card moves a full place on their list.** The best free card is +4 against a rank step of 5, so
a card can never cheaply substitute for reading someone. `test_no_card_moves_a_full_place_on_their_list`
pins it, and it is why diagnosis pays.

**Place, then offer.** Putting a product in front of someone costs a tick and tells you only how
warm they look — a band, not a number. **Offering is free**, reveals the exact gap and that
interest's rank, and is what makes them react. So placing is the price of information, and asking
is the price of exposure. It also means you can pad a deal that would have closed cold, which is
the whole reason the two moves are separate.

**Knowledge is efficiency, never permission.** Nothing is gated, so no card is ever dead in hand
and no turn is spent waiting — m1's two stated reasons v2 wasn't fun.

**The rules never say no; the arithmetic says "not worth it."** You may concede an offer to
negative margin and the engine will let you bank the loss. Nothing caps the core verb — m0's
durable lesson #2, learned the hard way when a pitch ceiling made pushing feel futile.

**Ticks are the whole clock.** No rounds, no per-round budget. Every card costs its tick, and a
tick burns that much patience from **every customer on the floor at once**, plus the shift clock.
Walking to a *different* customer costs 1; going back to whoever you were last with is free.

**Effects resolve, then the tick burns.** Small Talk saves someone at 1 patience; a sale lands on
the tick that would have walked them. m0's discovered rule — you close *during* your turn, before
the damage — pinned by `test_effects_resolve_before_the_tick_burns`.

**Nothing is yours until you sign.** A customer who says yes has not paid you: the product sits
**unsigned**. `close` banks the lot and frees the chair. If their patience hits zero first they
walk out with the entire unsigned deal. Every customer is a push-your-luck ladder.

**Each sale ramps most people** — their Line moves +3, and they hand back 3 patience. Family First is the exception and it
is her whole character.

---

## Archetypes are play patterns

Every archetype exists to teach one behaviour. Its numbers and its action are chosen to *force*
that behaviour, not to decorate it, and everything it does is **telegraphed on arrival** in a
`WHAT THEY DO` box on the customer sheet - and announced loudly, in dialogue, the moment it fires. m0 §2 found that a passive customer is *why* nothing was ever tight — "it was
solitaire with a scoreboard." This is the fix.

| Archetype | The pattern it teaches | What forces it | Line | Pat |
|---|---|---|---|---|
| **Easygoing** | This is how the loop works. | Nothing. Baseline. | 35 | 16 |
| **Lay-Down Larry** | Take the free money and **leave**. | His top five close cold, and he has no actions at all. He is worth two fast sales, not six ticks of optimising. | 20 | 16 |
| **Budget Hawk** | Over-build **before** you ask, and pay in margin. | Every short offer moves their Line +5, and it stacks. You daren't ask speculatively, so you stack appeal first — and Discount is the only tick-efficient way to do that. | 40 | 16 |
| **Tire Kicker** | Don't diagnose. Sell **something**, now. | 9 patience and −2 more every 4 ticks. There is no time to read him. | 35 | 9 |
| **Tech Enthusiast** | Hunt the bullseye. | A sale on his 1st or 2nd banks **+$300**. Makes Read the Room lucrative on him specifically. | 35 | 16 |
| **Family First** | Sell her her favourites, fast. Don't fish. | Their Line **never moves** — she'll buy all afternoon — but any offer below her top five costs 4 patience, sold or not. | 35 | 16 |
| **The Karen** | See to her **first**, and give her what she came for. | −1 patience to everyone *else* every 5 ticks, and she will not sign until she has bought from the category she demanded. | 35 | 16 |

**The Karen's demand is the category of her own #1 interest**, announced on arrival — a free Read
the Room, and then she charges the whole floor rent until you act on it. The lock is on `close`
only: she still walks at 0 patience with her unsigned deal, so ignoring her is possible and
expensive. Two products per category means her demand is always servable.

---

## Files

| File | What it is |
|---|---|
| `play.py` | **The playable prototype.** The fun test. Two-level UI: floor ⇄ customer. |
| `engine.py` | Pure rules core — no I/O. A simulator can drive the same object later, so the two cannot drift. |
| `test_engine.py` | 355 checks. Pins the rules so retuning `data/` cannot silently change them. |
| `data/*.json` | Interests, products, cards, archetypes, objections, config. Each opens with its `_DESIGN_RULE`. |

The objection engine is entirely data-driven: **triggers** (`on_offer` with `short_at` /
`rank_worse_than` filters, `on_sale` with `rank_better_than`, `every`, `patience_below`) and
**effects** (`threshold`, `appeal`, `margin`, `patience_self`, `patience_floor`, `discard_hand`,
`margin_bonus`). A new customer type is a data edit.

---

## Current numbers

**Config** — 24-tick shift · quota $3,600 · 3 chairs · 4-tick walk-up · 4-card hand · place 1 tick ·
approach 1 tick (free to return) · dig 1 tick · short offer −1 patience · Line +3 and patience
+3 per sale · appeal step 5.

**Starter deck — 14 cards.** Products and support share one deck; a product in hand is always
legally placeable, so it can never clog the way v2's did. When the one you want isn't there you
**dig** — discard for a tick and draw.

| Product | Category · Interest | Margin |
|---|---|---|
| Vehicle Service Contract | Vehicle · Reliability | $1,600 |
| GAP Insurance | Deal · Equity | $1,400 |
| Payment Protection Plan | Person · Stability | $1,200 |
| Anti-Theft & Key Protection | Vehicle · Security | $800 |
| Payment Flex Plan | Deal · Affordability | $700 |
| Concierge & Roadside Plan | Person · Convenience | $600 |

| Support | × | Tick | Effect |
|---|---|---|---|
| Explain the Product | 3 | 1 | +4 Appeal |
| Offer a Discount | 2 | 1 | +8 Appeal, −$300 |
| Pad the Deal | 1 | 1 | **+$400**, −5 Appeal |
| Small Talk | 1 | 1 | +5 their Patience |
| Read the Room | 1 | 1 | Reveals their Line and the category of their #1 |

Two products per category is load-bearing twice: a category read is always actionable, and the
Karen's demand is always servable.

**Held back for the run**, in `data/` flagged `starter: false`: Performance & Tow ($1,100 · Power),
Trade-In Value Protection ($1,000 · Value Retention), Appearance & Wheel ($900 · Status); Payment
Framing, Bundle It In, Fearmonger, Hard Close. Three of nine interests have no answer in the
starter deck — that is where progression goes.

Everything above is a first-pass guess. Retune `data/config.json`, or for one run:

```bash
python m2/play.py --seed 7 --floor hawk,karen,kicker --set shift_ticks=12
```

---

## What changed in m2.1, and why

Playing the first m2 produced 11 pieces of feedback. Three of them were one bug.

**The scale was too small to express a small concession.** Appeal ran 0–8 and thresholds 4–9, so a
Budget Hawk wanting 9 could not be sold *anything* cold — not even her favourite thing in the
world — and the fix, one discount, moved 4 points on a 9-point scale while wiping 100% of a $3
product's margin. Rescaling to steps of 5 and margins to dollars gave every concession somewhere to
land, and gave the threshold ramp room to be gentle (+3 on a 40-wide scale) instead of brutal.

**The customer was passive again.** m2 v1 had numbers that sat there. The objection engine is m0's
lesson #2 rebuilt: archetype action pools, telegraphed on arrival.

**Placing and offering split**, which turned out to be the same mechanism as the objection engine.
Once offering is free in ticks, nothing stops you asking after every card — unless asking is what
provokes them. The two features give each other their price.

Also: deck 21 → 14, hand 5 → 4, shift 50 → 24 ticks, returning to the same customer made free,
partial arrivals and departure alerts restored, every product now shows `Category · Interest` so a
category read is actionable, and the customer sheet grew a **permanent appeal bar** — a fixed scale
with a marker where they say yes, so a Lay-Down's marker sits early and a Hawk's sits late and you
can read difficulty without reading a number.

The bar is permanent on purpose. The first version drew it only while an offer was live *and*
already asked, which meant a player whose offers were landing never saw it at all — the element
that explains the whole game was invisible to anyone doing well. It now shows in every state:
`?` before you know their bar, the marker alone once you do, and a filling bar with `N SHORT` once
you have asked.

---

## Where the balance sits

**Not measured properly, and deliberately so.** There is no simulator and no bot in this directory
— m0's durable lesson #7. A throwaway greedy probe was built to check the game is reachable, read
once, and deleted; it is **not** a balance claim, and it played a game a human would not.

What it said, over 150 shifts each:

| | Careful play | Just throwing the top card |
|---|---|---|
| Margin banked (mean) | **$3,074** | $1,020 |
| Quota hit rate at $3,600 | **37%** | 3% |
| Products per signed customer | **1.62** | — |
| Customers seen / signed / walked | 7.2 / 2.1 / 3.0 | — |

Thinking beats not-thinking **3.0×**, the widest separation of the three milestones (m0: 30–44%,
m1: 44%, m2 v1: 2.1×).

**Quota is $3,600, and it is set against a human, not the bot.** The first real playthrough banked
$5,800 against an earlier $2,400 quota — roughly double what the crude probe manages, which is the
clearest evidence yet that the decisions in this build are ones a person can actually play better
than a greedy heuristic. The probe clears $3,600 only 37% of the time; a competent human should
clear it comfortably, so if it still feels soft the next stop is $4,500.

Retuning that mattered: at patience 12 the floor churned 8 customers past you in a 24-tick shift and
4.4 of them walked untouched. Patience 16 cut walk-outs to 3.0 and raised margin 16% without
touching a rule.

---

## Open problems

1. **Half the floor is still wallpaper.** ~7 customers walk in, 2.1 get signed, 3.0 walk out. Some
   of that is the triage fantasy working — you cannot serve everyone — but if it reads as waste
   rather than as choosing, the lever is `walk_up_ticks` or `floor_size`, not patience.
2. **The unsigned deal is almost never actually lost** ($67 a shift to walk-outs). The push-your-luck
   spine is a threat that shapes behaviour without firing. Acceptable — but if it *also* never
   shapes behaviour it is decoration, which is exactly how m0's hidden threshold died.
3. **Discount spam.** If "+8 Appeal for −$300" is simply always correct, the negotiation is a
   calculator. Watch whether Pad-the-Deal-then-concede ordering ever gets used — that is the skill
   the two-step offer exists to reward.
4. **The Karen may be miserable rather than interesting.** A floor-wide drain punishes you for
   something happening elsewhere. If it reads as unfair rather than as a reason to deal with her
   first, shrink the effect before deleting her.
5. **Family First has no stopping point.** A flat Line means nothing ever prices you out of
   them; only their patience and your products do. Watch whether parking on her is simply correct —
   if so the fix is a +1 ramp, not abandoning the flat one.
6. **Eleven changes landed at once.** If it still isn't fun the cause is hard to isolate. The
   rescale and the two-step offer are the two that could plausibly have made it worse.
7. **No run layer.** m2 is one shift, like m1.

---

## The question none of this answers

Whether it is **fun**. Play it and judge:

1. When an offer comes back 12 short, is deciding *how* to close that gap — discount, explain, pad
   first, or walk away — a decision you enjoy making?
2. Does the band-then-number reveal make placing a product feel like a commitment?
3. Do the seven archetypes feel like seven different problems, or like one problem with different
   numbers?
4. Do you ever look at an unsigned deal and decide to push for one more? Do you ever regret it?
5. Does the Karen make you rearrange your whole shift, or just annoy you?

# G2 — the run layer

**Status:** design, approved 2026-09-05 · **Milestone:** `GODOT_SPEC.md` §10, G2
**Done when:** you can add, remove or upgrade a card and take it into the next shift.

## Context

G0 through G1.5 are on `master`: a pure rules core, and one shift that is fully playable and has
now actually been played and called fun. What does not exist is any reason to play a *second*
shift. `Shift` builds the same fixed 14-card starter deck every time, and the end-of-shift report's
only button starts an identical shift over.

G2 is the layer that makes a shift matter to the next one: a run of five shifts, a shop between
them, and a deck that carries what you did to it. `GODOT_SPEC.md` §4 already fixed the shape of the
meta layer — the shop does exactly three things, add / remove / upgrade a card, and nothing else.
No relics, no run modifiers. One system to balance instead of two.

Three things this build gets for free, because earlier milestones left the seams open:

- `Deck` already has `add(def)`, `remove(uid)` and `upgrade(uid)` — the three shop verbs, already
  written and tested.
- `CardInstance.new` is called **only** from `Deck.add`. Nothing in `Shift` ever creates or
  destroys an instance; a shift only borrows references into `draw`/`hand`/`discard`. So a
  persistent deck survives a shift untouched, with no reconstitution step, today.
- Seven cards are already authored and flagged `starter = false` — three products (Performance &
  Tow, Trade-In Value Protection, Appearance & Wheel) and four support (Payment Framing, Bundle It
  In, Fearmonger, Hard Close). m2's README calls them "held back for the run." The shop has real
  content to sell on day one.

## Scope

**In:** run state, a quota schedule, a shop screen, the three shop verbs, product-upgrade
rebalancing, archetype gating by shift, and the scene flow that strings shifts together.

**Out, deliberately:** disk persistence (a run lives in memory for one sitting), relics or run
modifiers, new archetypes or cards beyond what is already authored, and any 3D treatment of the
shop. `GODOT_SPEC.md`'s "vertical before horizontal" holds — nothing new gets added until G2 runs.

## 1. Product upgrades: +25%, exact

Today every product has `upgraded_margin = margin + 300`. That flat step is regressive: it is a 50%
boost on the $600 Concierge and 18.75% on the $1,600 VSC, so "upgraded" means something different
on every card.

**A product upgrade is +25%.** The benchmark is the game's own economy: *Pad the Deal* trades +$400
of margin for −5 appeal and a tick, so a 25% upgrade on the top card is worth exactly one free Pad
the Deal, permanently, with no appeal cost and no tick. That is a whole card's worth of effect —
meaningful — priced at something the game already considers fair. At 33% the top card gains $528
and two sales would be 29% of quota off a single purchase; at 20% it is worth less than the card it
is imitating.

Every base margin is a multiple of $100, so ×1.25 is always a whole number and no rounding rule is
needed:

| VSC | GAP | PPP | Perf | TVP | Appearance | Theft | Flex | Concierge |
|---|---|---|---|---|---|---|---|---|
| 1600 → **2000** | 1400 → **1750** | 1200 → **1500** | 1100 → **1375** | 1000 → **1250** | 900 → **1125** | 800 → **1000** | 700 → **875** | 600 → **750** |

**No model change.** `CardInstance.margin()` already reads `upgraded_margin`; the nine data values
are re-authored and a test pins the convention — nothing pins it today, which is how it drifted.
`margin()` stays parameterless on purpose: `card_text.gd` is a pure static formatter with no config
access, and threading a percentage through the call would infect it.

## 2. Archetype gating: a difficulty ladder by shift

The Tire Kicker (`patience = 9` against a default of 16) and the Karen (`demands_category` plus a
floor-wide patience drain) are the two hardest customers in the game, and both can currently walk
into the opening minute of a first-ever run.

`CustomerArchetype` gains **`@export var min_shift: int = 1`**. The default of 1 means every
existing single-shift caller and all current tests are unaffected.

| min_shift | Archetypes | Why |
|---|---|---|
| **1** | Lay-Down Larry, Easygoing | No actions at all; Larry's Line is 20 against a default 35 |
| **2** | Family First, Tech Enthusiast | Both act, but `line_per_sale = 0` and a margin *bonus* are gifts |
| **3** | Budget Hawk, Tire Kicker | The Line ramps against you; nine ticks of patience |
| **4** | The Karen | A demanded category *and* a drain on the whole floor |

`Shift` gains `shift_number: int = 1`, and `_pick_archetype()` filters to `a.min_shift <=
shift_number`. Two details that matter:

- **`floor_size` is 3 but shift 1 offers only 2 archetypes.** `_pick_archetype()` already degrades
  correctly — `unique_archetypes_on_floor` filtering is guarded by `if not fresh.is_empty()`, so a
  third chair simply repeats one. On shift 1 a doubled Larry is a gift.
- **An empty gated pool must fall back to the full pool.** Misauthored data (every `min_shift` set
  high) would otherwise index an empty array and crash. Guarded and tested explicitly.

`_forced` (how tests pin specific archetypes) bypasses `_pick_archetype` entirely, so every existing
forced-archetype test keeps working untouched.

`ArchetypePool.design_rule` is updated to state the ladder, since it is now a constraint any new
archetype must obey and the suite already asserts every pool states its rule.

## 3. The economy

- **A run is 5 shifts** — four shop visits. Enough to change a deck meaningfully, short enough to
  finish in a sitting.
- **Quota climbs 15% a shift:** 3600 · 4140 · 4761 · 5475 · 6296.
- **Money is that shift's `margin_banked`**, spent in the shop that follows, then reset. No new
  currency and no wallet to hoard into — `GODOT_SPEC.md` §4's "one system to balance" applied to
  the economy as well as the card pool.
- **Missing quota is not fatal.** It means a smaller shop budget and a worse final tally; the run
  always plays all five shifts.

**Prices scale with value.** This is the load-bearing part, not the figures:

| | Price | Why |
|---|---|---|
| Upgrade a card | ~4× the margin gain | Pays back in four sales. Because both the gain *and* the price scale with the card, a percentage upgrade is value-neutral across the ladder — so the decision becomes *"which product do I actually sell?"*, not *"which number is biggest?"* |
| Buy a card | new `@export var price: int` on `CardDef` | Support cards have no margin to derive a price from, so this is authored per card — content is data |
| Remove a card | flat, from `ShiftConfig` | Deck-thinning should be affordable, not free |

**Every figure above is a first-pass guess**, in the same spirit as m2's README about its own
numbers. Five shifts, 15%, and 4× payback are picks, not measurements — no multi-shift run has ever
been played, because none has ever existed. They are all single numbers in `ShiftConfig` or authored
data, so retuning is a data edit.

## 4. Architecture

A real `scripts/run/` layer, which `GODOT_SPEC.md` §1 has reserved since before G0. Both files are
plain `RefCounted` — no Node, same discipline as the model, so both are headlessly testable.

**`test_architecture.gd`'s guards must be extended to reach them.** Both of them —
"the model never reaches into the view" and "nothing calls the global RNG" — hardcode
`res://scripts/model`, so a new sibling directory is silently outside the rules the project
considers non-negotiable. The RNG one is not hypothetical here: **the shop needs randomness to
decide what is on offer**, which is precisely where a bare `randi()` would get written and quietly
destroy a run's reproducibility. `RunState` owns one seeded `RandomNumberGenerator` for the run and
hands `Shift` its per-shift seed from it, exactly as `Shift` already does for its own rolls.

```
game/scripts/run/
  run_state.gd    persistent Deck · shift number · quota schedule · money · per-shift reports
  shop.gd         what is on offer, what it costs, and applying a purchase
```

**`RunState`** owns the deck across shifts, builds each `Shift`, records each report, and sets the
next shop budget. **`Shop`** takes a `RunState`, produces the offer list, prices it, and applies a
purchase through `Deck`'s three existing verbs.

### The Shift seam

`Shift._init` currently always calls `Deck.build_starting(card_pool)`. It gains three trailing
defaulted parameters, so every existing caller and all 855 current checks keep working untouched:

| Param | Default | Meaning |
|---|---|---|
| `p_deck: Deck` | `null` | null → build a starter deck, exactly as today |
| `p_quota: int` | `0` | 0 → use `cfg.quota`, exactly as today |
| `p_shift_number: int` | `1` | 1 → every archetype is available, exactly as today |

### Scene flow

A new `run.tscn` with `run_controller.gd` instances `shift.tscn` and a new `shop.tscn` and switches
between them. `shift_controller.gd` gives up `_start_new_shift()` in favour of `setup(shift)` and a
`shift_finished` signal.

That last part is a small refactor of code that just shipped, and it is worth doing rather than
bolting the shop onto the existing controller: `shift_controller.gd` is already ~550 lines and owns
the table, the framing, the HUD and reconciliation. Making it the run orchestrator as well is how it
becomes the file nobody wants to open.

The shop is a plain 2D `Control` screen, in the spirit of the panels G1 used before the 3D pivot.
G2's bar is mechanical — add, remove or upgrade a card — and says nothing about presentation.

## 5. Testing

The run layer is pure `RefCounted`, so nearly all of it is headless-suite territory rather than
driver territory:

- **`test_run_state.gd`** — the quota schedule; money is set from the last shift's banked margin
  and resets; the run ends after five shifts; a missed quota costs budget but not the run.
- **`test_deck_persistence.gd`** — the load-bearing invariant: a deck taken through a whole shift
  comes out the far side with the same instances, same uids, same upgrade flags, none created and
  none lost. This is the property everything else rests on and nothing tests it today.
- **`test_shop.gd`** — each of the three verbs changes the deck as expected and debits the right
  amount; you cannot buy what you cannot afford; removing the last copy of something is allowed.
- **`test_archetype_gating.gd`** — the ladder holds; the Kicker cannot appear before shift 3 nor the
  Karen before 4; shift 1 draws only from the two easy archetypes; an empty gated pool falls back
  rather than crashing.
- **`test_architecture.gd`** — its two guards extended to walk `scripts/run` as well as
  `scripts/model`, plus a check that two runs built from the same seed produce the same shop
  offers, which is the reproducibility property the RNG rule exists to protect.
- **`test_cards.gd`** — extended to pin the 25% convention across all nine products.
- **`drive_shift.gd`** — extended for the run flow: finishing a shift reaches the shop, a purchase
  survives into the next shift's draw pile.

## Deferred

- Disk persistence. `GODOT_SPEC.md`'s milestone name says "with save" but its own "done when" line
  does not, and a resumable run wants a main menu and corrupt-save handling that G2 has no other
  use for.
- Whether +25% is *interesting* rather than merely bigger — `GODOT_SPEC.md` §12's open question,
  and one only a played run can answer.
- The quota curve's shape beyond a flat percentage, and the run's length. Both want play data.

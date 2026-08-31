# Rogue Dealership — Godot architecture spec

> **Status:** design, not yet built · **Engine:** Godot 4 (GDScript) · **Team:** solo · **Cost:** $0
> **This document is the ARCHITECTURE.** The rules are specified by
> [`m2/README.md`](m2/README.md), which stays the source of truth for what the game *does*. If this
> document and m2 disagree about a rule, m2 wins and this document is wrong.

## Context

m2 is fun. The stated limit on that fun is not the design — it is that a CLI is slow to read and
slow to drive. Three customers, a hand, an appeal bar and a live negotiation do not fit in a
scrolling terminal, so the player spends attention on parsing instead of deciding.

So this is a port, not a redesign. The rules do not change. What changes is that the floor becomes
a thing you look at instead of a thing you reconstruct.

Three properties of the prototypes have to survive the move, because they are why the project has
been able to throw away two designs without losing anything:

1. **The rules core is pure.** No I/O, no rendering, deterministic given a seed. `play.py` and
   `test_engine.py` drive the identical object, so they cannot drift.
2. **Content is data.** New cards and customers are data rows, not code.
3. **Every data file states its `_DESIGN_RULE`** — the constraint new content must obey — and the
   tests enforce it where they can.

`DESIGN.md` §7/§9/§10/§11 already sketched a Godot architecture along these lines. `DESIGN_V2` §10
declared those sections dead, but it meant the *mechanics*; the technical bones are sound and this
spec builds on them.

---

## 1. Layers

Four, kept strictly separate. The dependency arrow only ever points down.

| Layer | Lives in | Knows about |
|---|---|---|
| **View** | `game/scenes/`, `game/scripts/view/` | model + run |
| **Run** | `game/scripts/run/` | model + data |
| **Model** (pure rules) | `game/scripts/model/` | data only |
| **Data** | `game/data/**.tres` | nothing |

**The model never references a Node, a scene, or a signal from the view.** It is plain
`RefCounted` classes. This is the single most important line in this document: it is what lets the
headless test suite drive the real game, and what let m2 survive three redesigns.

```
game/
  project.godot
  data/
    interests/        category + interest resources
    products/         9 product cards
    cards/            support cards
    archetypes/       7 customer archetypes
  scripts/
    model/            Shift, Customer, Offer, CardInstance, Deck  (pure)
      effects/        Effect base + one small script per effect kind
      triggers/       Trigger base + one small script per trigger kind
    run/              RunState, Shop, SaveGame
    view/             scene scripts, all observers
  scenes/
    shift.tscn  floor_card.tscn  customer_panel.tscn  hand_card.tscn  shop.tscn
  art/                placeholders now, real art later
  tests/
    run_tests.gd      headless runner
    parity/           m2's cases, ported
```

---

## 2. Data: authored as Godot Resources

Every piece of content is a custom `Resource` with `@export` fields, authored in the Inspector.
Adding a customer is right-click → New Resource → fill in fields → drop it in the archetype pool.
No text file to get wrong, and the effect and trigger fields are dropdowns of what actually exists.

### Static definitions (Resources — immutable at runtime)

```gdscript
class_name Interest extends Resource
@export var id: StringName
@export var display_name: String
@export var category: Category          # Vehicle / Deal / Person
@export var blurb: String               # "will it break"

class_name CardDef extends Resource     # base for everything in the deck
@export var id: StringName
@export var display_name: String
@export var text: String                # flavour; mechanics are auto-described
@export var ticks: int = 1
@export var copies: int = 1
@export var starter: bool = false

class_name ProductCardDef extends CardDef
@export var interest: Interest
@export var margin: int
@export var upgraded_margin: int

class_name SupportCardDef extends CardDef
@export var needs_offer: bool = true
@export var effects: Array[Effect]
@export var upgraded_effects: Array[Effect]

class_name CustomerArchetype extends Resource
@export var id: StringName
@export var display_name: String
@export var pattern: String             # the ONE behaviour this teaches
@export var tell: String                # what you see on arrival
@export var line: int = 35
@export var patience: int = 16
@export var line_per_sale: int = 3      # Family First runs at 0
@export var top_interests: Array[Interest]
@export var bottom_interests: Array[Interest]
@export var demands_category: bool = false
@export var actions: Array[CustomerAction]

class_name CustomerAction extends Resource
@export var id: StringName
@export var display_name: String        # "Asks for the manager, loudly"
@export var tell: String                # telegraphed in WHAT THEY DO
@export var dialogue: String            # spoken when it fires
@export var trigger: Trigger
@export var effects: Array[Effect]
@export var cooldown: int = 0
```

`_DESIGN_RULE` survives the move as an `@export_multiline var design_rule: String` on a
`ContentPool` resource per folder — the rule stays next to the content it governs, and the test
suite still asserts every pool has one.

### Runtime state (RefCounted — mutable, never saved as Resources)

`Shift`, `Customer`, `Offer`, `CardInstance`, `Deck`, `EffectContext`. These are ordinary objects.
Keeping them out of the Resource system avoids Godot's sharpest trap here: Resources are shared by
reference and cached, so runtime state stored in one leaks between customers and across runs.

---

## 3. Effects and triggers: composable, one small file per verb

An `Effect` is a Resource with one method. A card or an action holds an `Array[Effect]` you
assemble in the Inspector.

```gdscript
class_name Effect extends Resource
func apply(ctx: EffectContext) -> void: pass
func describe() -> String: return ""     # powers UI text automatically
```

```gdscript
class_name ChangeAppeal extends Effect
@export var amount: int
func apply(ctx: EffectContext) -> void:
    if ctx.offer: ctx.offer.appeal += amount
func describe() -> String: return "%+d Appeal" % amount
```

The starting vocabulary, one file each: `ChangeAppeal`, `ChangeMargin`, `ChangeLine`,
`ChangePatience` (the customer you are with), `ChangePatienceFloor` (everyone *else*),
`RevealRoom`, `DiscardHand`, `MarginBonus`, and one combinator, `ScaleBySales`, which wraps another
effect and multiplies it by how many products this customer has already taken.

That reproduces every effect in m2 exactly:

| Card | Effects |
|---|---|
| Explain the Product | `[ChangeAppeal +4]` |
| Offer a Discount | `[ChangeAppeal +8, ChangeMargin -300]` |
| Pad the Deal | `[ChangeAppeal -5, ChangeMargin +400]` |
| Small Talk | `[ChangePatience +5]` |
| Read the Room | `[RevealRoom]` |
| Bundle It In | `[ScaleBySales(ChangeAppeal +4)]` |
| Hard Close | `[ChangeAppeal +12, ChangePatience -6]` |
| Budget Hawk's action | `[ChangeLine +5]` |
| The Karen's action | `[ChangePatienceFloor -1]` |
| Tech Enthusiast's action | `[MarginBonus +300]` |

**The honest boundary:** a new *card* is pure data — drag two existing effects together, zero code.
A genuinely new *verb* is one ~12-line file that then appears in every dropdown in the project
forever, and the engine itself never changes. There is no design in which new verbs cost nothing;
this makes them cost one small file instead of an edit to a growing `if/elif` in the core.

**`describe()` is load-bearing, not decoration.** The `WHAT THEY DO` panel, card tooltips and the
action announcements all build their mechanical text from `describe()`, so the numbers on screen
cannot drift from the numbers that execute. Authors write flavour; the machine writes mechanics.

Triggers work the same way:

```gdscript
class_name Trigger extends Resource
func matches(ctx: EffectContext) -> bool: return false
```

`OnOffer` (`short_at`, `rank_worse_than`), `OnSale` (`rank_better_than`), `Every` (`ticks`),
`PatienceBelow` (`at`, `once`). The rank filters are what let one vocabulary serve both the Budget
Hawk (any short offer) and Family First (any offer below her top five, short or not).

---

## 4. The deck, upgrades, and the shop

The deck is `Array[CardInstance]`, never an array of shared `CardDef` references.

```gdscript
class_name CardInstance extends RefCounted
var card: CardDef
var upgraded: bool = false
var uid: int                 # unique per instance, stable across a run

# Support cards upgrade their effects; product cards upgrade their margin.
# Each accessor is only meaningful for its own kind, and the model already
# branches on kind at the one place it matters (place vs play_card).
func effects() -> Array[Effect]:
    var s := card as SupportCardDef
    return s.upgraded_effects if upgraded and not s.upgraded_effects.is_empty() \
        else s.effects

func margin() -> int:
    var p := card as ProductCardDef
    return p.upgraded_margin if upgraded and p.upgraded_margin > 0 else p.margin
```

This is the fix for the trap that would otherwise bite immediately: with three copies of Explain in
your deck as raw Resource references, upgrading one upgrades all three. `uid` also gives the shop
and the view something stable to point at.

**The shop, between shifts, does exactly three things:** add a card, remove a card, upgrade a card.
That is the entire meta layer in this build — no relics, no run modifiers, no global rule hooks.
The deliberate consequence is one system to balance instead of two, and every purchase is legible
as a card you can look at.

*That said*, the seam that would let modifiers in later costs nothing to leave open now: the deck
is built by `Deck.build_starting_deck(pool)` and the shift reads its configuration through a single
`ShiftConfig` object rather than from globals. When run modifiers are wanted, they hook those two
places. Nothing is built for them today.

---

## 5. Commands, and how the view learns what happened

The model exposes command methods that mirror m2 exactly, each returning a `Result`:

| Command | Ticks | Notes |
|---|---|---|
| `approach(chair)` | 1, or **0** returning to whoever you were last with | |
| `place(hand_index)` | 1 | product onto the table; reveals a band only |
| `play_card(hand_index)` | card's | support card onto the live offer |
| `offer()` | **0** | reveals the exact gap and the rank; provokes their actions |
| `drop_offer()` | 0 | concessions lost |
| `close()` | 0 | the only thing that banks margin |
| `dig(hand_index)` | 1 | discard and draw |

`Result(ok, message, kind, data)` carries the outcome, and **`ok == false` means nothing at all was
spent** — not the tick, not the card. That convention is worth preserving verbatim; it is what
makes a misclick harmless.

The view learns what happened by draining two append-only arrays by index, exactly as `play.py`
does today:

- `shift.events` — arrivals, sales, walks, signings
- `shift.action_log` — structured records of what customers *did* to you, each carrying the
  customer, the action, its dialogue, and the effect list for `describe()`

No signals from the model. Append-only logs are deterministic, trivially testable, and they let the
view animate a sequence of consequences in the order they actually occurred — which signals, fired
mid-mutation, do not.

---

## 6. Screen

One screen. The whole point of leaving the terminal is that the floor and the negotiation are
visible at the same time.

```
+------------------------------------------------------------------+
|  ROGUE DEALERSHIP      tick 12/24     $2,400 / $3,600      [=]    |
+------------------------------------------------------------------+
|  +------------+   +------------+   +------------+                 |
|  |  portrait  |   |  portrait  |   |            |                 |
|  |  Sandra    |   |  Marcus    |   |   empty    |                 |
|  |  Budget H. |   |  Tech Ent. |   |  in 2      |                 |
|  |  ####----  |   |  ######--  |   |            |                 |
|  |  $3,000    |   |            |   |            |                 |
|  +------------+   +------------+   +------------+                 |
|      ^ hover: WHAT THEY DO                                        |
+------------------------------------------------------------------+
|  WITH  Sandra Okonkwo - Budget Hawk            patience  9/16     |
|                                                                   |
|  UNSIGNED   Appearance $900 . Anti-Theft $800    $1,700 at risk   |
|                                                                   |
|  ON THE TABLE   GAP Insurance      Deal . Equity        $1,400    |
|     "I don't lose sleep over that."          their 6th of 9       |
|     APPEAL [########------|.......]  12 SHORT   [OFFER]  [DROP]   |
|                                                                   |
|  YOU KNOW   Equity 6th . Affordability 2nd . line 38     [CLOSE]  |
+------------------------------------------------------------------+
|  HAND   [card] [card] [card] [card]      draw 6  discard 4        |
+------------------------------------------------------------------+
```

**Information model.** Patience and unsigned total are **always live for all three** — those are
the triage inputs, and hiding them creates frustration rather than tension. Negotiation detail (the
appeal bar, their Line, ranks you have learned) shows **only for the customer you are with**.
Nothing stale is drawn: an unattended customer's card shows who they are, how long they have, and
what is at risk, and nothing else.

**Hover a floor card** to see that customer's `WHAT THEY DO` panel — their actions and tells, built
from `describe()`. This is the triage tool: "this one is draining the whole floor" is the fact that
decides who you deal with first, and it should be one mouse-over away rather than a tick.

**Input is mouse-first with keyboard mirrors** of the CLI verbs (`1`–`4` cards, `O` offer, `C`
close, `A`/`B`/`C` chairs, `X`+digit dig), because the CLI's speed for an experienced player is
worth keeping.

---

## 7. Pixel art style guide

Fixed now so nothing has to be re-laid-out later, even though M1 ships with coloured boxes.

- **Base viewport 960×540**, `viewport` stretch, integer scaling, texture filtering off. Clean 2× to
  1920×1080. *This revises the 640×360 figure discussed earlier:* the game is text-dense — card
  text, tells, dialogue, a labelled bar — and 640×360 forces a 5×7 font that would reintroduce the
  exact legibility problem this port exists to solve.
- **Font:** one pixel font at 16px with an 8px variant for dense rows. Free options that read well
  at this size: `m6x11` / `m5x7` (Daniel Linssen), or Kenney's pixel set.
- **Slots:** customer portrait 64×64 · floor card 160×112 · hand card 96×132 · icons 16×16.
- **Palette:** 16 colours, fixed up front, addressed by *role* so art can change without touching
  code — `bg`, `panel`, `panel_hi`, `text`, `text_dim`, `appeal` (blue), `margin` (gold),
  `patience_ok` (green), `patience_warn` (yellow), `patience_bad` (red), `action` (magenta),
  `alert` (red), `accent`, plus three neutrals.
- **Placeholders are real UI**: coloured rects in the exact slot sizes with the exact palette roles,
  so dropping art in later moves no anchors.

Icons are pulled, not drawn — Kenney.nl (CC0) and game-icons.net (CC BY) — per `DESIGN.md` §10.

---

## 8. Determinism, RNG, and save

- **One seeded `RandomNumberGenerator` per run**, owned by the model. Never `randi()`, never
  `Array.shuffle()` — both use the global RNG and would silently destroy reproducibility. A test
  asserts that two shifts built from the same seed produce identical customers and hands.
- **The view gets its own RNG** for flavour lines. This is carried over deliberately from m2's
  `Voice` class: presentation must never be able to shift what the rules roll next.
- **Save** is run-level only, to `user://run.save` as JSON: deck (card id + upgraded + uid), shift
  index, banked total, quota schedule, and the run RNG state. No mid-shift save in this build.

---

## 9. Testing

A zero-dependency headless runner in m2's style, so the output is the same line the project has
been reading for three milestones:

```bash
godot --headless --script res://tests/run_tests.gd
# 355 checks, 355 passed, 0 failed
```

**The parity suite is the core of it.** m2's tests already force ranks and hands explicitly with
`_rank()` and `_hand()` to remove randomness — which means they port almost line for line and
assert the same facts about the same forced states. That proves the GDScript rules match the Python
ones *case by case*, which is achievable, rather than trying to match RNG streams across two
languages, which is not.

Also pinned, beyond parity:

- **`describe()` matches `apply()`** — for every effect, the described number is the number applied.
  This is the guard that keeps auto-generated UI text honest.
- **Deck integrity** — the starter deck is exactly 14 cards, 6 products at two per category, 8
  support, only `starter: true` entries.
- **Upgrade isolation** — upgrading one `CardInstance` of Explain leaves the other two untouched.
- **Resource hygiene** — no runtime state is stored on a `Resource`; two shifts built back to back
  do not share customer state.
- **Every content pool declares its `design_rule`.**

---

## 10. Milestones

Each is a build you can run.

| # | Goal | Done when |
|---|---|---|
| **G0** | Data resources + pure model + headless tests. No UI at all. | The parity suite passes against m2's cases |
| **G1** | One shift, fully playable on screen | You can play a shift end to end with a mouse and prefer it to the CLI |
| **G2** | Shift → shop → shift, with save | You can add, remove or upgrade a card and take it into the next shift |
| **G3** | Art pass, audio, Windows + itch.io web export | Someone else can play it without you in the room |

G0–G2 together are "the first Godot build". **Vertical before horizontal:** no new archetypes, no
new cards, no new mechanics until G2 runs.

Web export needs cross-origin-isolation headers (`COOP: same-origin`, `COEP: require-corp`) because
Godot 4 uses `SharedArrayBuffer`; itch.io has a checkbox for this. Develop against a native Windows
build and add web at G3 — `DESIGN.md` §11.

---

## 11. Risks

- **Text density versus pixel art** is the real tension in this port, and 960×540 is a bet on it.
  If it still feels cramped at G1, the fix is a larger base viewport, not a smaller font.
- **`.tres` files store script paths.** Moving or renaming an effect script breaks every resource
  referencing it. Mitigation: `class_name` on every effect and trigger, and settle the
  `scripts/model/effects/` layout at G0 before authoring content against it.
- **Godot Resource caching** shares instances project-wide. Any mutable state that reaches a
  Resource will leak between customers and between runs. The rule "runtime state is RefCounted,
  never Resource" is not stylistic, and a test enforces it.
- **Parity drift after G0.** Once the Godot rules are authoritative, m2 becomes frozen reference.
  Decide at G2 whether the Python engine is retired or kept as a fast balance sandbox; keeping both
  editable is exactly the drift this project has avoided three times.
- **Scope creep at G2.** The shop is three verbs. Relics, shift conditions and run modifiers are all
  designed *around* it in this document and none are in it.

---

## 12. Open items

- **Quota schedule across a run** — G2 needs a curve (flat? +15% a shift?). Undecided, and it wants
  play data from G1 rather than a guess now.
- **How many shifts is a run?** Undecided for the same reason.
- **What "upgraded" means for a product card** — `upgraded_margin` is the mechanism, but whether a
  +$300 VSC is interesting or just numerically bigger is an open design question.
- **Audio** — nothing decided beyond "at G3".

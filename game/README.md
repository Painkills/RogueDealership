# G0 — the rules, ported

The Godot project. **G0 has no UI**: it is the pure rules core, the data that
drives it, and the headless suite that proves the port is faithful. The point of
building it this way round is that the rules are proven *before* a pixel is drawn.

```bash
godot --headless --path game --import                       # after adding any class_name script
godot --headless --path game --script res://tests/run_tests.gd
```

```
564 checks, 564 passed, 0 failed
```

> **[`m2/README.md`](../m2/README.md) is the rules spec.** This project implements
> it. If the two disagree about a rule, m2 wins and this project is wrong.
> [`GODOT_SPEC.md`](../GODOT_SPEC.md) is the architecture.

---

## The three properties this is built to protect

**The model never touches a Node.** `scripts/model/` is plain `RefCounted`
classes — no scene, no signal, no `_process`. The headless suite drives the
identical object the game will, so they cannot drift. `test_architecture.gd`
enforces it.

**Content is data.** A new card is a `.tres` you assemble in the Inspector from
existing effects. A new customer archetype is a `.tres` with a list of actions.
Neither needs a line of code.

**All randomness goes through one seeded RNG.** Bare `randi()`, `randf()` and
`Array.shuffle()` use Godot's *global* generator and would silently destroy
reproducibility. A guard test scans the model for them — comments stripped, since
the model deliberately explains in prose why they are banned.

---

## Layout

```
game/
  data/                 authored content, all .tres
    interests/          3 categories, 9 interests, the pool
    products/           9 products
    cards/              9 support cards
    archetypes/         7 customer archetypes
    shift_config.tres   every number the game plays with
  scripts/model/        the pure rules core
    effects/            Effect base + one small file per verb
    triggers/           Trigger base + one small file per trigger
  tests/                the headless suite
  tools/                one-off bootstrap scripts (see below)
```

### The effect vocabulary

An `Effect` is a Resource with `apply(ctx)` and `describe()`. A card holds an
`Array[Effect]` assembled in the Inspector.

| Effect | What it does |
|---|---|
| `ChangeAppeal` | moves the live offer's Appeal |
| `ChangeMargin` | moves the live offer's Margin |
| `ChangeLine` | moves how high Appeal must climb |
| `ChangePatience` | the customer you are with |
| `ChangePatienceFloor` | everyone *else* on the floor |
| `RevealRoom` | their Line and the category of their number one |
| `DiscardHand` | takes cards out of your hand |
| `MarginBonus` | lands on the sale being settled, not the offer |
| `ScaleBySales` | combinator: applies the wrapped effect once per product taken |

**A new card is data. A new verb is one ~12-line file** that then appears in
every Inspector dropdown in the project, and the engine never changes. That is
the honest boundary — there is no design where new verbs cost nothing.

**`describe()` is load-bearing, not decoration.** UI text will be generated from
it, so the number on screen cannot drift from the number that executes, and a
test pins that they agree.

---

## Bootstrap scripts

`tools/seed_*.gd` wrote the initial `.tres` files from m2's data. They are
**bootstraps, not a build step** — the `.tres` files are the source of truth now
and are edited in the Inspector. Re-running a seed script overwrites hand edits.

```bash
godot --headless --path game --script res://tools/seed_interests.gd
godot --headless --path game --script res://tools/seed_cards.gd
godot --headless --path game --script res://tools/seed_archetypes.gd
godot --headless --path game --script res://tools/seed_config.gd
```

---

## What the suite pins

Beyond the ported m2 cases — the appeal ladder, the Line ramp, the two-step
offer, the Karen's lock, walking forfeiting the unsigned deal — G0 adds guards
that only matter in Godot:

- **`describe()` agrees with `apply()`** for every effect.
- **Upgrade isolation** — upgrading one `CardInstance` of a card leaves its
  siblings untouched. This is the trap a deck of shared Resource references
  walks straight into.
- **Resource hygiene** — two shifts built back to back share no state, and the
  runtime classes all extend `RefCounted`.
- **No global RNG** anywhere in the model.
- **The model never imports the view** and never extends `Node`.
- **Every content pool declares its `design_rule`.**

---

## Notes for whoever picks this up next

- **`--import` after adding any `class_name` script.** Without it the headless
  runner cannot resolve the global class and every test in that file reports
  "did not compile".
- **The test runner treats a parse error as a failure, not a crash.** A script
  that fails to parse loads as a broken `GDScript` rather than `null`; calling
  `new()` on it aborts the run before `quit()`. That is the state every task is
  in at its red step, so the runner checks `can_instantiate()`.
- **`EffectContext` holds untyped fields on purpose.** Typing them would make
  `Effect → EffectContext → Customer → CustomerArchetype → CustomerAction →
  Effect` a cyclic `class_name` dependency, which GDScript rejects.
- **Cadence lives in the caller, not the trigger.** `Every` has no memory; the
  shift tracks when each action last fired per customer.

---

## Open

- **No UI.** That is G1.
- **No run layer, no shop, no save.** That is G2. `Deck` already supports
  add/remove/upgrade and `CardInstance` carries a stable uid, so the seams exist.
- **Parity is proven case by case, not by RNG.** m2's tests force ranks and hands
  explicitly, so they port directly; matching random streams across two languages
  is not achievable and was never attempted.
- **m2 is still editable.** Once the Godot rules are authoritative, m2 should be
  frozen as reference — keeping both editable is exactly the drift this project
  has avoided three times. That decision comes due at G2.

---

## G1 — playable on screen

G1 is the view layer on top of G0's model. Five scenes — `HandCard`,
`FloorCard`, `CustomerPanel`, `ReportPanel`, and `ShiftController`, which
instances the other four and owns the live `Shift` — plus two static support
classes, `Palette` and `Format`. The whole shift plays end to end with a
mouse: approach a chair, play or dig cards, offer, close, watch the report,
restart.

### Layout

```
game/
  scenes/
    hand_card.tscn         one card in your hand
    floor_card.tscn        one chair on the floor (name, archetype, patience, unsigned)
    customer_panel.tscn    the negotiation view for whoever you're with
    report.tscn            end-of-shift report
    shift.tscn             the whole game — instances the other four, run/main_scene
  scripts/view/
    hand_card.gd
    floor_card.gd
    customer_panel.gd
    appeal_bar.gd          sub-component inside customer_panel.tscn, not its own scene
    report_panel.gd        script for both report.tscn and the overlay baked into shift.tscn
    shift_controller.gd    shift.tscn's script — owns the Shift, wires every signal, keyboard
    palette.gd              static class_name, the 16-colour palette by role (GODOT_SPEC.md §7)
    format.gd               static class_name, money/patience text shared by every scene
```

`Palette` and `Format` were originally planned as autoloads. Godot's
`--headless --script` test runner doesn't instantiate project autoloads at
all — not even for compile-time symbol resolution — so they're plain static
`class_name` classes instead, called the same way (`Palette.color(...)`,
`Format.money(...)`) but with no scene-tree dependency. That's a better fit
for two stateless helpers anyway; nothing else in this codebase uses an
autoload for something that isn't shared mutable state.

### Information model

One rule governs the whole screen, carried over from `GODOT_SPEC.md` §6:
patience and the unsigned total are **always live for all three floor
chairs** — those are the triage inputs, and hiding them would create
frustration instead of tension. Negotiation detail — the appeal bar, their
Line, what ranks you've learned — is drawn **only for the customer you're
currently with**. An unattended chair shows who they are, how long they
have, and what's at risk, and nothing else. Hovering a floor card shows that
customer's `WHAT THEY DO` panel — their archetype's actions and tells, built
from the same `describe()` the model already uses — so "this one is draining
the whole floor" is one mouse-over away, not a tick spent finding out.

### Keyboard mirror

Mouse-first, with a keyboard mirror of every action, 15 in total:

| Key | Action |
|---|---|
| `1`–`4` | play hand card 1–4 |
| `Shift`+`1`–`4` | dig hand card 1–4 (discard and redraw) |
| `A` / `B` / `C` | approach chair 1 / 2 / 3 |
| `O` | offer |
| `D` | drop |
| `Shift`+`C` | close |
| `F` | step back to the floor, without closing |

Two of these weren't in this plan's original scope. `dig_1`–`dig_4` exist
because Global Constraints required a keyboard mirror for dig and no draft of
this plan — including the one about to be dispatched — had ever actually
wired one; the gap was only caught while writing Task 9. `floor_key` (`F`)
exists because Task 6's own manual-verification notes flagged that there was
no way to step back to the floor view without closing the customer you were
with, and that gap sat unfixed until Task 9 added it. Both were found by
someone reading the actual wiring, not planned up front.

### Open

**No task in this implementation ever ran with an interactive display.**
Neither the controller session nor any subagent could launch the editor and
press Play — every "manual verification" step in Tasks 6, 7, and 9 was
rescoped, out of necessity, into scripted headless checks: construct a
`SceneTree`, drive it through state transitions or synthetic `InputEventKey`
events, and assert on node state the same way a human's eyes would check it.
Those checks are real, not theater — Task 1's fix loop found that Godot's
`--script` mode never instantiates project autoloads, not even for
compile-time symbol resolution, which forced Palette/Format off autoloads
entirely; Task 9's driver found that an action registered without an
explicit `shift_pressed` also fires on Shift-held input, which made
`close_key` (Shift+C) unreachable until the `_unhandled_input` branches were
reordered. But a script can only confirm that the wiring does what the code
says it does. It cannot confirm the screen reads well, that the information
model actually resolves the tension it's meant to, or that any of this is
fun. G1's stated goal — more legible than the CLI it replaces — has not been
judged by anyone yet. That happens the first time a human runs
`godot --path game --editor`, presses Play, and looks at it.

Smaller, known gaps, all deliberate:

- **No shop, no run layer, no save.** One shift, played once, then a report
  screen with a restart button. That's G2.
- **No real art.** Floor card and hand card slots use the exact sizes and
  palette roles `GODOT_SPEC.md` §7 specifies. The portrait and icon slots §7
  also defines were never built — no task's design included them — and most
  palette roles are applied ad hoc per-script rather than through a shared
  `Theme` resource. Both are open for a later polish pass, not implemented
  placeholders waiting for art.
- **No sound.** Nothing plays; nothing is wired to play anything.

---

## G1.5 — the cards became 3D

The hand, the piles and the customers' tables are now real 3D cards, using
[Card3D](https://github.com/tdecker91/Card3D) (MIT, vendored verbatim into
`addons/card_3d/` — see `VENDORED.md` there). **You play a product by dragging
it onto a customer.** Dropping on someone you are not standing with approaches
them first, at the usual tick cost; dropping on the discard pile digs.

The model did not change. Not one line under `scripts/model/`. That isolation is
the entire reason a UI rewrite of this size was cheap, and it is worth saying
plainly the first time it actually paid out.

`shift.tscn` is a `Node3D` table with a `CanvasLayer` HUD over it: a head-on
`Camera3D`, a `WorldEnvironment`, and six `CardCollection3D` zones — three
chairs, draw, discard, hand.

**Everything on the table is a card, including the words.** A customer is a
card; what they do is a second card tucked flush behind the first; a product on
the table is a card; what it is worth is a fourth. Sitting down slides the two
detail cards out to the right — and that slide is what replaced the earlier idea
of *growing* the customer card, which scaled it up by a third and drove it
straight down into the product slot below.

The HUD keeps only what belongs to the player or to the shift: the top bar, the
event log, the OFFER / DROP / CLOSE column, the mode button, the floor tooltip
and the end-of-shift report. It describes nothing that is on the table. Two
surfaces describing one customer is how a customer's data went missing, and a
panel positioned by arithmetic is how it kept landing on top of the product it
was describing. Geometry does that job now, and geometry can be asserted.

**Sitting down hides the other two seats.** The seats are close enough together
for the floor view to be legible, which puts the neighbours inside the seat
framing whether you like it or not. Hiding a `Node3D` does *not* disable the
`Area3D` under it, so the chair's drop zone is disabled with it — otherwise you
could drag a card into a customer you cannot see and be walked over to them.

### Three rules that will bite whoever changes this next

**One stray `Control` makes every card in the game dead.** Godot resolves
Control GUI input *before* 3D physics picking, so any Control with
`mouse_filter != IGNORE` under the cursor eats the click. `ColorRect`,
`PanelContainer` and `RichTextLabel` all default to `STOP`; `Container`
defaults to `PASS`, which also blocks. G1's full-rect background `ColorRect` is
gone for exactly this reason, replaced by the `WorldEnvironment`. Only real
`Button`s and the report overlay may block. `test_shift_scene.gd` lints it, and
that lint is also the regression test G1's floor-card bug never had — its
`HoverPanel` was revealed by hovering the card it covered, so as a `STOP` node
it swallowed the very click that revealed it.

Related and identical in symptom: `get_viewport().physics_object_picking`
defaults to `false`, and Card3D's whole input path is `StaticBody3D.input_event`.
The controller sets it in `_ready()`. If nothing responds, check both.

**Cards are reconciled by uid, never rebuilt.** G1's `_render()` freed and
recreated the hand every pass; in 3D that frees the node a drag is holding and
kills every tween. `CardHomes.desired()` derives where each card belongs purely
from model state and `_reconcile()` moves only the difference. Nothing frees a
card node outside `_start_new_shift()` — a freed node still held by
`DragController` crashes the next `apply_card_layout()`.

This is also why there is no revert path for a refused drop: the model still has
the card in hand, so reconciliation walks it home on its own, tweening because
`_move_card()` preserves `global_position` across the reparent. **The bounce is
the reconcile.**

**Scene inheritance cannot come from a builder script.** Load-instantiate-repack
bakes a *copy* and severs the link to upstream, so `card_face_3d.tscn` is
hand-authored `.tscn` text instead — a scene whose *root* node carries
`instance=ExtResource(...)` is an inheritance. Everything else is still built by
`tools/build_*_scene.gd`, which is fine because instancing *does* survive
packing. What does not survive is any strategy property that is not `@export`:
`LineCardLayout.max_width` serialized as nothing and silently reverted to the
library default of 20 units, so it is set at runtime and asserted by the driver.

### Verifying it

```bash
godot --headless --path game --import
godot --headless --path game --script res://tests/run_tests.gd     # the suite
godot --headless --path game --script res://tools/drive_shift.gd   # a live shift
godot --headless --path game --script res://tools/probe_framing.gd # where things land
```

`drive_shift.gd` instantiates the real scene, drives it through approach, play,
offer, dig, close and leave, simulates a drop and a refused drop, walks the
appeal meter through red / amber / green, and asserts after every one that each
card sits where the model says and that only hand cards are draggable. It cannot
live in the suite: `run_tests.gd` works inside `_init()`, where `_ready()` has
not fired.

**The layout is asserted in screen pixels, not eyeballed.** Both of the last two
rounds of "this looks wrong" — the customer card overlapped by the product card,
and the offer panel landing on top of the product it described — were arithmetic
that happened to be checked by a human. `drive_shift.gd` now unprojects every
card in both framings and asserts the rectangles do not intersect, that each
detail card is wholly to the right of its partner, that nothing reaches into the
log's column, that no button sits on a card, and that a floor card is at least
360 px tall. `probe_framing.gd` prints the same numbers instead of asserting
them, which is how the camera constants were chosen — it asks the camera rather
than reasoning about field of view, and reasoning about field of view is how the
last three layouts went wrong.

**A test that runs no checks is a failure.** Three times now a runtime error has
aborted a check function partway, leaving the remaining checks unrun and the
summary reporting "all passed" on whatever happened to have executed — twice in
the driver, and once in the suite, where a `test_` that loaded a deleted scene
counted for exactly nothing across two commits. `run_tests.gd` now fails any
`test_` that records zero checks, and `drive_shift.gd` fails if its total falls
below a floor. Neither guard is optional; a silent abort must never read as a
pass.

### Still open

**Nobody has looked at this.** Everything above is structural or arithmetic: that
the wiring matches the model, that no Control blocks picking, that the text says
what it should, that the rectangles do not collide. None of it can tell you
whether the composition reads, whether the push-in feels like walking over to
someone, or whether a hand that runs off the bottom of the screen is comfortable
to play from. The numbers say a card face lands at 317×444 px on the floor and
254×356 px at a seat, against a 500×700 authored face — that is a legibility
argument, not a verdict.

Two specific things to look at first, both single constants:

- `SEAT_CAM_Z` and `FLOOR_CAM` in `tools/build_shift_scene.gd`, or just drag the
  `CameraFloor` / `SeatCam*` gizmos in the editor.
- `DetailCard3D.SLIDE_OUT`, which is how far the detail cards travel.

Also unchanged from G1's list: whether any of it is *fun*. Still only answerable
by playing it.

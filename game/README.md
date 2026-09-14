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
have, and what's at risk, and nothing else. What a customer DOES is the BACK
of their card: hovering turns the card over, showing their archetype's actions
and tells, built from the same `describe()` the model already uses — so "this
one is draining the whole floor" is one mouse-over away, not a tick spent
finding out.

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

**Everything on the table is a card, and every card has a back.** A customer is
a card; what they do is a second card of the same size sitting flush behind the
first and facing the other way — so it really is that card's back. A product on
the table is a card; what it is worth is that card's back.

Hovering a customer on the floor turns the **pair** over. Doing it card by card
cannot work: flip each in place and the front card is still in front, so all you
see is its own back. The z-order has to come along, which is what rotating a
shared parent (`FlipPair`) does. Sitting down instead slides both backs out to
the LEFT and turns them face-front, so you have both halves side by side.

That replaced the earlier idea of *growing* the customer card, which scaled it
up by a third and drove it straight down into the product slot below.

The HUD keeps only what belongs to the player or to the shift: the top bar, the
event log, the OFFER / DROP / CLOSE column, the mode button and the end-of-shift
report. It describes nothing that is on the table. Two surfaces describing one
customer is how a customer's data went missing, and a panel positioned by
arithmetic is how it kept landing on top of the product it was describing.
Geometry does that job now, and geometry can be asserted.

**Sitting down hides the other two seats.** The seats are close enough together
for the floor view to be legible, which puts the neighbours inside the seat
framing whether you like it or not. A hidden seat must still refuse drops — but
that is enforced *during* a drag, never by arming a drop zone (see the next
section, which is the most expensive lesson in this file).

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

**An empty floor used to stop time for good.** Every command that moves the
clock needs a customer to move it on — except `dig`, and `dig` goes through your
hand, which the view stows below the bottom of the screen while you are out on
the floor. So the last customer walking out of a floor with empty chairs left
nothing on screen to press and a tick counter that would never reach the end of
the shift. `Shift.wait()` is the way out; the view calls it by itself, in a loop,
because an empty floor is not a decision. Two things make that safe: `wait()`
always advances the clock by at least one tick, and it refuses while anybody is
still seated so it can never become a general skip-time button.

**The view must show everything the model tells the player.** Twice now a rule
has been set in the model and silently dropped on the way to the screen:
`customer.demands` (the Karen's "will not sign until they buy from this
category") is enforced by `close()`, so it never fires, never reaches the event
log, and appeared nowhere at all; and `customer.known_top_category` — the half
of Read the Room that narrows nine interests to three — was set by
`reveal_room()` and then ignored by `known_text()`, which only walked
`known_ranks`. Both are on the detail card now, and the driver imposes each
condition rather than waiting for the deal to produce one, because a check that
only sometimes runs has only sometimes been verified.

**A hover target must never be the thing the hover moves.** Hovering a customer
turns their pair over — and while the pair turns, the card's collider turns with
it. A card is a flat quad with no thickness, so its projected area shrinks to
nothing on the way round: the ray stopped finding it, the mouse "left", the flip
reversed, the mouse "entered", and the card stuttered. `probe_input.gd` measured
it — aimed near the card's edge, the collider was gone from 75° onward and did
not come back until 180°, which is exactly why it depended on where you brought
the cursor in from. Every seat now has a `HoverPad`: an invisible box that never
moves, owning the hover and the click, with the customer card's own collider
disabled so the two cannot disagree.

**And a third with the same symptom, which is the one that actually shipped:
never enable a drop zone outside a drag.** Godot's 3D picking fires ONE ray and
takes the CLOSEST collider, so anything in front of a card owns every click
meant for it. A `CardCollection3D`'s `DropZone` is a `StaticBody3D` on a 14 × 4
slab sitting **3.2 units nearer the camera than the cards** — a wall. That is
why the addon arms them in `_drag_card_start()` and disarms them in
`_stop_drag()`, and why arming one to stop a hidden seat taking drops made every
card in the game untouchable: hover dead, clicks dead, no error, nothing on
screen to say why. Hidden seats are disarmed from `drag_started` instead, which
fires *after* the addon has armed everything. `drive_shift.gd` now fires the
same ray the engine fires and asserts it reaches the card — and asserts that no
drop zone is ever armed at rest.

**Cards are reconciled by uid, never rebuilt.** G1's `_render()` freed and
recreated the hand every pass; in 3D that frees the node a drag is holding and
kills every tween. `CardHomes.desired()` derives where each card belongs purely
from model state and `_reconcile()` moves only the difference. Nothing frees a
card node outside `setup()` — a freed node still held by
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
godot --headless --path game --script res://tools/drive_run.gd     # a live run: shift, shop, shift
godot --headless --path game --script res://tools/probe_framing.gd # where things land
godot --headless --path game --script res://tools/probe_input.gd   # why nothing is clickable
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

`probe_input.gd` answers the other question that keeps coming back: *why is
nothing clickable?* There are two systems that can cause it and they have
identical symptoms, so it asks both — it fires the real camera ray at each
card's screen centre and prints what the physics space actually returns, and it
walks the HUD for any visible Control containing that same point without
`MOUSE_FILTER_IGNORE`. That is what found the drop-zone wall: a ray aimed at a
hand card came back `Seat0/Chair0/DropZone`.

**A test that runs no checks is a failure.** Three times now a runtime error has
aborted a check function partway, leaving the remaining checks unrun and the
summary reporting "all passed" on whatever happened to have executed — twice in
the driver, and once in the suite, where a `test_` that loaded a deleted scene
counted for exactly nothing across two commits. `run_tests.gd` now fails any
`test_` that records zero checks, and `drive_shift.gd` fails if its total falls
below a floor. Neither guard is optional; a silent abort must never read as a
pass.

### Still open

**Somebody has looked at this now, and it played.** Everything above is
structural or arithmetic - that the wiring matches the model, that no Control
blocks picking, that the rectangles do not collide - and none of it could have
answered whether the composition reads or the push-in feels like walking over to
someone. That took several rounds of the same person actually sitting down with
it: reporting cards that would not respond, a hover that stuttered, a hand whose
left edge disappeared under the one to its right, a softlock when the floor
emptied out. Every one of those was a real defect this file's checks could not
see, and every one is fixed and pinned by a check now. The two single-constant
knobs this section used to point at - `SEAT_CAM_Z`/`FLOOR_CAM` in
`tools/build_shift_scene.gd`, and `DetailCard3D.SLIDE_OUT` - are exactly what
those rounds tuned; they are not open questions any more.

What playing it produced, unprompted: "this is fun, this iteration feels
engaging." That is G1's own exit criterion in `GODOT_SPEC.md` §10.

What is still genuinely unverified, because two people who already know the
design are not the same test as a stranger: whether it reads to someone sitting
down with no context, and how the pacing holds up across a full shift played at
real speed rather than in the short bursts each feedback round has been so far.

---

## G2 — the run layer

G1 played one shift, once, then offered a restart. G2 wraps that in an actual
run: five shifts, climbing quota, a shop between each one where what you did to
your deck last time is still true. `RunState` and `Shop` are the whole layer -
`scripts/run/`, pure `RefCounted` like the model, no scene, no signal, driven by
the identical object the headless suite drives.

`RunState` owns the run's ONE seeded RNG, the deck, and the money; `Shop` is
stateless with respect to all of that - it takes a `RunState` in its
constructor and every verb (`buy`, `remove`, `upgrade`) reads and writes
straight through it. The split exists so `run_controller.gd` can stay exactly
what its own doc comment says it is: it owns the `RunState` and decides which
of two screens you are looking at, and nothing else. That is the same
discipline `shift_controller.gd` learned the hard way in G1.5, when it stopped
building its own `Shift` and started being handed one - the run layer is what
now hands it one, seeded and quota'd for the shift you're on.

**The economy in one sentence:** the quota is the house's cut and comes out
first, so only what a shift banks OVER its quota is yours - and that overage is
a BONUS that stacks for the length of the run. `RunState.finish_shift()` does
`money += maxi(0, margin_banked - quota)`, and nothing else pays you.

The stacking is what makes the rule survivable rather than punishing. Nothing
on any shelf costs less than the cheapest product, so a budget that reset each
shift would round most overages to nothing at all - beat quota by $300 three
times and you would have bought exactly nothing. Pooling them turns three thin
shifts into one real purchase. Missing quota adds nothing to the bonus pot, but
it never drains what earlier shifts already earned - it does, however, cost you
somewhere else now. See standing, below.

The number is announced twice, because it is two different questions. The
report panel says what THIS shift earned ("You exceeded your quota. You got a
$900 bonus!"), computed by `RunState.bonus_from()` - a static, because the
panel is on screen while `finish_shift()` has not run yet and the run has not
advanced. The shop says what the POT is worth now, with the latest addition
beside it, since a total alone cannot tell you whether the shift you just
played earned anything.

The open balance question is `quota_growth`, which climbs 15% a shift on the
stated premise that the deck is getting stronger in the shop to keep pace. That
premise holds more weakly here than under a flat budget: a run that keeps
scraping by faces a rising quota against a deck it could not afford to improve,
and only the pooling saves it. Whether that pressure is the good kind is a
playtest question - `quota`, `quota_growth` and every price are single values
in `shift_config.tres` and the card `.tres` files if it isn't.

**Standing is the run's HP - the stake this economy was missing.** Before this,
`is_over()` was exactly `shift_number > shifts_in_run`: nothing else in a shift's
outcome ever touched it, so a run could be played badly from the first customer
to the last and still walk into shift 5 on schedule - a scorecard, not a game
that can be lost. Now `is_over()` is `shift_number > shifts_in_run OR standing
<= 0`, and standing has two separate ways to lose ground in one shift, added
together into one delta. The quota side reuses the exact `margin_banked - quota`
number that already funds the bonus - one number, two consequences, nothing new
to learn there. `Shift._standing_delta_from_quota()` is asymmetric on purpose:
missing quota costs `standing_damage_scale` (50) points at a full miss, beating
it heals only `standing_heal_scale` (15) at an equal fractional margin - "a bad
shift makes death more likely," not "one bad shift and you're out." A run
starts at `standing_start` (100), so one total wipeout is survivable and two in
a row is not.

**Letting customers walk costs standing on its own, independent of the till -
and IMMEDIATELY, not at the report screen five minutes later.** `_burn()`
drains every SEATED customer's patience on every tick spent, regardless of who
you are actually helping - so a floor you neglect empties itself even while
you make quota elsewhere, and until now that had no consequence beyond the
margin left unsigned on their table.

This is the one place `Shift` genuinely owns a live piece of the run's HP
rather than only reporting on it after the fact. `Shift.standing` is seeded
from `RunState.standing` at construction (the same "0 means use the config
default" convention `quota` already uses), and `_walk()` docks it
`standing_cost_per_walkout` (8) THE MOMENT someone leaves - `maxi(0, ...)`, so
a walkout is what can make `is_over()` true, never what makes `standing` read
negative. `Shift.is_over()` grew the matching clause: `tick >= tick_budget or
standing <= 0`. Nothing else needed to change for "the run ends the instant
you get fired" to be true - `_apply()` already checks `is_over()` after every
single command and shows the report the moment it is true, for whatever
reason, so a walkout that zeroes standing mid-shift shows YOU'RE FIRED on the
very same command that caused it, with ticks still left on the clock.

The quota term still can't be evaluated until the shift ends - margin_banked
isn't final until then - so `report()`'s `standing_delta` is
`(standing - _initial_standing) + _standing_delta_from_quota()`: whatever
walkouts already docked live, plus the quota term evaluated fresh at the end.
`RunState.finish_shift()` didn't need to change at all - it was already just
applying whatever delta the report handed it, and that delta still means the
same thing it always did. `standing_lost_to_walkouts` travels in the report
too, tracked as its own running total in `_walk()` rather than re-derived from
a formula, so a walkout that hits the floor at 0 reports the dollars - sorry,
standing - it actually cost, not a theoretical amount partly clamped away.

**A customer about to leave says so in the log first.** `leaving_soon()`
already existed - it is what turns a low patience number red on their card -
but it drove no text anywhere. `_settle_patience()` now logs one line per
ENTRY into that danger zone ("is losing patience"), not one per tick spent in
it: `Customer.warned_leaving_soon` re-arms the moment patience climbs back out
above the threshold, so a customer saved once and endangered again gets warned
again, honestly, rather than either spamming the log every tick or falling
silent for the rest of the shift after the first scare.

The formula lives on `Shift`, not `RunState`, unlike the bonus: `bonus_from()`
is a static that needs nothing but the report dict, but standing's formula
needs `cfg.standing_damage_scale`/`standing_heal_scale`, which `Shift` already
holds and `RunState` does not see until the report comes back. So
`Shift.report()` embeds `"standing_delta"` as one more fact about what
happened, the same way it already embeds `made_quota`, and both
`RunState.finish_shift()` and the report panel just read that key rather than
computing it twice.

A fatal shift has to look different from a finished one, or the feature is
invisible - both used to roll a fresh run through the exact same silent
`_start_run()`, with only a console `print()` telling them apart. The report
panel now overrides its own title to `YOU'RE FIRED` and its continue button to
match whenever the shift it is reporting on would take standing to 0, computed
in `shift_controller._show_report()` - the one place that has both the run's
pre-shift standing and this shift's own delta, since `Shift` has never held a
`RunState` reference and `standing_before` travels in through `setup()`
alongside it instead.

**The archetype ladder is the run's difficulty curve.** Every
`CustomerArchetype` declares `min_shift`, and `Shift` only deals customers
whose `min_shift` has come due - `shift.gd`'s comment on that filter is blunt
about why: a misauthored `min_shift` must never index an empty array, because
an empty floor is a stalled game, not a graceful skip. `archetype_pool.tres`'s
own `design_rule` states the ladder in full: easiest first, an archetype with
no actions opens the run, a gift comes next, a resource working against you
after that, and the archetype that punishes the whole floor comes last. G2
does not add to that ladder; it is what finally plays it end to end, five
shifts deep, instead of stopping after one.

**Two guards keep the shop from being able to build a run it cannot win.**
`min_deck_size` (from G1.5) floors the deck's raw SIZE: below a full hand,
`_draw_up` cannot fill one, so there is nothing to dig and nothing to wait for
if you are seated - the exact softlock `wait()` exists to fix, reachable
through the shop if nothing stopped it. `min_products`, new here, floors the
deck's COMPOSITION instead: `margin_banked` only ever moves through a placed
product's `Offer`, so a deck with no products left can never bank another
dollar, and since `money` is whatever `margin_banked` clears the quota by, that
shop then has $0 forever with no other income. The run keeps playing, but it is already dead -
which is worse than a softlock, because nothing on screen says so. Both guards
are the same shape in `Shop.remove()`: refuse and spend nothing, with a message
that says which floor you hit.

**`hand_min_products` floors the HAND, for the same reason on a smaller scale.**
A 5-card hand from the 14-card starter deck holds no product at all 2.8% of the
time (`C(8,5)/C(14,5)`), and that hand is close to paralysis rather than merely
weak: `needs_offer` defaults to true and only `readroom` and `smalltalk` set it
false, so six of the eight starter support cards refuse to play with an empty
table. You get Read the Room, Small Talk, and then `dig` at a tick a card. G1.5
softened this by raising `hand_size` from 4 to 5, which took it from 7% to 2.8%;
this takes it to nothing.

`_draw_up` deals off the top of the pile as it always did, *unless* taking the
top card would strand the hand under the floor - which it only checks once the
slots left to fill are down to the product deficit itself. So a hand that draws
products on its own never sees the bias and the shuffle stays honest right up to
the last card. A floor of 1 fires on ~1 hand in 36. A floor of **2** would fire
on ~1 in 4 and hand you a second probe on a fifth of all hands, which is a
balance change rather than a guard - probes are how you read a customer, so that
number is not a knob to turn casually.

The subtlety is `_recycle_discard()`. Placed products drain into the discard as
a shift runs, so by mid-shift the draw pile goes product-free while still
holding plenty of support - and waiting for the pile to empty on its own would
make the floor lapse exactly when a dead hand hurts most. So when the floor
needs a product, the pile has none, and the discard *does*, the discard comes
back early. The promise that buys is worth stating: **if a product is anywhere in
circulation, you can play a product.** It only fails when all of them are
sitting in offers on the table, which `_next_draw_index`'s `-1` branch handles
by dealing the top card - there is nothing to conjure.

### Layout

```
game/
  scenes/
    shop.tscn            between shifts - add, remove, upgrade, then back to work
    run.tscn             the main scene: ShiftView + ShopView, run_controller.gd on top
  scripts/run/           pure RefCounted, like scripts/model/
    run_state.gd          the run: deck, money, banked_total, the seeded rng
    shop.gd               the three verbs, each a Result, each a refusal that spends nothing
  scripts/view/
    shop_screen.gd         shop.tscn's script - rebuilds both lists after every purchase
    run_controller.gd      owns the RunState, switches between ShiftView and ShopView
  tools/
    build_shop_scene.gd    builds shop.tscn
    build_run_scene.gd     builds run.tscn
    drive_run.gd           drives a whole run through a live scene: shift, shop, shift
```

### Verifying it

```bash
godot --headless --path game --script res://tools/drive_run.gd   # a live run: shift, shop, shift
```

`drive_run.gd` instantiates the real main scene, plays a shift out, presses the
report's own button rather than emitting its signal by hand, buys a card in the
shop by uid rather than by `CardDef` - an old copy already in the deck would
satisfy a `CardDef` match even if the purchase never reached the next shift's
deck at all - and confirms it deals into the next shift. It also measures the
shop screen in pixels, the same discipline `drive_shift.gd` applies to the
shift's own HUD: `shop.tscn`'s `DoneButton` is the only way out of the shop,
and the shop has no keyboard mirror, so a button rendered off-screen is a hard
softlock with no other way out.

### Open

**No end-of-run screen.** Finishing the fifth shift logs `banked_total` and the
shift count and rolls a fresh run rather than presenting one. That is out of
scope for G2 by design - what mattered here was making the end of a run
*legible*, not building the screen for it. The report button now says FINISH
THE RUN instead of Continue on that last shift, so pressing it does not read as
just another shift wrapping up.

**No save.** A run lives entirely in memory; closing the game loses it. m2's
own G2 note flagged this as the point where m2 itself should be frozen as
reference rather than kept editable alongside Godot - that decision has not
been made yet.

## Touch - the first pass, ahead of any real mobile build

Two things in this game only ever worked because a mouse can hover, and a
touchscreen cannot: everything else - approach, place, offer, drag-and-drop -
is already click/tap-shaped and needed nothing.

**The floor peek.** Hovering a seat used to be the only way to see a
customer's back (their line, their rules) before committing to them, and the
SAME `HoverPad` already approached on click - so a plain "tap flips it" cannot
coexist with a plain "tap approaches" on the identical spot. The rule that
serves both inputs without asking which one this is: **a press on an
already-peeked-or-hovered seat approaches; a press on a fresh one only
peeks.** For a mouse this changes nothing observable - hovering already peeks
it before the click ever lands, so one click still approaches, exactly as
before. For touch, which has no hover at all, the first tap peeks and a second
tap on the same seat commits. `_peeked` is the new, explicit state this needs;
it self-clears if the seat it points at empties out before a second tap
arrives, so a stranger who later sits in that same chair can never inherit a
stale peek.

**The hand-card lift.** Hovering a hand card nudges it up so its bottom -
otherwise clipped by the card to its right - is legible; this is the addon's
own `hover_pos_move`, driven purely by `mouse_entered`/`mouse_exited`. Touch
has nothing to drive that with, but the addon already emits a signal for the
exact moment that matters: `card_selected`, fired on the raw press, *before*
`DragController`'s own drag-threshold check has decided whether this becomes a
real drag at all. Hooking that (and its `card_deselected` counterpart, on
release) reproduces the same lift a press-and-hold or a press-and-drag would
want, and does nothing extra for a mouse - hovering has already lifted the
card by the time it is pressed, and re-tweening to a target it is already at
is a no-op.

**Deliberately not relied on: Godot's touch-emulates-mouse layer.** It can
make a touch approximate hover, but `mouse_exited` normally needs a
*subsequent motion event* to fire, and lifting a finger generates none - a
card could stay peeked or lifted after release until the next touch landed
somewhere else. Both fixes above are built entirely on unambiguous press/
release signals instead (`input_event`'s button state for the floor,
`card_selected`/`card_deselected` for the hand), so neither depends on that
emulation working any particular way.

**Confirmed on a real device: yes, touch-to-mouse emulation fires
`mouse_entered` on a bare touch-down.** A phone approached on the very first
tap, skipping the peek entirely - exactly the failure mode predicted above,
now observed rather than theorized. The narrow fix predicted above was also
the fix applied: `_touch_check` (an injectable `Callable`, defaulting to
`DisplayServer.is_touchscreen_available`, so a test can force the branch
without real touch hardware) gates the decision - a touchscreen never
consults `_hovered` here at all, only its own explicit `_peeked`, which only a
genuinely prior, discrete tap can set. There is no per-event way to tell a
real hover from an emulated one apart, so this asks the platform once instead
of trusting the event.

**The hand-card lift needed the same device-gating, discovered from the
opposite direction.** `DragController._drag_card_start()` calls
`remove_hovered()` the instant a real drag begins, on the assumption a mouse
cursor needs no local offset once the card's root starts tracking it directly.
The first cut of the touch fix reapplied the lift right after, for every
device - which fixed touch and broke a real desktop: the dragged card grew
AND stayed lifted for the *whole* drag, visibly detached from the drop-plane
position `DragController` was actually tracking underneath it, so where the
card looked like it would land and where it actually would stopped agreeing.
The reapplication now goes through the SAME `_touch_check` gate as the floor
peek - touch keeps the lift through the whole drag (a fingertip sits on the
card's own center otherwise, for the whole gesture, not just the instant
before it), a mouse gets exactly the addon's original behaviour back, with
nothing reapplied at all.

---

## G3 - the floor demands attention

Two mechanics had quietly made this a game about optimising **one** negotiation,
when the interesting decision is which negotiation deserves the next tick.
Walking cost the clock, and customers were passive. G3 removes the first and
replaces the second.

### Walking is free

`approach()` used to burn `cfg.approach_ticks`, discounted to 0 only when you
returned to `last_customer`. Stepping out to check on someone else and coming
back therefore cost **2 of 24 ticks**, and the cheapest play in the game was to
finish whoever you were with and never look up - a tax on exactly the decision
the floor exists to pose.

The clock now measures **work** - cards, digs, waiting for the door - not
distance. `cfg.approach_ticks` survives at 0 rather than being deleted, so the
charge is one number away if free movement reads as too loose. What did *not*
survive is the return discount: an asymmetry that made coming back cheaper than
leaving was the shape of the tunnel vision, so if the charge ever returns it
returns uniform. `_burn()` already no-ops on 0, so the default spends no branch
and `ticks_approach` stays in the report, honest and zero.

**This is load-bearing for what comes next.** With movement free, the world no
longer advances while you walk, so a customer's fuse measures *units of work*,
not wall-clock beats - which is what will make "leave them alone for a few
ticks" mean "go do work elsewhere" rather than "stand still".

### A second Small Talk

`smalltalk.tres` is `copies = 2`, taking the starting deck to **15** (6 products,
9 support). It is the only patience-restoring card in the game, and what comes
next leans hard on patience, so the second copy is load-bearing rather than
generous.

Two knock-ons worth knowing. A pure-support opening hand - nearly a dead turn,
since `needs_offer` defaults to true and 6 of the 9 starter support cards refuse
an empty table - is now `C(9,5)/C(15,5)` = 4.2% rather than 2.8%, so
`hand_min_products` earns its keep more often than it used to. And the fifteenth
card moved every shuffle: `test_shift_clock.gd`'s deliberately barren seed is
**15** where it was **8**, which is a fact about the deck's size and not about
either seed.

### The Line is fogged, and Read the Room is the only way through

`offer()` used to set `known_line`. Offering is free, so the exact Line was
free: ask once, anywhere, and the number was yours for the rest of the shift.
That made Read the Room a *convenience* - it bought you the Line a tick earlier
than asking would have - rather than the one thing that could tell you.

Offering now teaches you the **rank** of whatever you just put in front of them,
and nothing else. Read the Room is the only source of the Line, all shift.

**The fog had two exits and both are closed.** `appeal_bar.marker_x()` already
refused to draw the marker without `known_line`, but `detail_card_3d.gd` printed
`"17 SHORT"` right beside it, gated on having *offered* rather than on knowing.
Having asked still buys you something real - the band - but a band is a read and
a number is a readout, and only one of those you have paid for. `READY - they
will sign` is gated the same way and for the same reason: appeal can climb past
the Line on cards played after a miss, and being told you have cleared a line
you cannot see is the number wearing a hat.

The model still knows the true gap, and `offer()`'s `Result` still carries it.
That is deliberate: `_apply()` logs a Result's message only when it is a refusal,
so nothing player-facing reads it, and the fog belongs in the one layer that can
decide what a player has earned the right to see.

**The upgrade is real now.** `readroom.tres` authored its `upgraded_effects` as a
second, identical `RevealRoom` - an $1,100 shop purchase that changed nothing
observable, which `shop.gd` was happy to sell because it only checks that the
array is non-empty. `RevealRoom` gained an `exact` flag: the base card narrows
nine interests to three, the upgrade narrows those three to one. It records the
answer as `known_ranks[top] = 1` rather than as its own flag, so everything that
already walks `known_ranks` picked it up for free.

Worth knowing for whoever balances this: "ALMOST" now replaces "3 SHORT" as your
best read until you spend the tick, which is a real difficulty increase landing
on top of everything else in G3. It is also the cheapest thing here to walk
back - restoring `known_line` in `offer()` is one line.

### Customers ask for things now

The floor had no way to interrupt you. `Every`-triggered actions existed, but
they were **passive taxes** - the Karen drained everybody's patience whether or
not you dealt with her, the Tire Kicker bled himself on a timer you could not
stop. Nothing in the game ever said *drop what you are doing and come here*.

A **Demand** is a customer asking for something, and it has to state three
things or it is not designed yet:

| | |
|---|---|
| **a. how long you have** | `Demand.ticks` - a fuse |
| **b. what answers it** | `Demand.resolve`, a `DemandResolve` |
| **c. what ignoring it costs** | `Demand.effects`, and optionally `relief` for meeting it |

**A fuse is counted in WORK, not in time.** Because walking is free, the clock
only moves when you play a card, dig, or wait. "Three ticks" means three things
done, anywhere on the floor - which is what makes a deadline something you
spend attention against rather than something you wait out.

**Demands are raised by the machinery that already existed.** A new
`RaiseDemand` effect hangs off an ordinary `CustomerAction`, so the existing
trigger vocabulary decides WHEN a customer asks and the Demand says what the
asking means. No new trigger plumbing; `Shift.fire()` and `_trigger_name()` are
untouched, and a new demand is a `.tres` like everything else.

`DemandResolve` is the same shape as `Effect` and `Trigger` - one ~12-line file
per verb in `scripts/model/demands/`, each appearing in every Inspector
dropdown. Six exist: `PlayAnySupport`, `PlayConcession`, `MakeAnOffer`,
`OfferSomethingGood`, and `LeaveThemAlone`. **`PlayConcession` is defined by
what a card DOES** - any support card whose executed effects include a negative
`ChangeMargin` - rather than by card id, so every card that gives money away
answers it and a future one will too, without either file changing.

**`LeaveThemAlone` inverts both halves**: the fuse running out is the ANSWER,
and touching them before it does is the failure. Its `PRESENT` break - a tick
burning while you stand with them - is what makes it a real decision instead of
a free pause. You cannot spend their minute standing there, because standing
there does not move the clock. **The only way to give someone a minute is to go
and spend it on somebody else**, which is the whole triage loop in one card.

### Three rules inside `_burn()` that will bite whoever changes this next

**The presence notice runs BEFORE the action pass.** A customer can raise a
demand on the very tick you happen to be standing with them. The first cut ran
presence afterwards, and "give us a minute" broke on the same burn that created
it - charging the player 5 patience for ignoring an ask they had not been shown
yet. Found by a test, not by reasoning. Every demand gets one whole tick to
exist.

**Fuses come due AFTER the action pass and BEFORE `_settle_patience()`**, so a
`WalkOut` consequence leaves down the one path a customer has ever left by.

**The deadline is an absolute tick, never a countdown.** A countdown
decremented inside `_burn()` would be wrong for a multi-tick burn - Hard Close
costs two - and would let a demand raised during that burn expire before anyone
could answer it.

### The three new consequences, and what they cost to build

`WalkOut` sets patience to 0 and lets `_settle_patience()` do the leaving, so it
inherits the standing damage, the log line, the at-risk accounting and
`_vacate()` **by construction** and can never drift from what running out of
patience already does. `ChangeStanding` needed no report accounting at all -
`standing_delta` is already computed from the live number - and no end-of-run
wiring either, because `is_over()` already reads `standing <= 0`. `DropOffer`
sweeps the PLACED offer into the discard and deliberately leaves agreed sales
alone.

### All five action-carrying archetypes converted

| | asks | fuse | answer | ignoring it |
|---|---|---|---|---|
| **Karen** | for the manager | 3 | a concession | whole floor -2 patience, **your standing -5** |
| **Tire Kicker** | for a price | 3 | ask for the business | **he walks** (and a walkout costs 8 standing) |
| **Budget Hawk** | after any short offer | 2 | a concession | **your product comes off the table** |
| **Tech** | to see the good stuff | 3 | offer their top three | -2 patience; meeting it is **+6** |
| **Family First** | for a minute | 3 | leave them alone | -5 patience; meeting it is **+5** |

Easygoing and Lay-Down still do nothing, which is what opens the ladder.

The pre-existing reactive actions were **replaced, not kept alongside**.
`archetype_pool.tres`'s design rule says every archetype teaches exactly ONE
play pattern, and keeping both would have taught two. Their identities survive
in the demand: the Hawk still punishes you for not conceding, Tech still pays
you for finding the bullseye, the Karen still wants seeing first. Family First
is the one whose *pattern string* changed, because theirs genuinely did.

**Tech stays a favour.** The design rule requires at least two archetypes in the
player's favour, so their demand is an *opportunity with a deadline* - the
relief is the point and the miss is nominal.

**`Customer.demands` is now `demands_category`.** It is the Karen's standing
gate on `close()`, not a timed ask, and one letter between it and `demand` with
completely unrelated meanings was a trap waiting to be sprung.

### Throttles, and what is still a guess

One demand per customer at a time; `demand_grace_ticks` (2) before a fresh
arrival may ask; `demand_cooldown_ticks` (4) between one customer's demands.
Three customers each free to open a fuse every few ticks against a 24-tick
budget is not a floor you triage, it is one you lose - these are the first
numbers to reach for if it feels frantic rather than busy. A floor-wide cap is
the next lever if per-customer throttling proves not to be enough.

`fire()` skips a demand-raising action **wholesale** when the customer cannot
take one, rather than firing it to do nothing: the log would otherwise narrate
an ask that never happened, and burn the action's own cadence doing it.

### The log finally says what they said

`action_log` entries have carried a `dialogue` key since G1 and `_drain_log()`
never once read it. It matters now - a demand the customer says out loud reads
as a person interrupting you, where the same event as a bare stat change reads
as a rules engine ticking over.

### The table is a carousel, and nobody gets hidden

Approaching someone used to **hide the other two**. That was defensible when
the only thing you could do about a customer was be standing with them; with
demands on fuses it is exactly wrong, because the whole decision is about the
people you are *not* with.

The three seats now sit on a circle. Approaching somebody spins the circle
until they are at the front, and the other two fall away to either side -
smaller because they are further off, not because anything scaled them. The
camera barely moves: one marker for the floor, one for a seat, both unpitched,
both on the axis.

### Why the lens had to change, and why no radius would have done instead

This is the part worth knowing before anybody touches `CAM_FOV`. With seats on
a circle of radius `R`, camera at radius `D`, near depth `N = D-R` and far
depth `F = D+R/2`:

```
flanker_offset_px            = 0.866 x R x K / F      K = 540 / tan(fov/2)
flanker_height/active_height = N / F
```

Eliminate `R` and `D` and exactly one identity is left:

```
K = 1.7324 x offset_px / (1 - h_far/h_near)
```

**The flankers' distance from the centre of the screen does not depend on `R`
or `D` at all - only on focal length.** Widening the circle pushes them outward
and shrinks them by precisely the amount that cancels it. At `fov 60`, flankers
at 60% size land around x 744/1176: bunched in the middle, overlapping the
negotiation, and no radius anywhere fixes it. A longer lens compresses depth so
they stay large while still subtending a wide angle.

**`CAM_FOV = 28`**, `CAROUSEL_R = 6`, and the two constants were then chosen so
that:

| | |
|---|---|
| the fronted floor card | **286 x 402 px** - pixel-identical to the pre-carousel floor card, so the `>= 360` readability floor survives untouched |
| the seat's customer card and product slot | **256 x 358 px** at the same pixels they already occupied - the negotiation you already tuned did not move |
| the flankers | **194 x 272** on the floor, **179 x 251** at a seat - honest perspective, and the number the icon work has to survive |

The tight seam in the whole layout is the offer detail against the left flanker:
**25 px of vertical clearance**, governed by `SEAT_CAM.y` alone at about 30 px
per 0.1 unit. Raising it costs headroom against the hand, which has 6 px.

**Only `PILE_DEPTH` changed for your own cards.** Screen offset is
`y x K / depth`, so scaling the pile depth by the same 2.3157 that `K` grew by
leaves the hand, the draw pile and the discard on exactly the pixels they were
on. The fan, the hover lift and every stowed position are untouched.

### Billboarding, solved without billboarding

A flat quad at 120 degrees off-axis renders edge-on. The fix is not a billboard
material and not a per-frame `look_at`: **each seat carries a local rotation
that cancels the carousel's**, holding its cards at world yaw 0. The camera
sits at z 27 against a table spanning ±6, so the worst bearing to a flanker is
`atan(5.196/30.2) = 9.8 degrees`, and a card viewed from there foreshortens by
`cos 9.8 = 0.985` - a 1.5% squeeze.

It has to be per-seat: one counter-rotating node above them would undo their
positions along with their facing. What it buys is that **`FlipPair` is
untouched** - it turns a node *below* this one, so the hover flip behaves
exactly as it did - and so are the hover pads, which are boxes rather than
quads and do not care about 9.8 degrees.

**That counter-rotation had no test and nearly shipped without one.**
Unprojecting a card's centre says where the card is and nothing about which way
it points, so three cards edge-on to the camera pass every rectangle check in
`drive_shift.gd`. Worse, the first facing check written for it ran at station
0 - where the carousel is unrotated and a missing counter-rotation is
indistinguishable from a working one - and passed against a deliberately broken
build. The check that counts runs after moving to chair B, the first station
that actually turns.

### What else moved

The **action column is on the left now**, under the mode button, mirroring the
log. The right rail is fully spoken for and the 155 px gutters inside the
composition are too narrow for a 300 px button. Real cost: OFFER/DROP/CLOSE sit
further from the product they act on.

The **customer detail card no longer slides out at a seat**. It went back to
being purely the back of the floor card; the space it used to occupy is where a
flanker now sits, and what it said belongs on the customer card's own front -
which is what the next section is for.

Drop zones are keyed on the **slot's** visibility rather than the seat's, since
every seat is visible now and only the one you are at has a product slot
showing.

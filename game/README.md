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
<= 0`, and standing moves on the exact same `margin_banked - quota` delta that
already funds the bonus - one number, two consequences, nothing new for the
player to learn. `Shift._standing_delta()` is asymmetric on purpose: missing
quota costs `standing_damage_scale` (50) points at a full miss, beating it heals
only `standing_heal_scale` (15) at an equal fractional margin - "a bad shift
makes death more likely," not "one bad shift and you're out." A run starts at
`standing_start` (100), so one total wipeout is survivable and two in a row is
not.

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

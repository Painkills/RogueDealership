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

# G0 — the rules, ported

The Godot project. **G0 has no UI**: it is the pure rules core, the data that
drives it, and the headless suite that proves the port is faithful. The point of
building it this way round is that the rules are proven *before* a pixel is drawn.

```bash
godot --headless --path game --import                       # after adding any class_name script
godot --headless --path game --script res://tests/run_tests.gd
```

```
513 checks, 513 passed, 0 failed
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

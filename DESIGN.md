# Auto Sales Executive — Design & Scope Document

> **Working title:** Auto Sales Executive · **Genre:** Roguelike deck-building strategy
> **Engine:** Godot 4 (GDScript) · **Cost target:** $0 · **Team:** solo
> **Tone:** satirical / darkly comedic (sales-floor sleaze played for laughs)
> **Status:** pre-production / v1.0 scope lock

---

## 0. Why this document exists (read this first)

The builder of this game has shipped **zero** completed projects out of three prior prototypes. The
prototypes were not the problem — **finishing** was. The single greatest threat to this project is
**scope creep**, not technical difficulty.

Therefore this document's #1 job is to **lock a small v1.0** and shove the exciting-but-endless
content into a clearly separated backlog. The full 20-day vision is real and worth building — but
only as **content poured into an already-shipped, working game.** Content added to a finished game is
fun. Content added to an unfinished game is why the last three didn't ship.

**Rule of the project:** _Do not grow v1.0 scope until v1.0 is shipped._

---

## 1. The pitch

You are a car dealership sales executive. Over a short cycle you face a series of customers, and in
each encounter you play cards to build up a deal across three product lanes — **Vehicle**,
**Protection**, and **Financing** — while keeping the customer's **patience** from running out. Close
enough deals to beat your **quota**, earn commission, upgrade your deck between customers, and try to
survive the cycle. Lose the quota and the run ends. Roguelike: every run is a fresh, seeded shuffle.

---

## 2. Guiding constraints

- **$0 cost.** Godot 4 (MIT), GDScript, CC0/CC-BY assets, free tools only.
- **UI-and-numbers game.** No physics, no real-time action. Turn-based, menu-driven.
- **Simple assets.** Flat/pixel UI, icon-based cards, tiny portraits. Art is *last*, not first.
- **Data-driven.** Cards/customers/upgrades are data, not code, so adding content is a data edit.
- **Ships on Windows + web (itch.io)** from one project.

---

## 3. ✅ v1.0 — Definition of Done (LOCKED SCOPE)

This is the whole game for v1.0. When every box is checked, **it ships.** These numbers are frozen.

- [ ] **5-day cycle** (one "week"), single quota checked at the end
- [ ] **3 customer archetypes** (Budget Buyer, Family First, Tech Enthusiast)
- [ ] **~18–20 cards**, built from **~8 effect types**
- [ ] **3 product lanes**: Vehicle / Protection / Financing
- [ ] Core encounter loop: draw → play cards → build deal value → close → reward
- [ ] Energy + Patience + hidden Resistance/close tiers all functional
- [ ] **Customer objections** with visible intent, Rapport-as-shield, and specific counters (§6)
- [ ] **One shop screen** (buy 1 card / remove 1 / upgrade 1 — enforced limits)
- [ ] **One reward screen** after a successful close
- [ ] **2 meta-upgrades** (not a tree)
- [ ] Title screen → run → win/lose screen → "run again"
- [ ] Save/resume a run
- [ ] Seeded RNG
- [ ] Exported Windows build **and** itch.io web build

**If it's not on this list, it's not in v1.0.** See §4 for where the rest goes.

---

## 4. 🅿️ Post-1.0 backlog (the parking lot)

Everything here is deferred **on purpose**. Adding any of it before v1.0 ships is scope creep.

- Full **20-day cycle** with quarterly reviews between weeks
- Additional archetypes (Executive, etc.) and the full **trait system** (Commuter, High Mileage,
  Young Child, Lease Prefers, …)
- **Floor expansion / sales-training trees** (deeper meta-progression)
- More lanes/products, more card rarities, card synergies & combos
- Events, boss/"tough client" encounters, multiple dealerships/biomes
- Music, richer art, animations & "juice"
- Achievements, run stats, daily seeds, mobile-web polish

---

## 5. Core loops

**Encounter loop (one customer):**
`See the telegraphed objection → draw hand → spend Energy: shield against the objection, answer its
rider, and build Deal Value across 3 lanes → close at whatever tier you have reached, or push on →
objection resolves at end of turn → repeat until you close (commission + reward) or lose them
(patience hit 0, customer walks, you bank nothing).`

**Run loop (one cycle):**
`Day 1..5: face a customer → shop (buy/remove/upgrade, strict limits) → next day → after Day 5,
check commission vs Quota → win or lose the run.`

**Meta loop (across runs):**
`Earn a soft currency on runs → spend on the 2 permanent upgrades → attempt a harder run.`

---

## 6. Mechanics spec

> The numbers below are a **provisional first-pass model to validate in the M0 paper prototype**
> (§12). The *architecture* is locked; the *tuning* is expected to change.

### Resources
- **Energy** — refills each turn (start: **3**). Cards cost energy to play. Energy is the scarce
  resource the whole game contests: every point spent answering an objection is a point not spent
  building the deal.
- **Patience** — the customer's willingness to stay (start: **50**). **It only ever goes down.**
  Objections damage it, aggressive cards (markups) cost extra, and a small passive decay (**−2/turn**)
  keeps a floor of urgency. **At 0, the customer walks and the encounter is lost.**
- **Rapport** — a per-turn **shield**, not a heal. Rapport cards grant Rapport points that absorb the
  incoming objection's patience damage. **Unspent Rapport expires at end of turn**, so it must be
  played in anticipation of the telegraphed objection — never banked.

### The deal
- **Budget** — the customer's money ceiling (e.g. **$30,000**). This is the max value you can extract.
- **Deal Value** — the running total you build across the three lanes. Sum of Vehicle price +
  Protection add-ons + Financing markups.
- **Resistance** (hidden, per-lane) — reduces or caps how much value a card adds to that lane until
  you lower it (via probe/rapport/discovery cards). This is *why* you can't just slam max markup on
  turn one.
- **Close tiers** (hidden) — Deal Value breakpoints that gate the close. Graded rather than a single
  cliff, so pushing further is a smooth risk gradient:

  | Deal Value | Tier | Commission |
  |---|---|---|
  | ≥ 60% of Budget | **Sale** | 1.0× |
  | ≥ 80% of Budget | **Strong Close** | 1.25× |
  | 100% of Budget | **Max Close** | 1.5× **+ reward pick unlocked** |

### Customer objections — the customer acts
The customer is an **active opponent**, not a wall of numbers. Each turn they raise an objection, and
you must answer it while still building the deal.

- **Intent is always visible.** At the start of your turn you see the objection that will resolve at
  the **end** of it — its damage and any rider. You play into known information.
- **Every objection damages patience.** That damage is absorbed by Rapport (shield) from *any*
  Rapport card, so no Rapport card is ever dead.
- **Some objections carry a rider** — an extra effect beyond the damage (raising resistance, locking
  a lane, draining energy, shaving accumulated value). **A rider can only be negated by the specific
  Rapport card that counters it.** Generic shield reduces the damage but never stops the rider.
- **Objections escalate** as the encounter runs long. This is the mechanical reason to close rather
  than keep milking — and what makes the Sale-vs-Max-Close decision bite.
- **Each archetype has its own objection pool.** This is where archetype personality lives; it is
  what makes them play differently rather than just holding different resistance numbers.

### Closing
- **Appraise** reveals hidden info — resistance values, close tiers, the trait, and **objection
  intent further ahead** than the default one-turn telegraph.
- **Closing Offer** — when Deal Value clears a tier, you may close at that tier. Draining 100% of
  Budget is the jackpot outcome.
- **Closing happens during your turn, before that turn's objection lands.** A tier you reach is
  bankable immediately — but if you push on for a better tier and they walk at end of turn, **you get
  nothing.** This is the push-your-luck decision; M0 found the loop had none until this rule existed.

### StS mapping (for anyone who knows the reference)
| This game | Slay the Spire analog |
|---|---|
| Energy | Energy/mana |
| Draw / hand / discard | Same |
| Customer Budget → drain 100% | Enemy HP → kill |
| Patience (0 = walks) | Player HP (per encounter) |
| Rapport (expires each turn) | Block |
| Objections with visible intent | Enemy attacks with telegraphed intent |
| Objection riders | Debuffs / status effects |
| Specific counter cards | Targeted answers to a given attack |
| Resistance & hidden tiers | Hidden armor revealed by play |
| Bide Your Time | Energy retention |
| Reward pick after close | Post-combat reward |
| Sales training / floor expansion | Relics / meta-upgrades |
| 5-day cycle / quota | Run map / win condition |

---

## 7. Card system architecture (the one thing to get right up front)

Cards are **data**, interpreted by a single **effect executor**. New cards = new data rows that
recombine existing effect types — *not* new code. This is what keeps late-game content from becoming
a wall.

**Card data schema (Godot Resource or JSON):**
```
Card:
  id: "rate_markup"
  name: "Rate Markup"
  cost: 1                       # energy
  lane: "financing"             # vehicle | protection | financing | none
  targeting: "single_product"   # none | single_product | lane
  patience_cost: 5              # extra patience spent (0 for most)
  effects:
    - { type: "increase_base_price", amount: 500 }
  upgrade_effects:              # applied when this card is upgraded
    - { type: "increase_base_price", amount: 800 }
  rarity: "common"
```

Rapport cards additionally carry `shield` (points of patience damage absorbed this turn) and,
optionally, `counters` (the objection tag whose rider they negate).

**v1.0 player effect-type set (~9), each a small function in the executor:**
1. `add_deal_value` — add value to a lane
2. `increase_base_price` — mark up a targeted product
3. `gain_shield` — Rapport (absorbs this turn's objection damage; expires unused)
4. `counter_objection` — negate the telegraphed objection's rider
5. `reduce_resistance` — probe/discovery
6. `gain_energy` / `carry_energy` — incl. Bide Your Time
7. `draw_cards`
8. `reveal_hidden` — Appraise (resistance / tier / trait / objection intent)
9. `buff_next` — e.g. "next markup +X" (simple synergy hook)

Adding the 10th effect type is a deliberate decision, not a reflex.

**Objections are data too**, interpreted by the same executor:
```
Objection:
  id: "competitor_quote"
  name: "The Dealer Down The Road"
  patience_damage: 8
  counter_tag: "competitor_quote"    # the Rapport card that negates the rider
  rider:                             # optional; omitted = pure damage
    { type: "raise_resistance", lane: "financing", amount: 0.15 }
```

**Objection rider types (4):** `raise_resistance`, `lock_lane`, `drain_energy`, `shave_value`.
Riders are the customer's mirror of the player's effect list — same executor, opposite direction.

---

## 8. v1.0 content lists

### Customer archetypes (3)
| Archetype | Budget (approx) | Patience | Flavor / quirk | Objection style |
|---|---|---|---|---|
| **Budget Buyer** | low (~$18k) | high | High resistance on Financing markups; forgiving patience | Hammers price objections |
| **Family First** | mid (~$30k) | mid | Low resistance on Protection (safety sells); dislikes aggressive markups | Questions the extras; needs to consult a spouse |
| **Tech Enthusiast** | mid-high (~$40k) | low | Low resistance on Vehicle upsells; impatient, wants it fast | Comparison-shops and stalls |

> **Card deal values are expressed as a share of the customer's Budget, not absolute dollars.**
> M0 proved that absolute values make Budget secretly the difficulty dial — small-budget customers
> become trivially easy and large-budget ones impossible. Difficulty must come from resistance,
> patience, and objection pool instead.

### Objection set (5)
| Objection | Damage | Rider | Countered by |
|---|---|---|---|
| **"It's out of my budget"** | high | — (pure pressure) | — |
| **"The dealer down the road quoted less"** | med | raises resistance in a lane | Beat The Quote |
| **"I don't need all these extras"** | med | locks a lane for one turn | Justify The Value |
| **"Let me talk to my spouse"** | low | costs you energy next turn | Create Urgency |
| **"I'm pre-approved at my credit union"** | med | shaves accumulated Financing value | Reframe The Rate |

### Starter card set (~22; add/cut during M0–M1)
- **Vehicle:** Base Trim Pitch, Upsell Package, Highlight Features
- **Protection:** Extended Warranty, Gap Insurance, Paint Protection
- **Financing:** Rate Markup, Term Extension, Doc Fee
- **Rapport (shield):** Build Rapport, Small Talk, Empathize — plain shield, no counter
- **Rapport (shield + counter):** Beat The Quote, Justify The Value, Create Urgency, Reframe The Rate
  — smaller shield, but each negates its matching objection's rider
- **Utility:** Appraise, Probe Needs, Bide Your Time, Test Drive (draw + shield), Anchor High
  (buff_next markup), Close Hard (big deal value, high patience cost)

### Meta-upgrades (2)
- **Sales Training** — +1 starting Energy per encounter (or a stronger starting deck; pick one).
- **Floor Expansion** — reward screens offer 1 extra card choice.

---

## 9. Technical architecture

Four clean layers — keep them separate:
1. **Data** — cards / customers / upgrades (Resources or JSON in `/data`).
2. **Model / rules** — pure logic: deck state, energy, patience, effect execution. *No UI.* Unit-testable.
3. **View** — Godot scenes rendering cards/customer and sending input.
4. **Meta / save** — run state, day progression, quota, unlocks (`FileAccess` + JSON).

**Suggested folder structure:**
```
/data/cards/          # card definitions
/data/customers/      # archetype definitions
/data/upgrades/       # meta-upgrades
/scripts/model/       # pure rules engine (no nodes)
/scripts/view/        # scene scripts
/scenes/              # .tscn files
/art/icons/           # card/UI icons
/art/portraits/       # customer avatars
/audio/
DESIGN.md
```

- **Seeded RNG:** one `RandomNumberGenerator` seeded per run → reproducible, shareable runs.
- **Balance lives in a spreadsheet**, not in-engine. Tune costs/values there, export to `/data`.

---

## 10. Art & audio plan (do the least)

- **Cards:** a 9-slice colored frame per lane (3 colors) + one icon + text. No per-card illustration in v1.
- **Customers:** small fixed-size pixel avatars (64×64 or 128×128), or simple silhouettes.
- **Icons:** pull, don't draw — **Kenney.nl** (CC0) and **game-icons.net** (CC BY). Saves weeks.
- **Font:** one good free pixel/UI font sets the tone.
- **Audio:** Kenney + Freesound (free) for clicks/whooshes. Music is post-1.0.
- **Tools (free):** Piskel / Krita / LibreSprite. (Aseprite ~$20, optional.)
- **Discipline:** consistent folder + naming from day one — asset-management pain comes from
  inconsistency, not volume.

---

## 11. Distribution

- **Develop & test as a native Windows build** — fastest iteration, no web-header hassle.
- **Add the web export near the end** for distribution.
- **Godot 4 web export needs cross-origin-isolation headers** (`COOP: same-origin`,
  `COEP: require-corp`) because it uses `SharedArrayBuffer`/threads.
- **Default free host: itch.io** — has a "SharedArrayBuffer support" checkbox that sets those headers,
  and hosts the Windows download on the same page. (Plain GitHub Pages can't set headers without a
  `coi-serviceworker` shim.)
- Ship **both** targets from the one project.

---

## 12. Milestones — every one is a playable build

| # | Goal | "Done" = playable when… |
|---|---|---|
| **M0** | Paper/spreadsheet prototype: 1 customer, ~8 cards, prove the **3-lane + threshold** loop is fun | You'd play a second round on paper |
| **M1** | One full encounter in Godot (hand/energy/patience/effects/close/win-lose) | A friend can play one customer end-to-end |
| **M2** | Run structure: 5-day cycle, customer sequence, basic rewards | You can lose or win a full run |
| **M3** | Shop + deck editing (buy/remove/upgrade, strict limits) | You can meaningfully change your deck mid-run |
| **M4** | Meta layer: quota check, 2 upgrades | A losing run makes you stronger next time |
| **M5** | Content + polish: all 3 archetypes, full card set, balance, art, audio, export | It's the shippable v1.0 in §3 |

**Vertical before horizontal:** get one customer fully playable before adding a second archetype.

---

## 13. Decisions & open items

**Decided:**
- ✅ **Tone** — **satirical / darkly comedic.** Sales-floor sleaze played for laughs. Card names and
  flavor should lean into the bit (Doc Fee, Anchor High, "trust me"); art direction can be a little
  seedy/kitschy.
- ✅ **v1.0 scope** — **keep the small §3 lock.** Full 20-day vision is post-ship (§4).
- ✅ **The customer is an active opponent** (§6). M0 proved a passive customer makes the loop
  solitaire — energy had no competing demand, so nothing was ever tight. Objections with visible
  intent are the fix.
- ✅ **Rapport is Block, not heal.** Shield absorbs the turn's objection damage and expires unused.
  Patience only ever goes down, so the clock stays real.
- ✅ **Every objection damages patience; some carry riders.** Any Rapport card mitigates damage (so
  no dead hands); only the *specific* counter card negates a rider.
- ✅ **Card values are budget-relative, and close tiers are graded** (60 / 80 / 100%). Both are
  direct fixes to problems M0 measured — see `m0/README.md`.

**Still open (fine to defer):**
- **Title** — keep "Auto Sales Executive," or something punchier?
- **Exact encounter numbers** (§6) — provisional; will be set in M0.

---

## 14. Anti-scope-creep rules (the finishing discipline)

1. **Do not grow v1.0 scope until v1.0 ships.** New ideas go to §4, not into the build.
2. **Vertical before horizontal** — depth on one customer before breadth of many.
3. **Every milestone is a build you'd let a friend try.** Not playable = not done.
4. **Balance in the spreadsheet**, not by relaunching the game.
5. **Adding a 9th effect type / 4th lane / 4th archetype is a decision**, never a reflex.

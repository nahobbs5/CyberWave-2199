# Cyberwave 2199: Reference

The detailed companion to the [README](../README.md). It covers how each system works, every track, the weapons, the project layout and the headless checks. The [Game Design Document](Game%20Design%20Document.md) (v6.9) is the design authority; this file describes what is **built**. The [dev tracker](https://nahobbs5.github.io/CyberWave-2199/dev/) follows the work still in progress.

Last refreshed 2026-11-12.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Accelerate | W / Up | RT / R2 |
| Brake / Reverse | S / Down | LT / L2 |
| Steer | A / D, Left / Right | Left stick |
| Drift | Hold Shift + A / D | Hold RB / R1 + steer |
| Cycle camera (Far → Close → Rear) | C | D-pad Down |
| Look back (hold) | Q | Right stick click |
| Reset vehicle | R | D-pad Up |
| Select weapon slot 1 / 2 | 1 / 2 | D-pad Left / Right |
| Use selected weapon | Space | LB / L1 |
| Trick (in the air off a ramp) | E | Y / Triangle |
| Pause menu | Esc | Start / Options |
| Menu buttons (incl. pause, podium, results) | Enter, mouse, arrow keys | A / Cross, D-pad or left stick |
| Menu back | Esc | B / Circle |

Arrow keys are an extra convenience on top of the GDD's bindings. Space doesn't press menu buttons, so firing
weapons as you cross the line can't skip the results screen. The results buttons also wait 1.5 s before they respond.
Godot's built-in `ui_accept` / `ui_cancel` have no gamepad buttons, so `InputSetup` adds A and B to them.
The podium ceremony's crown only drops over a human winner.

Every gameplay action can be rebound in **Settings → Controls** (keyboard and gamepad separately; see below).
Actions are registered at startup by `scripts/core/input_setup.gd`. Any action you define in
**Project Settings → Input Map** with the same name takes priority over the defaults (your Settings rebinds still apply on top).

## How it plays

### Drifting

- At speed (over 12 m/s, about 43 km/h), hold **Shift** and steer with **A** or **D**. The steering direction when the drift starts picks left or right; after that, keep Shift held and steer to shape it (into the drift tightens it, against it widens it). Shift while driving straight does nothing.
- Shift drifting replaced the original Q/E binding in GDD v1.1 (see its Revision History).
- Charge only builds while the car is grounded and sliding sideways.
- **Cyan** at 1 s, **Magenta** at 2.5 s, **Gold** at 4 s of valid drifting with neutral steering. **Steering into the drift charges faster** (up to 1.5x, so Gold in about 2.7 s); steering out of it charges slower (0.75x).
- The car **hops** as the drift starts and its body **angles into the slide** (visual only). After the drift, grip blends back over 0.15 s so it straightens cleanly into the boost.
- **Releasing** Shift (or the bumper) fires the boost. Higher levels give more speed for longer.
- Leaving the ground pauses charging. Staying airborne for more than 1.5 s, hitting something hard, or slowing well below drift speed cancels the drift with no boost.
- Feedback: rear-wheel sparks and an undercarriage glow in the current level's colour, **tyre smoke** while sliding, a looping **skid** hiss (your car only), a tone for each level, exhaust flames and a FOV kick while boosting, and the HUD charge bar.

### Recovery

Recovery is a quick **holographic teleport** (`docs/Recovery System.md`).

- **R** (or gamepad D-pad Up) resets you to the last point on the track you legitimately drove through, about 6 m behind it. Resets can never move you forward, so they can't be used as shortcuts.
- Automatic recovery happens when the car is:
  - upside down or on its side for 2.5 s,
  - stuck (pressing throttle or brake while barely moving forward or back; sliding sideways along a wall counts as stuck) for 4 s,
  - below the world,
  - over **deep water** (a splash, then the recovery). Tracks whose terrain has a flood plane (Six Flags, Arashiyama) get a `RecoveryZone` over every hollow more than 0.6 m deep, except within a few metres of a road, so bridges and road edges never trigger it,
  - outside the circuit (more than 3 m past the road edge, i.e. beyond the barrier) for 1 s, or
  - making no progress: trying to drive but gaining less than 15 m along the track in 8 s (catches a car rocking back and forth against a wall, which never looks "stuck").
- **The sequence** (1.6 s; every time is an export on `VehicleRecovery`):

  | Stage | Time | What happens |
  |---|---:|---|
  | Disintegrating | 0.3 s | The car freezes where it is. A cyan hologram flickers over it, grows scan lines and sweeps away from the bottom up, with a warning blip and digital static. |
  | Teleporting | 0.4 s | Fragments burst out with a flash and a low pulse. The car is gone and moves to the recovery spot. |
  | Reconstructing | 0.5 s | Fragments converge, and a grid "wireframe" hologram builds from the bottom up with a rising shimmer. The solid body fades back in and the glow fades. |
  | Protected | 1.0 s | You drive again, starting at 25% of top speed, straight ahead. A faint shimmer shows while you pass through other cars. A confirm tone plays. |

- **During the first three stages:**
  - Your controls are locked, and so are the AI's.
  - Drift charge, boosts and slipstream are cleared.
  - The car is on no collision layer, so other cars, crates, coins, spikes, boost pads and ramps all ignore it.
  - It can't be targeted or hit by weapons, drafted, or fire weapons.
- **Checkpoints are never paused.** Gates only count in order, so coming back behind one can't skip it.
- **One recovery per incident.** No new recovery starts until the whole sequence (protection included) is over.
- **Items:** a recovery for going out of bounds, into deep water, off track, or a manual reset (R) empties your item slots. Overturned, stuck, no-progress and Overdrive recoveries keep them (`VehicleRecovery.ITEM_LOSS_REASONS`).
- **Elimination** cancels a recovery in progress.
- **Reduced flashing** dims the flash and flicker.
- **The respawn spot** is checked for other vehicles, and for cars that are re-forming there. It shifts sideways or back if it's occupied.
- **Code:**
  - `VehicleRecovery`: stages and gameplay.
  - `RecoveryEffect`: hologram, particles and sounds, made in code.
  - `assets/shaders/hologram.gdshader`.
  - `RecoveryZone`: hazard volumes. Add box shapes in the editor for pits or other hazards.

### The test circuit

The test circuit is a 2.6 km graybox loop driven clockwise:
- a 600 m main straight into a tight right hairpin (T1),
- a left-right pair (T2–T3), where T3 is a long 133° right-hander made for drifting,
- flowing esses (T4–T6) into a 95° drift corner (T7),
- a fast kink (T8) onto a 500 m back straight,
- a double-right hairpin (T9–T10), then a left (T11) onto the main straight.

The two long straights ending in hard braking are the main overtaking spots.

The layout is the `control_points` list on `scenes/tracks/test_circuit.tscn`, sampled from straights and arcs. Barriers have a 4 m invisible collider above the 1.4 m visible wall, so cars can't be launched out of the circuit.

### Racing

- **Grid:** seven AI rivals fill slots 1–7 and you start last (GDD §2.1). Controls are locked during the 3 / 2 / 1 / START countdown. **Rocket start:** press and hold accelerate as the "2" fades for a boost off the line; holding from earlier is a burnout (smoke, a spin, a slow start). The exhausts pop while you rev (`scripts/race/start_launch.gd`). AI rivals do it too: more rocket starts and fewer burnouts on harder difficulties (`rocket_start_chance` / `burnout_chance` in `resources/ai/*.tres`). A start-light board on the gantry over the line lights one lamp per beep: three reds, then green on START (lights out 4 s later).
- **Checkpoints:** 8 evenly spaced gates, with gate 0 at the start/finish line. A gate only counts if it is the next one in order. Skipping ahead, reversing through gates, or a recovery teleport never adds progress. Crossing the line after every gate completes a lap.
- **Positions** are live: finishers in finishing order, everyone else by distance raced since their last valid gate.
- **When you finish,** your car switches to autopilot. The race ends for everyone once all but one car have finished: the last car (human or AI) is placed last at once. Racers placed without crossing the line get a **projected time** from their pace so far; only the last place and Elimination's runner-up show **DNF**. Projected times never count as personal bests. Elimination ends when the first finalist crosses instead. A podium ceremony plays after a Grand Prix, a Versus set or a single Versus race, then the results screen (see HUD and results).
- **HUD:** position, lap, race time, live standings and lap / finish banners (see HUD and results below). Driving the wrong way hangs a 3D neon WRONG WAY sign over the road ahead (`scripts/race/wrong_way_sign.gd`).
- **AI difficulty, laps and weapons** come from the race setup screen. When `race.tscn` is run directly, they come from the `Race` node in the Inspector instead (`difficulty`, `total_laps`, `weapons_enabled`).

### Game modes

**Cups and tracks (Mario Kart style).** Grand Prix and Versus share one **cup screen** (`CupBoard`, used by `CupSelect` and `TrackSelect`): a row of round **cup badges** (`CupBadge`, drawn in code: a gold-rimmed medallion in the cup's colours with its map: the USA, Europe, Asia, South America, Africa) above a panel that previews the focused cup's races (the cup's trophy, then a card per race with its outline, location and your best time). Moving across the badges previews each cup; opening one (click, Enter or A) moves into the panel, and Back returns to the badges. **Grand Prix** confirms the cup with **START GRAND PRIX**, then goes to the setup screen and races the whole cup (a cup locked for Grand Prix is greyed with a padlock and can't be confirmed). **Versus** starts on the setup screen (car, race type, **number of races**, laps, NPC difficulty, weapons), then the cup screen: open a cup and pick a race, or open the **"?" Random badge** for a RANDOM card. There are five cups: the **American Cup** (Vegas Overdrive, Six Flags New Orleans, The Stacks), the **Europe Cup** (Hoia Baciu Run, Catacombs Descent, Vatnajökull Glacier), the **Asia Cup** (Arashiyama Circuit, Crazy House, Gardens by the Bay), the **South America Cup** (Parque Quinta Normal, Vale da Lua, Choquequirao) and the **Africa Cup** (Kilwa Kisiwani Ruins, Fires of Nyiragongo, Chefchaouen). The Europe Cup was the World Cup; its resource keeps the old file name and id (`world_circuit`) so saved results carry over. A cup can be greyed out as "coming soon" with `locked = true` on its resource. Each cup is data (`resources/grand_prix/*.tres`, listed in `GrandPrixData.CUPS`); its `emblem` picks the trophy picture. The Test Circuit isn't in a cup: it's the Practice track.

- **Versus** (GDD §2.1): you start eighth. Pick **1, 2, 3, 4, 6, 8, 12 or 16 races**. With one race, the results offer **Race again** or the menu. With more, the track screen comes back before each race ("RACE 2 OF 4"; the standings stay on the results screen), points and grids work like a Grand Prix, and the last results name the series winner. A series isn't saved; each race pays its normal coins.
- **Grand Prix** (GDD §2.2): any of the five cups (three races each), three laps per race. The cup-win bonus is 100 coins for three races, scaled by the cup's race count.
  - Points are 15-12-10-8-6-4-2-1. Ties are broken by most wins, then most second places, then the order in the most recent race.
  - Race 1 starts the seven rivals in slots 1–7 with you last. Each later grid is the previous race's finishing order, not the points order. Rivals keep their names, colours and personalities all season.
  - **The race result is fixed when you cross the line:** anyone still racing is classified in their current order. That way you never have to wait for the field, and the points always match what the results screen shows.
  - The results screen shows your race points and the championship standings, then **Next race**. After race 3 it shows the final standings with the champion highlighted.
  - **Saving:** the championship is saved to `user://grand_prix_save.json` when it starts and after every race. If you quit midway, **Continue Grand Prix** appears on the single-player menu. The save holds the championship, results, points, next grid, vehicle, rival identities, settings and the coins already awarded. It's deleted once the championship is complete. Starting a new Grand Prix replaces it.
  - **Restart race** (pause menu) replays the current race, but only until you finish it: once the result is saved it can't be rerolled.
- **Elimination** (GDD §2.3): picked as the **Race type** on the Versus setup screen (Standard / Elimination; Versus reopens on the one you used last). Always three laps.
  - A red **ELIMINATION** arch marks checkpoint 4 (the lap midpoint).
  - On each lap, racers qualify in the order they cross it: 6 on lap 1, 4 on lap 2, 2 on lap 3. The moment the last place is taken, everyone else still racing is out. There's no timer, and the start/finish line never eliminates anyone.
  - Eliminated cars stop colliding with active racers and stop fighting at once, then shrink away and disappear. Their positions are 7–8, 5–6 and 3–4, ordered by how far they'd got.
  - The first finalist across the line wins; the other is placed second and shows DNF.
  - HUD: active racers, the next elimination, places left, your distance to the gate, a QUALIFIED banner when you get through, and an "X ELIMINATED" feed. If you're knocked out, the camera follows the leader and the results appear.
- **Pause menu** (Esc / Start): the whole race stops (physics, timers, AI). Neon **Resume**, **Restart race** and **Quit to main menu** buttons, a VOLUME panel (Master / Music / Sound effects, shared with Settings), a picture of your car, and a controls table read from your current bindings (keyboard keys as magenta keycaps, gamepad inputs as cyan ones).

### Menus

- **Title menu** (GDD §11.2): the Cyberwave 2199 logo (`assets/logo/`) over a live 3D night street with your garage car (`MenuStreetScene`), and slanted neon buttons: Single Player, Multiplayer, Settings, Credits, Exit. A description panel explains the focused option, and controller hints sit bottom right.
- **Single-player menu:** Continue Grand Prix (only when one is saved), Grand Prix, Versus, Practice, Garage, Settings, Credits, Back.
- **Multiplayer:** three screens (see "Split-screen multiplayer" below).
- **Boot splash:** the logo's skyline and sun (`assets/logo/splash_skyline.png`) on black while the game loads. The engine shows it first, then the boot scene (`scenes/boot.tscn`, the main scene) keeps the same picture in the same place and adds a cyan progress bar while the title menu loads in the background.
- **Loading card:** races and Practice open behind a card with the track name, location, mode, outline and a **progress bar with a percentage**. The game files load in the background, then the track is built in steps (road, each feature, and each scenery set in several parts) while its textures load in the background. Last comes race setup (cars, racing line, HUD). Each step still pauses the game, so the bar moves in small jumps. Race setup is one step at the end (about 1–4 s headless). The menu underneath is frozen and ignores input while loading. Scenery `build()` functions call `await step(share)` between big parts so the bar can redraw; outside the loading card `step()` returns at once and the build runs in one go. The app/window icon is a square crop of the same skyline (`assets/logo/app_icon.png`). A Windows .exe icon (.ico) gets set in the export preset when you export.
- **Credits:** the game, music, sound, fonts, textures and sky, weapon art and engine, with a Back button (Esc / B also goes back).
- **Race setup** (GDD §11.3): the cup (Grand Prix) or race type and number of races (Versus), vehicle picker with a rotating preview of your car (paint, cosmetics and plate), stats, NPC difficulty, laps (Versus), weapons on/off, and a short explanation of the chosen mode (how Elimination knocks cars out, how points work). Grand Prix starts the race; Versus goes on to the track screen. It keeps your choices until the game closes (each launch starts on the defaults: Standard, 3 races, 3 laps, Normal, weapons on; the last cup is kept) and shows your personal best (Versus) or best championship finish (Grand Prix).
  - **A Grand Prix keeps the car you started it with** for all three races (the GDD saves the player vehicle with the championship).
- **Garage** (GDD §11.4): your car on a turntable in a full-screen neon garage room (auto-spin; drag or the right stick turns it), COSMETICS and INFO tabs, the license plate editor, the 8 cosmetic categories and your coin balance, with B Back / A Apply.
  - **Click an item's name** to try it on. **Buy** spends coins and equips it; **Equip** puts an item you own on this car. Purchases are permanent and shared by all cars, but **each car has its own equipped look**.
  - The **license plate** is one text for every car: up to 8 characters (letters, digits, spaces, dashes), saved as you type.
- **Settings** (GDD §11.9): every change applies and saves immediately.
  - **HUD scale** 75–150%, **motion blur** (off by default; a subtle edge blur at high speed and during boosts, the centre stays sharp), **camera shake** 0–100% (impacts, stuns, boosts), **reduced flashing** (the INCOMING warning stays steady instead of blinking; weapon flashes, status lights and the lock reticle are calmer), **controller vibration** (on by default; gamepad rumble on boosts, boost rings, tricks, drift boosts, hits and crashes; switching it on gives a test buzz).
  - **Audio:** Master, Music and Sound effects. The Music slider controls menu and race music.
  - **Controls:** press a binding, then the new key, gamepad button or stick direction within 5 seconds. A rebind replaces all of that action's keyboard inputs (so W + Up becomes just your new key) or all of its gamepad inputs. If another action already uses that input, you get a note (both keep working). **Reset controls to defaults** undoes all rebinds.
  - HUD scale and motion blur take effect from the next race.

### Split-screen multiplayer

Two to four players on one PC (GDD §2.4). **Multiplayer** on the title menu opens three screens:

1. **Connect controllers:** press Enter (keyboard) or A (gamepad) to join, then again for READY. That device is yours: the keyboard can be one player and each gamepad another. B takes back READY, then leaves.
2. **Choose your cars:** each player picks on their own device and sees the car turning, its type and its stat bars. **Y / Tab edits your license plate**: the keyboard player types, gamepad players use a letter picker (up/down letter, left/right move, X delete, A done). Player 1 drives their Garage loadout and plate; players 2–4 drive their car in their player colour (P1 cyan, P2 magenta, P3 gold, P4 green).
3. **Race setup:** Grand Prix or Versus, race type, number of races, **NPCs** on/off (on fills the grid to eight; Elimination needs them), NPC difficulty, laps, weapons. Defaults: Versus, Standard, 3 races, 3 laps, NPCs on, Normal, weapons on; choices last until the game closes. Then the cup or track screen.

In the race:
- **2 players:** top and bottom halves, minimap at the right end of the divider. **3 players:** three corners plus a **LIVE** broadcast camera in the fourth that cuts between close battles and the leader. **4 players:** a corner each, one minimap in the centre with an arrow per player.
- Each view has its own camera and HUD. Wrong-way signs and lock-on rings only show in their owner's view; everyone else's car has a "P2"-style tag.
- Any player's Start / Esc pauses everyone. When every player has finished, one shared results screen opens.
- **No coins, personal bests or saved Grand Prix** in split screen: a split-screen Grand Prix lives in memory and never replaces your single-player save.

### Vehicles

All eight GDD cars are available from the start (GDD §5.1). Each has its own low-poly model, after the roster concept art:

| Vehicle | Model |
|---|---|
| V8 Specter | Muscle car: long hood and scoop, fastback, full-width orange light bars, ducktail |
| Aurora GT | 1980s wedge: knife-edge nose, rear louvres, pink light lines |
| Empyrean S | Upright luxury limo: towering chrome grille, gold lights, chrome trim |
| Nexus X | Low angular supercar: cab-forward canopy, side intakes, big wing, cyan blades |
| Riviera 88 | Vintage roadster: curvy fenders, open cockpit with seats, round lamps, chrome grille |
| Orbiter | Jet-age coupe: pointed nose, bubble canopy, tail fins, round red jet lights |
| Valkyrie R | Performance sedan: four-door cabin, slatted purple grille, wing |
| Cipher EVO | Open-wheel prototype: narrow tub, sidepods, exposed wheels, front and rear wings |

The models share the car scene's physics, wheels and effects; only the body changes. Their stats are a first balance pass, kept within about 13% of the V8 Specter (the biggest gap is the Nexus X's acceleration). No car beats another in all four stats; a test enforces this.

| Vehicle | Character | Top speed | Accel | Handling | Drift |
|---|---|---:|---:|---:|---:|
| V8 Specter | Balanced (the reference car) | 44.0 | 14.0 | 2.40 | 1.40 |
| Aurora GT | Smooth, precise, extra grip | 43.5 | 13.6 | 2.50 | 1.32 |
| Empyrean S | Highest top speed | 46.2 | 13.0 | 2.25 | 1.35 |
| Nexus X | Strongest acceleration | 43.0 | 15.8 | 2.35 | 1.38 |
| Riviera 88 | Responsive cornering | 42.8 | 14.0 | 2.62 | 1.46 |
| Orbiter | Keeps more steering flat out | 45.0 | 13.6 | 2.30 | 1.30 |
| Valkyrie R | Predictable, steady drifts | 43.8 | 14.2 | 2.42 | 1.36 |
| Cipher EVO | Sharp and loose: less grip, slow off the line | 44.8 | 13.4 | 2.56 | 1.56 |

Speeds are m/s, acceleration m/s², handling and drift rad/s. Each rival drives a **random car** from the eight, with its real model and stats, painted in the rival's own colour. Like the plates, the cars are rolled once per series. The AI get a racing line per car model: the path is worked out once and only the speeds and drift zones are recomputed for each car's stats, so loading barely changes. Rival license plates are random (like `KRX-417`), rolled once per series: they stay the same through Race again / Restart in Versus and Elimination, and for a whole Grand Prix (saved with it). Your plate defaults to `CW-2199` until you change it in the Garage.

#### Vehicle models

`CarModelBuilder` lofts each body and cabin through cross-section stations listed in `scripts/vehicles/car_designs.gd`, then adds detail parts (grilles, light bars, wings, fins). Edit a design there to reshape a car (the format is explained at the top of that file). The meshes are cached, so eight cars on the grid share geometry.

To use **your own model** for a car, import it (`.glb`) and set it as `model_scene` on that car's `resources/vehicles/<car>.tres`. It replaces the procedural model; anything it doesn't provide falls back gracefully. Conventions:
- **Orientation and scale:** metres, +Y up, the car's nose toward **−Z**, origin at the body centre (matching the 1.9 × 0.55 × 4.2 m collision box).
- **No wheels in the model:** the game's wheels sit at x ±0.85, z ±1.35, radius 0.38 and move with the suspension.
- **Paint:** every mesh whose name starts with `Paint` gets the player's paint and finish. Other meshes keep their imported materials.
- **Optional anchors** (empties or `Marker3D`, named exactly): `PlateAnchor` (rear plate, facing +Z), `DecalL` / `DecalR` (door decals), `ExhaustL` / `ExhaustR`, and meshes `NeonL` / `NeonR` for the underglow strips.
- **Stripes** only work on the procedural models; imported models skip them.

### Coins and cosmetics

- **Track coins** (GDD §9.2): every lap the coins move to a new random layout: small clusters of 1–3 in one lane, spread round the lap, clear of the start, the crate rows and any road columns (shortcut bonus coins stay where they are). Only you collect them (on contact); the cap is 30 per race, and getting hit never costs any. There are no coins in split screen.
- **Race rewards** (GDD §9.3), paid when your race ends: 25 for completing, +15 / +25 / +40 for 3rd / 2nd / 1st, +100 for winning a Grand Prix, plus your track coins.
  - **Eliminated** in Elimination counts as not completing: you keep only your track coins. The other finalist counts as completing in 2nd.
  - **Paid once:** in a Grand Prix the race's coins are written into the championship save first, and the race can't be restarted after its result is saved, so neither resuming nor restarting pays twice (GDD §13.2).
- **Results screen** (GDD §11.7) adds: coins earned line by line and your new balance, **NEW PERSONAL BEST** (race time and/or best lap, per track and lap count), cosmetics you can **newly afford**, and in a Grand Prix the **next race's grid**.
- **Shop** (GDD §9.4), one free starter item per category, owned from the start:

| Category | Items | Price |
|---|---|---:|
| Paint | Crimson, Ultraviolet, Acid Green, Arctic White, Sunset Orange, Midnight Black | 100 |
| Finish | Matte 500, Metallic Flake 750, Chrome 1,000 | 500–1,000 |
| Stripes | Twin racing, centre line, side flash | 300 |
| Decals | "2199", "88" 200; "CYBERWAVE" 300 | 200–300 |
| Wheels | Chrome mesh, gold spoke, neon rim | 500 |
| Plate frame | Chrome, gold, neon magenta | 250 |
| Underglow | Cyan, magenta, lime | 400 |
| Exhaust | Plasma blue, toxic green, violet tips | 350 |

The GDD prices basic paint (100), plate frames (250), wheels (500) and premium finishes (1,000); the other prices are first guesses. Items live in `scripts/progression/cosmetic_catalog.gd`; ids must stay stable because saves refer to them. Exhaust cosmetics colour the exhaust tips only: boost flames keep their drift-level colours, which carry gameplay information.

### Saving

- **Profile** (`user://profile.json`, GDD §13.1): coins, owned and equipped cosmetics, license plate, selected car, personal bests, completed Grand Prix results and the last race setup. It's versioned JSON written atomically (to a temporary file, then swapped in). A damaged or unknown-version file falls back to a fresh profile instead of crashing; an interrupted swap is recovered from the temporary file.
- **Settings** (`user://settings.cfg`): display, audio, control rebinds and the camera view.
- **Grand Prix** (`user://grand_prix_save.json`): as in Phase 4, now also written atomically, with the coins already awarded.
- To start over, delete those files (on Windows they're in `%APPDATA%\Godot\app_userdata\Cyberwave 2199\`).

### Slipstream

Tuck in close behind another car to draft it. You're in its **slipstream** when it's 2–16 m ahead of you, no more than about a car width to either side of your line, heading the same way, you're doing at least 72 km/h, and both cars are on the ground. A meter fills while you stay there: 1.4 s close up (6 m), up to 2.2 s at the back of the tow. When it's full you get a short **Slipstream** boost (+4.5 m/s for 1.2 s, milder than a Cyan drift boost) to slingshot past; out of the tow the meter drains. After a slipstream boost there's a 2 s wait before the meter can fill again. Every car can draft, rivals included (they draft each other and you). The speed panel shows **SLIPSTREAM** and the meter's percentage, faint wind streaks rush in from the screen edges (off with Reduced flashing), and the boost shows SLIPSTREAM! with a whoosh. While the boost runs, glowing cyan arches ring the car (`SlipstreamRing`) and a SLIPSTREAM banner shows at the bottom centre. Rules and tuning: `scripts/race/slipstream.gd`.

### Ramp tricks

Going over a **jump ramp** (three on Six Flags New Orleans, one in The Stacks) opens a trick window. Press **Trick** (E / gamepad Y) while you're in the air, or just as you leave the lip, and the car spins a full turn; land it and you get a short cyan **Trick** boost (+6 m/s for 1 s, a little weaker than a Cyan drift boost). The spin is visual only (body and wheels), so your heading, physics and the camera aren't affected. The HUD shows TRICK! and TRICK BOOST!, with a tone. AI rivals trick too: 30% of the time on Easy, 60% on Normal, 90% on Hard (`trick_chance` in `resources/ai/*.tres`). Logic in `scripts/vehicles/vehicle_trick.gd`.

### HUD and results

The race HUD is built from small parts in `scripts/ui/hud/`, coordinated by `RaceHUD`:

| Where | What |
|---|---|
| Top left | **POSITION** as a big slanted "2/8" (pulses cyan with POSITION UP! when you gain a place, orange when you lose one), then the live standings: a place box, a shield emblem in the racer's colour and their name, your row in gold. Only racers still in the race. Elimination info below |
| Top right | LAP as "1/3" and the race time as 00:23.567, with your coins (count and coin symbol) under the time in single player |
| Top centre | Announcements that pop in and fade: 3 / 2 / 1 / START, LAP, FINAL LAP!, NEW BEST LAP!, 1ST PLACE! (taking the lead from lap 2, at most every 10 s), FINISH!, QUALIFIED, plus INCOMING and the elimination feed |
| Bottom left | A round speed gauge (km/h) with five drift-charge cells under the number in the current tier's colour |
| Bottom right | The minimap, with the two item squares (number badges 1 and 2) under it |
| Bottom centre | The SLIPSTREAM banner while a slipstream boost runs |

Split-screen views keep lap and time under the position and the items top right, so the corner next to the shared minimap stays clear. Layout after `reference files/Cyberpunk Slipstream Under the Neon Moon.png` (GDD §11.5).

There's no mode or track name on the HUD, and no control instructions; the controls (from your current bindings) are in the pause menu.

**Results screen** (single player, `NeonResultsScreen`, after `reference files/Cyberwave 2199 Race Results.png`), over the dimmed race:
- **Left card:** your placement in big letters between gold laurels ("P3", then "3RD PLACE" and VICTORY! / PODIUM! / ...), your car, the track's picture with its name and mode, and YOUR TIME / BEST LAP / LAPS / COINS rows with gold NEW BEST tags. Your new coin balance and anything newly affordable sit under the card.
- **Table:** every racer, with a gold / silver / bronze place badge, their car in its own paint (rendered when the screen opens, by `CarThumbnails.request_looks`), name, **PTS** (the points the place earns on the Grand Prix scale, shown in every race), total time and best lap. Projected times and DNF as under Racing. Your row is magenta.
- **Buttons:** **Race again / Next race** and **Main menu**.
- **Grand Prix and Versus sets** are two pages, as in Mario Kart: the race with +points, then Continue shows the standings (rows slide into points order, totals count up), then Continue goes on.
- It animates in over about 1.5 s; Enter / A or a click skips to the end.

**Split screen** uses the same layout, shared by everyone: the card shows the best-placed human (placement and car in their player colour, TIME / BEST LAP / LAPS), with a line per player (place and time) where the coins would be. Each player's row is filled in their colour, and the menu button reads **Quit to Home** (back to the title screen).

**Music:** after a podium, its *Victory* theme carries on; any other results screen (mid-Grand Prix races, a single Elimination) plays alex-morgan's *Background Music*. Race sound effects stay muted on the results screen.

**Podium ceremony** (`scripts/ui/podium/`, GDD §11.7a): before the results after a Grand Prix, a Versus set or a single Versus race. The top three cars drive onto neon platforms on the menu's night street, the platforms rise 3rd, 2nd, then 1st, and a crown drops over a human winner, with spotlights and confetti. The fanfare only plays with the crown (a human winner). The *Victory* theme starts and carries on into the results. Race sound effects are muted while it shows. A / Enter skips to the end.

**Style:** `UIStyle` (`scripts/ui/ui_style.gd`) holds the colour system (magenta = you / selection / drifting, cyan = boost / speed / navigation, gold = coins and rewards, orange-red = warnings), translucent purple panels with thin neon borders, and the fonts: **Oxanium** for headings and big numbers, **Rajdhani** for everything else (the project theme, `resources/ui/cyberwave_theme.tres`). Both fonts are under the SIL Open Font License (`assets/fonts/*-OFL.txt`). Menus fade in and buttons have a focus glow and a small pop.

### Audio

One song per screen or track (`scripts/core/music.gd`; race music per track in `TrackCatalog`, `scripts/track/track_catalog.gd`). Moving between menus that share a song doesn't restart it, and changes crossfade.

| Where | Song | Artist |
|---|---|---|
| Title, main menu, setup screens, settings, credits | Cyberpunk | ikoliks_aj |
| Garage | Wings of Hope | ikoliks |
| Podium ceremony and the results after it | Victory | alex-morgan |
| Other results screens (no podium) | Background Music | alex-morgan |
| The Stacks | Cyber Dreams | Lilex |
| Six Flags New Orleans | Race Winner | TheBoysBeats |
| Vegas Overdrive | Heavy Racing | SPmusic |
| Hoia Baciu Run | Cyberpunk Music | kulakovka |
| Catacombs Descent | Hard Cyberpunk | kulakovka |
| Arashiyama Circuit | The Cyber Geisha | Ob-Lix |
| Vatnajökull Glacier | Besieged Castle | ed-musicproductions |
| Crazy House | Spooky Halloween Strange House | sonican |
| Gardens by the Bay | Garden Fairytale | elisaveta_stoycheva |
| Parque Quinta Normal | To the Moon and Back | theorienvibes |
| Vale da Lua | Rise of the Phoenix | restum-anoush |
| Choquequirao | Epic Victory March for Heroes | DesiFreeMusic |
| Kilwa Kisiwani Ruins | The Dragon's Lair | vishiv |
| Fires of Nyiragongo | Danger Imminent | Jean-Paul-V |
| Chefchaouen | none yet | |
| Test Circuit and Practice | The Garden Wakes | stageechoesmusic |

- **Final lap:** in races of 2+ laps (Elimination included), the race music speeds up 5%, pitch and all, over about 0.4 s. Restarting or leaving the race puts it back.
- **Countdown:** the clip has four beeps a second apart, one per start light and word (3, 2, 1, START).
- **Weapon and track sounds** (`CombatSfx`, GDD §12.2) come from the car or object that makes them, so they fade with distance: Firewall up / down, Railgun, EMP, System Override, Road Spike drop, Hunter-Killer launch / lock warning / hit, and barrier smashes. Each clip has its own level so it sits just above the music, and a hard limiter on the Master bus stops loud moments distorting.
- **Buses:** music plays on the Music bus and effects on the SFX bus (`default_bus_layout.tres`), so the Settings sliders control each.
- **Web build:** plays 96 kbps `.ogg` copies from `music/web/`.
- Every song and clip used must be credited. `tests/test_ui.gd` checks this by the author prefix in each file name.

### Tracks

Fifteen tracks in five cups, raced in this order in a Grand Prix. The **Test Circuit** is used for Practice.

| Cup | Race 1 | Race 2 | Race 3 |
|---|---|---|---|
| American | Vegas Overdrive | Six Flags New Orleans | The Stacks |
| Europe | Hoia Baciu Run | Catacombs Descent | Vatnajökull Glacier |
| Asia | Arashiyama Circuit | Crazy House | Gardens by the Bay |
| South America | Parque Quinta Normal | Vale da Lua | Choquequirao |
| Africa | Kilwa Kisiwani Ruins | Fires of Nyiragongo | Chefchaouen |

Each track below lists its race music in the Audio table above. Best times saved under the old name "The Stacks Grand Prix" carry over to The Stacks.

#### The Stacks (GDD §8.1)

A 2.9 km technical circuit through the Library of Congress **at sunset**. It's mostly indoors, with one open-air courtyard. The road is a 16 m polished marble floor with gold and white racing neon.

- **Great Hall** (start/finish): a 24 m high marble hall with windows on both sides, twin grand staircases, statues on pedestals, red velvet banners and chandeliers. A chicane leads out.
- **Gallery:** the long straight, with bookshelves to the east and tall arched windows to the west. The low sun throws shafts of light across the floor through the window openings. Boost pad.
- **Archive stacks** (shortcut): a narrow 11 m lane between towering bookcases under a low ceiling, with a smashable book cart and bonus coins. It's about 100 m shorter than the main road.
- **Main Reading Room:** one big sweep round the domed rotunda: a ring of marble columns, a drum wall with arched windows, a balcony with statues, a ribbed, painted dome with a glowing oculus, and rings of reading desks with green lamps. A boost ring.
- **Courtyard:** an open-air straight under the sunset sky between the building's façades, with lit windows, hedges, lanterns, a fountain and a jump ramp over a low stair.
- **Card-catalogue corridor** and the long north hall back to the start. Boost pad.
- No water or EMP: it's a clean, technical track. 5 crate rows and 10 coins per lap.
- **Lighting:** a low gold sun with shadows, the `qwantani_sunset` sky, warm volumetric fog (Forward+ only), SSR on the floor, chandeliers and emissive windows.
- Everything is built from code (`StacksScenery`, `HallBuilder`), with Poly Haven marble, parquet, velvet and stone textures and a generated book-spine texture.

#### Hoia Baciu Run (GDD §8.4)

Europe Cup race 1. A 3.2 km winding **dirt road through Romania's haunted forest on a foggy, moonlit night** (no rain). The road is 15 m wide with no centre line, and cold blue-white racing neon dimmed to read through the fog.

- **Start:** under a carved wooden archway with lanterns and red banners.
- **Crooked Forest:** four S-bends through a grove of Hoia's bent trees. Their trunks leave the ground sideways, curl up in a J/S bend and rise tall and straight, all bowing the same way.
- **Graveyard:** a straight beside a railed forest cemetery with leaning crosses, headstones, candles and a chapel ruin.
- **Viaduct:** a stone-arched bridge over a ravine with a stream. Boost pad.
- **Hairpins:** two hairpins through dense pines beside a black bog with faint marsh lights. The bog has an EMP puddle.
- **Castle:** the main road swings round a ruined red-stone castle. The **shortcut** (11 m) goes through the east gatehouse, past a timber barricade (smashable), across the rubble courtyard and out of the west gate through a boost ring. About 120 m shorter, with three bonus coins. A ruined keep on a rocky rise, with lit windows, stands out across the lap, with the moon low behind it.
- **Round Clearing:** after a jump over a fallen-log mound, the road sweeps round the treeless meadow of the legend, ringed by bowing trees and old stones. Boost pad.
- **Atmosphere:** the misty_pines HDRI darkened as the distant forest, dense blue-grey fog with low ground fog (plus volumetric fog in Forward+), cold moonlight with shadows, warm lanterns along the road (steady with Reduced flashing). Nothing supernatural, just lights in the fog.
- **Trees:** about 7,000, built by `TreeBuilder` and instanced. It mixes crooked trees, tall misty pines, bare twisted trees and dead snags, densest by the road and thinning into the fog. Ferns, boulders, logs and stumps fill the ground.

#### Catacombs Descent (GDD §8.5)

Europe Cup race 2. A 2.8 km twisting race **through the quarried tunnels under Paris**, roofed over every metre: no sky anywhere. The road is a 12 m strip of wet cobbles, the narrowest in the game, between low sandstone kerbs with dim pink racing neon. The stone walls stand about 3 m beyond the kerbs, under barrel vaults about 7.5 m high. Tight corners (30–45 m radius), short straights and narrow chevron boards on every bend. It's lit by about 160 wall torches with a soft flame flicker (steady with Reduced flashing), candle clusters, and pale light falling through five iron street grates (no visible beams).

- **Barrière d'Enfer** (start/finish): a tall 15 m vaulted chamber with cut-stone piers and iron braziers by the gantry. At its far end, over a low archway, the carved lintel **"ARRÊTE ! C'EST ICI L'EMPIRE DE LA MORT"**. Boost pad with item boxes.
- **Ossuary galleries:** chicanes between walls of stacked bones set with rows of real skulls, with a row of skulls along the top ledge. Candles and skull heaps on the floor. Pale light from a street grate.
- **Crypt:** burial niches in three rows (most sealed with slabs, a few open with a skull inside), and sarcophagi along the walls. Jump over a hump of fallen masonry.
- **Service passage:** pipes along both walls and red emergency lamps.
- **Flooded cistern:** a wide, 12 m high hall of columns standing in black water, with standing water on the road (keep right to stay dry). Pale light from a street grate.
- **Forgotten chapel:** the road sweeps past an apse with an altar, a white statue, a cross, candelabras, dozens of candles and pale light from above.
- **More ossuary**, then the **quarry:** bare rock walls propped with timber. A fallen cable has electrified a puddle (EMP).
- **Tomb gallery** back to the start.
- **Flooded crypt** (shortcut): a 10 m passage under a 5.6 m vault that cuts across the waist of the lap. It's about 300 m shorter than the main road, but half of it is under water and a **fallen-rubble barricade** (smashable) blocks the half-collapsed stretch. Boost ring at the exit, three bonus coins.
- **Atmosphere:** near-black background, low warm ambient light and dark brown fog, so the tunnels fade to black about 60 m ahead (plus volumetric fog in Forward+). The street grates light the road but cast no visible beams (GDD v6.8: they read as UFO lights).
- Built from code: `CatacombsScenery` and the new `TunnelBuilder`, with Poly Haven old_stone_wall, large_sandstone_blocks and cobblestone_floor_08 textures and a generated bone-wall texture (colour and normal map). About 18,000 skulls are one small instanced mesh in 100 m chunks.

#### Arashiyama Circuit (GDD §8.6)

Asia Cup race 1. A 3.1 km race **through Kyoto's bamboo grove on a soft, sunny day**, built to feel like an indoor garden out of doors. Tall culms bow in from both sides until their leaves close over the road like a green ceiling (about three quarters of the lap is under the canopy). The sun dapples the road through the leaves. The road is 13 m of paved stone between brushwood (shibagaki) fences with two bamboo rails, with soft green racing neon along the fence tops and vermilion chevrons. Corners are drift-friendly 35–60 m radius bends with one hairpin and short straights.

- **Start plaza** (open sky): stone lanterns and white and vermilion banners along the grid, then a timber gate with a tiled roof, paper lanterns and the **ARASHIYAMA** plaque where the road enters the grove.
- **The grove:** S-bends under the canopy, past a stacked mossy-boulder wall. Boost pad on the exit.
- **Katsura river bridge** (open sky): a long, low wooden bridge on timber pile bents over the river, which flows into a pond inside the loop, with wooded mountains behind. Boost pad before it, crates on the deck.
- **Hillside sweepers:** mossy retaining walls on the hill side, red, orange and green maples among the bamboo, ending in the hairpin.
- **Rain-soaked stretch:** wet, glossy stone with puddles near the edges and standing water on the road (keep right to stay dry), then a jump over a hump of roots and an electrified puddle from a fallen lantern cable (EMP).
- **Temple garden** (open sky, walled): white plaster walls with tiled caps around a levelled moss garden with a pond (rocks, a pine island, snow-viewing lanterns), clipped azalea mounds, maples, stone lanterns, a raked-gravel garden with moss-ringed rock groups, and the abbot's hall.
- **Shrine path** (shortcut): a 9 m lane under the bamboo through black torii with straw ropes and paper lanterns, past a small shrine. It's about 200 m shorter, but **fallen bamboo** (smashable) blocks the entrance. Boost ring at the exit, three bonus coins.
- **Atmosphere:** the kloofendal overcast sky, a warm sun with shadows (limited to 90 m), green-tinted ambient light, light green haze (plus volumetric fog in Forward+). The sun comes through the canopy in dapples, with no visible shafts (GDD v6.8).
- **Bamboo (GDD v6.1 rework, after `reference files/Bamboo Forest 1-5.webp`):** straight, rigid, jointed culms tilted from the base 9–15° toward the road, with leaves only on the top third as flat fans at the branch nodes, so the crowns meet high overhead. Stands are clumped in greens and blue-greys, with ferns, sasa and fallen culms underfoot, bristly brushwood fence crests with thick bamboo rails, and a darker, greener grade.
- Built from code: `ArashiyamaScenery` and `BambooBuilder` (straight, arching and dead culm kinds, with low-detail meshes past 15 m; instanced), with Poly Haven pavement_01 (road), reed_roof_04 (fences), hinoki_planks (bridge and timber), dry_decay_leaves (ground), mossy_stone_wall and sparse_grass (moss) textures, and generated culm and leaf textures.

#### Vatnajökull Glacier (GDD §8.6a)

Europe Cup race 3. A 3.1 km race **through an ice cave under Vatnajökull, Iceland**: fully under the ice like the Catacombs, but roomy and bright instead of cramped. One continuous cave of swirling blue, white and ash-striped ice opens up and closes in along the lap (roofs from 15 m to about 36 m), lit mostly by daylight glowing through the ice. The road is 14 m of blue-grey asphalt between pale ice-block barriers with cyan and white neon, with long flowing corners (55–115 m radius). Over ten thousand icicles hang from the roof, and none hangs lower than 7.5 m over a road. In driving order:
- **Glacier Mouth** (start): a huge opening onto bright daylight and snow, beside the grid.
- **Blue Cathedral:** a vast swirling hall along the longest straight, with a meltwater stream beside the road. Boost pad with item boxes.
- **Icicle Gallery:** lower and wide, lined with icicle curtains and hourglass ice columns.
- **Moulin Hall:** five meltwater holes in the roof let sky light onto snow drifts (no visible beams). Boost ring and a meltwater ford across the road.
- **Ash Canyon:** a tall gorge striped with black volcanic ash, with a snow-drift jump.
- **Frozen Lake:** a glassy lake beside the road under ice chandeliers, and a slush puddle (EMP), back to the mouth.
- **Crystal Tube** (shortcut): a narrow, glowing round tunnel of scalloped ice from the Cathedral to the Gallery, with white light at its far end. About 120 m shorter, but an **ice wall** (smashable) blocks the entrance. Boost ring at the exit, three bonus coins.
- **Atmosphere:** no sky; a dark blue background, pale blue ambient light and light blue fog thin enough to see far down the cave, strong glow on the daylight, and volumetric fog in Forward+.
- Built from code: `GlacierScenery` and the new `CaveShellBuilder` (one noise-carved shell along each route, blending between zone shapes). The ice is a procedural shader (`assets/shaders/glacier_ice.gdshader`: swirling flow bands, ash streaks, and a glow strongest near the daylight), so it doesn't come out black in the Compatibility renderer. Icicles are instanced. The ice blends in a Poly Haven rock_face normal map (`assets/shaders/detail_common.gdshaderinc`). Poly Haven snow_floor (packed-snow road), snow_02 (barriers, floor and snow drifts) and dark_rock (basalt) textures.

#### Crazy House (GDD §8.6b)

Asia Cup race 2. A 2.9 km race **inside Hang Nga's Crazy House** in Da Lat, Vietnam: the guesthouse built to look like a hollowed-out tree, here grown to giant size so the whole lap runs inside one hollow trunk. Nothing has a straight line: melted grey and dark-brown bark dripping with cream plaster, oval windows letting in daylight from the roof and warm light from the walls, staircases winding everywhere and bone-like branches. The road is 13 m of worn concrete between cream plaster barriers with amber and cream neon, and it never stops turning (40–70 m corners, no straight longer than about 220 m). The road is flat; the stairs are scenery. In driving order:
- **Root Hall** (start): gnarled root columns from floor to roof, knotted bone railings beyond the barriers.
- **Spiral Stair Well:** a tall well (roof about 46 m) ringed with helical staircases: rounded steps, bone banisters with knobs, twisted posts and lit doorways at the top. Boost pad with item boxes.
- **Animal Rooms:** warm-lit alcoves with a bear, an eagle on its perch and a giraffe, after the house's themed rooms. Stair-step jump.
- **Gingerbread Gables:** the yellow timber house with steep, curling gables, dark trim and warm windows, built into the trunk. Boost ring.
- **Lava Grotto:** orange-red pitted walls and giant mushrooms, with a sap puddle (EMP).
- **Bone Gallery:** bone arches over the road (never lower than 7.5 m), knotted railings and a giant spider web on the wall. Stair-step jump.
- **Rib Tunnel** (shortcut): a narrow passage lined with bone ribs that carries straight on where the road turns into the Gables. About 250 m shorter, but a **bone barricade** (smashable) blocks the entrance. Boost ring at the exit, three bonus coins.
- About 29 staircases (1,500 steps) in all, daylight through eight oval roof windows (no visible beams).
- The location is spelled "Da Lat" because the game fonts lack the Vietnamese "ạ".
- Built from code: `CrazyHouseScenery` on the same `CaveShellBuilder` as the glacier (with slow "bulge" swellings), organic tube and blob helpers for bones, branches, railings and figures, and a procedural bark-and-drips shader (`assets/shaders/crazy_house.gdshader`, with a lava variant). The shader blends in Poly Haven bark_brown_02 grain and normals. Poly Haven dirty_concrete (road), patterned_plaster_wall (barriers), brown_mud_leaves_01 (floor), hinoki_planks (the gables and trim) and white_plaster_rough_01 (bones, steps and caps).

#### Gardens by the Bay (GDD §8.6c)

Asia Cup race 3. A 3.4 km **night race along a glass skyway 10–53 m above the jungle** in Singapore, through the Supertree Grove during the light show. It's the only track in the air. The road is a 12 m glass deck framed in wood that rolls over four crests (grades up to about 9%, 7° banking in the sweepers), between glass side walls with amber-lit wooden handrails, on steel pylons. Winding, linked corners (45–90 m radius). The Supertrees (26–52 m) change colour together in a wave of purple, cyan, green and magenta, with Marina Bay Sands and the skyline beyond. In driving order:
- **Supertree Grove** (start): the grid between two Supertrees under a GARDENS BY THE BAY sign.
- **Skyway S-bends:** weaving between Supertrees, Marina Bay Sands ahead. Boost pad.
- **The Great Wrap:** a hairpin round the tallest Supertree. Boost ring.
- **East side:** a long run with a jump on the deck.
- **Canopy Run:** low over the treetops, with rain-wet glass (standing water) and an **open edge**.
- **Bayfront:** over the water past the Flower Dome and the wooden dragon (spark puddle EMP), with a second open edge over the bay.
- **Open edges** have only a low wooden curb. Go over and you fall into the jungle or the bay and are recovered onto the deck. They're on straights, on the outside of the loop.
- **Cloud Forest walk** (shortcut): through a smashable glass panel into the Cloud Forest dome, round the misty waterfall mountain on a narrow walkway with two open edges of its own. About 150 m shorter.
- **Engine:** the opt-in `TrackCircuit` exports `elevated` + `ground_depth` (deck collider), `open_edges`, wooden curbs and `road_material` / `barrier_material`. Built from code: `GardensScenery`, `SupertreeBuilder` and `assets/shaders/supertree.gdshader` (a world-position colour wave), plus `TreeBuilder` rainforest and palm kinds.

#### Parque Quinta Normal Greenhouse (GDD §8.6d)

South America Cup race 1. A 3.1 km race on a **bright summer day through and around the old Victorian greenhouse in Santiago's Parque Quinta Normal**, with **wire mesh everywhere**: every road edge outside the glasshouses has a tall welded-mesh fence on iron posts over a low brick wall, and the glasshouses have mesh walls under their glass vaults. The sun is high in the north-west, so the iron ribs throw striped shadows on the road. The road is 13 m of worn cobbles. In driving order:
- **The main wing** (start / finish): the grid sits under a long barrel-vaulted glasshouse, iron ribs every 2.5 m, about a third of the glass gone and some yellowed, bougainvillea climbing the outside, a railed catwalk along the ridge. It comes in two spans with a sunny courtyard of flower beds between them (boost pad).
- **The avenue** south between hedges and plane trees.
- **The Rotunda**: a short stalk leads into the domed pavilion, where the road sweeps **about 310° round the checkerboard plinth** (palms, flowering shrubs and graffiti-covered low walls in the middle, more graffiti outside), then leaves along a parallel stalk beside the way in, with a mesh-fenced divider between the two (boost ring).
- **The south**: hedge-lined S-bends past the infield's **tiered dome** (exterior iron staircase, gallery, open lantern) and its two glass wings (sprinkler puddle).
- The south-west corner, the west side (spark puddle EMP), and back into the main wing.

The Andes fill the eastern horizon; Santiago's Gran Torre and skyline stand to the north-east. **Shortcut:** the **Fern Wing**, through a smashable glass panel into a narrow, mesh-caged glasshouse across the south-west corner (9 m wide, about 110 m shorter). Built from `GlasshouseBuilder` (`scripts/track/scenery/glasshouse_builder.gd`: barrel wings, ribbed domes with a drum, lantern, gallery and stair, and the wire mesh) and `QuintaNormalScenery`. Checks: `tests/test_quinta_normal.gd`.


#### Vale da Lua (GDD §8.6e)

South America Cup race 2. A 3.1 km race through **Brazil's Valley of the Moon**: smooth grey "moon rock" sculpted by a fast river, under a soft daylight sky with green cerrado forest on the rock tops. The road is 13 m of pale stone with teal and white neon, with flowing 60–100 m corners. **The water moves**: a new animated water shader scrolls ripples, streaks and foam downstream, turns into fast white falling water on the waterfalls, and churns white at their feet. In driving order:
- **Start straight** over the first **rock bridge**: the main river passes 5 m below the road. Boost pad with item boxes.
- **First open rock shelf** (about 90 m): no barrier on the right, with a creek canyon right below the road edge. Run wide and you drop in, splash and are put back on the road.
- **East stream bridge**, with spray from the falls across the road (water).
- **The headland loop** (jump), which the shortcut cuts off.
- **The deep gorge bridge**, at the bottom of a long dive (about 19 m below the start), still 5 m+ above the main river, which falls to about 25 m down where it leaves the valley.
- A **rock hump jump**, then the **second open shelf**.
- **West stream bridge** and the cerrado (boost ring), back to the start.
- **Behind the Falls** (shortcut): a ledge under a rock overhang, with a stream pouring off the overhang as a curtain past its outer edge into a pool. About 250 m shorter, but **driftwood logs** (smashable) block the entrance. Boost ring at the exit, three bonus coins.
- Inside the loop the main river drops over two waterfalls and both streams fall into it: **six waterfalls** in all, with white churn and mist. About **900 smooth boulders** (instanced, water-worn shapes) line the canyons, sit in the water and hold up the bridges and the overhang. Bleached driftwood is jammed in the channels.
- The road is **elevated** (Gardens by the Bay's skyway mode) so the shelves are real drops, and **sloped**: about 21 m up over the headland, 19 m down at the gorge, humps between, grades up to about 10%. One water `RecoveryZone` runs along every river at the water line.
- Built from code: `ValeDaLuaScenery` (river polylines generated with the layout, slot-canyon meshes with smooth normals, water ribbons, boulder MultiMeshes), `SceneryTerrain` carved by the rivers plus a rock dome, `TreeBuilder` rainforest and palm trees, and two new procedural shaders: `assets/shaders/moon_rock.gdshader` (erosion ripples, potholes, a wet band toward the water) and `assets/shaders/flowing_water.gdshader`.

#### Choquequirao (GDD §8.6f)

South America Cup race 3. A 3.3 km race through an **Inca village in a green Andean valley** on a bright sunny day (Poly Haven's partly cloudy kloofendal sky, a high sun with shadows lined up with the sun in the sky). You start outside on the valley floor and work your way **in through the village and back out**. The road is 12 m of warm flagstone with faint gold and teal edge lights.
- **A labyrinth of rings.** The village is a double spiral: the road spirals in, crosses the plaza on an S-bend (29 m radius) and spirals back out between the inbound rings. Inbound and outbound lanes alternate ring by ring, about 27 m apart, so the car on the next ring is coming the other way.
- **Terraces and houses.** Each village lane runs between 2.6 m stone terrace walls with grass on top, and the houses stand on the terraces, so you can't see across the rings. Outside, the terraces step up the valley sides (six more steps) to cloud forest and jagged peaks.
- **Old but sturdy stone.** Flat, irregular fieldstone set in mortar (`old_stone_wall`) everywhere, with dressed lintels. About 120 houses: most are roofless ruins with tall gable ends, rows of small trapezoidal windows and a trapezoidal doorway, some partly collapsed with fallen stones; about one in six has a steep thatched roof.
- **Eight Inca gateways** the road drives through: the village gate in, one on the outer inbound ring, the plaza entrance, a pair on the plaza S-bend, the plaza exit, one on the outer outbound ring and the village gate out. Trapezoidal openings with leaning jambs, a flat lintel and a recessed second frame on each face, wide and tall enough to clear the barriers and Overdrive flight.
- **The plaza:** the great hall in one half of the S, the stepped usnu platform in the other.
- **Qolqa storehouses** (shortcut): a 9 m lane over the hill spur past a row of storehouses on a terrace, with a wooden QOLQAS sign. About 130 m shorter; stacked baskets (smashable) block the entrance, boost ring inside.
- Boost pad with item boxes on the start straight, a terrace-step jump after the shortcut rejoins, a boost ring after the plaza.
- Built from code: `ChoquequiraoScenery` with three new reusable builders in `scripts/track/scenery/`: `TerraceBuilder` (stepped terraces along any road, each side reaching to the halfway line to the next lane), `IncaBuildingBuilder` (gabled houses, qolqas, great hall, usnu) and `IncaGateway`; plus `TrackScenery.add_prism` / `add_quad`. The valley is `SceneryTerrain` lifted by a distance-to-road field that stays under the terraces and rises to mountains. Checks: `tests/test_choquequirao.gd`.

#### Kilwa Kisiwani Ruins (GDD §8.6g)

Africa Cup race 1. A 3 km race through the ruins of the medieval Swahili city on its island off Tanzania, **late on a mildly overcast afternoon**: Poly Haven's kloofendal overcast sky, a low warm sun from the west-south-west (22° up) with soft shadows, and warm haze. The layout is a **maze**: about twenty right-angle corners, a **22 m road** and walls along it. A little of the lap is in the village; the rest is inside the ruins.
- **Old stone with a Persian feel.** Coral rag (rough fieldstone with peeling lime plaster) for the walls; dressed coral blocks for the piers, arch rings and frames. Pointed two-centred arches, domes, pointed niches and stepped Omani crenellations.
- **Village:** about 500 one-storey houses, most with steep makuti palm-thatch roofs and some flat or ruined, with carved doors, palms, baobabs and red flame trees. The start straight and a jog through the streets.
- **Great Mosque:** a walled forecourt with an ablution tank, a tall pointed portal, then the **hypostyle hall**. This is a 12 m grid of square piers with pointed arcades both ways, threaded by the road three times.
  - **Columns stand in the middle of the road** on the straight aisles (19 of them, about 10 m gaps either side). They are solid (`TrackCircuit.road_columns`), and the AI's racing line, recovery spots and Overdrive flights steer round them.
  - Flat vaults with saucer domes overhead, domed bays, and a few collapsed bays open to the sky. One fallen dome has a tree growing up through it.
- **Husuni Kubwa palace:** a portal, walled lanes lined with niches, a vaulted gallery, the octagonal bathing pool (its spill floods the road edge) and a terrace jump.
- **Shore straight:** a sea wall, beach and dhows on the channel, the crenellated Makutani walls, and a great gateway arch over the boost ring.
- **Shortcuts:**
  - the **Gereza fort yard** (11 m): in at a pointed gate, past the round tower, rusty cannons and a fallen beam, saving about 130 m, with a smashable barricade;
  - the **Small Domed Mosque aisle** (10 m): a U-turn under small domes with a line of coins, saving about 80 m.
- Built from code: `KilwaScenery` with new reusable builders in `scripts/track/scenery/`:
  - `PointedArch` (pointed arcade walls, niches, domes, stepped merlons);
  - `HypostyleHallBuilder` (pier grid, arcades, domed / collapsed bays, `is_roofed`);
  - `SwahiliHouseBuilder`.
  The layout comes from a generator script (orthogonal route with filleted corners, columns on the grid). Checks: `tests/test_kilwa_kisiwani.gd`.

#### Chefchaouen (GDD §8.6i)

Africa Cup race 3. A 3.15 km race through **the blue medina in the Rif mountains** on a bright late morning (the kloofendal partly cloudy sky, sun about 48° up). **Two forks per lap, so four ways round.** The main road is 16 m and the branches 12 m. The town climbs about 28 m from the lower square to the upper terrace.
- **Fork 1, uphill** (a neon gantry 125 m before the split):
  - the **Blue Stairway** (branch): steep stone steps (up to about 12%) between landings, a switchback of two tight bends, flowerpots and deep-blue doors, a crest above the terrace with a boost ring;
  - the **Outer Street** (main): a longer, wider sweeping climb, banked 6°, with items.
  - They meet on the **upper terrace** (Elimination checkpoint, the Galerie tower, the view of the Rif).
- **Fork 2, downhill:**
  - the **Market Lane** (branch): a slalom under hanging kilims through a horseshoe arch;
  - the **Fountain Steps** (main): four flights past a zellige wall fountain, then a long final landing ending in a real drop with a jump ramp in the right lane, landing beside the Market Lane's merge lane.
  - Separate lanes into the **lower square**, then one shared final corner.
- **Stairs over a smooth ramp:** the road surface is hidden on the flights (`hidden_surface`) and `StairBuilder` draws irregular treads whose tops meet the ramp mid-tread. The collider stays smooth.
- **Branch routes (engine):** `TrackShortcut.is_branch` turns a shortcut into a full alternate route:
  - its own AI line (`BranchLine`), with a traffic-aware choice;
  - recoveries respawn on the branch (`VehicleRecovery.safe_branch`);
  - a full-strength minimap line;
  - merge lanes (`start_lateral` / `end_lateral`) and optional item rows (`crate_distances`).
  - `TrackCircuit.elimination_gate` puts the Elimination checkpoint on a shared section.
- Built from code: `ChefchaouenScenery` with the new `MedinaHouseBuilder` (blue and white houses, arched doors, grilles, shutters, awnings, lanterns, flowerpots) and `StairBuilder`, generated kilim and zellige textures, and Poly Haven painted_plaster_wall, rough_plaster_brick, stone_tiles_02, wood_shutter and terracotta_floor_tiles. The layout comes from a generator script (a filleted polygon for the main loop, the two branches as Godot shortcut curves, monotone height keys). Checks: `tests/test_chefchaouen.gd`. No race music yet.

#### Six Flags New Orleans (GDD §8.2)

A 3.1 km circuit through a **realistic, eerie, abandoned amusement park**, after the real park left to rot after Hurricane Katrina. It goes for believable decay, not supernatural effects. The only clean light is the illegal racing neon on the barriers, dimmed to fit the scene. The road is 18 m wide.

- **Atmosphere:**
  - a stormy overcast night sky (Poly Haven HDRI, graded dark)
  - blue-grey fog with low ground fog, dim cold ambient light and moonlight
  - a few failing sodium lamps that flicker (steady and dim with Reduced flashing)
- **Road:** cracked, patched, weathered asphalt (`road_damaged`) with faded, worn centre markings and small reflective puddles near the edges. The puddles are cosmetic; the gameplay water patches are tinted and lit.
- **Ground:** overgrown, waterlogged terrain (rolling grass and mud, flooded hollows), dead trees, weeds, debris, wrecked cars, and a damaged chain-link fence along the circuit.
- **Signs of the flood:** a dark flood-line stain on walls and booths, search-and-rescue "X" codes sprayed on buildings, and "KEEP OUT" / "NO TRESPASSING" signs.

Representative section (full detail, ready for your review):
- **Park Entrance:** start/finish under the derelict gate. Peeling sign with missing letters, chained gates pushed open, a smashed ticket booth, toppled turnstiles. A rusted, tilted Ferris wheel on the skyline.
- **Flooded Midway:** the S-bends between boarded-up game booths with torn awnings, standing in flood water. A wrecked carousel with fallen horses, and the park's faded jester billboard.
- **Bumper-car pavilion:** on the outside of the right-hander at the end of the Midway straight, dead ahead all the way up it: a derelict, silted-up bumper-car ride under a rusty corrugated roof on teal columns, with seven abandoned cars, shuttered back and right walls, and palms at one corner. Its open front faces the cars coming up the straight, and its open railing side faces the road as it turns away. It's the first Blender model on a track (`models/SixFlagsNewOrleansBumperCars.glb`, placed by `SixFlagsScenery._bumper_cars`). Its rust, paint, floor and roof are the park's own Poly Haven grime and faded colours, matched to the Blender material names, because Blender's procedural materials export as plain white. The terrain is levelled under it, and the Midway's booths, flood water, signs and debris keep out of its footprint. It's visual only, with no collision.
- **Coaster Run:** a **massive wooden lattice coaster** (about 1 km of track) runs alongside the road, then **crosses over it twice** on steel gantries (17 m clearance). It has a lift hill, a turnaround and a return run with a collapsed section. A jump ramp sits halfway along the straight.

The rest of the lap now has the same treatment:
- **Water park shortcut:** the slide tower, tiled pools with coping (some flooded black, some drained to an algae-slick bottom), lifeguard stands with torn canopies, dumped inner tubes, deck weeds and a faded WAVE POOL sign.
- **Backlot:** rusted stage warehouses with flood lines and X-codes, stacked and toppled shipping containers, maintenance trucks, wrecks, and light poles knocked flat into the weeds.
- **Bayou boardwalk:** planks with gaps (cosmetic; the road stays solid), broken and sagging railings, cypress with Spanish moss over black water, a half-sunk skiff and a LIVE BAIT shack ruin with a fallen tin roof.
It keeps its jump ramps, water patches, EMP puddle and smashable fence.

**Needed assets.** Apart from the bumper-car pavilion, every prop is a procedural placeholder. These GLB models (Y-up, metres) would raise the fidelity most:
- a coaster train car
- a turnstile
- a ticket booth
- a carousel horse
- the jester / park sign
- a chain-link fence segment
- a debris kit (barrels, tyres, trash)
- an abandoned car
- a Ferris wheel gondola
- an optional water normal map for the flood water

#### Vegas Overdrive (GDD §8.3)

A 3.2 km night circuit (shortened from 4.4 km after your first drive) with 20 m wide roads:
- **The Strip:** a roughly 500 m boulevard lined with neon casino towers, palms and billboards, starting past the "Welcome to Fabulous Las Vegas" sign. Two boost pads.
- **Fountain lake:** a sweeping right-hander along a lake with an animated fountain show and a grand hotel.
- **Paris:** an Eiffel-style tower and a glowing balloon along the south-east straight.
- **Casino interior:** an infield S-bend under a roof, with chandeliers and slot machine rows. Two EMP puddles to avoid.
- **High Roller:** a giant observation wheel inside the infield loop.
- **Service tunnel:** an enclosed concrete tunnel with strip lights and a boost ring.
- **Excalibur:** a castle with coloured spires along the south straight.
- **Luxor shortcut:** a narrower 12 m road that cuts the west corners straight **through the glass pyramid** (under its sky beam). It's about 135 m shorter, but has a smashable barrier at the entrance (costs some speed), tighter turns and three bonus coins. A boost pad waits inside the pyramid.
- Chevron signs mark every sharp corner; 5 rows of weapon crates and 10 coins per lap.
- Poly Haven textures: asphalt_track (road), concrete_panels (barriers and towers), brushed_concrete (ground and concrete), marble_01 (white stone), palm_tree_bark (palms) and velour_velvet (the casino carpet). Neon, windows and glass stay plain emissive colours.

#### Track tech

- **`TrackShortcut`** (child of a TrackCircuit): give it control points from one point on the main road to a later one. The circuit builds its road and barriers, opens the main barriers where the two meet, and mirrors any checkpoint gate it bypasses onto it, so laps always count. Positions on a shortcut map onto the main loop proportionally, so race positions, recovery, wrong-way checks and the AI all work on either route.
- **AI shortcuts:** each AI decides once per approach (the shortcut's `ai_chance` × the difficulty's `shortcut_chance` × aggression), then follows the shortcut at its own safe speeds and rejoins the racing line. If it gets pinned while still heading for a shortcut it isn't on (a late turn-in), it gives up and follows the main road.
- **Junction design:** a shortcut should leave at a gentle angle (the Luxor one turns in about 55°). A first version peeled off at nearly 110° and trapped a car in the wedge between the roads.
- **`TrackFeature`**: boost pads, boost rings, EMP puddles, breakable barriers, **jump ramps** and **water**, placed by distance (or near a layout point) on the main road or a shortcut. Every kind is lit and marked so it reads at speed.
  - **Boost pad patterns:** each main-road boost pad is laid out as a single pad, three in a diagonal, or a triangle (two side by side, then one ahead). The pattern is random per pad but seeded by the track, so a track always has the same layout. The first pad is the `TrackFeature`; the others are generated copies (`pattern_copy`). Checks: `tests/test_boost_patterns.gd`.
  - **Item boxes:** every jump ramp carries a row of "?" crates just above its lip (about one per 4.5 m of width), so you grab one at take-off. A boost pad or ring gets two crates when its `item_boxes` box is ticked in the Inspector. Currently ticked: The Stacks' Gallery pad and Rotunda ring, Six Flags' Coaster Run pad, and Vegas' second Strip pad and tunnel ring.
  - **Jump ramp:** a solid wedge (`length` × `width`, lip of `ramp_height`) that the wheels drive up. Put them on straights at full road width. On the Coaster Run a car at full speed gets about 1.6 s of air and 4 m of height, and lands on its wheels.
  - **Water:** standing water makes cars **wet**: top speed ×0.88 and grip ×0.75 while in it (and for 0.3 s after), with spray from the rear wheels and "WET" in the effects line. A Firewall doesn't keep you dry; wet stacks with EMP and Road Spike effects. The water is textured (drifting ripples, rain-drop rings, silt, glints and a soft shoreline; `assets/shaders/standing_water.gdshader`), and scenery puddles and ponds share it.
  - **EMP puddle:** dark, oily water with crackling white-violet arcs and sparks, a raised yellow/black hazard lip and a lightning-bolt sign on each side, so it never reads as a boost pad (`assets/shaders/emp_puddle.gdshader`, `hazard_sign.gdshader`). Reduced flashing slows the arcs and drops the sparks.
- **`TrackScenery`**: base class for a track's set dressing (`VegasScenery`, `SixFlagsScenery`, `StacksScenery`), with shared helpers such as `add_ferris_wheel`, `add_palm`, `textured()` (Poly Haven PBR sets mapped triplanar, so generated geometry needs no UVs) and `add_flicker_light()`.
- **Reusable scenery builders** (`scripts/track/scenery/`):
  - `SceneryTerrain`: overgrown, waterlogged terrain with level banks along the roads
  - `WoodenCoaster`: a lattice coaster along any 3D path, with steel gantries where it crosses a road
  - `ChainLinkFence`: damaged fencing with a procedural chain-link texture
  - `TreeBuilder`: a procedural forest. A few tree meshes (lofted bark tubes plus needle clumps: crooked, pine, bare, snag) are built once, then scattered as MultiMesh instances in 200 m chunks with a visibility range (300 m past the chunk), so thousands of trees cost a few draw calls.
  - `SceneryTerrain` also takes an optional `carve` function (ravines under bridges) and can skip the flood water.
  - `TunnelBuilder`: a stone barrel vault along a stretch of the main road or a shortcut, with walls lined per side as `skulls` (ossuary), `tombs`, `pipes`, `rock` or plain `stone`, arch ribs, torches, candles and grate lights. Wall pieces that would stand on another road are left out at junctions, but the vault always closes over the top. Span ends get a stone face around the opening, so a low tunnel entering a tall chamber reads as an archway.
  - `BambooBuilder`: a procedural bamboo grove. A few culm meshes (straight, jointed tubes tilted from the base, with branch fans of leaves only up high, plus low-detail far versions) are built once, with generated culm and leaf textures, then scattered as MultiMesh instances in 120 m chunks, each with its own tint. Culms and leaves cast shadows, so the sun dapples the road.
  - `SceneryTerrain.height_at()` gives the ground height at any point, so scenery can stand on the terrain.
  - `HallBuilder`: an interior hall along a stretch of road: marble wainscot, plaster walls, pilasters, open arched window bays or bookshelf bays, a coffered painted ceiling and chandeliers. Plus a stand-alone `bookcase()`.
- **Track look exports** also cover `neon_energy` and `edge_line_energy` (racing-edge brightness), `faded_markings`, `ground_visible`, and `road_texture` / `barrier_texture` / `ground_texture`. Geometry is merged into a few batched meshes, one per material, and it skips anything that would overlap a road. It builds in the editor too.
- **Look:** road, edge, barrier, neon and light colours are exports on each track, and corners tighter than `corner_sign_radius` get chevron signs automatically (`corner_sign_width` and `corner_sign_gap` narrow them for tunnels).
- **`FlickerLight`** has a `flame` mode for torches and candles: a soft wobble that never goes dark.
- Each track scene carries its own sky, fog and lighting (`WorldEnvironment`).

### Weapons

Drive through a "?" crate to collect a random weapon into your first free slot. With both slots full, crates stay in place for someone else. Crates respawn after 3 s, in 5 rows of 4 around the lap, plus the item boxes on jump ramps and some boosters.

| Weapon | How it works | Effect on the victim |
|---|---|---|
| Railgun | Targeted. Fast shot aimed at your lock (with lead), else straight ahead | 0.7 s stagger (hard stun); knocks out the selected weapon |
| Hunter Drone | Targeted / guided. Follows the track, then homes in on your lock or the nearest racer ahead | 0.8 s stun (hard stun); knocks out the selected weapon |
| EMP Pulse | Instant 22 m pulse around you | 1.5 s: no drift charging, −15% top speed; weapons jammed (unusable, but kept) for 5 s |
| Road Spike | Strip dropped behind you; lasts 12 s; single use | 1 s traction loss |
| Nitro Overload | Self boost | 3 s, +10 m/s top speed |
| Triple Nitro | Three Nitro charges in one slot (HUD shows ×3, ×2, ×1). Each press is a separate boost; the slot empties after the third | Rare. Mostly for trailing racers. A Railgun or drone hit knocks out all remaining charges |
| Triple Spike | Three Road Spikes in one slot (HUD shows ×3, ×2, ×1). Each press drops one spike behind you; the slot empties after the third. The AI space their drops at least 1.5 s apart | Uncommon, mostly for leaders (front 0.6, back 0.15). A Railgun or drone hit knocks out all remaining spikes |
| Firewall | Shield | Blocks the next attack, up to 10 s |
| Hunter-Killer Drone | Rare (3rd–8th). Locks on to the **leader** at launch and keeps that racer even if they lose the lead. Flies along the road at 1.8× their top speed, passing everyone else. Close behind, it holds a red reticle and beam over them for 1.2 s, then dives in | 1.5 s spin-out (hard stun). Goes straight through a Firewall. **Dodge** it with a Nitro in the last 0.4 s of the warning or during the dive: it misses (DODGED). Waits while the target is recovering or in Overdrive, and burns out after 12 s or when the target finishes |
| Overdrive Protocol | Rare (5th–8th). Your kart lifts 3.5 m off the road (2.2 m under the catacomb vaults), grows cyan thruster pods and flies itself along the road centre at 2× top speed for about 5 s. It then lands on the next clear stretch of road (not near a jump ramp or another car) and hands back control at top speed | You can't be hit, steered or recovered while flying, and cars under your path are nudged aside. Every checkpoint gate still counts. Starting it shrugs off a System Override |
| System Override | Rare (3rd–8th). A red hacking pulse hits **every racer ahead of you** at that moment. Nobody behind you is touched | Hacked for a time set by **their** position when it fires: 1st 12 s, 2nd 10.5 s, 3rd 9 s, 4th 7.5 s, 5th 6 s, 6th 4.5 s, 7th 3 s (`duration_by_position` in `resources/weapons/system_override.tres`), so the leader suffers most. −25% top speed, −30% acceleration, drift charge lost and no charging while hacked; steering and weapons still work. Red arcs crawl over the car. A repeat hit does nothing |

- **Targeting** (GDD §6.2):
  - With a Railgun or Hunter Drone selected, the nearest eligible opponent in a 40° cone ahead is targeted, preferring racers ahead of you in the race.
  - A reticle shrinks onto them and locks after 0.4 s.
  - A lock survives 0.6 s without line of sight.
  - You never target yourself, and finished racers can't be targeted.
- **Status rules** (`StatusEffects`, GDD §6.5):
  - Hard stuns (stun / stagger) take away control, scrub speed, and spin the bodywork as a visual.
  - When a hard stun ends, the racer is protected from further hard stuns for 1.5 s.
  - A Firewall blocks the next attack of any kind except a Hunter-Killer, which goes straight through it.
  - A landed Railgun or Hunter Drone hit knocks out the victim's selected weapon (or the other one if that slot is empty). Hits blocked by a Firewall or stun protection cost nothing.
- **Self-effects** (GDD §6.4): only the Road Spike can hit its owner, and only after a 1 s grace period. Everything else ignores its owner.
- **Crate odds** depend on race position (GDD §6.5). Each weapon has a percent chance per position (`WeaponData.position_chance`, 1st to 8th), and a crate makes one pick from those. Leaders get weak and defensive items: Road Spikes only drop for 1st–3rd and Firewalls only for 1st–5th. Odds climb toward stronger items further back, and 7th–8th mostly get Overdrive, System Override and Triple Nitro.
- **Advanced weapons** (`docs/Cyberwave_2199_Advanced_Weapons.md`): the three rare items (`WeaponData.rare`) never drop for 1st and 2nd.

  | Weapon | 1st–2nd | 3rd–4th | 5th–6th | 7th–8th |
  |---|---:|---:|---:|---:|
  | Railgun | 12% | 12% | 10% | 8% |
  | Hunter Drone | 8% | 12% | 15% | 14% |
  | EMP Pulse | 8% | 9% | 9% | 8% |
  | Road Spike | 24% | 14% | 7% | 3% |
  | Nitro Overload | 12% | 14% | 15% | 15% |
  | Triple Nitro | 3% | 5% | 8% | 12% |
  | Triple Spike | 10% | 6% | 3% | 2% |
  | Firewall | 23% | 18% | 13% | 7% |
  | Hunter-Killer | 0% | 3% | 5% | 5% |
  | Overdrive | 0% | 2% | 6% | 10% |
  | System Override | 0% | 5% | 9% | 16% |

  With fewer than 8 racers, positions are spread over the same rows. **Counters:**
  - A Firewall soaks a System Override (and is used up). It does nothing against a Hunter-Killer.
  - An active Overdrive ignores every attack.
  - The Hunter-Killer joins the INCOMING warning. AI rivals try the Nitro dodge against it.
  - The target also gets a "HUNTER-KILLER LOCKED" banner during the 1.2 s warning.
  - Icons:
    - The drone and Overdrive icons are crops of the concept art in `reference files/Weapons concept_art/`.
    - System Override's is a symbol (a hacked chip split by a glitch bolt), drawn as SVG.
    - Regenerate them with `tests/tools/make_weapon_icons.gd`.
- **HUD:**
  - two item squares with number badges 1 and 2, under the minimap (bottom right; top right in split-screen views), showing each weapon's picture (`assets/ui/weapons/`). Triple items show their charges (x3, x2, x1). Picking an item up flashes the slot and pops the icon in; using one puffs it out
  - a **minimap** in the bottom-right corner (GDD §11.5): the circuit (muted purple), shortcuts (dimmer), the white start line, the elimination gate in Elimination, every racer as a dot in their colour (ringed when near you), and you as a cyan arrow pointing your heading
  - under the slots: lock status, your active effects (with timers, e.g. JAMMED), and hit / pickup / "LOST …" notices
  - a flashing INCOMING warning when someone has locked on to you or a drone is chasing you
  - short tones for pickup, hit, getting hit, blocked and incoming
- **AI** score each weapon for the moment: fire when locked, EMP when someone is close, drop spikes on a racer behind, Nitro on long straights (one burst at a time), and raise a Firewall when attacked. They launch a Hunter-Killer after a short beat, a System Override when two or more racers are ahead, and an Overdrive once they're on the ground. Difficulty sets reaction time and reliability; personality sets how long they hold weapons.
- **Weapons on/off** is the **Items** toggle on race setup (the `weapons_enabled` setting on the `Race` node when `race.tscn` runs directly).
- **Item loss on recovery:** see Recovery.

## Project layout

```
project.godot                Main scene: scenes/boot.tscn (loading splash, then the title menu)
scenes/
  boot.tscn                  Loading splash with progress bar
  menu/                      title_menu, main_menu, race_setup, cup_select, track_select, garage,
                             settings_menu, credits, multiplayer_connect / _cars / _setup
  race/race.tscn             The race (RaceManager + track + cameras + HUDs); F6 runs a Versus race
  free_drive.tscn            Practice sandbox (one car, no race rules)
  tracks/*.tscn              13 race tracks + test_circuit.tscn (layout, shortcuts, features, scenery, environment)
  vehicles/placeholder_car.tscn  The shared car: body, 4 raycast wheels, drift / recovery / feedback
scripts/
  core/                      Static services: GameSession, GameSettings, InputSetup, Music, SaveUtil, boot
  vehicles/                  VehicleController (suspension, drive, grip), DriftController, VehicleRecovery,
                             RecoveryEffect, VehicleFeedback, VehicleTrick, OverdriveController, SlipstreamRing,
                             VehicleStats / VehicleData / VehicleCatalog, CarModelBuilder + CarDesigns, VehicleCosmetics
  race/                      RaceManager, RaceProgress, RaceConfig, Championship, GrandPrixData, EliminationTracker,
                             Slipstream, StartLaunch (rocket start), SplitScreen, WrongWaySign, RacerProfile, RivalRoster
  combat/                    WeaponManager, WeaponData, ItemInventory, TargetingSystem, StatusEffects, CombatSfx,
                             railgun_shot, hunter_drone, hunter_killer_drone, road_spike, emp_blast, weapon_crate
  ai/                        AIController, AICombat, RacingLine, AIDifficulty
  camera/                    ChaseCamera, CameraProfile, SpectatorCamera
  track/                     TrackCircuit, TrackShortcut, TrackFeature, RecoveryZone, TrackScenery, TrackCatalog,
                             FlickerLight, one <Track>Scenery per track
  track/scenery/             Reusable builders: SceneryTerrain, TreeBuilder, BambooBuilder, TunnelBuilder, HallBuilder,
                             CaveShellBuilder, GlasshouseBuilder, SupertreeBuilder, TerraceBuilder, IncaBuildingBuilder,
                             IncaGateway, PointedArch, HypostyleHallBuilder, SwahiliHouseBuilder, WoodenCoaster,
                             ChainLinkFence, GlbProp (merges a Blender .glb into one mesh)
  ui/                        UIStyle, Neon* widgets, StartMenuLayout, MenuStreetScene, CarShowcase, VehiclePreview,
                             CupBadge, TrackCard, Minimap, PauseMenu, LoadingScreen, PhysicsDebugOverlay (F3), ...
  ui/hud/                    RaceHUD parts: race_info_panel, standings_panel, speed_drift_panel, item_slots,
                             announcer, slipstream_banner, neon_results_screen, results_screen
  ui/podium/                 PodiumCeremony, PodiumStage
  menu/                      One script per menu scene, plus CupBoard and DeviceInput
  progression/               PlayerProfile, CosmeticCatalog, CosmeticItem, RaceRewards, TrackCoins
resources/
  vehicles/                  The eight cars (+ stats/)
  weapons/*.tres             The eleven weapons: durations, speeds, position_chance odds
  ai/easy|normal|hard.tres   AI difficulty (speed, drift, shortcut, trick and rocket-start odds)
  grand_prix/*.tres          The five cups (listed in GrandPrixData.CUPS)
  cameras/                   Far chase, close chase, rear view
  racers/rival_roster.tres   The seven rivals
  ui/cyberwave_theme.tres    Project theme (Rajdhani)
assets/                      shaders/, fonts/, logo/, ui/ (weapon icons, track pictures), textures/polyhaven/, sky/
models/                      Blender .glb props for tracks (Y-up, metres), loaded with GlbProp
music/, sounds/              Audio (music/web/ holds the .ogg copies for the web build)
tests/                       Headless suites (below) and tools/ (screenshot, car_showroom, track_cards, perf_probe, ...)
docs/                        GDD, this reference, physics guide, advanced weapons, recovery, drifting notes
web/                         The exported browser build (GitHub Pages)
dev/                         The dev tracker site (GitHub Pages)
```

### Architecture notes

- **Vehicle physics** (`VehicleController`, a RigidBody3D) are shared and configured with a `VehicleStats` resource (GDD §14.3).
  - Four `RayCast3D` wheels apply spring/damper forces.
  - Drive, lateral grip and yaw shape the body's velocity directly in `_integrate_forces`. This gives arcade handling and keeps the car from rolling over in corners.
  - A low centre of mass and a gentle upright assist (on the ground and while truly airborne) resist flipping.
  - AI drive the same car: `AIController` sets `player_controlled = false` and writes `throttle_input`, `steer_input` and the drift buttons. Difficulty never changes car stats (GDD §7.2).
- **Drifting** (`DriftController`) is pure logic, fed by the vehicle each physics step, so it is unit-testable. Its signals drive the HUD and effects.
- **Recovery** (`VehicleRecovery`) keeps `last_safe_offset` (distance along the track). It only accepts a forward move if the car actually travelled about that far (+15 m slack), so teleports and shortcuts never count, but missed updates (airborne, scraping a wall) do. It works the same for AI cars. `total_progress` feeds the free-drive lap timer; races use checkpoints.
- **The racing line** (`RacingLine`) is built once per race and shared by every AI driver:
  - A shortest-path pass cuts the corners, then a minimum-curvature pass rounds off the apexes.
  - A safe speed is computed for every point from the car's handling, with a braking pass so the AI slows before corners.
  - Drift corners are stretches whose turn rate suits a drift (at least 0.6 rad/s) and that last long enough to earn at least Cyan.
- **AI drivers** (`AIController`):
  - steer toward a point ahead on the line, and track the line's speed scaled by difficulty and personality,
  - pull out to pass slower cars and ease away from cars alongside,
  - roll per corner whether to drift, using the difficulty's drift chance times the rival's drift tendency.
  - Rubber-banding only adjusts the AI's target speed (Easy mild, Normal minimal, Hard none).
- **The track** (`TrackCircuit`, `@tool`) generates everything from a closed loop of control points (a Catmull-Rom curve). It runs in the editor too, so the layout is visible there.
  - Generated nodes are prefixed `_Gen` and are not saved, so edit the exported values instead.
  - It also builds the checkpoint gates (Area3D, emitting `checkpoint_crossed`), defines the grid slots, and exposes `get_offset_at`, `get_safe_transform`, `wrapped_delta` and related helpers.
- **Blender props** go in `models/` as `.glb` (Y-up, 1 unit = 1 m). A track's scenery loads one with `GlbProp.merged(path, skip, tint)`. That bakes every object in the file into one mesh, with a surface per material, so thousands of leaves and scraps cost one draw call per material. The result is cached, so rebuilding the track reuses it. `skip` leaves out objects by name prefix (e.g. a ground plane the terrain replaces), and `tint` dims the model's colours to suit the track's light. `overrides` swaps materials by their Blender name. Procedural node materials (noise, colour ramps) export to glTF as plain white, so the track stands its own textured materials in for them (`SixFlagsScenery.BUMPER_CARS_MATERIALS`). Baking them to image textures in Blender before export would carry the real look across instead. Re-exporting from Blender is all it takes to update one: keep the file name, and move or rotate it in the track's scenery script.
- **Collision layers:** 1 = environment, 2 = vehicles. Wheel rays only hit the environment, so cars never "drive" on each other.
- **Camera choice** is stored in `user://settings.cfg` (`[camera] profile_index`), next to `GameSettings`' own sections.
- **Static services:** `GameSession`, `GameSettings`, `PlayerProfile`, `CosmeticCatalog` and `VehicleCatalog` are static classes that load on first use, not autoloads. That keeps every scene runnable on its own and works with `godot -s` test scripts.

## Running the headless checks

```
godot --headless --import                                   # first run / after adding scripts
godot --headless --fixed-fps 60 -s res://tests/test_phase1.gd
```

Swap in any suite:

| Suite | Covers |
|---|---|
| `test_phase1.gd` | Driving, drifting, cameras, recovery (free-drive scene) |
| `test_phase2.gd` | Checkpoints, standings, grid, countdown, full AI races |
| `test_phase3.gd` | Combat: inventory, crates, targeting, status rules, a full race with weapons |
| `test_phase4.gd` | Versus, Grand Prix save / resume, Elimination (~6–10 min; run alone) |
| `test_phase5.gd` | Menus, garage, shop, coins, rewards, saving, settings, rebinding |
| `test_phase6.gd` | Car models, track layouts / shortcuts / features, full track races (run alone) |
| `test_vehicle_physics.gd` | Raycast suspension, wheel cache, landing stabiliser, jumps |
| `test_drift.gd` | Drift charge rates, hop, grip recovery |
| `test_start_boost.gd` | Rocket start: timing window, boost, burnout, revving, AI odds |
| `test_weapons_advanced.gd` | Hunter-Killer, Overdrive, System Override: odds, counters, AI use |
| `test_recovery_items.gd` | Which recoveries clear the item slots |
| `test_weapon_sfx.gd` | Weapon and barrier sounds |
| `test_race_end.gd` | Last-car classification, projected times, DNF |
| `test_boost_patterns.gd` | Boost-pad patterns: single, diagonal, triangle, same layout every load |
| `test_podium.gd` | Podium ceremony timeline |
| `test_slipstream_ring.gd` | Slipstream ring |
| `test_multiplayer.gd` | Split screen: devices, views, setup screens |
| `test_pad_menus.gd` | Gamepad navigation in menus, pause, podium, results |
| `test_ui.gd` | Fonts, HUD panels, results, layout at two HUD scales, credits coverage |
| `test_audio.gd` | Music per screen / track, crossfades, countdown, web copies |
| `test_quinta_normal.gd`, `test_vale_da_lua.gd`, `test_choquequirao.gd`, `test_kilwa_kisiwani.gd` | Per-track layout, shortcut and scenery checks |

**Track outlines:** menu cards, the loading screen and results draw each track's outline from `resources/ui/track_outlines.tres` (`TrackOutlines`). This way the menus never load whole track scenes; loading them froze the track screen on the web build. After moving a track's control points or adding a track, rebake with `godot --headless --path . -s res://tests/tools/bake_track_outlines.gd`. `test_ui.gd` fails while the baked copy is out of date.

The render scripts in `tests/tools/` take real screenshots, so they need a display (run them without `--headless`). For example, `godot --path . -s res://tests/tools/car_showroom.gd -- user://cars front` renders every car, and `SHOT_TRACK=res://scenes/tracks/vegas_overdrive.tscn SHOT_AUTOPILOT=1 SHOT_EVERY=600 godot --path . --fixed-fps 60 -s res://tests/tools/screenshot.gd -- res://scenes/race/race.tscn user://lap.png 6000` saves a screenshot every 10 s of an autopilot lap.

Every suite uses its own `user://test_*` save files, so running them never touches your profile, settings or Grand Prix.

`--fixed-fps 60` runs the physics as fast as the machine allows (about 2.5× faster than real time here), which matters for the simulated races. Phases 1–3 take 40–90 s each here. Phase 4 takes about 6 minutes: it runs a Versus race, three Grand Prix races (shortened to 1 lap each) and a full Elimination event. It writes a temporary save (`user://test_phase4_gp.json`), never your real one.

Phase 1 covers:
- drift thresholds and rules (pure logic),
- input bindings,
- track queries,
- spawning and settling,
- acceleration, braking and reverse,
- steering direction,
- a simulated drift reaching Gold and boosting,
- camera cycling and placement,
- manual reset and the anti-shortcut rule,
- overturned, stuck and out-of-bounds recovery,
- a scripted lap and Shift + A/D drifting with real key events.

Phase 2 covers:
- checkpoint order and lap logic (pure logic),
- standings order,
- grid layout (8 cars, you last, nobody overlapping, all behind the line),
- countdown lock and GO,
- teleporting past gates not counting,
- the wrong-way warning,
- a full 3-lap race with 8 AI drivers, checking that every gate is counted, finish order matches standings, live positions agree with an independent distance measure, and the results screen appears,
- AI earning drift boosts on a test oval.

Phase 3 covers:
- inventory rules, status rules, stun protection, Firewall, crate odds by position, and targeting priority (pure logic),
- crates (collect, full inventory, respawn) and the 1/2/Space keys with auto-select,
- the Railgun lock timing and hit,
- the drone finding a target without a lock,
- the EMP's radius, that it never hits its owner, and that weapons stay jammed for 5 s without being lost,
- Railgun and drone hits knocking out the selected item, and blocked hits or Road Spikes costing nothing,
- the HUD layout: item slots top right, race info top left with the standings below, bottom-right corner clear,
- the Road Spike's owner grace period, then hitting its owner and an opponent,
- the Nitro boost, Firewall blocking, a stunned car losing control, and the protection window,
- finished racers being out of combat, and weapons switching off,
- a full race with weapons: everyone finishes, every gate is counted, and every weapon type is used and lands hits.

Phase 4 covers:
- the points table, both tiebreak rules, and the next grid following the previous result (pure logic),
- championship save / load of every saved field, a completed championship not being offered, and clearing the save,
- elimination rules: only the gate counts, double crossings and wrong-lap crossings don't, and the last two are out as each quota fills (pure logic),
- Triple Nitro charges in the inventory, and three separate boosts in a race,
- the mode select screen building the right race settings, saving a new Grand Prix, and offering Continue,
- the pause menu: Esc stops the timer and the cars, Esc again resumes,
- a full Versus race and its results buttons,
- a 3-race Grand Prix, continued from the save after race 1: grids, rival identities, 58 points per race, one save per race, no restart after a saved result, and final standings,
- a full Elimination event: 2 out at each of the three midpoints, nobody who qualified eliminated, positions 1–8, eliminated cars gone, and results shown.

Phase 5 covers:
- the catalogue (8 categories, one free starter each, GDD prices),
- the profile: buying (not enough coins, twice, then success), equipping only owned items, per-car looks, plate rules, personal bests, newly affordable items, and everything surviving a "restart" (reloading from disk),
- save safety: corrupt and unknown-version files, no leftover temp file, and recovery from an interrupted swap,
- the reward rules, including eliminated and Grand Prix wins,
- the eight vehicles: GDD names, the stat band, no car better in all four stats, Empyrean fastest and Nexus quickest,
- settings and rebinding: keyboard and gamepad rebinds, surviving a restart, audio buses and volumes, stick directions, and reset,
- HUD scale keeping full-screen controls on screen, and every cosmetic actually appearing on the car (and being replaced when changed),
- the menus: main menu entries, garage buy / try-on / plate / per-car loadout, race setup remembering choices within a session, and rebinding through the Settings screen (including the conflict note and the timeout),
- in races: your car's stats and plate, AI plates (random per series, kept through a Grand Prix and its save), coins (only you collect, respawn, the 30 cap), camera shake, reduced flashing, motion blur, a chosen car's stats,
- a finished race paying once and saving, with the results showing coins and personal bests, and a Grand Prix race recording its coins in the championship and refusing a replay.

The exit code is non-zero if anything fails. These checks do **not** judge how the game looks or feels.

## Credits

- **Game:** Cyberwave 2199 by Nathan Hobbs.
- **Music:** see the Audio table above (ikoliks_aj, ikoliks, alex-morgan, Lilex, TheBoysBeats, SPmusic, kulakovka, Ob-Lix, ed-musicproductions, sonican, elisaveta_stoycheva, theorienvibes, restum-anoush, DesiFreeMusic, vishiv, Jean-Paul-V, stageechoesmusic).
- **Sound:** Short beep countdown, Shield drop, Electric zap 001, Crowbar drop 1 (rear), Planks clattering and Missile lock detected by freesound_community; Sci-fi energy shield activation by vadim_makes_sound; Electrical current 2 by 49053354; Sci-fi weapon shoot firing pulse TM 05 by rescopicsound; Field: launching a small model rocket by fronbondi_skegs; Missile explosion by voicebosch.
- **Fonts:** Oxanium and Rajdhani, SIL Open Font License 1.1 (`assets/fonts/`).
- **Engine:** Godot Engine, MIT License.

The in-game Credits screen (`scripts/menu/credits.gd`) shows the same list.

Environment textures and the track skies are from [Poly Haven](https://polyhaven.com) (CC0, public domain): asphalt_track, concrete_panels, brushed_concrete, metal_plate_02, palm_tree_bark, snow_02, snow_floor, rock_face, worn_rock_natural_01, bark_brown_02, white_plaster_rough_01, dark_rock, dark_rock_02, rock_ground, road_damaged, rust_coarse_01, rusty_metal_02, rusty_corrugated_iron, concrete_moss, dirty_concrete, peeling_painted_wall, wood_peeling_paint_weathered, distressed_painted_planks, brown_mud_leaves_01, bark_willow, dirty_tiles, painted_worn_brick, withered_grass, sparse_grass, marble_01, herringbone_parquet, velour_velvet, monastery_stone_floor, forest_ground_04, forest_leaves_02, pine_bark, red_sandstone_wall, mossy_rock, old_stone_wall, large_sandstone_blocks, cobblestone_floor_08, pavement_01, reed_roof_04, hinoki_planks, dry_decay_leaves, mossy_stone_wall, and the kloofendal_overcast_puresky, kloofendal_48d_partly_cloudy_puresky, qwantani_sunset_puresky and misty_pines HDRIs. They live in `assets/textures/polyhaven/` (colour, normal and roughness at 1K) and `assets/sky/`.

## Status and known issues

As of 2026-11-13 (GDD v7.4). Phase 6, content and polish, is in progress. The [dev tracker](https://nahobbs5.github.io/CyberWave-2199/dev/) holds the live milestone status.

- **Content built:** 15 race tracks in 5 cups (all open for Grand Prix) plus the Test Circuit, 8 cars, 11 weapons, 7 named rivals, split screen for 2–4 players, podium, music on every track.
- **Weapons:** Railgun, Hunter Drone, EMP Pulse, Road Spike, Nitro Overload, Triple Nitro, Triple Spike, Firewall, Hunter-Killer Drone, Overdrive Protocol and System Override. The GDD §6.3 roster's Holo Decoy, Gravity Mine, System Glitch, Cyber Leech and Swarm Bots are not built.
- **Known failing checks** (they failed before the latest work):
  - `test_phase3`: "every racer crossed every gate despite weapons" (also fails with the pre-v7.4 crate odds; cause not yet checked);
  - `test_weapons_advanced`: System Override "victim's top speed is cut by 25%" and "hacked car accelerates slower" (also fail with the pre-v7.4 odds);
  - `test_phase6`: Arashiyama "shortcut is shorter" and "every gate counted on the shortcut".
- **Running tests:** run `test_phase4` and `test_phase6` on their own. Parallel runs slow the track builds past the build-time limit, and suites that share a save file can clash.
- **Screenshots from the dev container are software-rendered** (Compatibility / lavapipe). Forward+ on Windows shows stronger glow, fog and reflections.
- **Split screen hasn't been played with real gamepads** on the heaviest tracks (the Hoia forest, Arashiyama bamboo); four views there may be slow.
- **Balance is ongoing:** vehicle stats, AI pace (`speed_factor` in `resources/ai/*.tres`), crate odds, System Override durations, rocket-start odds and coin prices are all playtest-driven (GDD §18).
- **Car models are stylised low-poly** built from code. Any car can take a `.glb` instead (see Vehicle models).

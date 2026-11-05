# CyberWave-2199

Single-player 3D arcade combat racing game for Godot 4 (GDScript, Jolt Physics).
The authoritative design is [`docs/Game Design Document.md`](docs/Game%20Design%20Document.md) (GDD v1.7).

**Current milestone: Phase 6, content and polish** (GDD §16), in progress. Done so far:
- **Eight vehicle models**, built procedurally after the roster art, with support for swapping in your own `.glb` models,
- **Six Flags New Orleans**, the second finished track: an abandoned, overgrown theme park at night with real jump ramps, flooded water patches and a water-park shortcut,
- **Vegas Overdrive**, the first finished track: a 3.2 km neon circuit with themed scenery, the Luxor shortcut, boost pads and rings, EMP puddles, a smashable barrier and chevron signs,
- **weapon pictures** in the HUD slots and a **minimap** in the bottom-right corner,
- the track tech the other five tracks will reuse: shortcuts, track features, batched scenery and per-track looks.

Still to come in Phase 6: the other five tracks, the remaining weapons, named rivals, sound and music (your files in `sounds/` aren't wired in yet), race presentation, optimisation and balancing.

Phases 1–5 are unchanged apart from the models.

Open the project in Godot 4.7 and press **F5** for the main menu (`scenes/menu/main_menu.tscn`).
Running `scenes/race/race.tscn` directly (**F6**) still starts a Versus race using the `Race` node's Inspector settings and your selected car.
**Free drive (practice)** on the main menu opens the Phase 1 sandbox (`scenes/free_drive.tscn`) with your car; Esc returns from it.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Accelerate | W / Up | RT / R2 |
| Brake / Reverse | S / Down | LT / L2 |
| Steer | A / D, Left / Right | Left stick |
| Drift | Hold Shift + A / D | LB / L1 (left), RB / R1 (right) |
| Cycle camera (Far ↔ Close) | C | View / Touchpad |
| Reset vehicle | R | Y / Triangle |
| Select weapon slot 1 / 2 | 1 / 2 | D-pad Left / Right |
| Use selected weapon | Space | A / Cross |
| Pause menu | Esc | Start / Options |
| Menu buttons | Enter, mouse, arrow keys | A / Cross, D-pad |

Arrow keys are an extra convenience on top of the GDD's bindings. Space doesn't press menu buttons, so firing
weapons as you cross the line can't skip the results screen. The results buttons also wait 1.5 s before they respond.

Every gameplay action can be rebound in **Settings → Controls** (keyboard and gamepad separately; see below).
Actions are registered at startup by `scripts/core/input_setup.gd`. Any action you define in
**Project Settings → Input Map** with the same name takes priority over the defaults (your Settings rebinds still apply on top).

### Drifting

- At speed (over 12 m/s, about 43 km/h), hold **Shift** and steer with **A** or **D**. The steering direction when the drift starts picks left or right; after that, keep Shift held and steer to shape it (into the drift tightens it, against it widens it). Shift while driving straight does nothing.
- Shift drifting replaced the original Q/E binding in GDD v1.1 (see its Revision History).
- Charge only builds while the car is grounded and sliding sideways.
- **Cyan** at 1 s, **Magenta** at 2.5 s, **Gold** at 4 s of valid drifting.
- **Releasing** Shift (or the bumper) fires the boost. Higher levels give more speed for longer.
- Leaving the ground pauses charging. Staying airborne for more than 1.5 s, hitting something hard, or slowing well below drift speed cancels the drift with no boost.
- Feedback: rear-wheel sparks and an undercarriage glow in the current level's colour, a tone for each level, exhaust flames and a FOV kick while boosting, and the HUD charge bar.

### Recovery

- **R** (or gamepad Y) resets you to the last point on the track you legitimately drove through, about 6 m behind it, upright and stopped. Resets can never move you forward, so they can't be used as shortcuts.
- Automatic recovery happens when the car is:
  - upside down or on its side for 1.5 s,
  - stuck (pressing throttle or brake while barely moving forward or back; sliding sideways along a wall counts as stuck) for 3 s,
  - below the world, or
  - outside the circuit (more than 3 m past the road edge, i.e. beyond the barrier) for 1 s, or
  - making no progress: trying to drive but gaining less than 15 m along the track in 8 s (catches a car rocking back and forth against a wall, which never looks "stuck").
- The respawn spot is checked for other vehicles and shifts sideways or back if it is occupied.

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

- **Grid:** seven AI rivals fill slots 1–7 and you start last (GDD §2.1). Controls are locked during READY / SET / GO; there are no false-start penalties.
- **Checkpoints:** 8 evenly spaced gates, with gate 0 at the start/finish line. A gate only counts if it is the next one in order. Skipping ahead, reversing through gates, or a recovery teleport never adds progress. Crossing the line after every gate completes a lap.
- **Positions** are live: finishers in finishing order, everyone else by distance raced since their last valid gate.
- **When you finish,** the results screen shows the standings and fills in as the AI cross the line. Your car switches to autopilot.
- **HUD:** position, lap, race time, live standings, lap/finish banners and a WRONG WAY warning. Speed and drift charge are as before.
- **AI difficulty, laps and weapons** come from the mode select screen. When `race.tscn` is run directly, they come from the `Race` node in the Inspector instead (`difficulty`, `total_laps`, `weapons_enabled`).

### Game modes

All races use the test circuit for now. Grand Prix races carry the real track names, and each championship's
track list is data (`resources/grand_prix/*.tres`), so the Phase 6 tracks can be dropped in.

- **Versus** (GDD §2.1): one race, you start eighth. When you finish, the results fill in as the AI cross the line. **Race again** or **Quit to mode select**.
- **Grand Prix** (GDD §2.2): *American Circuit* or *World Circuit*, three races of three laps each.
  - Points are 15-12-10-8-6-4-2-1. Ties are broken by most wins, then most second places, then the order in the most recent race.
  - Race 1 starts the seven rivals in slots 1–7 with you last. Each later grid is the previous race's finishing order, not the points order. Rivals keep their names, colours and personalities all season.
  - **The race result is fixed when you cross the line:** anyone still racing is classified in their current order. That way you never have to wait for the field, and the points always match what the results screen shows.
  - The results screen shows your race points and the championship standings, then **Next race**. After race 3 it shows the final standings with the champion highlighted.
  - **Saving:** the championship is saved to `user://grand_prix_save.json` when it starts and after every race. If you quit midway, **Continue Grand Prix** appears on the mode screen. The save holds the championship, results, points, next grid, vehicle, rival identities, settings and a coins field (coins are Phase 5). It's deleted once the championship is complete. Starting a new Grand Prix replaces it.
  - **Restart race** (pause menu) replays the current race, but only until you finish it: once the result is saved it can't be rerolled.
- **Elimination** (GDD §2.3): always three laps.
  - A red **ELIMINATION** arch marks checkpoint 4 (the lap midpoint).
  - On each lap, racers qualify in the order they cross it: 6 on lap 1, 4 on lap 2, 2 on lap 3. The moment the last place is taken, everyone else still racing is out. There's no timer, and the start/finish line never eliminates anyone.
  - Eliminated cars stop colliding with active racers and stop fighting at once, then shrink away and disappear. Their positions are 7–8, 5–6 and 3–4, ordered by how far they'd got.
  - The first finalist across the line wins, and the other is classified second.
  - HUD: active racers, the next elimination, places left, your distance to the gate, a QUALIFIED banner when you get through, and an "X ELIMINATED" feed. If you're knocked out, the camera follows the leader and the results appear.
- **Pause menu** (Esc / Start): the whole race stops (physics, timers, AI). It offers **Resume**, **Restart race** and **Quit to mode select**.

### Menus

- **Main menu** (GDD §11.2): Continue Grand Prix (only when one is saved), Versus, Grand Prix, Elimination, Garage, Settings, Free drive (practice), Exit.
- **Race setup** (GDD §11.3): track (only the test circuit for now) or championship, vehicle picker with a rotating preview of your car (paint, cosmetics and plate), stats, AI difficulty, laps (Versus), weapons on/off, Start race. It remembers your last choices and shows your personal best (Versus) or best championship finish (Grand Prix).
  - **A Grand Prix keeps the car you started it with** for all three races (the GDD saves the player vehicle with the championship).
- **Garage** (GDD §11.4): rotating preview, vehicle stats, license plate editor, the 8 cosmetic categories, your coin balance.
  - **Click an item's name** to try it on. **Buy** spends coins and equips it; **Equip** puts an item you own on this car. Purchases are permanent and shared by all cars, but **each car has its own equipped look**.
  - The **license plate** is one text for every car: up to 8 characters (letters, digits, spaces, dashes), saved as you type.
- **Settings** (GDD §11.9): every change applies and saves immediately.
  - **HUD scale** 75–150%, **motion blur** (off by default; a subtle edge blur at high speed and during boosts, the centre stays sharp), **camera shake** 0–100% (impacts, stuns, boosts), **reduced flashing** (the INCOMING warning stays steady instead of blinking; weapon flashes, status lights and the lock reticle are calmer).
  - **Audio:** Master, Music and Sound effects. There's no music yet, so the Music slider has nothing to control until Phase 6.
  - **Controls:** press a binding, then the new key, gamepad button or stick direction within 5 seconds. A rebind replaces all of that action's keyboard inputs (so W + Up becomes just your new key) or all of its gamepad inputs. If another action already uses that input, you get a note (both keep working). **Reset controls to defaults** undoes all rebinds.
  - HUD scale and motion blur take effect from the next race.

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

Speeds are m/s, acceleration m/s², handling and drift rad/s. The AI rivals all drive the V8 Specter model and stats (so the racing line and AI pace stay as tuned), each in their own colour. Rival license plates are random (like `KRX-417`), rolled once per series: they stay the same through Race again / Restart in Versus and Elimination, and for a whole Grand Prix (saved with it). Your plate defaults to `CW-2199` until you change it in the Garage.

#### Vehicle models

`CarModelBuilder` lofts each body and cabin through cross-section stations listed in `scripts/vehicles/car_designs.gd`, then adds detail parts (grilles, light bars, wings, fins). Edit a design there to reshape a car (the format is explained at the top of that file). The meshes are cached, so eight cars on the grid share geometry.

To use **your own model** for a car, import it (`.glb`) and set it as `model_scene` on that car's `resources/vehicles/<car>.tres`. It replaces the procedural model; anything it doesn't provide falls back gracefully. Conventions:
- **Orientation and scale:** metres, +Y up, the car's nose toward **−Z**, origin at the body centre (matching the 1.9 × 0.55 × 4.2 m collision box).
- **No wheels in the model:** the game's wheels sit at x ±0.85, z ±1.35, radius 0.38 and move with the suspension.
- **Paint:** every mesh whose name starts with `Paint` gets the player's paint and finish. Other meshes keep their imported materials.
- **Optional anchors** (empties or `Marker3D`, named exactly): `PlateAnchor` (rear plate, facing +Z), `DecalL` / `DecalR` (door decals), `ExhaustL` / `ExhaustR`, and meshes `NeonL` / `NeonR` for the underglow strips.
- **Stripes** only work on the procedural models; imported models skip them.

### Coins and cosmetics

- **Track coins** (GDD §9.2): 10 gold coins per lap on the test circuit, in pairs on the straights a few metres off the racing line. Only you collect them (on contact); they come back every lap, the cap is 30 per race, and getting hit never costs any. The HUD shows a coin counter.
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

### Audio

| Where | Sound | File |
|---|---|---|
| Main menu, race setup, settings | Main theme (loops) | `music/ikoliks_aj-cyberpunk-cyberpunk-music-614562.mp3` |
| Garage | Wings of Hope (loops) | `music/ikoliks-wings-of-hope-no-copyright-music-background-corporate-380579.mp3` |
| Race start | Countdown beeps on READY / SET / GO | `sounds/freesound_community-short-beep-countdown-81121.mp3` |

Music carries across menu screens without restarting and crossfades when the track changes (`scripts/core/music.gd`); races and free drive have no music yet, so it fades out when one starts. The countdown clip has four beeps a second apart; it starts 1 s in so the last three land on READY, SET and GO. Music plays on the Music bus and effects on the SFX bus, so the Settings sliders control each. Tracks by ikoliks / ikoliks_aj and freesound_community.

### Tracks

The race setup screen lists **Six Flags New Orleans**, **Vegas Overdrive** and the **Test Circuit**. In a Grand Prix, American Circuit races 2 and 3 are Six Flags and Vegas; the other Grand Prix races still run on the test circuit under their real names until those tracks are built.

#### Six Flags New Orleans (GDD §8.2)

A 3.1 km circuit through an abandoned, overgrown amusement park at night, on an 18 m road (narrower than Vegas):
- **Park Entrance:** start/finish under a decaying "SIX FLAGS / NEW ORLEANS" arch with a fleur-de-lis, a purple Ferris wheel and a drop tower on the skyline.
- **Midway:** tight S-bends lined with game booths (striped awnings, glowing stall signs) and a carousel.
- **Coaster Run:** a long straight beside a red roller coaster (lift hill, loop, a crossing high over the road), with a **jump ramp** halfway.
- **Water Park:** the main road loops around the park; the **water-park shortcut** cuts straight through it past the slide tower and pools: a smashable fence at the entrance, a flooded pool section, a **slide jump** and three bonus coins. It's about 110 m shorter.
- **Backlot:** 90° service-road corners between warehouses ("STAGE 4"), containers and light poles; an EMP puddle (downed power lines).
- **Bayou Outrun:** a plank boardwalk through a swamp of cypress trees and hanging moss, with a **jump ramp** and two **water patches**.
- Rainy purple night with heavier fog; 5 crate rows and 10 coins per lap.

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

#### Track tech (for the next five tracks)

- **`TrackShortcut`** (child of a TrackCircuit): give it control points from one point on the main road to a later one. The circuit builds its road and barriers, opens the main barriers where the two meet, and mirrors any checkpoint gate it bypasses onto it, so laps always count. Positions on a shortcut map onto the main loop proportionally, so race positions, recovery, wrong-way checks and the AI all work on either route.
- **AI shortcuts:** each AI decides once per approach (the shortcut's `ai_chance` × the difficulty's `shortcut_chance` × aggression), then follows the shortcut at its own safe speeds and rejoins the racing line. If it gets pinned while still heading for a shortcut it isn't on (a late turn-in), it gives up and follows the main road.
- **Junction design:** a shortcut should leave at a gentle angle (the Luxor one turns in about 55°). A first version peeled off at nearly 110° and trapped a car in the wedge between the roads.
- **`TrackFeature`**: boost pads, boost rings, EMP puddles, breakable barriers, **jump ramps** and **water**, placed by distance (or near a layout point) on the main road or a shortcut. Every kind is lit and marked so it reads at speed.
  - **Jump ramp:** a solid wedge (`length` × `width`, lip of `ramp_height`) that the wheels drive up. Put them on straights at full road width. On the Coaster Run a car at full speed gets about 1.6 s of air and 4 m of height, and lands on its wheels.
  - **Water:** standing water makes cars **wet**: top speed ×0.88 and grip ×0.75 while in it (and for 0.3 s after), with spray from the rear wheels and "WET" in the effects line. A Firewall doesn't keep you dry; wet stacks with EMP and Road Spike effects.
- **`TrackScenery`**: base class for a track's set dressing (`VegasScenery`, `SixFlagsScenery`), with shared helpers such as `add_ferris_wheel` and `add_palm`. Geometry is merged into a few batched meshes, one per material, and it skips anything that would overlap a road. It builds in the editor too.
- **Look:** road, edge, barrier, neon and light colours are exports on each track, and corners tighter than `corner_sign_radius` get chevron signs automatically.
- Each track scene carries its own sky, fog and lighting (`WorldEnvironment`).

### Weapons

Drive through a "?" crate to collect a random weapon into your first free slot. With both slots full, crates stay in place for someone else. Crates respawn after 3 s, in 5 rows of 4 around the lap.

| Weapon | How it works | Effect on the victim |
|---|---|---|
| Railgun | Targeted. Fast shot aimed at your lock (with lead), else straight ahead | 0.7 s stagger (hard stun); knocks out the selected weapon |
| Hunter Drone | Targeted / guided. Follows the track, then homes in on your lock or the nearest racer ahead | 0.8 s stun (hard stun); knocks out the selected weapon |
| EMP Pulse | Instant 22 m pulse around you | 1.5 s: no drift charging, −15% top speed; weapons jammed (unusable, but kept) for 5 s |
| Road Spike | Strip dropped behind you; lasts 12 s; single use | 1 s traction loss |
| Nitro Overload | Self boost | 3 s, +10 m/s top speed |
| Triple Nitro | Three Nitro charges in one slot (HUD shows ×3, ×2, ×1). Each press is a separate boost; the slot empties after the third | Rare. Mostly for trailing racers. A Railgun or drone hit knocks out all remaining charges |
| Firewall | Shield | Blocks the next attack, up to 10 s |

- **Targeting** (GDD §6.2):
  - With a Railgun or Hunter Drone selected, the nearest eligible opponent in a 40° cone ahead is targeted, preferring racers ahead of you in the race.
  - A reticle shrinks onto them and locks after 0.4 s.
  - A lock survives 0.6 s without line of sight.
  - You never target yourself, and finished racers can't be targeted.
- **Status rules** (`StatusEffects`, GDD §6.5):
  - Hard stuns (stun / stagger) take away control, scrub speed, and spin the bodywork as a visual.
  - When a hard stun ends, the racer is protected from further hard stuns for 1.5 s.
  - A Firewall blocks the next attack, whatever kind it is.
  - A landed Railgun or Hunter Drone hit knocks out the victim's selected weapon (or the other one if that slot is empty). Hits blocked by a Firewall or stun protection cost nothing.
- **Self-effects** (GDD §6.4): only the Road Spike can hit its owner, and only after a 1 s grace period. Everything else ignores its owner.
- **Crate odds** depend on race position (GDD §6.5). Leaders mostly get Road Spikes and Firewalls, while trailing racers get more Hunter Drones and Nitros.
- **HUD:**
  - two weapon slots, top left, showing each weapon's picture from the Weapon Arsenal concept art (`assets/ui/weapons/`; the name is in the tooltip). The selected slot is outlined in magenta, empty slots show only their key number, and Triple Nitro shows its charges (x3, x2, x1)
  - position, lap, time and standings below the slots (moved to the very top when weapons are off)
  - a **minimap** in the bottom-right corner (GDD §11.5): the circuit, shortcuts (dimmer), the start line, the elimination gate in Elimination, every racer as a coloured dot, and you as a magenta arrow pointing your heading
  - beside the slots: lock status, your active effects (with timers, e.g. JAMMED), and hit / pickup / "LOST …" notices
  - a flashing INCOMING warning when someone has locked on to you or a drone is chasing you
  - short tones for pickup, hit, getting hit, blocked and incoming
- **AI** score each weapon for the moment: fire when locked, EMP when someone is close, drop spikes on a racer behind, Nitro on long straights (one burst at a time), and raise a Firewall when attacked. Difficulty sets reaction time and reliability; personality sets how long they hold weapons.
- **Weapons on/off** is the `weapons_enabled` setting on the `Race` node (GDD §2.1).

## Project layout

```
scenes/
  tracks/vegas_overdrive.tscn  Vegas Overdrive (layout, shortcut, features, scenery, environment)
  tracks/six_flags_new_orleans.tscn  Six Flags New Orleans
  menu/main_menu.tscn        Main scene: main menu
  menu/race_setup.tscn, garage.tscn, settings_menu.tscn
  race/race.tscn             8-car race (RaceManager + track + camera + HUDs)
  free_drive.tscn            Phase 1 sandbox (one car, no race rules)
  tracks/test_circuit.tscn   Graybox circuit, environment and moonlight
  vehicles/placeholder_car.tscn  Primitive-mesh car: body, 4 raycast wheels, drift/recovery/feedback
  ui/prototype_hud.tscn      Speed / drift / camera HUD
scripts/
  free_drive.gd              Wires the sandbox scene together
  race/
    race_manager.gd          RaceManager: grid, countdown, checkpoints, positions, finish
    race_progress.gd         RaceProgress: one racer's laps, gates, times
    race_config.gd           RaceConfig: mode, difficulty, laps, weapons, track, grid order
    championship.gd          Championship: Grand Prix points, tiebreaks, grid, save / load
    grand_prix_data.gd       GrandPrixData resource: a championship's three races
    elimination_tracker.gd   EliminationTracker: lap-midpoint qualifying and eliminations
    racer_profile.gd         RacerProfile resource: rival name, colour, personality
    rival_roster.gd          RivalRoster resource: the seven rivals
  combat/
    weapon_manager.gd        WeaponManager: crates, odds, deployment, hits, incoming warnings, reticle
    weapon_data.gd           WeaponData resource (data-driven weapons)
    item_inventory.gd        ItemInventory: two slots, 1/2/Space input
    targeting_system.gd      TargetingSystem: lock-on
    status_effects.gd        StatusEffects: stun / EMP / traction / shield rules and visuals
    railgun_shot.gd, hunter_drone.gd, road_spike.gd, emp_blast.gd, weapon_crate.gd
  ai/
    ai_controller.gd         AIController: steering, speed, drifting, traffic
    ai_combat.gd             AICombat: weapon decisions
    racing_line.gd           RacingLine: precomputed line, safe speeds, drift corners
    ai_difficulty.gd         AIDifficulty resource (Easy / Normal / Hard)
  core/input_setup.gd        Default keyboard and gamepad bindings
  vehicles/
    vehicle_controller.gd    VehicleController: suspension, drive, grip, steering, boost
    drift_controller.gd      DriftController: drift state, charge levels, boost on release
    vehicle_recovery.gd      VehicleRecovery: manual/auto reset, safe-point tracking
    vehicle_feedback.gd      Placeholder drift/boost visuals and generated audio cues
    vehicle_stats.gd         VehicleStats resource (Top Speed, Acceleration, Handling, Drift, ...)
    vehicle_data.gd          VehicleData resource: name, type, stats, placeholder proportions
    vehicle_catalog.gd       VehicleCatalog: the eight cars, stat ratings
    vehicle_cosmetics.gd     VehicleCosmetics: applies the model, cosmetics and plates to the car
    car_model_builder.gd     CarModelBuilder: builds the procedural car models
    car_designs.gd           CarDesigns: the eight car shapes
  camera/
    chase_camera.gd          ChaseCamera: shared controller, collision avoidance, saved choice
    camera_profile.gd        CameraProfile resource (distance, height, FOV, smoothing, ...)
  track/track_circuit.gd     TrackCircuit: builds the circuit and answers track-space queries
  track/track_shortcut.gd    TrackShortcut: an alternate route
  track/track_feature.gd     TrackFeature: boost pads / rings, EMP puddles, breakable barriers
  track/track_scenery.gd     TrackScenery: batched set-dressing base class
  track/vegas_scenery.gd     VegasScenery: the Vegas landmarks and city
  track/six_flags_scenery.gd SixFlagsScenery: the park, coaster, water park, backlot and bayou
  track/track_catalog.gd     TrackCatalog: raceable tracks for the menus
  ui/                        PrototypeHUD, DriftMeter, RaceHUD, Minimap, PauseMenu, UIStyle,
                             VehiclePreview (rotating 3D car), HudScaler, SpeedBlur (motion blur)
  menu/                      MainMenu, RaceSetup, Garage, SettingsMenu
  progression/
    player_profile.gd        PlayerProfile: coins, shop, equip, plate, records, save / load
    cosmetic_item.gd         CosmeticItem resource
    cosmetic_catalog.gd      CosmeticCatalog: every shop item and price
    race_rewards.gd          RaceRewards: coin payout rules
    track_coins.gd           TrackCoins: on-track coin pickups
  core/game_session.gd       GameSession: carries the chosen RaceConfig between scenes, menu navigation
  core/game_settings.gd      GameSettings: settings, accessibility, audio buses, rebinds
  core/save_util.gd          SaveUtil: atomic writes
assets/ui/weapons/           Weapon pictures cropped from the Weapon Arsenal concept art
                             (also the five weapons still to build)
resources/
  vehicles/*.tres            The eight VehicleData resources (V8 Specter uses placeholder_gt_stats.tres)
  vehicles/stats/*.tres      The other seven cars' stats
  cameras/far_chase.tres, close_chase.tres
  ai/easy.tres, normal.tres, hard.tres
  racers/rival_roster.tres   Seven placeholder rivals (edit in the Inspector)
  weapons/*.tres             The six weapons: durations, speeds, odds
tests/
  test_phase1.gd             Driving checks (free-drive scene)
  test_phase2.gd             Race checks, including full simulated races (weapons off)
  test_phase3.gd             Combat checks, including a full race with weapons
  test_phase4.gd             Mode checks: full Versus, 3-race Grand Prix and Elimination events
  test_phase5.gd             Menus, garage, shop, coins, rewards, saving, settings and rebinding
  test_audio.gd              Menu / garage music, crossfades, countdown beep
  test_phase6.gd             Vehicle models, imported models, Vegas layout, shortcut, features, full Vegas races
  tools/screenshot.gd        Dev tool: renders a scene / race to PNG (needs a display, see below)
  tools/car_showroom.gd      Dev tool: renders every car model
docs/                        GDD
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
- **Collision layers:** 1 = environment, 2 = vehicles. Wheel rays only hit the environment, so cars never "drive" on each other.
- **Camera choice** is stored in `user://settings.cfg` (`[camera] profile_index`), next to `GameSettings`' own sections.
- **Static services:** `GameSession`, `GameSettings`, `PlayerProfile`, `CosmeticCatalog` and `VehicleCatalog` are static classes that load on first use, not autoloads. That keeps every scene runnable on its own and works with `godot -s` test scripts.

## Running the headless checks

```
godot --headless --import                                   # first run / after adding scripts
godot --headless --fixed-fps 60 -s res://tests/test_phase1.gd
godot --headless --fixed-fps 60 -s res://tests/test_phase2.gd
godot --headless --fixed-fps 60 -s res://tests/test_phase3.gd
godot --headless --fixed-fps 60 -s res://tests/test_phase4.gd
godot --headless --fixed-fps 60 -s res://tests/test_phase5.gd
godot --headless --fixed-fps 60 -s res://tests/test_phase6.gd
godot --headless --fixed-fps 60 -s res://tests/test_audio.gd
```

The two scripts in `tests/tools/` render real screenshots, so they need a display (run them without `--headless`). For example, `godot --path . -s res://tests/tools/car_showroom.gd -- user://cars front` renders every car, and `SHOT_TRACK=res://scenes/tracks/vegas_overdrive.tscn SHOT_AUTOPILOT=1 SHOT_EVERY=600 godot --path . --fixed-fps 60 -s res://tests/tools/screenshot.gd -- res://scenes/race/race.tscn user://lap.png 6000` saves a screenshot every 10 s of an autopilot lap.

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
- the HUD layout: slots top left, race info below, bottom-right corner clear,
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
- the menus: main menu entries, garage buy / try-on / plate / per-car loadout, race setup remembering choices after a restart, and rebinding through the Settings screen (including the conflict note and the timeout),
- in races: your car's stats and plate, AI plates (random per series, kept through a Grand Prix and its save), coins (only you collect, respawn, the 30 cap), camera shake, reduced flashing, motion blur, a chosen car's stats,
- a finished race paying once and saving, with the results showing coins and personal bests, and a Grand Prix race recording its coins in the championship and refusing a replay.

The exit code is non-zero if anything fails. These checks do **not** judge how the game looks or feels.

## Status and known issues

**Verified (2026-11-05):** 91 Phase 1, 159 Phase 2, 103 Phase 3, 124 Phase 4, 113 Phase 5 and 93 Phase 6 headless checks pass on Godot 4.7.2 (Linux build). On the shortened 3.2 km Vegas Overdrive, a simulated 8-car, 3-lap race with weapons ran 3:54–4:00 (laps about 1:18) with no recoveries, and the AI took the Luxor shortcut 7 times. With every AI forced onto the shortcut, all 8 still finish with every gate counted. On the test circuit, a typical simulated weapons race sees the AI use 30–50 weapons and land 13–19 hits; races there run with no or very few recoveries at any difficulty, and AI earn roughly 2–18 drift boosts each per race.

| AI difficulty | Typical lap | 3-lap race (all 8 AI) |
|---|---|---|
| Easy | about 71 s | 3:33–3:42 |
| Normal | about 64 s | 3:12–3:27 |
| Hard | about 61 s | 3:01–3:25 |

The racing has **not** been played on screen yet.

- **AI pace is untested against a human.** Normal laps at about 64 s may be quick or slow for you. Tune `speed_factor` in `resources/ai/*.tres`.
- **Screenshots are from a software renderer.** I rendered the cars, Vegas and the menus with Godot's Compatibility renderer in a virtual display. Your Forward+ (D3D12) renderer will show stronger glow, reflections and fog, so colours and brightness will differ; layout and geometry are the same.
- **Vegas hasn't been driven by a person.** The AI complete it reliably, but corner speeds, the shortcut's payoff (about 180 m shorter, minus the barrier and tighter turns) and feature placement need your feel.
- **Car models are stylised low-poly**, made from code. They match each car's silhouette and colours from the roster art, but aren't detailed. Any car can take a `.glb` instead (see "Vehicle models").
- **Scenery is visual only and fairly blocky:** generic buildings away from the landmarks are plain boxes with neon roof lines.
- **Menus are only partly checked on screen.** I've looked at the main menu and garage in screenshots (the garage overflowed at 1280×720 and is fixed; the project's base resolution is now 1280×720). The race setup, settings, pause and results screens, the Grand Prix standings and the Elimination HUD are still only checked headless.
- **Cosmetics and the 3D preview haven't been seen either.** Stripes, decals, plates and rims are positioned by hand on the placeholder body; the Riviera's lowered cabin and the other proportions may leave stripes or decals slightly off.
- **Vehicle balance is a first pass.** The stat spread follows each car's GDD character but hasn't been driven. AI always drive the V8 Specter.
- **Prices and payouts are first guesses** where the GDD gives none (stripes, decals, underglow, exhaust, metallic and matte finishes). At roughly 30–75 coins per race, the 1,000-coin Chrome finish takes 15+ races.
- **Not in Phase 5:** the optional first-time tutorial (GDD §11.9, not chosen for this phase), the race presentation items in GDD §11.8 (pre-race camera sweep, position-change feedback, podium ceremony), music, and dragging to rotate the preview.
- **Five tracks are still to build.** Races on them use the test circuit under their real names.
- **Grand Prix classification at your finish** gives racers still on track their current position. The GDD doesn't specify this; it avoids waiting for the field.
- **Only 6 of the GDD's 11 weapons** exist so far, plus Triple Nitro. Holo Decoy, Gravity Mine, System Glitch, Cyber Leech and Swarm Bots are Phase 6 content; the data-driven setup should make adding them straightforward.
- **Combat balance is untested against a human:** crate odds, durations, the 22 m EMP radius and the Railgun's speed. The Railgun hits about half its shots in AI races. The AI often spend a held Firewall pre-emptively rather than saving it.
- **Weapon visuals and sounds are placeholders:** glowing primitives, coloured lights and generated tones.
- **The combat HUD hasn't been seen on screen.** Its layout is built in code and may need nudging.

- **Tuning is first-pass.** Every number in `VehicleStats` and the camera profiles is a starting point (GDD §18 leaves these to playtesting): speeds, grip, drift yaw, boost strength, suspension and camera smoothing.
- **Camera jitter on high-refresh monitors.** The camera updates in `_physics_process` (60 Hz). Physics interpolation is not enabled yet.
- **Placeholder feedback only.** Sparks are emissive spheres, the audio cues are generated sine tones, and there are no tyre or engine sounds yet.
- **The free-drive lap timer is distance-based.** Races use real checkpoints.
- **Race length:** AI finish a Normal race in about 3:15. A human finishing mid-pack will likely take about 3:30–4:00, near the low end of the GDD §15.2 target of 4–6 minutes. Lengthen the layout or raise the lap count if races feel short.
- **Scene load takes about 1.2 s** of generation (track meshes and colliders about 0.8 s, racing line about 0.4 s) before the countdown. That's acceptable for now, but could later be cached or baked.
- **The Aggressor wins most simulated races.** Its personality never backs off behind slower cars, which pays off in AI-only races. Balancing rivals is Phase 6 work.
- **The track is flat.** No elevation, ramps or banking yet. The road is visual only; the ground slab provides collision, so elevation will need road colliders.
- **No pause** (Esc), menus, cosmetics or pre-race camera sweep yet. These come in later phases.
- **Rival names are placeholders** ("The Technician", etc.), following GDD §7.3. AI cars show a floating name tag.

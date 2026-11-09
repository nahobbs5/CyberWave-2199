# CYBERWAVE 2199
## Game Design Document — Version 4.1

**Status:** Development Baseline  
**Engine:** Godot 4  
**Primary Language:** GDScript  
**Genre:** 3D Arcade Combat Racing  
**Platform:** Windows PC initially  
**Players:** Single-player against seven AI opponents, or 2–4 player local split screen  
**Camera:** Third-person chase  
**Setting:** Retrofuturistic cyberpunk, year 2199

---

# 1. Game Overview

## 1.1 Concept

Cyberwave 2199 is a single-player arcade combat racing game featuring luxury retrofuturistic vehicles, futuristic weapons, challenging AI opponents, and atmospheric circuits inspired by recognizable real-world locations.

Players compete against seven AI racers in conventional races, three-race championships, and checkpoint-based elimination events.

The experience emphasizes accessible driving, rewarding drifting, tactical weapon use, and memorable environments.

## 1.2 Design Pillars

**Fast, satisfying driving**

Vehicles should be responsive, with arcade-oriented handling rather than strict driving simulation.

**Skill-based drifting**

Drifting is a central mechanic, rewarding controlled slides with progressively stronger speed boosts.

**Tactical combat**

Weapons should create opportunities for overtaking and defensive play without making racers lose control for excessive periods.

**Distinctive environments**

Each circuit should feel visually and mechanically different, from abandoned amusement parks to subterranean catacombs.

**Fair competition**

AI difficulty should primarily reflect driving ability and tactical decisions rather than artificial performance advantages.

**Manageable scope**

The initial release focuses on polished single-player racing. Additional features are considered only after the core experience works.

---

# 2. Game Modes

## 2.1 Versus

A race, or a set of races, against seven AI opponents. Set up Mario Kart style:

1. Race setup: vehicle, race type (Standard or Elimination), **number of races** (1, 2, 3, 4, 6, 8, 12 or 16), lap count (three by default), Easy / Normal / Hard AI, weapons on or off.
2. Cup screen (Versus): a row of cup badges plus a "?" Random badge. Moving across the badges previews each cup's races; opening a cup moves into its race cards, and picking one races it. The Random badge opens a **RANDOM** card for a random built track from any cup (in a series, one not raced yet while any are left). Built tracks of a cup that's locked for Grand Prix can be raced here.

With more than one race, the track screen comes back before each race (showing "RACE 2 OF 4" and the points so far). Points and the next grid work like a Grand Prix (§2.2). The final results name the series winner. A series isn't saved: quitting part-way ends it. Each race pays its normal coins, with no cup bonus.

The player starts in eighth position.

The race concludes when the player finishes or is otherwise removed from competition under the active mode's rules.

## 2.2 Grand Prix

Three cups, each a championship of its tracks raced back to back (three races each). As in Mario Kart, Grand Prix and Versus both pick from the same cup screen: a row of cup cards between gold arrows (each a rounded card in the cup's colours with its white map between gold laurels and its name; the selected one is larger, edged in gold and points down at the panel; a cup locked for Grand Prix is grey with a padlock) above a neon panel that previews the focused cup's races (trophy, name, race count and best finish, then a card per race with a screenshot of the track, its race number, name and location, and in Versus your best time). Opening a cup (click, Enter or A) moves into the panel. In Grand Prix you confirm the cup with START GRAND PRIX (a cup locked for Grand Prix shows "coming soon" and can't be confirmed). In Versus you pick one of its races (§2.1). Back from the panel returns to the badges.

### American Cup (trophy: a map of the USA)

| Race | Track | Location |
|---|---|---|
| 1 | Vegas Overdrive | Las Vegas, Nevada |
| 2 | Six Flags New Orleans | Louisiana |
| 3 | The Stacks | Library of Congress, Washington, DC |

### Europe Cup (trophy: a map of Europe)

| Race | Track | Location |
|---|---|---|
| 1 | Hoia Baciu Run | Romania |
| 2 | Catacombs Descent | Paris, France |
| 3 | Vatnajökull Glacier | Vatnajökull, Iceland |

### Asia Cup (trophy: a map of Asia)

| Race | Track | Location |
|---|---|---|
| 1 | Arashiyama Circuit | Kyoto, Japan |
| 2 | Crazy House | Hang Nga Villa, Da Lat, Vietnam |
| 3 | Gardens by the Bay | Marina Bay, Singapore |

### South America Cup (trophy: a map of South America)

| Race | Track | Location |
|---|---|---|
| 1 | Parque Quinta Normal | Santiago, Chile |
| 2 | Vale da Lua | Chapada dos Veadeiros, Brazil |
| 3 | Coming soon | |

The South America Cup is locked for Grand Prix until its third track is built; Parque Quinta Normal and Vale da Lua can already be raced in Versus.

The American, Europe and Asia Cups are playable. The Europe Cup was the World Cup; its save id is unchanged, so earlier results still count. The cup-win coin bonus is 100 for a three-race cup, scaled by the number of races (§9.3).

### Starting Grid

- Race 1: Player starts eighth.
- The seven AI opponents occupy positions one through seven.
- Race 2: Starting grid follows Race 1 finishing order.
- Race 3: Starting grid follows Race 2 finishing order.
- AI identities remain consistent across the championship.
- Grid positions are based on the immediately preceding race, not cumulative points.
- A race's result is fixed when the player finishes: racers still on track are classified in their current race order.

### Championship Points

| Finish | Points |
|---|---:|
| 1st | 15 |
| 2nd | 12 |
| 3rd | 10 |
| 4th | 8 |
| 5th | 6 |
| 6th | 4 |
| 7th | 2 |
| 8th | 1 |

The racer with the highest cumulative score wins.

**Proposed tiebreaker:** Most race victories, followed by most second-place finishes, then the finishing order in the final race.

### Championship Saving

Progress is saved between races.

The save includes:
- Championship identifier
- Completed race results
- Cumulative standings
- Next starting grid
- Selected vehicle
- AI racer identities
- Coins already awarded

An unfinished championship displays **Continue Grand Prix** on the main menu.

Mid-race saving is not required.

---

## 2.3 Elimination

An eight-racer event lasting three laps.

Elimination is determined by **checkpoint crossing order**, not a countdown timer.

### Elimination Schedule

| Race Progress | Action | Racers Remaining |
|---|---|---:|
| Start | Race begins | 8 |
| Lap 1 midpoint | Eliminate last two | 6 |
| Lap 2 midpoint | Eliminate last two | 4 |
| Lap 3 midpoint | Eliminate last two | 2 |
| Lap 3 finish | Determine winner | 1 |

The final two racers compete through the second half of lap three.

### Elimination Rules

- Each elimination checkpoint has a fixed number of qualifying positions.
- Racers qualify in the order they cross the checkpoint.
- Once all qualifying positions are filled, remaining racers are eliminated.
- Eliminated racers immediately lose the ability to deploy weapons or collide with active racers.
- Eliminated vehicles disappear through a brief visual transition rather than being destroyed.
- The player receives a results screen if eliminated.
- The start/finish line tracks laps but does not trigger eliminations.

Checkpoint placement must be consistent with each track's layout and alternate routes.

## 2.4 Split-Screen Multiplayer

Two to four players on one PC, Mario Kart style. The title menu offers **Single Player** (the main menu in §11.2) and **Multiplayer**.

### Setup Screens

1. **Connect controllers.** Each player presses Enter (keyboard) or A / Start (gamepad) once to join, then again to confirm READY. That device is theirs for the session: the keyboard can be one player and each gamepad another. Each slot shows its device; connected pads are listed. Back / B takes back READY, then leaves. When two to four have joined and all are ready, an **ALL READY** banner appears; one more Enter / A / Start from any player opens step 2 (Back / B still takes a READY back).
2. **Choose your cars.** One card per player: the car turning on its platform, its name and type, and its stats (top speed, acceleration, handling, drift as 1–10 bars). Left / right changes car on that player's device; Enter / A readies up; Back / B un-readies, or returns to step 1. When everyone is ready, an **ALL READY** banner asks for one more Enter / A / Start before step 3 opens.
   - Player 1 drives their Garage loadout. Players 2–4 drive the stock car painted in their player colour (P1 cyan, P2 magenta, P3 gold, P4 green).
   - Everyone can set a license plate (§9.5) with Y (gamepad) or Tab (keyboard). The keyboard player types; gamepad players use a letter picker (up / down changes the letter, left / right moves, X deletes, A done). Player 1's plate is saved to their profile; players 2–4 default to "P2"–"P4".
3. **Race setup.** Mode (Grand Prix or Versus); in Versus, race type (Standard or Elimination) and number of races; NPCs on or off (the computer-driven cars: on fills the grid to eight, off races the humans only; Elimination needs NPCs); NPC difficulty (shown only with NPCs on); laps; weapons. A panel explains the chosen mode and race type, including how Elimination knocks cars out.
   - Grand Prix goes to the cup screen. Versus goes to the cup screen to pick a race (§2.1), before every race of the set.

Leaving a race, or finishing a set, returns to step 2 with the same players joined.

### Screen Layout

| Players | Layout |
|---|---|
| 2 | Top half and bottom half |
| 3 | Three corners; the bottom-right corner shows a broadcast-style spectator camera cutting between other cars, preferring close battles |
| 4 | One corner each |

- Each view has its own chase camera and HUD, scaled down to fit. In 3–4 player races the standings list is hidden.
- One shared minimap shows every player as an arrow in their colour. It sits in the centre for 3–4 players, and at the right end of the divider for 2. HUD panels that would sit under it move to that view's bottom-right corner.
- Wrong-way signs and lock-on rings show only in their owner's view. Each car's "P2" tag shows in every view except its driver's.
- Players start at the back of the grid, player 1 last.
- Each player who finishes hands their car to the autopilot and sees their place until the shared results open, once every player is done.

### Rules

- Split screen pays no coins and records no personal bests or Grand Prix results. Versus sets of races work as in §2.1, with each human scoring points. Track coins can still be collected for the HUD count.
- A split-screen Grand Prix is kept in memory only, so it never replaces a saved single-player championship. Every human scores points; any player can be champion.
- Rubber-banding, coin respawns and the final-lap music follow the leading human.
- Any player's pause button pauses the race for everyone.

---

# 3. Driving and Controls

## 3.1 Driving Model

Cyberwave 2199 uses ground-based vehicles with arcade physics.

Driving should feel responsive, fast, and controllable, with recognizable vehicle weight and momentum.

The physics model should prioritize enjoyable racing over realistic tire simulation.

## 3.2 Keyboard Controls

| Key | Action |
|---|---|
| W | Accelerate |
| A | Steer left |
| S | Brake / Reverse |
| D | Steer right |
| Shift (hold) + A / D | Drift left / right |
| Space | Use selected weapon |
| 1 | Select item slot 1 |
| 2 | Select item slot 2 |
| C | Cycle camera |
| Q (hold) | Look back |
| R | Reset vehicle |
| Esc | Pause |

## 3.3 Gamepad Controls

| Input | Action |
|---|---|
| RT / R2 | Accelerate |
| LT / L2 | Brake / Reverse |
| Left stick | Steering |
| LB / L1 | Use selected weapon |
| RB / R1 | Drift (hold + steer) |
| D-pad Left | Select slot 1 |
| D-pad Right | Select slot 2 |
| Y / Triangle | Trick (in the air) |
| D-pad Up | Reset vehicle |
| D-pad Down | Cycle camera |
| Right stick click (hold) | Look back |
| Start / Options | Pause |

Gamepad support is part of the initial scope.

Control remapping is recommended.

---

# 4. Drifting and Boosts

## 4.1 Drift Mechanics

Drifting is a central driving skill.

- Holding Shift while steering left or right starts a drift in that direction.
- The drift continues while Shift is held; steering does not switch its direction.
- Steering input controls the slide.
- Valid drifting accumulates boost charge. **Steering into the drift charges faster** (up to 1.5x when steering fully in; 0.75x when steering fully out), so tighter cornering is rewarded, at the cost of a possibly worse racing line.
- Releasing Shift (or the gamepad drift button) ends the drift and activates the accumulated boost.
- The car hops slightly as a drift starts, and its body angles further into the slide than it actually travels (visual only; the physics stay as tuned). Both ease smoothly in and out.
- After a drift, grip blends back to normal over about 0.15 s, so the car straightens cleanly into the boost instead of snapping.

A valid drift requires actual lateral movement. Holding the drift button while driving straight does not generate charge.

## 4.2 Drift Charge Levels

| Level | Color | Required Drift (neutral steering) | Steering fully into the drift |
|---|---|---:|---:|
| Level 1 | Cyan | 1 second | about 0.67 seconds |
| Level 2 | Magenta | 2.5 seconds | about 1.67 seconds |
| Level 3 | Gold | 4 seconds | about 2.67 seconds |

Higher levels grant stronger speed boosts.

Charge thresholds are the initial design targets. Boost strength, duration, and charge retention require playtesting.

## 4.3 Drift Feedback

Each stage should have:
- Distinct wheel or undercarriage effects
- A unique audio cue
- Visible HUD progression
- Clear feedback when the drift ends
- A recognizable boost activation effect

Current effects: rear-wheel sparks and an undercarriage glow in the level's colour, tyre smoke from the rear wheels while sliding, a looping skid sound (louder at higher levels) for human players, a tone per level, exhaust flames when boosting, and the HUD charge bar.

## 4.4 Drift Interruption

Proposed behavior:
- Major collisions cancel an active drift.
- Leaving the ground suspends or ends charging.
- Losing control ends the drift.
- Normal steering corrections do not immediately cancel it.

---

# 5. Vehicle System

## 5.1 Vehicle Roster

Eight vehicles are available from the beginning.

| Vehicle | Type | Intended Character |
|---|---|---|
| V8 Specter | Grand Tourer | Balanced performance |
| Aurora GT | Executive Coupe | Smooth, precise handling |
| Empyrean S | Hyper Luxury | High top speed |
| Nexus X | Super Coupe | Strong acceleration |
| Riviera 88 | Luxury Roadster | Responsive cornering |
| Orbiter | Aero Coupe | Stable high-speed driving |
| Valkyrie R | Performance Sedan | Balanced, predictable control |
| Cipher EVO | Prototype | High skill ceiling |

These characteristics are initial balancing directions rather than final stat assignments.

## 5.2 Vehicle Statistics

Each vehicle has four primary attributes:

1. Top Speed
2. Acceleration
3. Handling
4. Drift

There is no Armor or Durability statistic.

No vehicle should be universally superior.

## 5.3 Vehicle Damage

Vehicles cannot be permanently destroyed.

Weapons and collisions may temporarily:
- Reduce speed
- Interrupt acceleration
- Disrupt traction
- Disable weapon use
- Interfere with vehicle electronics

There is no persistent health meter.

## 5.4 Collisions

**Collision intensity: Moderate.**

- Racers can bump one another.
- Side contact can alter racing lines.
- Rear impacts may transfer momentum.
- Ordinary collisions should not cause major spinouts.
- Strong impacts may temporarily reduce speed.
- Vehicles should resist excessive flipping and physics instability.

## 5.5 Recovery

Both manual and automatic recovery are supported.

**Manual recovery:** R or the mapped gamepad control.

**Automatic recovery:** Triggered when the vehicle becomes stuck, overturned, or leaves the playable area.

Recovery must:
- Return the vehicle to a safe track position
- Preserve required checkpoint progress
- Avoid placing the vehicle inside another racer
- Prevent shortcuts through deliberate resets
- Restore a usable driving orientation

Recovery timing and momentum penalties will be balanced during development.

---

# 6. Weapons and Combat

## 6.1 Inventory

Each racer has two weapon slots.

- Question-mark crates award random weapons.
- Items occupy available slots.
- Full inventories cannot collect additional weapons.
- Keys 1 and 2 select a slot.
- Space activates the selected weapon.
- After a weapon is used, the other occupied slot is automatically selected.
- Empty slots are visibly distinguished from occupied slots.

## 6.2 Targeting

Automatic targeting with lock-on is the standard system.

- Guided weapons automatically identify eligible opponents.
- Targetable weapons prioritize racers ahead.
- A visible indicator identifies the locked target.
- Initial lock acquisition target: 0.4 seconds.
- Brief obstructions should not instantly break an established lock.
- Non-targeted weapons deploy immediately.
- Guided weapons do not target their owner.

## 6.3 Weapon Roster

| Weapon | Effect | Initial Duration |
|---|---|---|
| EMP Pulse | Disrupts nearby opponent electronics | 1.5s disruption, weapons offline 5s |
| Hunter Drone | Pursues and stuns a target | 0.8s stun |
| Holo Decoy | Creates a false vehicle | 8s lifetime |
| Road Spike | Deploys electrified spikes | 12s lifetime, 1s traction penalty |
| Nitro Overload | Temporary speed boost | 3s |
| Triple Nitro | Three Nitro Overload charges in one slot, used one at a time | 3s per charge |
| Gravity Mine | Creates a localized gravity pull | 12s lifetime, 1.5s pull |
| Firewall | Blocks one incoming attack | Maximum 10s |
| System Glitch | Interferes with HUD and steering | 2s |
| Cyber Leech | Drains or steals boost energy | 2s |
| Railgun | Fires a fast projectile | 0.7s stagger |
| Swarm Bots | Pursue and disrupt an opponent | 5s pursuit |

The Firewall shows as an orange force field around the car: a glowing rim and a drifting hex energy grid. It fades in, dissolves away when it runs out, and bursts with a flash when it blocks a hit (`assets/shaders/force_field.gdshader`).

All values are initial balance targets.

### Excluded Weapons

The following are not part of the planned roster:
- Traffic Hack
- Rewind
- Blackout
- Phase Shift

## 6.4 Weapon Self-Effects

Weapons may affect their owner **only when that makes sense for their mechanics**.

| Weapon | Can Affect Owner? |
|---|---|
| EMP Pulse | No |
| Hunter Drone | No |
| Holo Decoy | No |
| Road Spike | Yes |
| Nitro Overload | No |
| Triple Nitro | No |
| Gravity Mine | Yes |
| Firewall | No |
| System Glitch | No |
| Cyber Leech | No |
| Railgun | No under normal mechanics |
| Swarm Bots | No |

Road Spikes and Gravity Mines receive a short deployment grace period before they can affect the owner.

Once armed, they follow the same collision and effect rules for every racer.

## 6.5 Combat Fairness

- Major stuns should be brief.
- Repeated hard stuns should trigger approximately 1.5 seconds of temporary protection.
- Weapon effects must be visually readable.
- Players should receive incoming attack warnings when appropriate.
- Powerful offensive weapons should be less common for race leaders.
- Trailing racers may receive better opportunities for recovery and overtaking.
- A landed Hunter Drone or Railgun hit knocks out the victim's selected weapon. Hits blocked by a Firewall or stun protection cost nothing.

Weapon distribution will be tuned during testing.

---

# 7. Artificial Intelligence

## 7.1 Racer Count

Every race contains:
- One human player
- Seven AI opponents

## 7.2 Difficulty Levels

### Easy
- Forgiving racing lines
- Earlier braking
- Slower reactions
- Occasional drifting
- Less effective weapon use
- Mild rubber-banding

### Normal
- Competent racing lines
- Balanced braking
- Regular drifting
- Reasonable weapon decisions
- Minimal rubber-banding

### Hard
- Precise racing lines
- Optimized drifting
- Tactical shortcuts
- Strong weapon decisions
- No rubber-banding

Difficulty should not rely primarily on hidden vehicle stat advantages.

## 7.3 Rival Personalities

Seven named rivals will have persistent identities.

Their exact names and visual designs may be finalized during content development.

Proposed driving archetypes:

1. **Technician:** Precise and consistent.
2. **Aggressor:** Weapon-heavy and assertive.
3. **Drifter:** Excels through corners.
4. **Strategist:** Conserves and times weapons.
5. **Daredevil:** Uses risky shortcuts and jumps.
6. **Speedster:** Favors acceleration and overtaking.
7. **Opportunist:** Exploits openings and mistakes.

Each rival has a preferred vehicle and recognizable behavior.

Personality modifies driving decisions; difficulty determines overall competence.

## 7.4 AI Requirements

AI must support:
- Steering and braking
- Drifting and boost charging
- Overtaking
- Weapon collection and use
- Target selection
- Alternate routes
- Checkpoint progression
- Elimination rules
- Collision avoidance
- Vehicle recovery

---

# 8. Tracks and Environments

Eleven tracks are included at launch.

## 8.1 The Stacks

**Location:** Library of Congress, Washington, DC

A fictionalized racing circuit through monumental halls, archive corridors, marble chambers, and interconnected interior spaces.

**Identity:** Tight corners, dramatic interiors, technical driving.

Built at about 2.9 km, set at sunset. Mostly indoor: the Great Hall (start/finish), a long gallery with tall west windows, the narrow archive stacks (the shortcut), the domed Main Reading Room as one big sweep, and a card-catalogue corridor. One stretch runs outdoors through an open-air courtyard, with a jump over a low stair. No water or EMP hazards.

## 8.2 Six Flags New Orleans

**Location:** Louisiana

An abandoned amusement park with overgrown pathways, flooded sections, roller coasters, maintenance roads, and decaying attractions.

**Identity:** Jumps, environmental hazards, alternate routes.

Built at about 3.1 km as a realistic post-Katrina ruin (stormy overcast, fog, rusted rides, flood lines): two jump ramps on straights, a jump on the water-park shortcut, and standing water that makes cars slightly slower and less grippy while they're in it.

## 8.3 Vegas Overdrive

**Location:** Las Vegas, Nevada

A neon-lit circuit through a futuristic casino district, entertainment complexes, tunnels, and wide urban boulevards.

**Identity:** High speed, wide roads, spectacle.

About 3.2 km, after playtesting found the first 4.4 km layout and its 900 m opening straight too long.

## 8.4 Hoia Baciu Run

**Location:** Romania

An eerie forest with twisted trees, heavy fog, abandoned structures, and unsettling environmental effects.

**Identity:** Visibility challenges, winding roads, atmosphere.

Built at about 3.2 km on a foggy, moonlit night (no rain) along a dirt road. Dense pines and Hoia Baciu's crooked, S-bent trees close in on the road. Landmarks: a carved wooden start arch, a forest graveyard with a chapel ruin, a stone viaduct over a ravine, two hairpins past a bog, a ruined red-stone castle whose gatehouse and courtyard are the shortcut, a ruined keep on a rise, and the Round Clearing (the treeless meadow of the legend) as a wide, fast sweep.

## 8.5 Catacombs Descent

**Location:** Paris, France

A fictionalized underground circuit through skull-lined tunnels, flooded chambers, ancient passages, and underground infrastructure.

**Identity:** Constrained racing, precision, claustrophobic atmosphere.

Built at about 2.8 km, fully underground: a vaulted stone ceiling covers every metre of both routes, and no sky is visible. The 12 m road is the narrowest in the game, with tight corners (30–45 m radius) and short straights. It's lit by wall torches, candles and a few shafts of pale light through street grates, and the tunnels fade to black ahead. Landmarks in driving order:
- the tall Barrière d'Enfer start chamber;
- the "Arrête ! C'est ici l'Empire de la Mort" lintel into the ossuary galleries (walls of stacked bones set with skulls);
- a crypt of burial niches and sarcophagi;
- a service passage with pipes and red emergency lamps;
- a flooded cistern of columns (standing water on the road);
- a forgotten candlelit chapel;
- a quarry propped with timber (EMP puddle from a fallen cable);
- a tomb gallery back to the start.

The shortcut is a low, half-flooded crypt passage across the middle of the lap. It's about 300 m shorter, but slowed by water and a smashable rubble barricade. The Tunnel Collapse special (§8.9) is still a proposal.

## 8.6 Arashiyama Circuit

**Location:** Kyoto, Japan

A racing circuit through dense bamboo forests, mountain roads, bridges, and rain-soaked pathways.

**Identity:** Technical cornering, drifting, natural scenery.

Built at about 3.1 km on a soft, sunny day. It should feel like an indoor garden out of doors: tall bamboo bows in from both sides until the leaves close over the road like a green ceiling, with the sun coming through in shafts and dapples. The canopy covers about three quarters of the lap and opens only at the start plaza, the bridge and the temple garden. The 13 m road is paved stone between brushwood (shibagaki) fences with bamboo rails, with medium-radius drift corners (35–60 m), one hairpin and short straights. Landmarks in driving order:
- an open start plaza with stone lanterns and banners;
- a timber gate marked ARASHIYAMA into the grove's S-bends;
- a long wooden bridge over the Katsura river, with the mountains behind;
- hillside sweepers past mossy retaining walls and red maples;
- a rain-soaked stretch of wet stone (standing water on the road);
- a walled temple garden with a pond, moss, clipped shrubs, raked gravel and a temple hall;
- the grove again to the finish.

The shortcut is a narrow shrine path through black torii, about 200 m shorter, but fallen bamboo (smashable) blocks the entrance. The Bamboo Collapse special (§8.9) is still a proposal.

## 8.6a Vatnajökull Glacier

**Location:** Vatnajökull, Iceland

A race through an ice cave under Europe's largest glacier.

**Identity:** Beauty and space. It is fully under the ice like the Catacombs, but roomy and bright where the Catacombs are cramped and dark.

Built at about 3.1 km with a 14 m road and long flowing corners (55–115 m radius, two gentle sweeps on the straights). One continuous cave of swirling blue, white and ash-striped ice opens up and closes in along the lap, with roofs from 15 m to about 36 m high. It's lit mostly by daylight glowing through the ice, plus soft blue light. More than ten thousand icicles hang from the roof; none hangs lower than 7.5 m over a road. Landmarks in driving order:
- the Glacier Mouth: the start hall, with a huge opening onto bright daylight and snow beside the grid;
- the Blue Cathedral: a vast swirling hall along the longest straight, with a meltwater stream (boost pad);
- the Icicle Gallery: lower and lined with icicle curtains and hourglass ice columns;
- Moulin Hall: meltwater holes in the roof pour shafts of sky light onto snow drifts (boost ring, meltwater ford on the road);
- the Ash Canyon: a tall gorge striped with black volcanic ash (snow-drift jump);
- the Frozen Lake: a glassy lake under ice chandeliers (slush EMP puddle), back to the mouth.

The shortcut is the Crystal Tube: a narrow, glowing round tunnel of scalloped ice with white light at its far end. It cuts from the Cathedral to the Icicle Gallery, about 120 m shorter, but an ice wall (smashable) blocks its entrance. The Ice Cave Collapse special (§8.9) is still a proposal. Race music is still to be chosen.

## 8.6b Crazy House

**Location:** Hang Nga Villa, Da Lat, Vietnam (shown without Vietnamese accents because the game fonts lack "ạ")

A race inside Hang Nga's Crazy House, the guesthouse built to look like a hollowed-out tree.

**Identity:** Twists, turns and the bizarre. It's a fantasy on a giant scale: the whole lap runs inside one enormous hollow trunk, and nothing has a straight line or a right angle.

Built at about 2.9 km with a 13 m road and constant linked corners (40–70 m radius, no straight longer than about 220 m). The inside of the trunk is melted grey and dark-brown bark dripping with cream plaster, with roofs from about 19 m to 46 m. Daylight comes through oval windows in the roof, and warm light glows from oval windows in the walls. The road is flat; the stairs are scenery (real elevation is a later engine upgrade). Landmarks in driving order:
- the Root Hall: the start, between gnarled root columns, with knotted bone railings beyond the barriers;
- the Spiral Stair Well: a tall well ringed with helical staircases (rounded steps, bone banisters, lit doorways at the top) (boost pad);
- the Animal Rooms: warm-lit alcoves with a bear, an eagle and a giraffe, after the house's themed rooms (stair-step jump);
- the Gingerbread Gables: the yellow timber house with steep curling gables and warm windows, built into the trunk (boost ring);
- the Lava Grotto: orange-red pitted walls and giant mushrooms (sap puddle EMP);
- the Bone Gallery: bone arches over the road (never lower than 7.5 m), knotted railings and a giant spider web (stair-step jump), back to the Root Hall.

Smaller staircases climb the walls all round the lap (about 29 flights, 1,500 steps). The shortcut is the Rib Tunnel: a narrow passage lined with bone ribs that carries straight on where the road turns into the Gables. It's about 250 m shorter, but a bone barricade (smashable) blocks the entrance. Race music is still to be chosen.

## 8.6c Gardens by the Bay

**Location:** Marina Bay, Singapore

A night race along a glass skyway high above the jungle, through the Supertree Grove during the Garden Rhapsody light show.

**Identity:** Height and exposure. It is the only track in the air: the road is a narrow glass deck 24 m above the treetops and the bay, and in places there is nothing at the edge.

Built at about 3.4 km with a 12 m road and winding, linked corners (45–90 m radius). The deck is clear glass framed in wood, with wooden beams under the glass, wooden strips across it, and glass side walls topped by amber-lit wooden handrails. Steel pylons hold it up. Below is dense rainforest with palms; a few tall trees break through near the deck. The Supertrees (26–52 m) slowly change colour together, a wave of purple, cyan, green and magenta rolling across the grove. Marina Bay Sands and the city skyline glow beyond. The road is flat (the deck stays level); landmarks in driving order:
- the Supertree Grove: the start, with the grid between two Supertrees under a GARDENS BY THE BAY sign;
- the Skyway S-bends: weaving between Supertrees, Marina Bay Sands ahead (boost pad);
- the Great Wrap: a hairpin round the tallest Supertree (boost ring);
- the east side: a long run with a jump on the deck;
- the Canopy Run: low over the treetops, with rain-wet glass (standing water) and an **open edge**;
- the Bayfront: over the water past the Flower Dome, where the wooden dragon perches on its tree (spark puddle EMP), with a second **open edge** over the bay; then back to the grove.

**Open edges:** stretches with no side wall, only a low wooden curb. A car that goes over falls into the jungle (or the bay) and is recovered onto the deck. The open edges are on straights, on the outside of the loop, so racing lines don't need to touch them.

The shortcut is the Cloud Forest walk: through a smashable glass panel into the Cloud Forest dome, round the misty waterfall mountain on a narrow walkway with two open edges of its own, and out to rejoin the Bayfront. It is about 150 m shorter. Race music is still to be chosen.

## 8.6d Parque Quinta Normal Greenhouse

**Location:** Parque Quinta Normal, Santiago, Chile

A bright summer race through and around the park's old Victorian greenhouse: iron ribs, missing and yellowed glass, bougainvillea, and **wire mesh everywhere**.

**Identity:** An iron-and-glass cage. Every road edge outside the glasshouses has a tall welded-mesh fence on iron posts above a low brick wall, and the glasshouses themselves have mesh walls below their glass vaults, so the whole lap reads as one big enclosure. The sun is high in the north-west (southern hemisphere), and the iron ribs throw striped shadows across the road.

Built at about 3.1 km with a 13 m road. Landmarks in driving order:
- **the main wing** (start / finish): the grid and start lights under a long barrel-vaulted glasshouse with mesh walls and a railed catwalk on the ridge, in two spans with a sunny courtyard of flower beds between them (boost pad near the end);
- **the avenue**: south between hedges and plane trees, mesh fences both sides;
- **the Rotunda**: the road turns off along a short stalk into the domed pavilion and sweeps about 310° round the round checkerboard plinth (garden of palms, flowering shrubs and graffiti-covered low walls inside, more graffiti walls outside), then leaves along a parallel stalk beside the way in, with a mesh-fenced divider between them (boost ring);
- **the south**: hedge-lined S-bends past the infield, where the tiered dome (exterior iron staircase, gallery and open lantern) and its two glass wings stand in open lawns (a sprinkler puddle of standing water);
- **the south-west corner**, then the west side (spark puddle EMP) and back into the main wing.

The Andes stand on the eastern horizon and Santiago's skyline (the Gran Torre) to the north-east.

The shortcut is the **Fern Wing**: through a smashable glass panel into a narrow (9 m), mesh-caged glasshouse that cuts across the south-west corner. It is about 110 m shorter. Race music is still to be chosen.

## 8.6e Vale da Lua

**Location:** Chapada dos Veadeiros, Brazil

A race through the Valley of the Moon: smooth grey "moon rock" sculpted by a fast river.

**Identity:** Moving water everywhere, and nerve on the open rock shelves.

Built at about 3.1 km with a 13 m road and flowing corners (60–100 m radius) around a river system. The rock is smooth, pale-to-dark grey, with rippled erosion lines, dimples and round potholes, darker and glossier toward the water, with green cerrado forest on top. The water moves: a main river and two streams run through slot canyons beside the road. They pass under it at four natural rock bridges, 5–14 m below the road, and drop over six waterfalls with white churn and mist at their feet. The road is elevated (§8.7) with barriers most of the way, but two open rock shelves run right along creek canyons: a bad line drops you into the water, and you are put back on the road. Landmarks in driving order:
- the start straight, over the first rock bridge (boost pad);
- the first open shelf above a creek;
- the east stream's bridge, with spray from the falls across the road (water);
- the headland loop (jump), which the shortcut cuts off;
- the deep gorge bridge, 14 m over the main river;
- a rock hump jump, then the second open shelf;
- the west stream's bridge and the cerrado (boost ring), back to the start.

The shortcut is Behind the Falls: a ledge under a rock overhang, with a stream pouring off the overhang as a curtain past its outer edge into a pool. It's about 250 m shorter, but driftwood logs (smashable) block the entrance. Race music is still to be chosen.

## 8.7 Shared Track Features

Tracks may contain:
- Question-mark weapon crates
- Collectible coins
- Speed boost pads
- Speed boost rings
- Jump ramps
- Directional signs
- Destructible barriers
- Explosive environmental objects
- Electrified hazards
- Traction-altering surfaces (standing water: about 12% lower top speed and 25% less grip while in it)
- Starting gantries
- Open edges on elevated tracks (no wall; falling off means a recovery)
- Lap and elimination checkpoints
- Vehicle recovery points

## 8.8 Shortcuts

Each track may include one or two shortcuts where appropriate.

Shortcuts should offer meaningful tradeoffs:
- Faster but more difficult
- Hazardous but rewarding
- Additional coins or items
- Alternative overtaking opportunities

All routes must maintain valid checkpoint and lap progression.

## 8.9 Proposed Track Specials (not scheduled)

The track concept art suggests one signature dynamic event per track. They are recorded here as ideas for after the six tracks are complete, not as Phase 6 requirements:

| Track | Proposed special |
|---|---|
| The Stacks | Archive Lockdown: dynamic route changes |
| Six Flags New Orleans | Flooded sections and coaster hazards |
| Vegas Overdrive | Fountain show water barriers, collapsing signage, EMP security, police response |
| Hoia Baciu Run | Phantom Signal: false routes and visual distortions |
| Catacombs Descent | Tunnel Collapse: blocked routes and forced detours |
| Arashiyama Circuit | Bamboo Collapse: falling bamboo hazards |
| Vatnajökull Glacier | Ice Cave Collapse: falling icicles and blocks of ice |
| Crazy House | Moving Staircases: stairs that swing into new routes |
| Vale da Lua | Flash Flood: the river rises and floods the low bridges |

---

# 9. Coins and Cosmetic Progression

## 9.1 Progression Model

All eight vehicles, eight tracks, and all three Grand Prix cups are available immediately.

Progression is cosmetic-only.

No performance upgrades are included.

## 9.2 Coin Collection

Coins are collected automatically on contact.

- Each track coin is worth one coin.
- Track coins respawn each lap.
- Maximum collectible track coins per race: 30.
- Coins are not dropped when hit.
- Only the player collects track coins; AI racers pass through them.
- Coin placement should encourage exploration without requiring excessive deviation from racing lines.

## 9.3 Race Rewards

| Achievement | Coins |
|---|---:|
| Complete race | 25 |
| Finish third | +15 |
| Finish second | +25 |
| Finish first | +40 |
| Win Grand Prix | +100 |

These rewards are additive.

A racer eliminated in Elimination has not completed the race and keeps only the track coins collected.

## 9.4 Cosmetic Shop

Players spend coins on cosmetic items.

Planned categories:
- Paint colors
- Paint finishes
- Racing stripes
- Decals
- Wheel designs
- License plate frames
- Neon underglow
- Cosmetic exhaust effects

### Initial Pricing

| Cosmetic | Target Price |
|---|---:|
| Basic paint | 100 |
| License plate frame | 250 |
| Wheel design | 500 |
| Premium finish | 1,000 |

Prices may change during balancing.

Purchased cosmetics remain permanently available.

Purchases are shared by every vehicle; each vehicle keeps its own equipped cosmetics.

## 9.5 License Plates

- One global license plate text is shared by all player vehicles.
- Text is editable in the Garage or vehicle selection screen.
- Changes persist between sessions.
- Initial maximum: eight characters.
- Plate designs and frames are cosmetic selections.
- AI racers may use their own predefined plates.

---

# 10. Cameras

Three camera perspectives are included: Far Chase, Close Chase and Rear View. Cycle camera goes Far → Close → Rear → Far.

## 10.1 Far Chase

**Default camera.**

- Wider view of the track
- Better awareness of opponents
- Clearer visibility during combat
- Suitable for most players

## 10.2 Close Chase

- Camera positioned closer to the vehicle
- More cinematic presentation
- Greater emphasis on speed and vehicle details

## 10.2a Rear View

- Camera sits ahead of the car and looks back past it, to watch chasers and incoming fire
- Can be chosen as a view, or shown only while **Look back** is held (Q / right stick click); releasing returns to the chosen view at once
- The 3-player spectator view never looks back

## 10.3 Camera Behavior

All cameras share a common controller with configurable:
- Distance
- Height
- Field of view
- Smoothing
- Collision avoidance
- Speed responsiveness

Camera selection persists between sessions.

**Deferred:** Hood Camera.

---

# 11. User Interface and Experience

## 11.1 Visual Direction

The interface uses a premium retrofuturistic cyberpunk aesthetic.

Primary characteristics:
- Dark backgrounds
- Cyan and magenta highlights
- Chrome-inspired typography
- Restrained neon glow
- Clean, readable layouts
- Distinctive vehicle and weapon iconography

Visual effects should never compromise gameplay readability.

## 11.2 Main Menu

The game opens on a title menu: Single Player, Multiplayer (§2.4), Settings, Credits, Exit. Single Player opens the main menu:

- Continue Grand Prix, when a championship is saved
- Grand Prix
- Versus (Standard or Elimination, picked on the race setup screen)
- Practice
- Garage
- Settings
- Credits
- Back (to the title)

Both menus share one look, taken from the start-menu reference art:

- A live 3D night street fills the screen: a wet road, a neon skyline in front of a big magenta sun, an elevated highway with moving traffic lights, and chevron signs.
- The player's car is parked on the right, seen from behind at three-quarters with its tail lights on. It is always the car selected in the Garage, with its equipped cosmetics and license plate.
- The logo is at the top left, with a column of slanted neon buttons under it. Each button has an icon. The focused button turns gold and shows a ">>" chevron.
- A panel at the bottom right names the focused option and describes it in one line.
- Controller hints sit in the bottom-right corner: A Select / B Back on a gamepad, Enter / Esc on a keyboard.
- The main menu also shows the coin balance at the top right. The title menu doesn't.

Settings and Credits use the same street, dimmed, behind rounded neon panels. The logo, an icon and the screen name sit along the top, and a slanted Back button sits at the bottom left.

- **Settings** shows two panels side by side. On the left are Display & Accessibility (sliders and ON / OFF switches) and Audio. On the right is the Controls table: one row per action, with its icon and keyboard and gamepad bindings, plus Reset to Defaults. The DISPLAY & AUDIO and CONTROLS tabs above the panels jump between the two sides, as do LB / RB or Q / E. The tab for the side that has focus is lit gold.
- **Credits** is one panel of rows. Each row has a slanted heading tab with an icon on the left and the credit on the right. Music is a table of title, artist and where the song plays.

## 11.3 Race Setup

Grand Prix: cup screen, then race setup. Versus: race setup first (including the number of races), then the cup screen to pick a race (§2.1).

- Championship (Grand Prix) or number of races (Versus)
- Vehicle selection
- License plate preview
- AI difficulty
- Race settings
- Start race

Previously selected settings should be remembered.

The setup, cup and track screens share the Settings look (§11.2): the dimmed street behind them, the screen name along the top, coins at the top right and Back at the bottom left.

- **Race setup.** On the left is a panel under a gold banner ("VERSUS · 1 RACE", or the cup's name and trophy in Grand Prix). The panel has one rounded row per setting, each with an icon and a ‹ value › stepper (left / right changes it): Race Type, Races, NPC Difficulty, Laps, and an ON / OFF switch for Items (Weapons). Grand Prix shows only NPC Difficulty and Items. A note explains the race type. Below the panel is a big gold button: Next: Pick a Track, or Start Grand Prix. On the right is the car on its platform with gold arrows (LB / RB also change it), its name on a magenta banner, a cyan type tag, segmented stat bars with icons, a top-speed card and the plate. Hints along the bottom: B Back, A Next, Y Garage. The garage's Back returns to the setup.
- **Cup screen (Grand Prix) and track screen (Versus).** These use the cup cards and race panel described in §2.2. Grand Prix confirms with a gold START GRAND PRIX button at the bottom right. A track without a screenshot shows its outline instead.

## 11.4 Garage

- Rotating 3D vehicle preview
- Vehicle statistics
- License plate editor
- Paint customization
- Cosmetic inventory
- Cosmetic shop
- Coin balance

The layout follows the "Cyberwave 2199 Neon Garage" reference art.

- **The garage room** fills the screen. The car sits on a thick turntable with a glowing magenta band and cyan rings. Behind it is a roll-up door with a big "CW-2199" stencil, with neon tubes, tool chests, tyre stacks, a banner with crossed checkered flags, ceiling lights and a checkered floor. The same room appears behind the car everywhere a car is picked: race setup shows it in a framed stage, and the split-screen car cards use a lighter version with no props and fewer lights.
- **Top:** the logo and GARAGE at the top left, the coin balance at the top right.
- **Left:** the car with gold previous / next arrows and a dot per car. Below it are the name on a magenta banner, a cyan type tag, segmented stat bars with icons, a top-speed card, and the license plate.
- **Right:** COSMETICS and INFO tabs over a neon panel.
  - Cosmetics lists the eight categories, each with an icon, beside that category's items: swatch, name, and Buy / Equip / Equipped.
  - Info shows how the car drives, its specs (top speed, 0–100 km/h, braking, reverse, handling, drift, grip, gold drift boost) and what's equipped on it.
  - There are no performance upgrades, so the reference's Tuning tab is left out.
- **Bottom:** Back (B / Esc) and a gold Apply (A / Enter).

Clicking an item previews it on the car; Apply equips every owned item being previewed; Back discards previews. The car spins slowly on its own and can be turned by dragging it (or with the right stick); the spin resumes shortly after. LB / RB change the car.

## 11.5 Race HUD

Display:
- Current position out of eight
- Lap number
- Race timer
- Speedometer
- Drift charge level
- Minimap
- Two weapon slots
- Active item indicator
- Target lock indicator
- Incoming attack warning
- Coin pickup feedback
- Wrong-way warning

## 11.6 Elimination HUD

Additional information:
- Active racers remaining
- Upcoming elimination checkpoint
- Available qualifying positions
- Checkpoint crossing confirmation
- Eliminated racer notifications

## 11.7 Results Screen

- Final finishing order
- Race times
- Grand Prix points and standings
- Coins earned
- Personal best indicators
- Newly available cosmetics
- Next race grid preview

## 11.8 Race Presentation

- Loading card while a track builds (races and free drive): logo, track name, location, mode (and "Race N of M" in a set), track outline, LOADING. The countdown starts only after it fades out.
- Pause menu: Resume / Restart race / Quit, Master / Music / Sound effects volume sliders (saved straight away, shared with Settings), and the controls card
- Brief pre-race camera sweep
- 3 / 2 / 1 / START countdown, with a four-lamp start-light board on the start gantry (three reds, then green), one lamp per beep
- No false-start penalties
- Position-change feedback
- Distinct drift boost effects
- Clear finish-line presentation
- Grand Prix podium ceremony

## 11.9 Accessibility

Planned settings:
- HUD scale
- Motion blur toggle
- Camera shake intensity
- Reduced flashing effects
- Separate audio sliders
- Remappable controls

An optional first-time tutorial should introduce driving, drifting, weapons, and recovery.

---

# 12. Audio Design

The soundtrack should blend synthwave, electronic racing music, and darker industrial elements.

Each track should have its own musical identity.

On the final lap (races of two or more laps) the race music plays 15% faster, pitch and all.

Sound categories include:
- Vehicle engines
- Acceleration and braking
- Tire friction and drifting
- Three drift charge stages
- Boost activation
- Weapon deployment
- Incoming attacks
- Collisions
- Coin collection
- Environmental ambience
- Countdown announcements
- Elimination notifications
- Race results

Important gameplay information should have both visual and audible feedback.

---

# 13. Saving and Persistence

## 13.1 Persistent Player Data

Save:
- Coin balance
- Purchased cosmetics
- Equipped cosmetics
- Global license plate text
- Selected vehicle
- Camera preference
- Control bindings
- Accessibility settings
- Personal bests
- Grand Prix results

## 13.2 Grand Prix Persistence

Between races, save:
- Current championship
- Completed races
- Championship standings
- Racer identities
- Next starting grid
- Player vehicle
- Rewards already issued

Save updates should be atomic or otherwise protected against partial writes.

Race rewards must not be duplicated when resuming or restarting.

---

# 14. Technical Architecture

## 14.1 Engine

Godot 4 with GDScript.

The project uses reusable, data-driven systems.

## 14.2 Core Components

### Vehicle Systems
- VehicleController
- DriftController
- VehicleRecovery
- CameraController
- VehicleStats

### Race Systems
- RaceManager
- CheckpointManager
- LapTracker
- PositionTracker
- GridManager
- EliminationManager
- ChampionshipManager

### AI Systems
- AIController
- RacerProfile
- RacingLineManager
- OvertakingLogic
- AICombatLogic

### Combat Systems
- ItemInventory
- WeaponManager
- TargetingSystem
- ProjectileController
- StatusEffectManager

### Track Systems
- TrackManager
- ShortcutManager
- PickupManager
- CoinManager
- HazardManager

### Interface and Progression
- UIManager
- GarageManager
- CosmeticShop
- ProgressionManager
- SaveManager
- SettingsManager

## 14.3 Architectural Requirements

- Vehicle physics should be shared and configurable.
- Weapon behavior should be data-driven.
- AI racer identities should persist across championship races.
- Tracks should use standardized checkpoint structures.
- AI should support main routes and shortcuts.
- Weapon effects should use consistent status-effect rules.
- Save data should be versioned for future compatibility.
- Systems should remain modular enough to support later expansion.

Local split-screen multiplayer is supported (§2.4); online play is not.

---

# 15. Performance and Quality Targets

## 15.1 Performance

Initial target: **60 FPS on a midrange Windows gaming PC**.

The game should support eight simultaneously active vehicles, weapons, particles, and environmental effects without major frame drops.

## 15.2 Race Length

Target approximately four to six minutes for a typical three-lap race.

Actual track length and speed should be balanced through playtesting.

## 15.3 Track Readability

Every track must:
- Accommodate eight racers
- Provide overtaking opportunities
- Clearly indicate direction
- Have fair hazard warnings
- Support drifting
- Provide safe recovery positions
- Support AI navigation
- Maintain valid checkpoint progression

---

# 16. Development Roadmap

## Phase 1 — Driving Prototype

Implement:
- One controllable vehicle
- Acceleration and braking
- Steering
- Shift drifting
- Three drift boost levels
- Close and Far Chase cameras
- Manual and automatic recovery
- Gamepad support

**Acceptance criteria:** A player can complete laps around a test circuit, intentionally drift, earn each boost level, switch cameras, and recover from an off-track incident.

## Phase 2 — Racing Prototype

Implement:
- Seven AI opponents
- Racing lines
- Checkpoints
- Lap tracking
- Race positions
- Starting grid
- Countdown
- Results screen

**Acceptance criteria:** Eight racers can complete a three-lap race with accurate standings, reliable checkpoint detection, and no routine AI navigation failures.

## Phase 3 — Combat Prototype

Implement:
- Two-slot inventory
- Weapon crates
- Automatic targeting
- Representative offensive and defensive weapons
- Status effects
- Self-effect rules
- Temporary stun protection

**Acceptance criteria:** Players and AI can acquire, select, deploy, and be affected by weapons without breaking race progression or vehicle control.

## Phase 4 — Game Modes

Implement:
- Versus
- Grand Prix
- Checkpoint-based Elimination
- Championship scoring
- Starting grid persistence
- Between-race saving

**Acceptance criteria:** All three modes can be completed with correct scoring, elimination order, and save/resume behavior.

## Phase 5 — Interface and Progression

Implement:
- Main menu
- Race setup
- Garage
- Global license plates
- Coin pickups
- Cosmetic shop
- Save data
- Settings and accessibility

**Acceptance criteria:** Players can earn coins, purchase and equip cosmetics, customize their license plate, and retain their progress after restarting the game.

## Phase 6 — Content and Polish

Complete:
- Eight vehicle models
- Six finished tracks
- Eleven weapons
- Seven named AI rivals
- Track shortcuts
- Music and sound effects
- Visual effects
- Race presentation
- Optimization
- Gameplay balancing

**Acceptance criteria:** All advertised content is playable, all races can be completed reliably, and the game meets its performance and usability targets.

---

# 17. Deferred Features

The following are explicitly outside the initial release:

- Online multiplayer
- Additional tracks
- Additional vehicles
- Vehicle performance upgrades
- Permanent vehicle damage
- Story campaign
- Dynamic weather systems
- Hood camera
- Photo mode
- Replay system
- Elaborate character dialogue
- Advanced cosmetic editing

These may be reconsidered after the initial game is playable and stable.

---

# 18. Implementation-Level Decisions Still Open

The following do not block the beginning of development:

- Exact numerical vehicle statistics
- Final names and appearances of AI rivals
- Drift boost speed multipliers and durations
- Weapon pickup probabilities
- Weapon targeting cone and range
- Detailed shortcut layouts
- Coin placement
- Cosmetic inventory and final prices
- Exact recovery timeout thresholds
- Camera offsets and smoothing values
- AI balancing parameters
- Championship tiebreaker implementation
- Final hardware requirements

These should be resolved through prototyping, testing, and content development rather than additional high-level design work.

---

# 19. Definition of the First Playable Build

The first playable build is a functional demonstration of the core racing experience.

It must include:

1. One placeholder vehicle.
2. One graybox test circuit.
3. Acceleration, braking, and steering.
4. Shift drifting with Cyan, Magenta, and Gold boosts.
5. Close and Far Chase cameras.
6. Seven functioning AI racers.
7. Three laps with checkpoint validation.
8. Accurate position tracking.
9. A starting countdown.
10. A basic race HUD and results screen.
11. Manual and automatic vehicle recovery.

Detailed artwork, weapons, cosmetics, and completed environments are not required for this milestone.

**Primary success criterion:** The racing must be enjoyable before additional content is developed.

---

# 20. Document Control

**Project:** Cyberwave 2199  
**Document Version:** 2.1  
**Status:** Approved design baseline for initial development  
**Engine:** Godot 4  
**Initial Platform:** Windows PC  
**Initial Mode:** Single-player  
**Core Content:** 8 vehicles, 6 tracks, 12 weapons, 3 game modes  
**Progression:** Coins and cosmetic customization  
**Next Milestone:** First playable driving and racing prototype

Changes after Version 1.0 should be tracked as revisions rather than silently replacing established requirements.

## Revision History

| Version | Date | Change |
|---|---|---|
| 1.0 | — | Approved design baseline. |
| 1.1 | 2026-11-05 | Keyboard drift changed from Q / E to holding Shift while steering with A / D, after Phase 1 testing found it more intuitive (§3.2, §4.1, §16, §19). Gamepad drift buttons unchanged. |
| 1.2 | 2026-11-05 | After Phase 3 testing: Hunter Drone and Railgun hits knock out the victim's selected weapon (§6.5); the EMP Pulse keeps weapons offline for 5 s (§6.3). |
| 1.3 | 2026-11-05 | Phase 4: added Triple Nitro, three Nitro charges in one slot (§6.3, §6.4). Grand Prix results are fixed at the player's finish, classifying racers still on track by current position (§2.2). |
| 1.4 | 2026-11-05 | Phase 5: only the player collects track coins (§9.2); eliminated racers don't earn the completion reward (§9.3); purchases are shared across vehicles while each vehicle keeps its own equipped cosmetics (§9.4). |
| 1.5 | 2026-11-05 | Phase 6 (first part): track specials from the concept art recorded as proposals, not requirements (§8.9). Vegas Overdrive built at about 4.4 km, with the Luxor shortcut through the pyramid (§8.3, §8.8). |
| 1.6 | 2026-11-05 | After playtesting Vegas: shortened to about 3.2 km with a roughly 500 m opening straight (§8.3). HUD weapon slots show weapon pictures; the minimap sits bottom right (§11.5). |
| 1.7 | 2026-11-05 | Six Flags New Orleans built at about 3.1 km (§8.2). Jump ramps and standing water defined as track features (§8.7). |
| 1.8 | 2026-11-06 | The Stacks Grand Prix built at about 2.9 km, at sunset with one open-air courtyard (§8.1). The American Circuit is playable; the World Circuit is locked as "coming soon" until its tracks are built (§2.2). |
| 1.9 | 2026-11-06 | Championships are now cups chosen Mario Kart style: American Cup (USA-map trophy) and World Cup (globe). Versus picks a cup, then one of its tracks. The Stacks Grand Prix renamed The Stacks. American Cup order is now Vegas Overdrive, Six Flags New Orleans, The Stacks (§2.2, §8.1). |
| 2.0 | 2026-11-06 | Hoia Baciu Run built at about 3.2 km: moonlit, foggy, dirt road, crooked trees (§8.4). The World Cup stays locked until its other two tracks exist. Final-lap music speed-up (§12). |
| 2.1 | 2026-11-06 | Countdown is now 3 / 2 / 1 / START with a start-light board on the gantry, one lamp per beep (§11.8). |
| 2.2 | 2026-11-06 | Garage restyled after the reference art, with an Apply button and drag-to-rotate; race setup shares its car showcase (§11.4). |
| 2.3 | 2026-11-06 | Catacombs Descent built at about 2.8 km: fully vaulted, torch-lit, 12 m road, flooded-crypt shortcut (§8.5). The World Cup stays locked until Arashiyama exists. |
| 2.4 | 2026-11-06 | Arashiyama Circuit built at about 3.1 km: sunny bamboo grove whose canopy closes over most of the lap, paved stone road, river bridge, temple garden, shrine-path shortcut (§8.6). All six tracks are built, so the World Cup is unlocked (§2.2). |
| 2.5 | 2026-11-06 | Local split-screen multiplayer for 2–4 players: title menu, join lobby, top/bottom and corner layouts, a 3-player spectator view, one shared minimap, no rewards (§2.4, §11.2). |
| 2.6 | 2026-11-06 | Versus is Mario Kart style: pick the number of races, then each track from one screen listing every cup; points add up over the set (§2.1, §11.3). Split screen is three screens: connect controllers, choose cars (with stats), race setup (§2.4). |
| 2.7 | 2026-11-06 | Gamepad: RB drift (hold + steer), LB weapon, Y trick, D-pad up reset, D-pad down camera (§3.3). Split screen: join then READY on the connect screen, license plates on the car screen, "NPCs" wording and mode explanations on race setup (§2.4). |
| 2.8 | 2026-11-06 | Rear View camera (third in the cycle) and hold-to-look-back on Q / right stick click (§3.2, §3.3, §10). RANDOM track card on the Versus track screen (§2.1). Split screen: a final ALL READY confirm on the connect and car screens (§2.4). |
| 2.9 | 2026-11-06 | Volume sliders (Master, Music, Sound effects) on the pause menu. Loading card over track builds so the game no longer looks frozen, and the countdown waits for it (§11.8). |
| 3.0 | 2026-11-07 | Mario Kart style drift feel: steering into a drift charges faster (1.5x in, 0.75x out), drift-entry hop, body angled into the slide, smooth grip recovery after a drift, tyre smoke and a skid sound (§4.1–4.3). |
| 3.1 | 2026-11-07 | Firewall shield drawn as an animated force-field shader: rim glow, hex grid, fade in / dissolve out, flash on block (§6). |
| 3.2 | 2026-11-07 | Vatnajökull Glacier built at about 3.1 km: a roomy, bright ice cave with icicles, sky-light shafts, a frozen lake and the Crystal Tube shortcut (§8.6a). The World Cup becomes the Europe Cup (Hoia Baciu, Catacombs, Vatnajökull); Arashiyama moves to the new Asia Cup. Cup-win bonus scales with the cup's race count (§2.2). |
| 3.3 | 2026-11-07 | Crazy House built at about 2.9 km: inside a giant hollow tree (Hang Nga Villa, Da Lat, Vietnam), staircases everywhere, bone arches, Rib Tunnel shortcut (§8.6b). It is Asia Cup race 2 (§2.2). The road stays flat; elevation is planned as a later engine upgrade. |
| 3.4 | 2026-11-07 | Gardens by the Bay built at about 3.4 km: a night glass skyway 24 m above the jungle among glowing Supertrees, with open edges you can fall off, the Great Wrap hairpin, and the Cloud Forest walk shortcut (§8.6c). It is Asia Cup race 3, so all cups have three races (§2.2). Engine: elevated decks with their own collider and open edges (§8.7).
| 3.5 | 2026-11-07 | Parque Quinta Normal Greenhouse built at about 3.1 km: Victorian iron-and-glass greenhouse in Santiago, wire mesh throughout, start in the barrel-vaulted main wing, a 310° roundabout round the Rotunda's checkerboard plinth, the Fern Wing shortcut (§8.6d). It starts the new South America Cup, locked for Grand Prix until its other two tracks exist (§2.2). |
| 3.6 | 2026-11-08 | Vale da Lua built at about 3.1 km: Brazil's Valley of the Moon, smooth moon rock cut by moving water (a river and streams under four rock bridges, six waterfalls), an elevated road with two open rock shelves over creeks, and the Behind the Falls shortcut (§8.6e). It is South America Cup race 2 (§2.2). Track count corrected to eleven. |
| 3.7 | 2026-11-08 | Mario Kart style cup screen for both modes: a row of cup badges (gold-rimmed medallions with each cup's map) above a panel of the selected cup's races; confirm the cup for Grand Prix, pick a race for Versus, plus a Random badge (§2.1, §2.2). The Asia Cup's emblem is now a map of Asia. |
| 3.8 | 2026-11-09 | Title and main menus restyled after the start-menu reference art: a live 3D night street with the player's garage car, slanted neon buttons with icons, a description panel for the focused option, controller hints, and coins on the main menu (§11.2). The main menu list now matches the game. |
| 3.9 | 2026-11-09 | Settings and Credits restyled after their reference art to match the start menus: dimmed live street, neon panels, icon rows, Settings tabs that jump between the display / audio and controls panels (§11.2). |
| 4.0 | 2026-11-09 | Race setup, cup screen and Versus track screen restyled after their reference art: settings rows with ‹ value › steppers under a gold banner, a neon car showcase, cup cards with maps between laurels, race cards with track screenshots, and gold Next / Start Grand Prix buttons. Y opens the garage from the race setup and returns to it (§2.2, §11.3). |
| 4.1 | 2026-11-09 | Garage restyled after its new reference art: a full-screen neon garage room behind the car, COSMETICS / INFO tabs (Info lists the car's specs and equipped items), category icons, and B Back / A Apply buttons. The same garage room is now behind the car in race setup and the split-screen car cards (§11.4). |

**End of Game Design Document — Version 4.1**

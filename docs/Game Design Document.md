# CYBERWAVE 2199
## Game Design Document — Version 2.4

**Status:** Development Baseline  
**Engine:** Godot 4  
**Primary Language:** GDScript  
**Genre:** 3D Arcade Combat Racing  
**Platform:** Windows PC initially  
**Players:** Single-player against seven AI opponents  
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

A standalone race against seven AI opponents.

Players can select:
- Any of the six tracks
- Any of the eight vehicles
- Easy, Normal, or Hard AI
- Lap count, with three laps as the default
- Weapons enabled or disabled, if implemented in race settings

The player starts in eighth position.

The race concludes when the player finishes or is otherwise removed from competition under the active mode's rules.

## 2.2 Grand Prix

Two cups, each a championship of three consecutive races. As in Mario Kart, Grand Prix and Versus both start by choosing a cup; Versus then picks one of that cup's tracks.

### American Cup (trophy: a map of the USA)

| Race | Track | Location |
|---|---|---|
| 1 | Vegas Overdrive | Las Vegas, Nevada |
| 2 | Six Flags New Orleans | Louisiana |
| 3 | The Stacks | Library of Congress, Washington, DC |

### World Cup (trophy: a globe)

| Race | Track | Location |
|---|---|---|
| 1 | Hoia Baciu Run | Romania |
| 2 | Catacombs Descent | Paris, France |
| 3 | Arashiyama Circuit | Kyoto, Japan |

Both cups are playable now that all six tracks are built.

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
| R | Reset vehicle |
| Esc | Pause |

## 3.3 Gamepad Controls

| Input | Action |
|---|---|
| RT / R2 | Accelerate |
| LT / L2 | Brake / Reverse |
| Left stick | Steering |
| LB / L1 | Drift left |
| RB / R1 | Drift right |
| A / Cross | Use selected weapon |
| D-pad Left | Select slot 1 |
| D-pad Right | Select slot 2 |
| Y / Triangle | Reset vehicle |
| View / Touchpad | Cycle camera |
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
- Valid drifting accumulates boost charge.
- Releasing Shift (or the gamepad drift button) ends the drift and activates the accumulated boost.

A valid drift requires actual lateral movement. Holding the drift button while driving straight does not generate charge.

## 4.2 Drift Charge Levels

| Level | Color | Required Drift |
|---|---|---:|
| Level 1 | Cyan | 1 second |
| Level 2 | Magenta | 2.5 seconds |
| Level 3 | Gold | 4 seconds |

Higher levels grant stronger speed boosts.

Charge thresholds are the initial design targets. Boost strength, duration, and charge retention require playtesting.

## 4.3 Drift Feedback

Each stage should have:
- Distinct wheel or undercarriage effects
- A unique audio cue
- Visible HUD progression
- Clear feedback when the drift ends
- A recognizable boost activation effect

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

Six tracks are included at launch.

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

---

# 9. Coins and Cosmetic Progression

## 9.1 Progression Model

All eight vehicles, six tracks, and both Grand Prix cups are available immediately.

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

Two camera perspectives are included in the initial release.

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

## 10.3 Camera Behavior

Both cameras share a common controller with configurable:
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

- Versus
- Grand Prix
- Continue Grand Prix, when applicable
- Elimination
- Garage
- Settings
- Exit

## 11.3 Race Setup

- Track or championship selection
- Vehicle selection
- License plate preview
- AI difficulty
- Race settings
- Start race

Previously selected settings should be remembered.

## 11.4 Garage

- Rotating 3D vehicle preview
- Vehicle statistics
- License plate editor
- Paint customization
- Cosmetic inventory
- Cosmetic shop
- Coin balance

Layout follows the "Neon Cyberwave Garage Interface" reference art: logo and coin balance across the top; on the left the car on a neon turntable with previous / next arrows and a dot per car, then its name, type, stat bars and top speed, and the license plate; on the right a Cosmetics panel with the eight categories in a list beside that category's items (swatch, name, Buy / Equip / Equipped). There are no performance upgrades, so the reference's Upgrades, Performance and Details tabs are left out. Clicking an item previews it on the car; Apply equips every owned item being previewed; Back discards previews. The car spins slowly on its own and can be turned by dragging it (or with the right stick); the spin resumes shortly after. Race setup uses the same car showcase.

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

Multiplayer support is not an initial implementation requirement.

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

**End of Game Design Document — Version 2.4**
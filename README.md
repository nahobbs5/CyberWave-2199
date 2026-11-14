# CyberWave 2199

**Retrofuturistic cyberpunk combat kart racing, built in Godot 4.**
Luxury neon cars, drift boosts, weapons and fifteen circuits set in real-world places, against seven AI rivals or with up to four players in local split screen.

**▶ [Play the browser demo](https://nahobbs5.github.io/CyberWave-2199/web/)** · **🛠 [Dev tracker](https://nahobbs5.github.io/CyberWave-2199/dev/)** · **📖 [Full reference](docs/Reference.md)** · **📐 [Game Design Document](docs/Game%20Design%20Document.md)** (v6.9)

> **Status (2026-11-14):** Phase 6, content and polish, is in progress (GDD §16). Every track, car and mode below is playable. Handling, drift timing, weapon balance, atmosphere, UI and controller support are still being tuned; the dev tracker has the details.

---

## Features

- **Modes:** Versus (Mario Kart style sets of 1–16 races), Grand Prix (three-race cups with points and a save), and Elimination (checkpoint knockouts each lap).
- **2–4 player split screen** on one PC with keyboard and gamepads, a live spectator view for three players, and an optional AI field.
- **Drifting:** hold drift and steer to charge **Cyan → Magenta → Gold** boosts. Steering into the slide charges faster.
- **Rocket start:** hold accelerate as the "2" fades to launch, but too early and you burn out. A four-lamp start-light board on the gantry counts you in.
- **Slipstream, ramp tricks and boost pads / rings,** plus shortcuts with smashable barriers on every track.
- **11 weapons** with position-based crate odds. System Override hacks everyone ahead of you, and the leader stays hacked longest.
- **Holographic recovery** that never moves you forward.
- **8 cars** with distinct stats, a neon garage with 8 cosmetic categories, coins and license plates.
- **Presentation:** a podium ceremony, neon results, music for every track but Chefchaouen (5% faster on the final lap), rebindable controls and accessibility settings.

## Cups and tracks

| Cup | Track | Setting | Length | GDD |
|---|---|---|---:|---|
| **American** | Vegas Overdrive | The Strip at night, Luxor pyramid shortcut | 3.2 km | §8.3 |
| | Six Flags New Orleans | Abandoned, flooded amusement park and its derelict bumper-car ride | 3.1 km | §8.2 |
| | The Stacks | Library of Congress at sunset | 2.9 km | §8.1 |
| **Europe** | Hoia Baciu Run | Romania's haunted forest, foggy night | 3.2 km | §8.4 |
| | Catacombs Descent | Torch-lit tunnels under Paris | 2.8 km | §8.5 |
| | Vatnajökull Glacier | Blue ice cave, Iceland | 3.1 km | §8.6a |
| **Asia** | Arashiyama Circuit | Kyoto bamboo grove | 3.1 km | §8.6 |
| | Crazy House | Inside a giant hollow tree, Da Lat | 2.9 km | §8.6b |
| | Gardens by the Bay | Glass skyway among the Supertrees, Singapore | 3.4 km | §8.6c |
| **South America** | Parque Quinta Normal | Victorian greenhouse, Santiago | 3.1 km | §8.6d |
| | Vale da Lua | Valley of the Moon, Brazil | 3.1 km | §8.6e |
| | Choquequirao | Inca double-spiral village, Peru | 3.3 km | §8.6f |
| **Africa** | Kilwa Kisiwani Ruins | Swahili ruins, columns in the road, Tanzania | 3.0 km | §8.6g |
| | Fires of Nyiragongo | Inside the volcano's crater at dusk, D.R. Congo | 3.2 km | §8.6h |
| | Chefchaouen | Blue medina with two forks per lap, Morocco | 3.15 km | §8.6i |

All five cups are complete and open for Grand Prix and Versus. The graybox Test Circuit is the Practice track.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Accelerate | W / Up | RT / R2 |
| Brake / Reverse | S / Down | LT / L2 |
| Steer | A / D, Left / Right | Left stick |
| Drift | Hold Shift + steer | Hold RB / R1 + steer |
| Use selected weapon | Space | LB / L1 |
| Weapon slot 1 / 2 | 1 / 2 | D-pad Left / Right |
| Trick (off a ramp) | E | Y / Triangle |
| Cycle camera (Far → Close → Rear) | C | D-pad Down |
| Look back (hold) | Q | Right stick click |
| Reset vehicle | R | D-pad Up |
| Pause | Esc | Start / Options |
| Menus | Enter / Esc, arrows, mouse | A / B, D-pad or left stick |

Every action can be rebound in **Settings → Controls**.

## Documentation

| Doc | What's in it |
|---|---|
| [Game Design Document](docs/Game%20Design%20Document.md) | The design authority, with its revision history |
| [Reference](docs/Reference.md) | How every built system works, track by track, plus the project layout and tests |
| [Vehicle Physics Guide](docs/Cyberwave_2199_Vehicle_Physics_Implementation_Guide.md) | Raycast suspension and handling notes |
| [Advanced Weapons](docs/Cyberwave_2199_Advanced_Weapons.md) | Hunter-Killer, Overdrive Protocol, System Override |
| [Recovery System](docs/Recovery%20System.md) | The holographic recovery sequence |
| [Dev tracker](https://nahobbs5.github.io/CyberWave-2199/dev/) ([source](dev/)) | Milestones, backlog, decision log and playtest checklist |

## Credits

**Cyberwave 2199** by Nathan Hobbs.
Music by ikoliks_aj, ikoliks, alex-morgan, Lilex, TheBoysBeats, SPmusic, kulakovka, Ob-Lix, ed-musicproductions, sonican, elisaveta_stoycheva, theorienvibes, restum-anoush, DesiFreeMusic, vishiv, Jean-Paul-V and stageechoesmusic. Sound effects by freesound_community, vadim_makes_sound, rescopicsound, fronbondi_skegs, voicebosch and 49053354. Textures and skies from [Poly Haven](https://polyhaven.com) (CC0). Fonts Oxanium and Rajdhani (SIL OFL 1.1). Made with [Godot Engine](https://godotengine.org) (MIT).
The full list is on the in-game Credits screen and in [docs/Reference.md](docs/Reference.md#credits).

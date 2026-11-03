# Bobek's Adventure

*(Project 001, "The Deep Vault")*

A small, atmospheric 3D fantasy dungeon crawler built with **Godot 4.5** during an overnight autonomous-development experiment (Project 001).

Descend from a ruined outpost at dusk into the Vault of Ashkar. Fight risen skeletons, time your run through breathing fire vents, arm yourself in the Armory, and cross **the Glowing Deep**, a cavern split by a river of living light. Then face the Vault Warden for the Heart of the Vault.

## Play it

**On iPad (or any modern browser):** open **https://whitewolfcreativeworks-coder.github.io/The-deep-vault-game/** in Safari. The first load downloads about 66 MB.
- **Touch:** the on-screen controls appear as soon as you touch the screen. Use both thumbs at once, move with the left and look with the right:
  - left thumb to move (push all the way to sprint)
  - swipe on the right side to look
  - pinch to zoom between first and third person
  - buttons for attack, block, bolt, dodge, jump, use and potion
- **Magic Keyboard / trackpad:** works like a computer. If Safari won't lock the pointer, you drag to look and tap to attack instead. The arrow keys also turn the camera.
- **Tip:** in Safari choose Share → *Add to Home Screen* to play full-screen.

The browser version uses Godot's web renderer, which has no volumetric fog or light shafts. Everything else is the same game.

**Download a build** (`BobeksAdventure-Windows.zip`, `-macOS.zip`, `-Linux.zip`) from the [`builds` branch](https://github.com/whitewolfcreativeworks-coder/The-deep-vault-game/tree/builds): Windows, macOS (Apple Silicon and Intel) and Linux zips, with run instructions in that branch's README. Only the Linux build has actually been launched and tested so far.

**Run from source (any OS):**

1. Install [Godot 4.5.1 (standard edition)](https://godotengine.org/download/archive/4.5.1-stable/).
2. Clone this repository.
3. Open Godot, choose **Import**, and select `game/project.godot`.
4. Press **F5** (Play). The first import takes a minute.

Alternatively, run `godot --path game` from the repo root.

A GPU with Vulkan gives the full look (volumetric fog and light shafts). Without Vulkan, Godot falls back to OpenGL automatically and everything except volumetric fog still works.

## Screenshots

*Captured by the automated test harness under software rendering (no GPU), so expect smoother lighting and higher frame rates on real hardware.*

| | |
|---|---|
| ![Title](docs/screenshots/01_title.jpg) | ![Character creator](docs/screenshots/02_character_creator.jpg) |
| ![Outpost](docs/screenshots/03_outpost.jpg) | ![Skeletons rise](docs/screenshots/04_skeletons_rise.jpg) |
| ![Fire vents](docs/screenshots/05_fire_vents.jpg) | ![The Glowing Deep](docs/screenshots/06_glowing_deep_bridge.jpg) |
| ![River, first person](docs/screenshots/07_river_first_person.jpg) | ![Amulet heals](docs/screenshots/08_amulet_heals.jpg) |
| ![The Vault Warden](docs/screenshots/10_warden.jpg) | ![Victory](docs/screenshots/12_victory.jpg) |

## Controls

| Input | Action |
|---|---|
| WASD | Move. **Strafe movement by default**: your hero keeps facing where you look, sidestepping and backpedaling (switch to "Free" movement in the pause menu) |
| Mouse (or arrow keys) | Look |
| **Mouse wheel** | Zoom smoothly from wide third person into **first person** |
| V | Snap between first and third person |
| Left mouse | Sword attack (press again mid-swing for a 3-hit combo) |
| Right mouse (hold) | Raise shield / block |
| Q | Arcane bolt (homing, costs mana) |
| **X** | **Hero special ability** (on a cooldown; big purple button on touchscreens) |
| Space / Shift / C | Jump (press against a ledge to climb up) / Sprint / Dodge roll |
| E | Interact (chests, levers, shrines, inscriptions) |
| R or 1 | Drink a healing draught |
| F or 2 | Drink a mana potion |
| I or Tab | Inventory and character sheet |
| Esc | Pause menu |

Basic gamepad support is included: left stick to move, A jump, X attack, LB block, RB spell, B dodge, Y interact, right-stick click special.

## What's in it

- **Hero special abilities (new).** Each hero has a special move on its own button, with a cooldown:
  - **Rogue: Backstab** (6 s). Vanish and reappear behind the nearest enemy, striking for a 3.5x critical.
  - **Mage: Shadow Step** (5 s). Blink up to 11 m the way you look (or move), with a shadow burst that damages and staggers enemies where you leave and where you land.
  - **Knight: Shield Charge** (7 s). Rush forward, smashing and stunning everything in the way.
  - **Barbarian: Whirlwind** (8 s). Spin twice, hitting every enemy around you.
  - **Ranger: Volley** (7 s). A fan of five glowing arrows.

- **Random loot (new).**
  - Weapons, armor, trinkets and *skins* come in five rarities: Common, Uncommon, Rare, Epic and Legendary.
  - Each piece rolls random bonuses: attack, defense, health, mana, mana regeneration, critical hits, life steal and spell power.
  - Loot drops from monsters and from 13 chests (plus a reward chest after the boss). Rare and better drops shoot a beam of light.
- **Gear changes your look.** Weapons glow in their rarity colour, armor changes your shield and colours, and Epic or Legendary gear gives you an aura. Skins transform you: Lizardfolk, Bone Ward (you become a skeleton), Gilded, Spectral, Ember and Frost.
- **Healing and mana potions.** Your sword hits recharge mana, so the rhythm is: cast, slash to recharge, cast again.

- Character creation with a live 3D preview: five heroes, skin tone (9, including goblin green and frost blue), 8 hair styles, 10 hair colours, face details (beard, mustache, eyepatch, scar, war paint, rosy cheeks), build (skinny to big) and height (short to tall) sliders, armor & cloak colour, helm toggle, a "Randomize look" button and a Bobek-themed random name.
- App icon, loading screen and title art use the Bobek's Adventure cover art (green-hooded Rogue).
- A continuous first-/third-person camera that collides with walls.
- Real-time combat: a combo chain, block with guard break, dodge with i-frames, a homing spell, hit-stop, screen shake and damage numbers.
- Four enemy types plus a three-phase boss. Skeletons rise out of the floor, mages kite and shoot, the Revenant telegraphs heavy slams, and the Warden leaps, summons and enrages, then shatters into physics debris.
- XP and levels, a gear progression (3 weapons, 3 armors, 1 artifact), gold, potions, an inventory and a character sheet.
- Checkpoint shrines, death and respawn, lore inscriptions, and a victory screen.
- **The Glowing Deep**:
  - a flowing luminous river shader with depth foam, ripples where you wade, and a colour shift when you wear the amulet
  - glowing waterfalls and feeder channels, drifting mist, rising motes and volumetric fog with a light shaft
  - caustic light on the stone
  - the river burns you, or heals you if you carry the Amulet of the Deep
- Dynamic torchlight, firelight, fire-vent traps, and synthesized sound and music.

## Repository layout

```
game/        the Godot project (scenes, scripts, shaders, assets)
docs/        design notes, licenses, known issues, experiment report
tools/       build.sh (exports), run_tests.sh (automated playthrough), make_audio.py (sound synthesis)
```

## Build and test

```bash
GODOT=/path/to/godot tools/build.sh all        # export Windows / Linux / macOS into builds/
GODOT=/path/to/godot tools/run_tests.sh flow   # scripted playthrough to victory, with screenshots
GODOT=/path/to/godot tools/run_tests.sh shots  # screenshot tour of every area
```

The test drives the real game through input actions (movement, mouse-wheel zoom, attacks, interaction) and writes `results.json` plus screenshots.

## Docs

- [docs/DESIGN.md](docs/DESIGN.md): the adventure, systems, the river chamber, and decisions and substitutions
- [docs/LICENSES.md](docs/LICENSES.md): dependencies, asset sources and licenses
- [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md): what's rough or unfinished
- [docs/EXPERIMENT_REPORT.md](docs/EXPERIMENT_REPORT.md): how the overnight autonomous build went

## Credits

- Characters, weapons and dungeon props: **KayKit** by Kay Lousberg (CC0)
- Textures: **Poly Haven** (CC0)
- Shaders, level, Warden, sound and music: original, made for this project
- Code: MIT

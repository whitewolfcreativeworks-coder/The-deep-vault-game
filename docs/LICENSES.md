# Dependencies, assets and licenses

Everything shipped in this repository can be used, modified and redistributed.
No third-party asset in the game requires attribution, but credit is given below anyway.

## Software

| Component | Version | License | Used for |
|---|---|---|---|
| [Godot Engine](https://godotengine.org/) | 4.5.1-stable (official build) | MIT | Engine, rendering (Forward+ / OpenGL fallback), GDScript |
| Jolt Physics (built into Godot 4.5) | bundled | MIT | 3D physics (`physics/3d/physics_engine="Jolt Physics"`) |
| Godot export templates | 4.5.1-stable | MIT | Windows / Linux / macOS builds |
| Python 3 + NumPy | 3.x / 2.x | PSF / BSD | `tools/make_audio.py` (offline sound synthesis, not shipped) |
| Mesa llvmpipe / lavapipe | 25.2 | MIT | Software rendering for automated screenshots in the dev sandbox only |

Not used (evaluated, see `docs/DESIGN.md`): Blender, Godot Voxel Tools, glslViewer, Taichi, the separate godot-jolt extension (Jolt is now built in).

## Art assets

| Asset | Source | License | Where in repo |
|---|---|---|---|
| KayKit Character Pack: Adventurers 1.0 (Knight, Barbarian, Mage, Rogue, Rogue Hooded, swords, shields) | Kay Lousberg, <https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0> | CC0 1.0 | `game/assets/kaykit/adventurers`, `game/assets/kaykit/items` |
| KayKit Character Pack: Skeletons 1.0 (Minion, Warrior, Rogue, Mage, weapons, shields) | Kay Lousberg, <https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0> | CC0 1.0 | `game/assets/kaykit/skeletons`, `game/assets/kaykit/items` |
| KayKit Dungeon Remastered 1.0 (props: torches, chests, barrels, banners, pillars, ruins…) | Kay Lousberg, <https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0> | CC0 1.0 | `game/assets/kaykit/dungeon` |
| KayKit Medieval Hexagon Pack 1.0 (trees, rocks, mountains, mine entrance, buildings, bridge, tents, props) | Kay Lousberg, <https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0> | CC0 1.0 | `game/assets/kaykit/forest`, `game/assets/kaykit/halloween` (graves, crypt, coffins, fences, candles: Ghost Knight Castle) |
| KayKit Character Pack: Adventurers 2.0 (the Knight, Mage, Ranger, Rogue, Engineer and Barbarian heads, used as the modelled hair styles) | Kay Lousberg, <https://kaylousberg.itch.io/kaykit-adventurers>; copied from <https://github.com/GeorgeQLe/assets-kaykit-3d-characters> | CC0 1.0 | `game/assets/kaykit/adv2` |
| KayKit Halloween Bits 1.0 (autumn pines, dead trees, arch gate used as the portal, lanterns, skull posts, pumpkins) | Kay Lousberg, <https://github.com/KayKit-Game-Assets/KayKit-Halloween-Bits-1.0> | CC0 1.0 | `game/assets/kaykit/forest` |
| KayKit Restaurant Bits 1.0 (round table, plates, jars, dish rack, pan, cutting board, bread, cheese, vegetable crates; used in the cabin kitchen) | Kay Lousberg, <https://github.com/KayKit-Game-Assets/KayKit-Restaurant-Bits-1.0> | CC0 1.0 | `game/assets/kaykit/kitchen` |
| KayKit character collection: Mystery Monthly characters (Dino/Monster costume, Werewolf, Vampire, Clown, Ninja, Robots, Witch, Caveman, Superhero, Space Ranger, Toy Soldier, Animatronic bears, Avian Swordsman, Tiefling, Plant Warrior, Helper, Magical Girl, Lorekeeper, Driver, Action Figure, Combat Mech, Farmers, Hiker, Survivalist, Cleric, Hoarder, Paladin) and Skeletons 1.1 (Necromancer), used as costumes and armour outfits | Kay Lousberg (kaylousberg.com), CC0 per the included KayKit license file; copied from <https://github.com/GeorgeQLe/assets-kaykit-3d-characters> | CC0 1.0 | `game/assets/kaykit/costumes` |
| Poly Haven textures: `castle_brick_07`, `cobblestone_floor_08`, `rock_wall_08` (1k diffuse / normal / roughness) | <https://polyhaven.com> | CC0 1.0 | `game/assets/textures` |

The original license files are kept next to the assets (`game/assets/kaykit/LICENSE_*.txt`).
Courtesy credits: *KayKit by Kay Lousberg (kaylousberg.com)* · *Textures from Poly Haven (polyhaven.com)*.

## Original work created for this project (CC0, same as the repo's MIT code)

- All shaders in `game/shaders/` (procedural masonry, luminous river, mist, waterfall, rune circles).
- All 26 sound effects, ambience loops and music in `game/assets/audio/`, synthesized by `tools/make_audio.py`.
- The Vault Warden boss model and its animation (procedural, `scripts/player/humanoid.gd`).
- All level geometry, lighting, particles and UI (built in code).

## Code

The project code is MIT licensed (see `LICENSE`).

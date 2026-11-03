# Experiment report: Project 001, overnight autonomous build

*Written by Claude (Opus 5.5) at the end of the session. It is meant to be candid about what worked, what didn't, and what was actually verified.*

**Headline:** in about 1.5 hours of wall-clock time, starting from an empty repo, the environment produced a complete, exportable dungeon crawl (an estimated 15–25 minutes for a human player; not yet timed) with a boss and a victory screen. It passes a 29-check automated playthrough. A human still needs to play it on real hardware.

## Timeline (Nov 2, 2026, Pacific time)

| Time | Event |
|---|---|
| 16:52 | Brief received. Surveyed the sandbox environment. |
| 16:55–16:58 | **Human input:** created the GitHub repo (with the Godot `.gitignore` and MIT license) and approved running Godot and installing packages. These were the only interventions needed. |
| ~17:00 | Godot 4.5.1 downloaded and verified to render. Software Vulkan installed so Forward+ (volumetric fog) could be screenshot-tested. Export templates downloaded in the background. |
| ~17:05 | Asset-scout agent dispatched while the core code was written. It reported back with CC0 KayKit packs and Poly Haven textures. |
| ~17:15 | Compared KayKit rigs against the procedural humans in rendered lineups, then switched characters to KayKit. |
| ~17:30 | First full launch: 18 checks passed through the armory on the first try, with no crashes. |
| 17:30–18:05 | Three test-and-fix rounds (see below). Run 2 scored 23/28, run 3 scored **29/29**. |
| 18:10–18:20 | Exported Windows, Linux and macOS builds. Pruned unused assets so every build fits under GitHub's 100 MB file limit. Tested the exported Linux build, captured a screenshot tour of every area, and published. |

### Iteration log (bugs the automated tests caught)
- The HUD vignette read an unset shader uniform, which produced 207 runtime errors per run. Fixed.
- **River damage flag:** four river segments each overwrote the player's "in river" flag, so wading never registered. Fixed by having the player query every river.
- **Chest loot:** it spawned behind wall-facing chests, so the armor upgrade could not be collected. It now pops out toward the player.
- **Spell test:** the cast was blocked by a still-running sword combo. That is correct game behaviour; the test was fixed.
- **Lighting:** screenshots showed the entry hall and armory nearly black, so ambient and torch light were raised. The river's glow fog washed out the screen while wading, so its density was reduced.
- **Boss:** the first version died in about 15 seconds to the bot, so HP went from 760 to 1700 and it gained 20% damage reduction. It now lasts about 31–33 seconds of game time against a relentless, invulnerable bot, which takes 294–381 damage (roughly twice its maximum HP).
- **macOS export:** it needed ETC2/ASTC texture import enabled, and was 100.7 MB. Removing 160 unused props brought it to 90.5 MB.

## Environment findings

- **Machine**: Ubuntu 24.04 VM with 2 vCPU, 8 GB RAM and **no GPU**. Xvfb is present and passwordless `sudo` works.
- **Network**: through an allowlisting proxy.
  - Reachable: github.com (including release downloads and git), PyPI/npm, Ubuntu apt mirrors, dl.polyhaven.org.
  - Blocked: api.github.com, kenney.nl, quaternius.com, api.polyhaven.com, ambientcg.com.
- **GitHub CLI**: the preset token was invalid. Repo access worked through the session's GitHub integration once the user created the repo.
- **Rendering**:
  - Mesa *llvmpipe* (OpenGL 4.5) worked out of the box.
  - Installing `mesa-vulkan-drivers` added *lavapipe*, so **Godot's Forward+ renderer runs in software**. Volumetric fog, SSAO and glow could be screenshot-verified.
  - Frame rates in the sandbox are about 2–8 fps, so screenshots prove the image but not the real-time feel.

## Which technologies integrated successfully

| Technology | Result |
|---|---|
| Godot 4.5.1 (official binary) | Smooth. Headless import, scripted runs under Xvfb, and exports all worked. |
| Jolt Physics (built in) | Worked with a one-line setting. Used for characters, Warden debris and loot. |
| KayKit CC0 glTF characters and props | Imported cleanly with skeletons and 76–95 animations each. Weapons attach to the `handslot` bones. |
| Poly Haven CC0 textures | Worked, used as world-space triplanar materials. |
| Godot shaders and particles | The custom river, mist, waterfall, rune and masonry shaders all ran on both renderers. |
| Python/NumPy audio synthesis | Worked. All 26 sounds were generated in about a second. |
| Blender, Voxel Tools, glslViewer, Taichi | **Not used.** None was needed, and each would have added risk without improving the first build. |

## What required extra configuration

- Software Vulkan: `apt-get install mesa-vulkan-drivers` (sandbox only).
- Export templates: a separate ~1 GB download, unpacked to `~/.local/share/godot/export_templates/4.5.1.stable/`.
- `godot --check-only` can't see autoload singletons, so it was useless here. Real launches under Xvfb were the only reliable compile check.
- The KayKit dungeon pack mixes `.gltf.glb` and `.glb` names, so the prop loader handles both.

## Delegation

- **One sub-agent** was used, for asset scouting, in parallel with core coding. It took about 12 minutes and produced exactly what was needed: licenses verified, files inspected, and animation lists extracted. This was the highest-value delegation of the night, because it changed the character approach.
- Core gameplay was written by a single agent on purpose. The systems are tightly coupled (the player, character model, enemies and world all share one animation-input contract and one set of collision layers), and parallel edits would likely have conflicted.
- Delegation that would work well next time: an independent **review agent** that reads the code against the brief; an agent that hunts for **balance and edge cases** using the test harness; and separate agents per **room art pass** once the layout is frozen.

## What was verified, and how

See the results table below, filled in from `tools/run_tests.sh flow`. It is a scripted playthrough that drives the game through real input actions: WASD and jump; mouse-wheel events for zoom; attack, spell and interact actions.

**Final run: 29/29 checks passed with 0 script errors** (`docs/test_results_flow.json`), and the **exported Linux build passed the 5/5 boss scenario** (`docs/test_results_exported_linux_boss.json`).

| Verified automatically | Evidence |
|---|---|
| Project imports; main scene launches; title and character creator render | screenshots `01`, `02` |
| WASD movement, sprint, jump | `movement_wasd` 4.4 m, `jump` +1.0 m |
| **Mouse-wheel zoom into first person and back out to third** | `camera_first_person` zoom 0.00, `camera_third_person` zoom 5.36, screenshots |
| Inscriptions, chests, loot pickup, potions, gold | `interact_inscription`, `chest_loot_pickup` |
| Skeletons rise from the floor; melee combat kills; XP; level-up | `skeletons_awaken`, `melee_combat_kills` 3, `level_up` → 2 |
| Enemies damage the player (no god mode in the first fights) | `player_took_damage` |
| Arcane bolt | `spell_cast` |
| Fire vents hurt; lever opens the gate and disables the vents | `fire_trap_damage` 118→88, `lever_opens_gate` |
| Armory cleared, including the Revenant; sword and armor upgrades auto-equip | `armory_cleared_incl_revenant`, `weapon_upgrade_equipped`, `armor_upgrade_equipped` |
| The river burns without the amulet and heals with it | `river_burns` 130→106, `amulet_river_heals` 73→88 |
| Boss wakes, seals the gate, fights (phase 3 reached), dies, reopens the gate | `boss_*` checks, screenshots `10`, `11` |
| Claiming the Heart triggers the victory screen | `victory`, screenshot `12` |
| Exported Linux binary runs the boss fight | separate run on `builds/linux` |

Several later stages ran with the bot made invulnerable (`god` flag in `autotest.gd`) so a single run could reach the end. Those checks prove the mechanics work; they say nothing about difficulty. Death and respawn are implemented, but **no automated test covers them**.

## What could not be verified

- **Real-time feel**: frame rate on real hardware, mouse sensitivity, input latency, and how combat *feels*. The sandbox renders at a few fps, so a human has to play it.
- **Audio**: there's no sound device in the sandbox (Godot used its dummy driver). The sounds were generated and load without errors, but nobody has *heard* them in-game.
- **Exported builds on Windows and macOS**: the exports were produced but not launched. The macOS build is unsigned (Gatekeeper will ask; right-click → Open).
- **Gamepad**: input actions are mapped but untested.

## What would improve a second experiment

1. Give the sandbox a GPU, or at least more CPU cores. Software rendering made every test slow, around 10–20 minutes per full playthrough.
2. Supply character assets up front, or allow more asset hosts, and decide on the art style before the night starts (realistic versus stylised).
3. Ask for a short human playtest checkpoint partway through. Feel and balance are where automated testing is weakest.
4. Have the repo created with the GitHub token working in advance, so the agent can create releases and attach builds itself.

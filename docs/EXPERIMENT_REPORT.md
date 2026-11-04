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


## Follow-up after the first human playtest (iPad, same evening)

**Feedback:**
- Looking around in tight rooms and corridors felt glitchy, and it was hard to get a sense of the space.
- The Mage's spells were unimpressive.
- Combat lacked strategy.

**Camera changes, based on standard third-person camera practice and Godot's jitter guidance:**
- The camera now updates every rendered frame instead of every physics tick. The player body uses Godot's physics interpolation so it glides smoothly on 60 and 120 Hz screens.
- **Look input is smoothed** (light for mouse, more for touch). Touch has a gentler vertical response and an acceleration curve. Pitch is limited to about ±60° so a swipe can't flip you from floor to ceiling.
- **Wall collision:** a sphere cast pulls the camera in almost instantly when it hits a wall, then **waits 0.55 s and eases back out slowly**. The old SpringArm snapped both ways.
- The shoulder offset shrinks when squeezed, the head hides when the camera is close, and the view auto-levels toward the horizon while you travel.
- Slightly wider field of view (74° in third person, 80° in first person), a small sprint FOV kick, and subtle first-person head bob.
- The fire-vent corridor was widened from 4 m to 5.5 m.

**Measured** with a new `camera` autotest. It walks four tight spots while sweeping the view, at 3.6 m and 6.5 m zoom, and runs the same test on both versions:

| | Original camera | New camera |
|---|---|---|
| Camera distance pumping in/out (average) | ~3.7 m/s | **~1.7 m/s** |
| Pull-in/push-out cycles (total) | 59 | **38** |
| Aim jerk | baseline | about 12% lower |

The sandbox renders at about 7 fps, so these numbers can't capture the frame-rate-related part of the fix. Only a playtest will show it.

**Not addressed yet:** per-hero spells and deeper combat, and an open-world direction. Both are proposed for the next session.

**Second playtest note: moving one way while looking another felt glitchy.** In third person the character always turned to face its movement direction, so pulling the stick back spun it round to face the camera. Strafe movement is now the default:
- The hero faces the camera direction and moves freely relative to it.
- Sideways movement plays the sidestep (`Running_Strafe_Left/Right`) animations; backward movement plays `Walking_Backwards`.
- Sidestepping is slightly slower than running forward (about 10%), and backpedaling slower still (about 28%).
- "Free" movement (face where you run) is still available in the pause menu.

New automated checks:
- `strafe_right_faces_camera`
- `backpedal_keeps_facing`
- `move_and_look_no_flip`, which runs forward-left while swiping the view; the worst deviation between body and view was 0.00 rad.

### Third playtest (iPad): "can't do both thumbs at once", flicker close to walls, stuck in pits

Each issue was first measured on the old build with a new `feel` autotest, then fixed and re-measured with the same test:

| Check | Before | After |
|---|---|---|
| Animation flips while backpedalling left and swiping right (3 s) | 4 (it even played *walking forward*) | 1 |
| Character off-centre, worst / mean | 0.19 / 0.04 rad | 0.15 / 0.04 rad |
| Frames with the camera inside a wall, hugging walls and pillars | 1 / 246 | 0 / 244 |
| Overlapping same-plane surfaces (z-fighting flicker) | **151** | **0** |
| Jump out of the river with no stamina | stuck until death | out in 0.6 s |
| Attack button radius | 78 px | 94 px (all buttons about 20% larger, no overlaps) |

**Fixes:**
- **Two thumbs at once.**
  - Safari treats two moving fingers as a page pinch-zoom, so the web page now blocks Safari's gesture, multi-touch scroll and double-tap zoom handling. This is the probable main cause, and it can only be confirmed on a real iPad.
  - Movement is now relative to the view actually on screen, not the target view.
  - The camera follows the body tightly side-to-side. Each finger's swipe is measured independently.
  - Walk, backpedal and sidestep are chosen from the stick direction with hysteresis, so they no longer flicker.
  - "Compatibility" mouse events that Safari synthesizes after a touch are ignored.
- **Flicker near walls.**
  - Builder now runs a z-fighting pass that nudges one face of every overlapping coplanar pair by 1–2 cm.
  - The camera near plane went from 0.04 to 0.08 m for better depth precision.
  - The camera now sweeps from the head out to its shoulder position before sweeping backwards, so hugging a wall can't start it inside the wall.
  - When a wall squeezes the camera in, it rises over the shoulder instead of pressing into the helmet.
- **Pits.**
  - Jumping no longer needs stamina. Standing in the burning river blocked stamina from refilling, which caused the trap.
  - Added coyote time (0.14 s) and jump buffering (0.18 s).
  - New **ledge climb**: press jump facing a ledge up to 2 m high.
  - The river and pool beds were raised from 1.5 m to 1.0 m deep.

**Renamed** to **Bobek's Adventure**. The random-name button now offers twenty variations of "Bobek".

### Fourth playtest (the designer's son): "ran out of potions and mana at the Warden, gear never changes"

**Added:**
- Random rarity loot from monsters and 13 chests, plus a boss reward chest
- Skins that transform the hero
- Gear that changes the hero's look
- Mana potions
- Mana regeneration doubled
- Sword hits that recharge mana
- Bigger, rarity-coloured spell bolts with spell power
- Life steal and critical-hit bonuses
- A rarity inventory with comparisons and salvage

**Loot test (`loot` autotest):**
- **Rarity spread over 2,000 rolls:** 998 Common, 479 Uncommon, 414 Rare, 86 Epic, 23 Legendary. Rare is inflated because skins are always Rare or better.
- **Opening every chest:** 17 healing draughts, 11 mana potions and 15 pieces of gear.
- **Monster drops:** over 200 kills, 159 potions and 73 items.
- **Mana:** four sword swings restored 28 mana.

**Boss balance without cheats (`balance` autotest).**

The first bot dodged every telegraph perfectly and beat the old Warden even with starting gear in seconds. The test bot was changed to play more like a person: it reacts to only about half of the Warden's slams and pauses between swings now and then.

The Warden was then tuned:
- health: 1700 → 3000
- swipe damage: 26 → 32
- slam damage: 36 → 44
- leap damage: 40 → 50
- summons twice instead of once

In the "geared" setup the bot is level 4 with everything a player would find before the boss, having drunk half its potions on the way down.

| Setup | Result | Damage taken | Lowest health | Potions used |
|---|---|---|---|---|
| Geared, seed 7 | won in 48 s | 339 (1.3× max health) | 38% | 1 |
| Geared, seed 42 | won in 62 s | 416 (2.1×) | 39% | 1 |
| Geared, seed 21 | won in 61 s | 420 (1.9×) | 29% | 3 |
| Starting gear, seed 21 | **died**, Warden at 59% | 439 | 0% | all |

A human player swings less relentlessly than the bot, so expect longer fights and more potions than this.

## Follow-up 3: cover art, character looks and hero specials (Nov 3)

**Requests:**
- Use the player's own artwork (green-hooded Rogue, "Bobek's Adventure" logo) as the app icon.
- Expand the character creator: hairstyles, hair colour, skin colour, fat/skinny, tall/short, and small face details.
- A special-ability button with a different move per hero.

**What was built:**
- The artwork is the project icon. The web export turns it into the iPad Home Screen icon (`index.apple-touch-icon.png`). It is also the loading screen, the title art and the tap-to-begin screen.
- **Looks:**
  - The recolour shader finds skin and hair texels in KayKit's shared texture atlas. It converts the sampled linear colours back to sRGB first; the first version compared linear values against sRGB thresholds and matched nothing.
  - Hair styles and face details are procedural meshes on the head bone, sized from each hero's head bounds.
  - Build and height scale the model, and first-person eye height follows height.
- **Specials:** one per hero, defined in `Game.ABILITIES` and implemented in `player.gd`. They use key X, right-stick click, or a purple touch button with a cooldown ring.

**How it was verified:**
- The `looks` autotest renders close-ups of all 5 heroes × 8 combinations from the front and the side. These close-ups were used to tune the pieces. One bug they caught: the test camera was looking at the backs of the heads.
- The `ui` autotest checks that custom looks appear in the game.
- The `special` autotest puts each hero in front of real enemies and confirms the ability works (19/19 checks):
  - Backstab lands behind the target for over 3× damage.
  - Shadow Step moves 11 m and damages the enemy it leaves behind.
  - Shield Charge moves and hits.
  - Whirlwind hits all 3 surrounding enemies.
  - Volley hits both targets.
  - Every ability goes on cooldown, and the cooldown blocks reuse.
  - Backstab with no target does nothing and costs no cooldown.

## Follow-up 4: hair colour bug, creator redesign, block and parry, camera (Nov 3, evening)

**Bug found by the human playtest that the automated checks missed.** Hair looked "all white" on the iPad. The cause was renderer-specific:
- The web/iPad build uses Godot's Compatibility (OpenGL) renderer. It hands `source_color` textures to the shader still in sRGB.
- The desktop Forward+ renderer hands them over in linear.
- The recolour shader converted linear to sRGB before testing for skin. On the web, that double conversion made the face texels fail the skin test and get recoloured as hair, so white hair meant a white face.

All earlier looks screenshots were rendered with Forward+, so the bug stayed hidden. Fixes:
- The shader takes a `tex_is_srgb` flag that is set from the active renderer.
- The creator preview gets gentler lighting on the web renderer, because it has no AgX tone curve and the same lights wash pale colours out.

The looks test is now also run with `--rendering-method gl_compatibility`. **Lesson for the next experiment:** render-check on the renderer the players actually use.

**Other changes:**
- **Creator:** five tabs. The face zooms in for the hair and face tabs, the preview can be dragged to spin, and the swatches and sliders are bigger.
- **Block:** it raises instantly and cancels a swing, fully stops frontal hits, and has a 0.35 s parry window.
- **Camera:** three-step view cycle (first person, behind, high) with an overhead tilt past 4.5 m. A "crane" lifts the camera over walls behind the hero.
- **Weapons:** 1.45× longer, with slash trails.

**Tests:**
- New `combat2` test, 5/5. Holding block takes 0 damage from 3 hits, a timed block parries, block cancels a swing, and the view button cycles.
- **Test-harness lesson:** taps of 1–2 frames can fall between physics ticks and never register. Test presses now hold for 0.07 s or more, like a real thumb.

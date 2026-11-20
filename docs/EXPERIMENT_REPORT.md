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

## Follow-up 5: touch layout and zoom (Nov 3, night)

**Playtest findings:**
- Pinch-zoom out of first person "didn't work".
- The right thumb had nowhere to steer without hitting buttons. The Mage player kept blinking by accident.

**Cause of the pinch problem:** a pinch only registered if both fingers began in the free gaps between buttons on the right. A finger on the left half became the joystick instead. The test passed because it pinched in an empty area.

**What changed:**
- A second finger near the first is now always treated as a pinch.
- Pinching out of first person jumps straight back behind the hero.
- An always-visible zoom slider sits on the left edge.
- New default layout: the combat cluster hugs the bottom-right corner, and potions and the view button moved to the top row. Button hit areas are exact circles instead of 1.15× circles, so near misses become camera drags.
- Players can move buttons themselves. Holding a button still for 1.2 s picks it up; ATTACK and BLOCK are excluded because they're held in normal play, but they can be moved in "Arrange" mode in the pause menu. Positions are saved to `user://touch_layout.cfg`, which is IndexedDB on the web.

**Tests:** the `touch` test grew to 24/24. It now covers:
- the slider
- pinching out of first person with one finger on the left half
- hold-to-move, saving, arrange mode and reset

It also found two stale tests that still looked buttons up by list position. Buttons are now looked up by name.

## Follow-up 6: save slots (Nov 4)

**Request:** keep up to three characters and continue where you left off after closing the app.

**How it works:**
- Each slot is a Godot text-variant file, `user://save_N.sav`. That format keeps Vector3 values and the generated loot dictionaries without any extra conversion code.
- A save holds: the profile, stats, items, inventory and equipment, the world `flags`, the checkpoint, the objective, and the last safe spot (on the floor, not in the river).
- Continuing loads the slot, then reloads the scene. Chests, gates, levers and enemies already read `flags` when they are built, so no other world code had to change.

**Tests:**
- `saves` autotest, three phases across scene reloads, all checks pass. Phase 1 plays, levels up, loots and kills an enemy, then saves. Phase 2 continues and checks that level, gold, items, position and the dead enemy came back, then uses Save & exit. Phase 3 checks the title's Continue button and the slot cards.
- `tools/web_save_test.js` runs the web build in headless Chrome. Visit 1 saves, the browser closes completely, and visit 2 with the same profile finds the save and the Continue button. This confirms that `user://` persists to IndexedDB in the browser build.

## Follow-up 7: Level 2, the Goblin Forest (Nov 4)

**Request:** a second level that feels like open roaming through a goblin forest. It should have a portal with a dungeon entrance in view of it, five NPCs that introduce quests, and one dungeon in the zone.

**What was built:**
- **Assets:** KayKit has no forest pack on GitHub (theirs is on itch.io, which this workspace can't reach). Two CC0 packs that *are* on GitHub covered it instead: the Medieval Hexagon Pack and Halloween Bits.
  - The Hexagon models are miniature (a tree is 1.2 units tall) and are scaled about 6×.
  - Halloween Bits is roughly life-size.
  - About 650 trees and rocks are drawn with MultiMesh, with cylinder trunk colliders on one shared static body.
- **Terrain:** a procedural height field: noise hills, a flattened road and clearings, a stream bed, a ridge in the north, and rising edges. It is drawn as one vertex-coloured mesh with a noise-detail shader, with a matching `HeightMapShape3D` for collision.
- **Goblins:** no goblin models were available, so goblins are built on the KayKit hero rigs. They use the character-creator machinery: green skin via the recolour shader, mohawk or bald hair, warpaint, small scale, plus a new `ears` option. All existing enemy AI, animation and loot code was reused unchanged.
- **Quests:** definitions live in `Game.QUESTS`. Quest state is saved in the slot, kill events come from `Enemy._die`, and collectible quest items show only while their quest is active.
- **NPCs:** `NPC` reuses `CharacterModel`, with a `Label3D` name and marker.
- **Levels:** `Game.zone` decides whether `main.gd` builds `VaultWorld` or `ForestWorld`. The Vault's victory screen offers the portal, which uses the same rebuild-from-save path as Continue.

**Bugs found by the new `forest` test before shipping:**
- **Instant death in the Warren:** the Warren sits at y = −60, below the Vault-era "fell out of the world" plane at −40. The kill plane is now per level.
- **Warren not visible from the portal:** fog hid it at 190 m, so the fog was pushed out and a beacon fire added on the ridge. The test now ray-casts from the arrival camera to the beacon.
- **Mine entrance backwards:** the model faced away from the road.
- **Quest items:** they toggled `monitoring` inside a physics callback, so that is now deferred.

**Tests:** the `forest` test covers the whole chain end to end, across three phases and a scene reload. It checks:
- the portal transition and the five NPCs
- line of sight to the Warren
- every quest: accept, progress, hand-in and rewards
- the barred door, the Warren, Gruk's summons, the strongbox and the forest-victory screen
- saving and continuing in the forest

`forestshots` is a quick visual tour, also run with the web renderer.

## Follow-up 8: opening movie, walk-in portal to Level 2, Surprise me! (Nov 4)

**The opening movie** (`scripts/world/intro.gd`) is built from game parts, not pre-rendered video:
- It has its own small valley (terrain, mountains, about 140 trees, the cabin with chimney smoke) and a separate cabin-interior set built from boxes and KayKit props.
- It uses the player's own character, with a pajama recolour and then their real outfit.
- The KayKit rigs' Lie / Sit_Chair / Use_Item / Interact / Cheer clips cover the morning routine. One new hook, `CharacterModel.hold_clip`, keeps a pose held.
- Camera moves are tweens, captions sit in a letterbox overlay, and there is a Skip button.
- New synthesized sounds: birdsong, a whistled tune, a kettle whistle, brushing, sips, a stone rumble, a portal whoosh, and a morning theme.
- While the movie plays, the Vault world is removed from the scene tree, so its environment and physics don't interfere.

**The end of Level 1** is now diegetic instead of a menu:
- Claiming the Heart opens a hidden door behind the altar: it slides into the floor with a rumble, dust and camera shake. Behind it, an ancient portal (the same arch as in the movie and the forest) lights up, and walking into it travels to Level 2.
- The `flow` test now ends by walking into the portal. A second phase, after the scene reload, checks that you arrive at the forest portal.

**Tests:**
- `intro` checks that all the shots play, that the movie is short, and that you end at the Vault outpost.
- `introskip` checks the Skip button.

## Follow-up 9: a shorter, better-looking opening movie (Nov 4)

**Request:** make the intro shorter and nicer to look at.
- Put the portal near the cabin, on a path that makes sense, and make it an ordinary family portal rather than a discovery.
- Use cameras that show the face, not the back of the head, especially while brushing teeth.
- Add striped pajamas, a stretch, a proper teapot, and the full tea routine (pour, steam, tea bag, about 3 s wait, stir, turns brown, drink).
- Beam the hero away in a light effect, and arrive at a portal in a side area of the Vault outpost.

**What changed:**
- `intro.gd` is rewritten as seven shots, about 40 s.
- Every indoor camera sits in front of the hero:
  - the wake-up is filmed from the foot of the bed;
  - the tooth-brushing is filmed from the mirror's point of view;
  - the tea is filmed from across the table.
- The hero is scaled to 0.72 indoors so he fits the furniture.
- **Stripes:** the recolour shader gained `stripes`/`stripe_color` uniforms, which give striped bands in model space. `CharacterModel` passes them through with a new `outfit_stripes` config key.
- **Teapot:** built from primitives (body, band, lid, knob, angled spout, loop handle).
  - The pour tilts it about its own side axis.
  - A water stream is stretched from the computed spout tip to the cup.
  - The cup is open-topped, so the tea's colour tween (clear to brown) is visible. Steam rises from the cup.
- **Portal:** about 13 m from the door, at the end of a worn dirt path painted into the terrain colours. The arch's iron gates are hidden, so it reads as an open archway.
- **Beam-out:** a light pillar, rising sparkles and a burst. The hero flashes, stretches thin and lifts, then the screen flashes white.
- **Vault side:**
  - The arrival portal moved from behind the spawn to the west side area, with a cobbled path through the gap in the ruined wall.
  - The hero now spawns inside it, facing the gate (`VaultWorld.spawn_yaw`, also used for the checkpoint), and beams in with a matching pillar and flash.

**Bug found by screenshots:**
- Two overlapping camera tweens fought each other: the previous shot's move was still running when the next shot started.
- In the teeth shot this pointed the camera at the kitchen, so the hero was off-screen.
- Fix: `_cam()` now kills the previous camera tween.
- Lesson: frame-by-frame contact sheets (`INTRO_FRAMES=1` env var on the `intro` test) caught this immediately, where the pass/fail checks did not.

## Follow-up 10: compass and quest arrow, morning-routine polish, stock assets (Nov 4)

**Request:**
- "Go north" meant nothing without a compass, so add a compass whose outer ring carries a quest arrow for the quest you're on.
- Let the player choose the quest (or have one auto-assigned).
- Fix the intro's missing toothbrush and foam, make the tea routine look right (steam, a whistle when ready), and keep it short.
- Look into libraries of ready-made models instead of hand-building cups and plates.

**Compass** (`scripts/ui/compass.gd`, drawn with `_draw()`):
- The dial turns with the camera's heading. North is world −Z, which matches the forest sign ("road north: the Warren").
- `quest_target()` resolves the followed quest each 0.4 s:
  - ready → the giver NPC;
  - collect → the nearest visible quest item of that kind;
  - kill → the nearest living goblin on your level;
  - boss → Gruk.
- When the target is in the Warren (60 m underground) and you're not, it points to the Warren door instead, and to the climb-out when it's the other way round.
- **Quest choice:**
  - `Game.tracked_quest` and `tracked_manual` are saved in the slot.
  - Accepting a quest follows it. Tapping a quest row, tapping the compass, or pressing T changes it.
  - With nothing followed, it picks hand-ins first, then the nearest target.
  - Touch taps reach the HUD through `TouchControls`, which asks `HUD.tap_at()` before treating a touch as move or look.
- **Test:** a new `compass` test (15 checks):
  - the dial turns;
  - the arrow appears only on a quest and goes to the nearest axe, the nearest goblin, and the Warren door for the strongbox;
  - tap-to-follow and T work;
  - the distance drops as you walk;
  - the arrow is at the top when you face the target;
  - a ready quest points to the giver;
  - a finished one auto-picks another;
  - the choice is saved.

**Intro polish:**
- **Teapot and teacup** are turned on a "lathe": `_lathe()` revolves a profile into a smooth mesh, and `_tube()` sweeps a tapered tube along a curve for spouts and handles. They are glazed china with blue bands. The cup has real wall thickness, so the tea's colour change shows inside it.
- **Toothbrush:**
  - It is attached to the head bone at the mouth, which is found from the head mesh's bounds, and scrubs side to side.
  - Toothpaste foam swells around the mouth, then a sparkle at the end.
  - Before, it was attached to the hand slot, where the chibi fist swallowed it.
- **Kettle:** it rumbles ("Bubble, bubble..."), the lid rattles, steam builds from the spout tip, then the whistle.
- **Sounds:** a new kettle sound (boil rumble rising into a two-tone whistle), a pour sound whose pitch rises as the cup fills, and spoon clinks for the stir.
- **Bug found:** `_steam()` added the particles to the movie node and the callers then tried to re-parent them under the teapot/cup. Godot refused ("already has a parent"), so all the steam had been emitting at the world origin, out of shot. The error was in the log all along. Lesson: grep test logs for `ERROR: Can't` as well as for test failures.
- **Bug found:** semi-transparent steam rendered a black blob at the spout on this renderer. Isolated with a 20-line render script (glow on/off, steam on/off), then switched steam to additive blending.

**Stock assets: what's reachable.**
- From this sandbox, GitHub is reachable but Poly Haven, Kenney, Quaternius, Sketchfab and Poly Pizza are blocked by the network allowlist.
- KayKit publishes its packs on GitHub, so **KayKit Restaurant Bits** (CC0) was added. Its round table, plates, jars, dish rack, pan, cutting board, bread, cheese and vegetable crates now dress the cabin kitchen.
- It has no teapot or teacup, hence the lathe-built ones.
- See the README for the libraries worth using if those sites become reachable (or if files are attached).

## Follow-up 11: playtest notes from the designer's son (Nov 4)

**Notes:**
- The quests and goblins were too easy.
- The hair looked funny (he did like the buns and spikes); find real hair models.
- Add a second forest dungeon, "the Sinkhole of Death": accepting the quest makes the ground open underneath you; red, fiery caverns; a Cyclops goblin boss; a giant funny chicken as your first mount.
- Add a day/night cycle with 7-minute periods.
- The mage hat is too big and blocks the view zoomed in.
- He didn't realise USE was needed, so it should get bigger when it applies.

**How the work was split:**
- The hair and the mage hat went to a parallel agent working in its own git worktree, and only those files.
- Everything else was built in the main checkout, then the branch was merged. It merged with no conflicts, after one housekeeping fix: the worktree folder had to be added to `.gitignore`.
- The agent was told not to run the save-file tests, because both copies share the same `user://` save slots.

**Hair:**
- KayKit Adventurers 2.0 (CC0) is on GitHub, and its rig is identical to 1.0's: same head bone and rest pose.
- So a hair style hides the hero's own head and attaches an unskinned copy of a 2.0 head, which has modelled hair, to the head bone. It lines up exactly.
- Hair colour: the shader recolours the one atlas cell the hair uses (`hair_rect`). Old save style names map to new ones.

**Sinkhole of Death** (`scripts/world/sinkhole.gd`):
- **The cave-in sequence** is triggered when the quest is accepted and the dialogue closes:
  - the camera shakes and the cracks widen;
  - you stumble onto the crack and the chunks fall;
  - then a fade, and you land in the caverns 140 m below.
- **The caverns** are built from the forest's room builder, re-themed red. Lava reuses the glowing-river shader in a new lava mode: always burns (the amulet doesn't help), and bounces you out so you can scramble to the bank. Plus rock spires, stalactites, embers and fire geysers.
- **New enemies:** Ember Goblin, Cinder Slinger, Magma Brute.
- **Grimgor the Cyclops Goblin:** scale 2.3, a modelled giant eye attached to the head bone, a telegraphed fire-ring stomp (a new `nova` enemy ability), and summons at half health.
- **The compass** now knows three levels (forest, Warren, Sinkhole) and points to the pit or the ladder as needed.

**Giant Chicken** (`scripts/player/chicken_mount.gd`):
- A procedural model: googly eyes, a comb that wobbles, scurrying legs, the famous head bob, and wings that flap in the air.
- The rider uses the Sit pose on the saddle. Riding speed is ×1.75 and jumps are higher.
- G or the touch RIDE button toggles it. The RIDE button appears only once the mount is unlocked.
- New synthesized sounds: cluck, BA-GAWK, cave-in, bubbling lava, the Cyclops roar.

**Day/night** (`scripts/world/day_night.gd`):
- 7-minute blocks, alternating day and night, each starting with a 90 s sunrise or sunset.
- Sun elevation, energy and colour; a moon light; sky, fog and ambient palettes; a star dome.
- The clock is saved in the slot. Underground areas switch it off.

**Difficulty:**
- Goblin HP is up about 1.6× and damage about 1.4×. Gruk now has 1150 HP.
- Fenn's quest is 6 → 10 goblins and Maera's 5 → 7 moonpetals, with three extra petal spots and goblin guards at five of them.
- The camps grew from 5 to 7 goblins.

**Tests:**
- New `daynight` test (7 checks) and `sinkhole` test (20 checks). The sinkhole test plays through: locked → unlocked → accept → fall → lava burns → boss stomp and summons → defeat → claim the chicken → ride (11.8 m in 1.5 s) → G off and on → ladder → hand in → mount saved.
- Both run in Forward+ and gl_compatibility.
- **Bug found:** the first lava damage formula killed the hero in about 1.5 s. The damage divisor amplifies at low defence, so the lava rate was halved and the bounce-out added.

## Follow-up 12: costumes, visible armour, wild chests, desktop downloads via GitHub Actions (Nov 4)

**Request:**
- Random skins from chests: some for a short time, some for days, and a new one overrides the old.
- Become a cute dinosaur, a skeleton, or NPCs from the game, with plenty of evil and dark ones.
- Loot that changes how your outfit and armour look, ideally using an existing library.
- Chests in random places with funny things around them.
- Also: was it a problem that the downloads were being split?

**The asset library:**
- A public GitHub mirror of the KayKit collection (CC0) has about 50 more chibi characters.
- Every one shares bone names with the original heroes. Rest poses were compared bone by bone in Godot: 40 match exactly; 8 "large" characters are 2 m different, so they were left out.
- **Technique:** take the character's skinned meshes and bind them to the hero's own `Skeleton3D`. Godot's glTF importer gives each Skin named binds, so they resolve by bone name. The hero's existing animations then drive any costume, with no retargeting.
- Verified by rendering all 40 costumes on the hero rig in a single line-up.

**Costumes** (`Loot.COSTUMES`, `Game.costume`):
- A chest can drop a `costume` pickup (14–60% depending on the chest). It shows as a tiny spinning figure in a rainbow beam.
- Picking it up transforms you at once. Duration is rolled: 3 or 10 minutes of play time, or 1 or 3 days of real time (compared against the Unix clock, so they keep counting while the game is closed).
- The costume is saved in the slot, expires on its own, and can be taken off in the Inventory.
- 40 costumes, 17 of them dark. The dark ones use a material finish (shadow, rot, deathly, infernal) plus a coloured aura.
- 4 costumes reuse the game's own characters (skeleton, goblin, Ember Goblin, Gruk) by building their look config.

**Outfits:**
- Every new armour item gets an `outfit` from a wardrobe for its armour type.
- The hero's body, arm, leg and cape meshes are swapped for the outfit's. The head and hair stay yours, and the outfit keeps its own colours (only your skin tone is applied).

**Wild chests** (`scripts/world/wild_chests.gd`):
- Random valid spots: off the road and stream, out of clearings, not on steep slopes, 22 m apart.
- 7 scenes, including a sleeping goblin (a dormant enemy lying down that wakes when you come close), pecking mini chickens, and a biting mimic that gives double loot.
- 7 in the forest and 2 at the outpost, with a new one every 4–5 minutes.

**Downloads:**
- The macOS zip reached about 98 MB, against GitHub's 100 MB limit for a file in a repository.
- This session isn't allowed to create GitHub Releases directly. So with the user's OK, a GitHub Actions workflow now builds the three desktop versions on GitHub's runners and attaches them to a `latest-build` Release, where files can be up to 2 GB.
- The web/iPad build was never affected; it's split into many files and served by GitHub Pages.

**Tests:** a new `costumes` test (10 checks):
- all 40 costumes build;
- the outfit files exist and armour carries an outfit, which gets worn;
- picking up a costume transforms you, and a new one replaces the old;
- play-time costumes expire, and real-time ones survive a save;
- wild chests spawn, and costumes drop from about 1 in 4 wild chests.

**Later the same evening:**
- **Pose mode.** "You never get to see what you look like."
  - P, the ME touch button, or the pause menu turns on a turntable camera: it swings to the front, auto-orbits until you drag, removes the shoulder offset, and hides the busy parts of the HUD.
  - The hero stays put; attack cycles 10 poses, jump hops.
  - Tested by the `pose` test (8 checks): the camera ends up in front and behind again, the turntable spins, and the pause-menu button works.
- **Rarity.**
  - "Full character skins should be rarer, with armour skins as common slight upgrades."
  - Costume odds dropped to 4–9% per ordinary chest.
  - New armour skins (22 looks, 7 of them dark with a material finish) drop at 30–50% from chests and 6% from monsters.
  - They sit in the skin slot, override the armour's look, carry a small defence and health bonus, and auto-equip when they score higher.

## Follow-up 13: Level 3, Ghost Knight Castle (Nov 5)

**Request:**
- quest beams over NPCs;
- a third zone that opens once every forest quest is done;
- ghost knights that drop their armour, and ghost archers;
- nine quests;
- a second mount (the moped);
- a second special ability for every class;
- zone-themed skins (50% zone / 40% fitting / 10% silly);
- an auto-run button;
- a skin designer.

**How it was built:**
- `CastleWorld` extends `ForestWorld`. It reuses the height-field terrain, the multimesh scatter and the model helpers, and overrides the land shape, the night sky, the area logic and the places. That kept the new level to about 600 lines.
- The KayKit Halloween Bits graves, crypt, coffins and candles were imported for it (all CC0).
- **Spectral enemies.** These are the KayKit hero and skeleton rigs drawn with see-through, emissive copies of their own materials. Each one also has a misty particle trail and a cold light.
- **Ghost knights' armour.** Four metal pieces bounce to the ground. There is a 35% chance (100% for the bosses) of a wearable Ghostforged / Moonsilver / Phantom armour drop.
- **Quest-driven world.**
  - The beacons light up when touched, and the mist thins when all three are burning.
  - The Gatehouse Warden only appears once his quest is accepted, so he can't be killed early.
  - The portcullis rises when he falls.
  - The Ghost Lord takes the throne once Elowen sends you.
  - Turning his quest in grants the moped and seats you on it.
- **Moped.** It is built from simple shapes (wheels, shell, handlebars, mirrors, a headlight spotlight, tail light and exhaust puffs). It has a new synthesized two-stroke engine loop and a "meep meep" horn (tools/make_audio.py). It goes 2.1× running speed. G cycles chicken → moped → off.
- **Second specials.** Holy Ward (−70% damage for 5 s, heal, knockback), Earthshatter, Smoke Bomb (enemies lose you, you dash), Rain of Arrows, and Frost Nova. Frost Nova freezes enemies in a block of ice; bosses only shiver.
- **Drops.** The castle has its own weapon and armour bases and item level 7–8. Monsters can drop costumes of themselves.
- **Delegation.** The skin designer was handed to a fork agent working in its own git worktree, in parallel with the castle work.

**Tests:** a new `castle` test runs the whole level's flow:
- the Moonlit Portal sleeps, then wakes, then carries you over;
- the beams go white, then green;
- auto-run moves you, and pulling back cancels it;
- ghost armour drops; the crypt passage works;
- the beacons light; the Warden appears and the gate opens;
- the music box is found; the Ghost Lord spawns, summons help and is beaten;
- all five second specials deal damage;
- the moped is granted, is fast and gets you off on G;
- the castle zone saves.

## Follow-up 14: Level 4, Cloud Island (Nov 6)

**Designer:** the designer's son, deciding over a few messages:
- the theme: cloud science;
- a weight meter that rains off when you stand still;
- bubbles everywhere;
- angels inspired by the Anunnaki;
- Mr. Bubbles the flying bear with lightning;
- the Dragonfly, a flying mount with stamina;
- twelve skins he cut down from a list of eighteen.

The plan was written into a project doc first and approved with "go".

**Parallel work:** a second agent built the Dragonfly in its own git worktree while the main thread built the zone. Because the session's working folder isn't a git repo, the harness's automatic worktree option failed, so the worktree was created by hand and the agent was pointed at it.

**How it's built:**
- **Islands:** flat-topped cylinder colliders dressed in puffs, all drawn as one MultiMesh of spheres with a new cloud shader. The shader has soft wrap lighting, a sunlit rim and a slow wobble; storm clouds get a darker per-instance colour.
- **New creatures:** thunder birds, storm sprites, bats, mimics, the golem, Mr. Bubbles and the sky whale are built from shapes (`CreatureLook`). Each rides on a hidden skeleton CharacterModel, so the existing enemy AI, hit flashes and animation timing still work. A new `fly` behaviour hovers, swoops to strike, and tumbles down when beaten.
- **Weight and bubbles:** the world sets a few new player fields every frame (`gravity_mult`, `jump_mult`, `fall_cap`, `lift`, `wind`). The weight meter, bubbles, updrafts and wind need nothing else from the player code.
- **Skins:** the 12 float skins are the hero recoloured, plus shape-built pieces on the head and chest bones: wings, a halo, a snout, balloons, a bubble, a jellyfish bell, a whale spout, a top hat. No new downloads.

**Tests:** a new `cloud` mode (35 checks) runs:
- the castle cloud lift and the arrival bubble;
- raindrops and raining off;
- weight changing gravity;
- the wisp bridge holding a floaty player and dropping a heavy one;
- sea-to-island and island-to-island bubble rides, updrafts and the garden;
- each new enemy; flyers hovering and falling;
- the storm layer, the Hail Golem and the vents opening;
- Mr. Bubbles: lightning bubbles, the storm dive, summons, the chest, the turn-in and the Dragonfly;
- a floaty skin, all twelve skins building, and the save.

## Follow-up 15: playtest fixes (Nov 12–13)

**Shaking camera at the start.** We measured the camera's frame-to-frame movement while the hero stood still after each arrival. At the Vault's arrival portal it moved up to 0.56 m per frame; after the forest portal and the Warren door it didn't move at all. Two feedback loops caused it:
- the "crane" that swings the camera up over a wall judged its options from its own, already tilted, view;
- the over-the-shoulder offset was scaled by how far the camera had been pushed in, which moved the camera, which changed that distance.

Both are now measured independently of the camera's current pose, and the crane only switches when another option is clearly better. Movement is now 0.000 at every arrival, including pressed against the arch. **Lesson:** measure "it feels shaky" with numbers before guessing; the first fix, moving the start spot, hid the bug rather than fixing it.

**Attack responsiveness.** Presses were silently dropped in four ways:
- in the first 45% of a swing;
- during a roll or a bolt cast;
- when stamina was below 6;
- holding the button only ever swung once.

Now a 0.4 s input buffer, hold-to-repeat, and swinging without stamina fix all four, with four new `combat2` checks.

**Abilities.**
- The Mage's Shadow Step (a blink) didn't help in a fight, so his first power is now an auto-aimed Fireball.
- The second powers moved from the castle to Cloud Island, as the designer asked.

**The bolt.** It now tiers up by level: 1, 2 or 3 bolts, bigger, recoloured, with a splash, a crackle and finally chain lightning. Each level-up announces it.

**Warren layout.** Two side caves and a totem-locked gate make the second dungeon play differently from the first. It's tested end to end: the gate blocks you, the compass points to the totems, you jump the bridge gap and fall into the pit and climb out, the mine lever works, and the gate opens.

## Follow-up 16: Mr. Bubbles could not be reached (Nov 13)

The designer reported an "invisible shield" around the boss island. The cause was the map's north boundary wall at z = −125: the thunderhead is centred at z = −145, outside the play area. Every earlier boss test **teleported** the hero onto the island, so none of them could catch it.

Lesson: an end-to-end test must travel the way a player does. The new `bubblesfight` test does that, with no teleports:
- rides the real vent bubble up;
- walks over to the boss and fights with real attack input;
- wins, sees the banner and slide, rides the slide down and lands by Anu;
- collects the dragonfly.

The same playtest found two more problems:
- Boss size was applied twice (body scale times look scale), so Mr. Bubbles was drawn about 13 m tall over a 4 m wide collision body, and the camera ended up inside his fur.
- There was no exit after the win.

Both are fixed: a `look_size` and `radius` per boss, camera framing near a giant boss, and a rainbow slide home.

## Follow-up 17: a long playtest list (Nov 17)

The designer sent about thirty notes in two messages, covering every level. We worked through them in five batches. Each batch got its own autotest mode, and screenshots were checked before anything was published:
- `polish1`: the playground, fire, levers, the Heart, wall line-of-sight and fowl.
- `polish2`: the balloon, discoveries and the moon portal.
- `classes`: the four new classes and their pets and powers.
- `sinkhole`: rewritten for the new caverns.
- `castle5`: the Bone Crypt, fishing, the horses, the cloud beacon and boss moves.

**Attacks through walls.** Enemies only checked distance, so a goblin on the other side of a cave wall, or a floor above, could still hit you. Now:
- engaging and every strike need a line-of-sight ray, cached every 0.3 s so it stays cheap on iPad;
- strikes also need a height check;
- an enemy that loses you across a level gives up and goes home.

**Harder, smarter enemies.** "Harder" was done three ways rather than just bigger numbers:
- **Progression scaling:** enemies get stronger with the zone's level, and with how many of the zone's quests are already done.
- **Skills:** agile types sidestep your swings, shield-bearers block from the front, and many types become enraged below 35% health.
- **A special-move system for bosses:** leap slam, charge, whirlwind, projectile fan, eye beam, thrown boulders and blink, each with a warning ring.

**Lessons:**
- **Glowing materials don't work on big meshes.** A material made for glowing particles turns every mesh into a camera-facing billboard. That's why the first moon beacon was invisible, and it is also the likely cause of the "blue square under my feet" the designer screenshotted (a ghostly costume's cape). The fix was a separate material for beams, with the capes toned down.
- **Run tests one at a time.** Two Godot test runs on the same machine share the same saved games and fight over the CPU. Tests were run in sequence, each on a frozen copy of the code with its own save folder.
- **Keep private details out of the repository.** The designer's name had slipped into two code comments. It was replaced with "Jason's son", and the private name now lives only in the private project notes.

## Follow-up 18: Cloud Island redesign and the flight home (Nov 18)

**The blue square, for real this time.** On Nov 17 we toned down the ghostly capes. That hid the symptom but missed the cause, and the designer saw it again on Cloud Island.

This time we measured every costume piece against the hero's feet. The Paladin cape sat from 0.7 m **below** the ground up to the ankles.

The cause: in the KayKit models, capes, wings, hats and sunglasses aren't skinned. They hang off a bone through a `BoneAttachment3D`, and the code that borrows a costume onto our skeleton copied the mesh but not that bone. The plate armours share the Paladin look, which is why it seemed random.

The fix re-creates the bone attachment, and the new `bluesq` test checks every affected costume.

**Lesson:** when a fix only makes a bug harder to see, it isn't fixed. Measure where the geometry actually is.

**Cloud floors.** Each island used to be one solid cylinder, so holes were impossible, and the cloud puffs stood 0.3 to 1.5 m above the walking surface, so feet sank into them.

- **Floors:** each island is now a grid of 1 m cells with holes cut out. Thin-cloud patches are separate floors that switch off when you're heavy.
- **Puffs:** they're placed so their tops sit on the floor.
- **Grip:** weight now sets a `grip` value on the player, which scales floor acceleration. A wet hero slid 1.24 m after letting go of the stick, against 0.28 m dry.

**What the tests caught.**
- The Hail Tower first threw you out of its top and restarted the cycle, so you never sank back below the freezing line.
- Mr. Bubbles' charge could knock you off the thunderhead (a long fall to the sea). The arena now has storm winds at its edge during the fight.

**The flight home** is a new zone that reuses the opening movie's valley and cabin (with collision added). The course is a Catmull-Rom path; rings are dropped every 30 m along it.

The `homeflight` test flies the whole course with an autopilot that steers at the next ring and climbs or dives, then checks the landing, the quest and the ending screen.

**Precipitation Simulator.** The designer's 6th-grade simulator (17 kinds of precipitation, each with steps and a fact) gave us the science for three quests, and its facts are what Adad says when you turn them in.

## Follow-up 19: afternoon playtest notes (Nov 18)

The designer started a new Necromancer and sent notes from the Outpost and the first dungeon.

**Floating face details.** Moustaches, eyepatches and the rest were placed on an ellipsoid fitted to the head mesh's bounding box. Measuring the heads showed why that failed:
- The Necromancer's head box reaches 0.25 units in front of the face (a jaw piece).
- The Druid's is twice as wide and half again as tall (antlers).
- Hair styles swap in a different modelled head, but the layout still used the hidden original head's box.

Each detail now casts a ray at the head you actually see (Godot's `TriangleMesh.intersect_ray` on the head mesh, cached per mesh) to find the real face surface. The layout box is clipped to the size every KayKit head shares. The eyepatch strap is fitted with four rays around the head. The `looks` test now also shoots every hero in profile.

**Mid-air ledge grab.** The new climbing wall's red route showed that a jump across a gap toward a higher hold almost never landed: air control is deliberately weak. Pressing JUMP again in the air now grabs any ledge in front of you, from a little below your feet to 2 m above them, before a double jump is tried. On the ground the mantle rule is unchanged.

**Coplanar faces, again.** The stair tunnel's walls were flush with the cliff face they were cut into. The coplanar fixer pushes the smaller face back, so the cliff's rock texture showed instead of the masonry. The tunnel walls now stand 4 cm proud of the cliff.

## Follow-up 20: evening playtest notes (Nov 18)

**Hands that hold things.** The opening movie's toothbrush and teaspoon moved on their own because no animation clip puts a hand on them. Godot's `SkeletonIK3D` now pulls the right arm (upper arm to hand) onto a marker on the object, blended in and out over a fraction of a second. In Godot 4.5 it runs as a skeleton modifier after the animation.
- The cup and spoon are tweened as before, and the hand follows them.
- The seated pose puts his shoulders well behind the stool, so the cup had to slide toward him and he leans in. That's measured from the bones at run time, not hard-coded.

**A sign built in the wrong place.** The climbing-wall sign's posts and board were added to the wall node (at the world origin) instead of to the sign node. They stood, blank, at the top of the dungeon stairs; the words floated by the climbing wall with nothing behind them. The designer read it as "a sign begging for a warning", so there is now a real DANGER sign there.

**Signs.** `SignText.fit` measures the text with the font's own metrics and picks the pixel size so it fits the board. A `node_added` hook gives every Label3D the new font.

**Food.** Food is laid out by casting rays down onto each table's own mesh. The most common hit height is taken as the tabletop, so decorations and broken corners are skipped. Barrels and crates whose top is out of reach (or which are giant scenery) get none.


## Follow-up 21: Goblin Forest notes (Nov 18)

**Rainbow vision.** Eating a glowing mushroom raises a single number, which wears off at one unit every 16 seconds. A full-screen `canvas_item` shader reads the screen texture and wobbles, swirls, splits and rainbow-tints it by that amount. `hint_screen_texture` works in the compatibility renderer, so the iPad build gets the same effect. From three mushrooms your steering drifts. At five you wobble about on your own and miss 70% of your swings.

**One line, 596 errors.** `CPUParticles3D` has no `amount_ratio` (only `GPUParticles3D` does). One line setting it printed an error every frame. The test runner's script-error count caught it, though every check had passed.

**Floating torches.** One of the Warren's wall torches stood in mid-air because the cave wall it was placed against curves away. After a level loads (once the physics world knows the walls), every wall torch casts a ray behind it. A torch with no wall there searches 2 m around in eight directions and moves onto the nearest wall, facing out. A torch with no wall in reach becomes a standing torch.

**Chief Gruk** has twice the health and two new moves (Spore Bomb and War Horn). The forest has 14 discoveries; the four gnome houses each give a different gift.

## Follow-up 22: man or woman, and the cabin at home (Nov 18, night)

**Man or woman, for every class.** Each class has a default sex. Choosing the other one changes four things:
- **Head:** the default head is swapped for a modelled one from KayKit Adventurers 2.0 (long or shoulder-length hair for women, short for men).
- **Hair colour:** tinted to the class's own colour, so a heroine Knight is blonde and a Necromancer's hair is white.
- **Build:** slimmer for women, broader for men.
- **Face (women only):** lashes, lips and rosy cheeks.

Exceptions:
- A woman in a full knight's helm keeps the helm and gets a long braid out the back.
- The Druid's antlered hood is the class's look, so a heroine Druid keeps it, with a braid.
- The Barbarian's bare-chested body gets a fur wrap for a woman.
- The Wild and Bald heads come with beards, so those buttons are disabled for women.

**Every KayKit head shares one face.** The first lashes sat above the eyebrows on the long-hair head. The layout box changes with the hair, but a depth scan down the middle of the face found the nose tip at the same height on every head (about 1.51 in skeleton space). Lashes, lips and cheeks are now placed from the nose.

**A bug from Godot's duplicate names.** Classes with their own body model hide the base rig's meshes and borrow the class's meshes onto the same skeleton. The Barbarian's base and class models both have a mesh called `Barbarian_Head`, so Godot silently renamed the borrowed one (`@Barbarian_Head@…`). Code that finds the head by name found the hidden one instead. A swapped Barbarian head left the old bearded face showing, and first-person view never hid the Barbarian's head. The hidden base meshes are now renamed before borrowing.

**Names and the iPad keyboard.**
- There are 49 funny Bobek names for heroines.
- The name box held 22 letters, which cut "Bobek the Goblin Bonker" short. A cut-off name no longer matched the list, so switching to Woman kept a man's name. It now holds 26.
- The web build's `experimental_virtual_keyboard` is off, so tapping the name box on an iPad brings up no keyboard. The game now has its own on-screen keyboard (letters, caps, space, backspace, clear).

**The cabin.** The opening movie's cabin set is reused as the room: an `IntroMovie` node is built 30 m under the valley and scaled by 1/0.72, because the set was sized for a hero shrunk to 72%.
- Collision boxes are generated from the set's own boxes and from every model standing on the floor.
- The doors move you in and out with the usual fade.
- The sun is switched off while you're inside, because it lit the floor through the roof.
- The desk opens the character creator in "desk mode": the class is locked, Cancel restores your old look, and Done rebuilds your hero.
- The gear chest is a new `stash` list in the save file (60 items).
- A game saved in the cabin continues in the cabin with the flight already done. Taking the Sky Gate again means flying the course again.

**Port Home** (asked for the same night). Once the flight home is done, a HOME button (Y or Home on a keyboard) asks "Port home?" and travels to the home zone. You arrive in the cabin. The zone you left and your last safe spot are saved, and the family portal in the yard then offers "Back to <that place>", "The Vault outpost" or "Stay home". The level change takes an optional arrival point for this.

**Rainbow vision, take two** (the next playtest). On the iPad, eating a mushroom showed nothing but one big rainbow, with the game gone. The effect read the screen back (`hint_screen_texture`) to warp it, and in the iPad's WebGL build that read seems to have returned nothing. The colour bands and rainbow arc were then all that was drawn. Even on a PC, three mushrooms' worth was more rainbow than game. The new effect never reads the screen:
- One overlay is multiplied onto the view: slow waves of rainbow colour.
- A second overlay is added: a rainbow glow at the edges and drifting blobs.
- The camera's field of view breathes and the camera sways.
- The sparkles round the hero stay.

A new test (`shroomvis`) shoots the same view plain and at one, two and five mushrooms' worth, and checks that the picture still matches the plain one (correlation of small grey copies) and isn't darker. It passes in both the desktop and the web (compatibility) renderer. One mushroom now lasts about 13 seconds, and five in a row about a minute.

**Faces for heroines, and the ninja mask.** Women get Makeup and Glitter in place of Beard and Mustache, and switching sex swaps one for the other. The ninja mask is now a copy of the visible head's own triangles below the bridge of the nose and in front of the ears. They are clipped against those two planes, pushed out 3 cm along their normals, and drawn in dark cloth, with a strap fitted by rays and a knot at the back. Face details on swapped heads are now placed from the nose tip, so eyepatches and glowing eyes sit on the eyes of the long-hair heads.

## Follow-up 23: weapons away, and a real fishing fight (Nov 19)

**Sheathing.** A `BoneAttachment3D` can change bone at run time, so drawing and sheathing just switch the weapon's attachment between the hand slot and the chest bone. A pivot node inside it moves to a "back" transform:
- A staff stands up over the right shoulder; a blade hangs hilt-up and slants down to the left hip.
- The shield's thinnest axis (measured from its own meshes) is turned to face out. The weapon rides on top of it.
- How far back to sit comes from the body and cape meshes' bounds.

The player draws on attack, block, a spell, a special or damage, and sheathes 4.5 s after the last of those while no enemy is within 10 m. Mounting and fishing sheathe at once (fishing used to hide the weapon). New autotest `sheath`.

**Fishing.** The old reel bar only rewarded tapping as fast as possible. The new fight has two bars, line tension and reel.

How the line moves:
- Each tap adds 0.085 to the tension.
- The line slackens by 0.3 a second while the fish rests.
- While it runs it barely slackens at all, and each tap counts 20% more. So you have to stop reeling.
- A run starts with a tug.

The green zone drifts and is narrower for stronger fish. The reel bar fills only while the tension is in the green, and drains a little outside it. You lose the fish after 1.5 s near slack, or 0.6 s near snapping.

The numbers were tuned with a quick simulation of five kinds of player over 80 fights per fish:

| Player | Result |
|---|---|
| Careful | Lands every fish in 6–10 s, Ghost Pike included |
| Taps on, a beat late into each run | Lands every fish, but only about three Ghost Pikes in four (6–29 s) |
| Sloppy (keeps reeling above the green) | Mostly loses the bigger fish |
| Taps flat out | Always snaps the line |
| Never reels | Always lets the line go slack |

The `castle5` bot now plays it by watching the tension. It also checks both ways of losing: tapping flat out snaps the line, and not reeling lets it go slack.

**Two test-suite lessons.**
- The food placed on barrels and crates used the engine's global random shuffle, so it changed from run to run, and could land right beside the dungeon lever. It now uses the level's own seeded generator, and never goes within 3.5 m of a lever, door or chest (where it would steal USE).
- Since the fire vents were made hotter, the `flow` test's 3.6-second stand in the fire could kill a level 2 hero. Everything after that failed, which looked like a sheathing bug at first. The test now steps out as soon as it gets burned.

## Follow-up 24: the Sky Ride and the Hail Golem (Nov 19)

The designer played the whole game through. His verdict on the flight home: "a great idea", but slow, long and plain. "That whole scene about the ride home should be a video game in itself."

**The Sky Ride** (`scripts/world/sky_ride.gd`) is a rail-style flyer built on the existing course spline:
- **Arc-length table:** the Catmull-Rom path has 3,000 samples, so rings and scenery are placed in metres along the course, offset sideways and up.
- **Riding:** each physics frame the ride finds where you are on the course and points the dragonfly along it (a `ride_dir` and `ride_speed` on the player, 17–21 m/s, plus boosts). The stick only steers sideways, and FLY/BLOCK move you up and down relative to the course.
- **A soft corridor** turns you back if you wander more than about 15 m off the line.
- **Rings:** 43 in five patterns (straight, slalom, weave, corkscrew, dives and climbs), each ring 30–34 m (about 1.5 s) from the next. That's well inside what the climb, dive and steering rates can cover.
- **Score:** each ring scores its base points times (1 + streak/10, capped at 3). The maximum score is worked out when the course is built, and medals are fractions of it.

Two looks fixes after the first test shots:
- The additive glow materials washed out to white against the pale sunset sky, so the rings and rainbow trail now use plain colours.
- The camera's "high" view (past 4.5 m) looked down at the clouds, so the ride holds it just behind you.

The `homeflight` bot now flies like a player (sideways input plus FLY/BLOCK toward the next ring). It scored 40 of 43 rings, a gold medal, and a 33-ring streak.

**The Hail Golem** used the same ball-built "humanoid" shape as Mr. Bubbles. He is now a hailstone:
- a core inside a translucent shell, with growth bands showing through, the way real hail forms in layers;
- seeded lumps and ice-crystal cones;
- a face that stays in front while the body rolls with his movement;
- floating fists and orbiting hailstones.

## Follow-up 25: replay modes (Nov 19)

The roadmap's replay modes, built now because they sit on top of the levels rather than in them, so polishing the levels later doesn't conflict.

**A new adventure** (`Game.new_adventure`):
- What resets: quests and world flags.
- What stays: mounts, the second power, Sky Ride records, a permanent `adventure_done` flag, and level, gold and stash.
- "Start fresh" moves everything but the starter sword and garb into the gear chest.

`adventure_done` (rather than the flight-home quest) now unlocks Port Home and tells the home world you've already landed, since a replay resets that quest.

**Difficulty:**
- Health is multiplied when each enemy spawns, and the Warden's in its setup. Speed and rewards are scaled on the enemy's own copy of its stats.
- Damage is scaled once, in `Player.take_damage`, so every source (monsters, fire, the river, lightning, the Warden) is covered without touching each one.
- **More monsters:** a twin is spawned beside an enemy based on a hash of its id, so the same monsters get twins on every visit. The twin's death is saved under the id plus `+`.

**Insane** adds two things:
- **Oddities** (Giant, Speedy, Splitting).
- **`InsaneChaos`:** an event every 25–42 s, chosen from eleven, never the same twice in a row. Most work through small player hooks (`chaos_gravity`, `mirror_t`, `bouncy_t`, the existing haste timer, rainbow vision) or spawn things (Fowl, Pickups, Enemies, meteors).

New autotest `modes` (21 checks):
- the portal offers the new adventure and the mode panel;
- Insane + Start fresh resets the run but keeps your level, puts your gear in the chest and shows INSANE on the HUD;
- there are twins and odd monsters;
- a minion has more than 2.8 times its health, and a hit does more than 1.8 times its damage;
- every chaos event works;
- the mode is saved.


## Follow-up 26: the level picker, and Insane that matches you (Nov 19, afternoon)

Jason's first Insane run, at level 20 with good gear, found the Deep Vault easy. The mode multipliers sat on top of monsters tuned for a level-4 hero: an Insane skeleton had about 5.6x its health and 3.6x its damage, against a hero who was five times stronger. He also found two portal buttons that went to the same place: "Back to the Deep Vault" and "Visit the Vault outpost".

**Level picker:**
- Once the adventure is done, the family portal offers Back where I left off / Choose a level / A new adventure! / Stay home.
- Choose a level lists the four levels plus the Sky Ride, then the usual mode-and-gear panel.
- `Game.replay_level` resets only that level:
  - quests come from the existing zone tags;
  - world flags come from a new prefix table, `Game.ZONE_FLAGS` / `Game.flag_zone()` (`e_`/`chest_` are the Vault; `f_`/`w_`/`s_`/`disc_` are the forest; `c_` is the castle; `cl_` is the cloud). Twin suffixes are stripped.
- Flags had never recorded their level. The level scripts already used consistent id prefixes, so a table plus a test is enough; no save migration is needed.
- The test builds each level and checks that every uid-bearing object (enemies, chests, gates, quest items, totems, horses, mounds, lamps) maps back to its own level.

**Monsters that grow to match you** (`Game.foe_scale`):
- Monster health is scaled by how much the hero's hitting power exceeds a reference hero at the zone's level with typical gear. Monster damage is scaled by how much the hero's effective health (health × armor factor) exceeds that reference.
- **Hard** and **Insane, start fresh** count your level only, using zone-typical gear. So a fresh start is underpowered at first and catches up as loot drops.
- **Insane with your gear** uses your actual weapon and armor (when better), times 1.15. This is the "compensates for your best gear" rule Jason asked for.
- Normal keeps the old gentle out-level bump.
- Applied in `Enemy._ready` (replacing the out-level bump) and in the Warden. XP and gold scale with the health factor. Loot item level becomes your level in Hard, and your level + 1 in Insane.
- Blocking still stops ordinary hits fully: the "big blow" threshold grows with the scaling.
- Meteor damage is now a scaled fixed hit instead of a share of max health.
- **Fixed a bug:** a twin copied its parent's already-scaled damage multiplier and scaled it again.

**More Insane:**
- Every monster gets a twin, and most get a third (ids `+` and `++`).
- Chaos starts 8 s after arrival and repeats every 14–24 s. 30% of the time it's DOUBLE TROUBLE (two events at once).
- Monster Party brings four.

New autotest `levels`:
- the portal buttons;
- the level panel, including the Sky Ride best score;
- the scaling numbers;
- the forest replay in Insane with gear: only forest flags and quests reset, other levels untouched, gear kept, packs, grown monsters, chaos within seconds;
- the Vault replay in Hard, starting fresh;
- the Sky Ride replay on the dragonfly;
- uid ownership for all four levels.

## Follow-up 27: Insane was laggy, so make crowds cheap (Nov 19, night)

Jason: "insane mode is definitely out of control, which is what we wanted... It's very laggy."

**Measurement first.** A new autotest, `perf`, stands in the forest and the Vault in Normal and Insane. It averages script and physics time per physics tick, frame time and draw calls, and counts monsters (awake and total), particle emitters and lights. It runs headless (CPU only) and under xvfb with `--rendering-method gl_compatibility` (the web/iPad renderer). The build Jason played was measured with the same test by checking out 89408bd in a worktree.

**Causes:**
1. **Quadratic separation.** Every monster looped over every other monster each physics tick (`get_nodes_in_group("enemy")`, which allocates a fresh array each time). That's about 33,000 iterations per tick with Insane's ~180 forest monsters, against ~6,000 in Normal.
2. **Everyone awake.** Monsters 100 m away still ran AI, `move_and_slide` and full skeletal animation.
3. **Everyone drawn.** About 13,000 draw calls in the Insane forest.
4. **Events.** Monster Party and Chicken Party built all their spawns in one frame (spikes). Every Gold Rain coin carried its own OmniLight.

**Fixes:**
- **Monsters sleep.** An idle or dormant monster beyond max(48 m, aggro or wake range + 14 m) sleeps: physics returns early (with a check every ~0.5 s), and its `CharacterModel` gets `PROCESS_MODE_DISABLED`, which stops the AnimationPlayer and the oddity sparkles parented to it. Any state change (a hit, a world event) or the player coming close wakes it.
- **Separation is cheap.** It uses a per-physics-frame shared list of awake monsters (a static cache), and only for moving monsters.
- **Far monsters aren't drawn.** Ordinary monsters' geometry gets `visibility_range_end` 80 m; bosses (`look_size`) stay visible.
- **Insane is toned down a little:**
  - twins 1.0 → 0.85, triplets 0.6 → 0.35;
  - events every 16–26 s (was 14–24), Double Trouble 25% (was 30%);
  - Monster Party is 3 at a time (at most 9 alive); Chicken Party at most 12 birds;
  - meteors 10 (was 14) with smaller bursts; disco 3 lights;
  - Gold Rain coins have no light;
  - spawns are staggered over a fraction of a second.

**Results** (Insane forest, same test):

| | Before (89408bd) | After |
|---|---|---|
| Script and physics per tick (CPU only) | 30.4 ms | 3.5 ms |
| Five events at once | 33.7 ms (worst 82) | 7.1 ms (worst 22) |
| Draw calls (compatibility renderer) | 12,809 | 4,783 |

For reference, the old Normal forest was 8.8 ms and 7,203 draw calls. The new Normal forest is 4.0 ms and 4,694.

**Lesson:** "more monsters" multiplies every per-monster cost. Anything that loops over all monsters inside a per-monster update is quadratic and must use a shared, filtered list. Distance-based sleeping should have been there from the start for an open valley full of monsters.

## Follow-up 28: Insane 2.0, fewer and fiercer monsters, and the draw-call diet (Nov 20)

Jason, after the sleeping-monsters build: "definitely better, but there's still some slight lag... let's just rethink insane mode... make them more aggressive where they really come after you... there's other workarounds instead of just generating more NPCs". He also reported moped steering going the wrong way.

**The moped.** Not a moped bug: it was Insane's Mirror World event (left/right swapped for 10 s), which applied on mounts too, with only the banner to explain it. Now it applies on foot only and isn't chosen while you're mounted. Every lasting effect shows a countdown at the top of the screen. A test drives right on foot and on a mount under Mirror World and checks the direction.

**Insane 2.0:**
- **Monster numbers:**
  - Twins 0.35 (was 0.85), no triplets. Hard is 0.4.
  - Health x3.4 (was 2.8), bosses x2.6, speed x1.3.
- **Fierce AI** (`Enemy.fierce`):
  - aggro x1.6, attack cooldown x0.6, windup x0.85, leash x2, dodge/block skill +0.12;
  - `_rally()`: a monster that starts chasing calls awake friends within 18 m (one level deep);
  - `_rage()` below 40% health: x1.3 speed, x1.2 damage, x0.7 cooldown, red ring.
- **Champions** (30%): Giant, Speedy, Splitting, plus three new ones:
  - **Vampire:** heals 8% of max health per landed hit.
  - **Blinking:** teleports behind the player every 4.5–7 s, checked with rays for floor and walls.
  - **Exploding:** a telegraphed blast on death.
  - Marked by a shared torus ring mesh, with no particles (the old CPU sparkles cost every frame).
- **Events:** Monster Party, which spawned monsters, is replaced by spawn-free events:
  - **Monster Rage**, **Earthquake** (trauma plus shoves);
  - **Bullet Time:** per-monster `slow_t` scales its delta and speed, and `CharacterModel.slow` scales its animations;
  - **Slippery Ice:** `player.grip`;
  - **Ghost Monsters:** flickering `body.visible`.
  - Events come every 12–20 s, Double Trouble 30%, and `_makes_sense()` filters out pointless picks (for example Rage with nobody around).

**Where the remaining lag was.** The `perf` test gained a fight scenario (standing in the biggest camp), and a new `perfdiag` test switches things off one at a time while counting draw calls on the compatibility renderer.

In the forest (Normal) there were about 4,400 draw calls:
- monsters: about 900–1,500 (about 30 per character);
- scenery: the rest;
- lights, shadows and particles: almost nothing.

Of the scenery meshes, 2,842 were built in code, each with its own mesh resource: character bits, mushroom spots, chicken parts, fences. Only 149 were batchable imported meshes.

**Fixes:**
- `StaticBatcher.cull_small` gives every mesh a draw distance by its world size: under 0.6 m, 40 m; under 2 m, 65 m; under 5 m, 110 m; anything bigger has none. It runs once after a level loads; monsters do the same for their parts.
- `StaticBatcher.batch` turns identical imported props in a 40 m cell (14 m for props with their own draw distance) into MultiMeshes and hides the originals. It only touches imported, unscripted, unanimated meshes not on moving bodies. Gates, portcullis, bells and the drawbridge containers are in a `no_batch` group.

**Results** (compatibility renderer):

| Forest view | Draw calls before | After |
|---|---|---|
| Arrival | 4,439 | 1,289 |
| Valley | 2,385 | 735 |
| Camp | 4,245 | 1,859 |
| Insane fight | (about 4,800 just standing in the forest, previous build) | 2,293 |

A new `tour` test takes a fixed screenshot tour of every level. Running it with `DEEPVAULT_NOBATCH=1` and without, and diffing the images, checks that nothing visible went missing.

**Lesson:** on a tablet browser, draw calls are the budget. A level built from thousands of small primitives needs distance culling from day one, and "add more monsters" is the most expensive way to add excitement.

## Follow-up 29: no more Mirror World; a living soundscape at the cabin (Nov 20)

Jason: "I really don't like that mirror vision left is right, right is left thing... what it causes is stress, and this game is not supposed to be stressful". Also: "at the cabin... there's one repeating tweet from a bird that's constant... We should have more natural atmospheric sounds".

**Mirror World is removed** from the events, the player (`mirror_t`) and the tests. A test now checks that right is right during Insane.

**Soundscape** (`scripts/world/soundscape.gd`). It replaces the 9-second `loop_birds` loop in the valley, which is used by both the opening movie and home.

| Layer | What it does |
|---|---|
| Breeze (`loop_breeze`, 24 s) | Non-positional; volume follows slow gusts |
| Crickets (`loop_crickets`) | Non-positional |
| Bees (`loop_bees`) | Positional, at the garden |
| Calls (scheduled) | Every 1.6–5 s, a weighted pick from 16 synthesized one-shots |
| Answers | Warbles, whistles and chips are answered 35% of the time from a second spot |

- **The calls:**
  - three warbles, two "fee-bee" whistles, two trills, two chip calls;
  - a dove, a cuckoo, a woodpecker drum, a leaf rustle.
- **How each call plays:** at a random spot 6–50 m around the listener (3–9 m up, in the trees), with ±8% pitch and a few dB of volume variation, from a pool of five players.
- **Indoors** (`HomeCabin.is_inside` via `inside_fn`): calls are half as frequent and quieter. The cabin room sits 30 m below the valley, so the calls also sound distant.
- **In the sky:** the soundscape fades out more than 90 m from the valley or 45 m above it, for the Sky Ride.
- **Generation:** all new sounds were added at the end of `tools/make_audio.py`'s list, so the random sequence, and therefore every older sound, is unchanged. The generator's `only` mode wrote just the 16 new files. Spectrograms were checked, since the sounds couldn't be listened to here.

New autotest `ambience`:
- the soundscape layers are playing, and the old loop isn't;
- indoors is recognised;
- 30 s in the yard gives at least 7 calls of at least 4 kinds;
- it's calmer indoors and quiet in the sky.

## Follow-up 30: Normal and Hard put back exactly; speed savings are Insane-only (Nov 20)

Jason, after the soundscape build: "I'm just really hoping you didn't apply the changes that had to happen to insane mode to normal mode, because normal mode was perfect... I thought we were done with normal mode." His process is to tune Insane first, then Hard (not yet played), and to leave Normal alone because it was already good.

The performance work in follow-ups 27–28 had been applied globally and reported as "Normal got faster too". That was a judgement call I should have asked about, because it moved a mode the designer had signed off. The fix:
- **`Enemy.lean`** (true only in Insane) gates the monster changes. In Normal and Hard the original code runs:
  - sleeping;
  - the awake-list separation (Normal and Hard use the original all-monsters loop);
  - the standing-still `move_and_slide` skip;
  - monster draw distances.
- `StaticBatcher.batch`/`cull_small` run only when the level loads in Insane.
- `CharacterModel`: the slow-motion change had altered one locomotion line (it passed a stored speed instead of `anim.speed_scale`). That could let a frozen monster (speed 0) animate in any mode. It's restored to `anim.speed_scale / slow`, which is identical to the original when `slow` is 1.
- Hard's twin chance is back to 0.5.
- A review of every script diff since 89408bd (the build Normal was signed off on) found nothing else that runs outside Insane, apart from the cabin soundscape (requested for all modes) and test changes.
- **Measured:** the Normal forest is back to 7,362 draw calls (89408bd: 7,203).
- **The `levels` test now checks:**
  - Hard has no batches, no sleeping monsters, no `lean` monsters and no detail culling;
  - Insane still culls (over 500 meshes).

**Lesson:** when a stakeholder has signed off a mode, global optimizations need explicit permission. A mode switch makes that cheap: one flag per subsystem.

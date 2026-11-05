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

## Follow-up 11: playtest notes from Bobek (age 11) (Nov 4)

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

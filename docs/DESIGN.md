# Design notes and decisions

## The adventure

**Story.** The Keepers of Ashkar sealed the Heart of the Vault beneath the cliffs so its light could feed the underground river, and left a stone Warden to guard it. An adventurer named Corwin went down and never came back. You find his companion's journal at an abandoned camp and follow him in.

**Route** (about 15–25 minutes at a normal pace):

| # | Area | What happens |
|---|---|---|
| 1 | **Ruined Outpost** at dusk | Campfire, tents, ruined walls. Read the journal (lore and a hint about the fire vents), loot a chest, rest at a shrine. Learn the controls. |
| 2 | **Stair tunnel** | Descend from the moonlit clearing into the Vault. |
| 3 | **Entry Hall** | Skeletons claw their way out of the floor as you pass. This is the first fight. |
| 4 | **Vent Corridor** | Four fire vents breathe in a rolling rhythm. Time your run, pull the lever at the far end, the portcullis opens and the vents die. Skeletons that follow you also burn. |
| 5 | **Armory** | Shielded Vault Sentinels, a skeleton, and the **Hollow Revenant** (the intermediate enemy, with telegraphed heavy slams). Two chests: the Knight's Longsword, then the Vault Guard Hauberk. |
| 6 | **The Glowing Deep** | The visual centrepiece (see below). Skeleton mages shoot across the river. Wade to the island for the **Amulet of the Deep**, find the **Runeblade** in a corner alcove, and read Corwin's last words. |
| 7 | **Warden's Sanctum** | The gate seals behind you. **The Vault Warden** is a 4.5 m rune-bound golem with three phases: swipes and ground slams, then summoned skeletons and a leaping slam, then an enrage. It shatters into physics debris when it dies. |
| 8 | **The Heart** | Claim it from the altar to see the victory screen. |

Shrines (checkpoints that also fully heal you) are at the outpost, the armory, the river entrance, and outside the Warden's door. Death returns you to the last shrine and keeps your XP and gear. Dying inside the arena resets the boss.

## Systems

- **Camera.** The mouse wheel moves the camera continuously from 9 m behind the character down to 0. Below 0.45 m it becomes true first person: the head meshes are hidden, the camera sits at eye height, and the body faces where you look, so you see your own sword arm and body. Above that it is an over-the-shoulder spring-arm camera that collides with walls. `V` toggles between views instantly, and `+`/`-` also zoom.
- **Combat.** A three-hit sword combo (diagonal, horizontal, heavy chop) uses clip-synced hit frames, a reach and cone test, 12% crits, hit-stop, screen shake, floating damage numbers, sparks and a white hit flash. Holding RMB raises the shield, which cuts frontal damage by 80% at a stamina cost; when stamina runs out the guard breaks. `C` is a dodge roll with invulnerability frames. `Q` fires a homing arcane bolt (costs mana). `R` drinks a healing draught.
- **Progression.** XP comes from kills and the curve is `80 × level^1.45`. Each level adds +18 HP, +3.5 attack, +8 mana, +5 stamina and +1 defense, and fully heals you. Weapons add attack; armor adds defense using diminishing returns (`dmg × (1 − d/(d+45))`). A normal run reaches about level 4–5.
- **Items.** There are 3 weapons, 3 armors, 1 artifact and the Heart. Chests and enemies drop gold and potions, and pickups float toward you. Better gear auto-equips, and you can swap anything in the inventory (`I`). The amulet can be unequipped.
- **Enemies.** Each runs a simple state machine: dormant (in the floor), awaken, idle, chase, wind-up, strike, recover, stagger, return home. Enemies are leashed to their room and separate from each other. Poise determines who staggers. Mages keep their distance and strafe.

## The Glowing Deep (visual centrepiece)

A 44 × 42 m cavern, 16 m high:

- **Luminous river** (`shaders/river.gdshader`). Two layers of flow noise slide at different speeds along the flow direction, with bright current streaks and sparkles. There is shoreline foam where the water meets stone (from the depth buffer), travelling vertex waves, and Fresnel-based transparency.
- **Interaction.** Ripple rings radiate from where you wade. The water pulses brighter when it burns you. While you wear the Amulet it shifts from cyan to green and heals you instead.
- **Light and mist.**
  - Two **cascades** (`shaders/waterfall.gdshader`) pour from the north wall into narrow stone channels that feed the river, plus a broad fall from the west inlet. Each has splash and mist emitters.
  - **Mist sheets** (`shaders/mist.gdshader`) drift with the current. They soft-intersect the floor and fade near the camera so they read as volume.
  - **Volumetric fog** (Forward+) has a glowing fog volume over the water and a **shaft of pale light** from a crack above the bridge.
  - **Drifting motes** are GPU particles with turbulence rising off the water. **Crystal clusters** have their own light.
  - **Caustic shimmer**: the stone shader takes a glow origin and paints animated caustics on walls and floor near the river.
- **Gameplay.** Mages fire across the water while you cross the bridge. The island chest holds the Amulet, so you have to wade through burning water to reach it. The amulet then changes how the river treats you.

## Major decisions and substitutions

1. **Characters: KayKit glTF rigs instead of procedural or Blender-made humans.**
   - I first built a fully procedural, customizable human (sex, skin, hair, outfit) with code-driven animation. It still exists in `scripts/player/humanoid.gd` and now drives the Warden. Rendered side by side it looked like a mannequin.
   - An asset-scouting agent found the CC0 KayKit packs, which are reachable from the sandbox through GitHub mirrors. They are professionally rigged with 76–95 animations each, and the skeleton enemies share the same rig and clip names.
   - **The trade-off**: KayKit is stylised with large heads, not realistic anatomy. Customization is therefore preset-based. You choose from five heroes (Knight, Barbarian and Mage read as male; Rogue and Ranger as female), a cloak colour, helm on or off, and a name. Skin tone and hair are baked into their texture atlas.
   - Swapping in realistic human rigs later only touches `character_model.gd`, because the controller talks to an animation-input interface.
2. **No Blender.** Every model is either a KayKit glTF or built in code. That avoids a Blender dependency and a long, fragile asset pipeline overnight.
3. **Architecture is code-built boxes with procedural shaders.**
   - The masonry shader (`stone.gdshader`) generates world-space blocks, mortar, bevels, moss and wet stone without textures. Because it works in world space it never stretches on scaled boxes.
   - Poly Haven PBR textures (triplanar) are used outdoors for the cobblestones and cliffs. KayKit dungeon props supply detail.
   - Box collision is exact and cheap.
4. **Renderer: Forward+ with automatic OpenGL fallback.** Volumetric fog, SSAO and fog volumes only exist in Forward+. The OpenGL fallback (`rendering_device/fallback_to_opengl3`) keeps the game launching on machines without Vulkan; it simply has no volumetric fog.
5. **Physics: Jolt, built into Godot 4.5.** No extension needed. Used for character collision, physics-driven Warden debris, and loot.
6. **Fluid: shader approximation, no simulation.** As the brief allowed. Taichi and true fluid sim were out of scope for one night.
7. **Audio: fully synthesized.** No reachable CC0 audio library was needed. `tools/make_audio.py` generates footsteps, sword swings, hits, bone breaks, shield clangs, fire, the river, cave ambience, a boss roar, an exploration pad and a boss drum loop.
8. **Single scene built at runtime.** The world, UI and characters are constructed from GDScript, not hand-authored `.tscn` files. That makes every change diffable and reviewable, and suits AI-driven development. The cost is that the Godot editor shows an empty scene until you press Play.

## Code map

```
game/
  project.godot              engine config (Forward+, Jolt, autoloads)
  scenes/main.tscn           the only scene; everything is built by scripts/main.gd
  scripts/
    main.gd                  game flow, pause/death/victory, hooks
    autoload/game.gd         stats, inventory, items, checkpoints, input map
    autoload/sfx.gd          sound playback, positional loops, music crossfade
    player/player.gd         controller, zoom camera, combat, interaction
    player/character_model.gd  KayKit rig wrapper: clip selection, weapons, hit flash
    player/humanoid.gd       procedural body + animation (used by the Warden)
    player/projectile.gd     homing magic bolt (player and mages)
    enemies/enemy.gd         skeleton state machine (minion, warrior, mage, revenant)
    enemies/warden.gd        boss AI, telegraphs, phases
    world/world.gd           level layout, atmosphere per area, story beats
    world/builder.gd         box geometry helpers (rooms, walls with doors, slabs with holes)
    world/river.gd           luminous river: mesh, lights, mist, motes, fog, damage/heal
    world/fire_trap.gd, gate.gd, interactable.gd, pickup.gd, props.gd, fx.gd, flicker.gd
    ui/hud.gd, ui/menus.gd, ui/ui_kit.gd
    tests/autotest.gd        automated playthrough + screenshots
  shaders/                   stone, river, mist, waterfall, rune
tools/  make_audio.py, build.sh, run_tests.sh
```

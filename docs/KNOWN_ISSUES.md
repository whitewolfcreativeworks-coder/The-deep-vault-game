# Known issues and incomplete features

## Not verified by a human yet (most important)
- **Feel and performance on real hardware.** All testing ran on a GPU-less sandbox using software rendering at a few frames per second. The game is expected to run well on any recent GPU (a few dozen dynamic lights, only a handful of which cast shadows), but the frame rate, mouse feel and input latency are unmeasured.
- **Sound.** The sandbox had no audio device. All 26 sounds were generated and load without errors, but nobody has listened to them in-game, so volume balance is a best guess.
- **Balance.**
  - Enemy and boss numbers were tuned against a scripted bot that attacks relentlessly. The early rooms were played by the bot *without* invulnerability and it took very little damage, so the first half may be too easy.
  - The Warden was made much tougher (1700 HP, 20% damage reduction) after the bot killed the first version in about 15 seconds.
  - Boss difficulty is now tested with a no-cheat bot (see the experiment report). The Runeblade of Ashkar is still a guaranteed Legendary in its chest, which makes every geared run similar in attack power.
  - Expect to want to tweak these values: they live in the `TYPES` table in `scripts/enemies/enemy.gd` and at the top of `scripts/enemies/warden.gd`.
- **Windows and macOS builds** were exported but never launched. The macOS build is unsigned, so the first launch needs right-click → Open.
- **Gamepad** bindings exist but are untested.
- **The iPad / browser version** is now played regularly on a real iPad by the designer, but every fix is first checked only in desktop Chrome with iPad emulation. That includes the Safari two-finger gesture blocking added in the third round, which is the main remaining unknown.
- *(original note)* **The iPad / browser version had not been tried on a real iPad when first built.**
  - What was checked: it was tested in desktop Chrome emulating an iPad (touch input, iPad screen size and user agent), and all 11 touch and trackpad checks passed in the browser.
  - What only a real iPad will show:
    - Safari performance
    - memory limits with the roughly 66 MB download
    - multi-touch feel
    - whether Safari grants pointer lock with a trackpad (if it doesn't, the game falls back to drag-to-look)
    - audio unlocking after the first tap

## Known limitations
- **Character style.** The KayKit models are stylised (big heads, chunky proportions), not realistic. Hair styles are simple chunky shapes (curls, strands, spikes, a crest) added on top of the hero's own recoloured hair, in keeping with the blocky look. On the Rogue, the built-in side locks stay (in skin colour) for the bald and mohawk styles. Helmets and the Ranger's hood hide custom hair (face details still show). Build and height are visual only and do not change hit boxes. See `docs/DESIGN.md`, decision 1.
- **First person.** The head is hidden and the camera sits at eye height. When you look straight down you see the chunky body and the cape, and some clipping is possible at extreme angles.
- **Enemy pathing.**
  - No navigation mesh. Enemies steer straight toward you, slide along obstacles and circle when close, which works in these open rooms.
  - Each enemy is leashed to its own room, so you can retreat through a doorway to reset a fight. Enemies can occasionally snag on pillars.
- **Animation.**
  - Enemy attacks use KayKit clips stretched to their wind-up timing, so a few look slightly rushed.
  - Dodge clips are played in place while code moves the character.
- **No save files.** Progress, checkpoints and loot persist through deaths within a session, but quitting the game starts a fresh run.
- **The editor view is empty.** The world is built from code at runtime (see the design notes), so opening `scenes/main.tscn` in the Godot editor shows almost nothing until you press Play.
- **Web renderer.** The browser build always uses Godot's Compatibility (WebGL 2) renderer. There is no volumetric fog or light shaft, and each surface can be lit by at most 8 nearby lights, so a few large floors in the river cavern may light slightly unevenly.
- **OpenGL fallback.** On machines without Vulkan the game switches automatically to OpenGL. It still looks good, but volumetric fog, fog volumes and the light shaft are not rendered there.
- **Settings.** The only setting in the pause menu is mouse sensitivity. There are no key rebinding, resolution or graphics-quality options yet.
- **Single hard-coded dungeon.** There is no procedural generation and no replay variation beyond hero choice.

## Ideas that were cut for time
- A secondary magic school (e.g. a fire nova) and a skill tree.
- Destructible urns and barrels with loot.
- Enemies knocked into the river taking damage, and the river reacting to the Warden fight.
- An outdoor dawn sequence after victory (currently a screen-text line only).
- Proper realistic human characters, for example a Mixamo-retargeted model. This would need an asset decision and a retargeting step.

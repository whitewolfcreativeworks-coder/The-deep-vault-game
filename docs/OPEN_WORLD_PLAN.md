# The open world: a plan to start from

*Written on Nov 25 by the Claude agent that works on Jason's other game, **Appearium**
(github.com/whitewolfcreativeworks-coder/Appearium-Game), after a conversation with Jason about
the next phase of Bobek's Adventure. It is a starting point, not a set of rules: Jason and his son
make the design decisions, and the agent working on this game knows its code far better than I
do. Change anything that doesn't fit.*

## Who I am and why this is here

I'm the agent building **Appearium**: a realistic first-person wilderness game in the browser
(Three.js, not Godot), aimed at iPad through GitHub Pages, like this game. In Appearium you live in
a permanent village, walk out of the gate into a procedurally generated land, gather and discover
things, and bring them home. The land changes the further you go, and some of what I learned
building that is useful here.

Jason sent me a message by mistake that was meant for you (about the Wardrobe). I only read this
repository to see which game it was for. Then we talked about the open world for Bobek's
Adventure, and he asked me to leave the plan here so you're up to speed. I haven't changed any
code. This file is the only thing I've added.

## What Jason wants

- **A new portal at home** (the family portal in the yard, or a new one) that leads to an **open
  world**, alongside the existing story levels and Normal / Hard / Insane.
- **The same basic idea as the cabin today:** a home base, crafting, Port Home back to the cabin.
- **One continuous world that keeps changing the further you go.** It's not a separate world
  behind each portal (that's how Appearium works). It's one world where, as you travel, the land
  and what happens in it change. The changes come from a **big list of possibilities, chosen at
  random**, so it isn't set in stone and new ideas can keep being added to the list.
- **Multiplayer eventually**, but not now (see "The order of work").

## How the world could work

### 1. One world seed

Everything random in the open world should come from a single number, the **world seed**. The
same seed always builds the same world. That matters for two reasons:

- **Multiplayer later:** two players' games build the identical world from the seed, so only the
  seed and the *changes* (below) ever need to be shared.
- **"Random but not set in stone":** a new seed is a whole new world. You could reroll it for a
  new season, or keep one world forever. That's Jason's call.

Practically, avoid `randf()` with an unseeded global generator for anything that shapes the world.
Derive every random choice from the seed plus a position or ID (for example, hash
`(seed, cell_x, cell_z)`), so it doesn't matter in what order things are generated or loaded.

### 2. Regions picked from a big list

This is what Appearium does far from the road (`zoneMod` / `zoneCell` in
`src/world/generator.js` there, if you want to look):

- Divide the world into irregular cells, each a few hundred metres to a kilometre across. In
  Appearium they're Voronoi cells about 1.3 km apart: a jittered point per grid square, and every
  location belongs to the nearest point.
- Each cell picks a **region type** from a list, using the seed and the cell's coordinates.
  Neighbouring cells should never be the same type, and the borders blend over a few dozen metres
  so the land changes gradually, not with a hard seam.
- The list can include all sorts: goblin forest, haunted marsh, crystal caves, sky-island chain,
  frozen ridge, ruined city, dragon valley, mushroom grove, desert of bones, and anything else
  Jason and his son think up. **Adding a new region type should be as easy as adding an entry to
  the list.** That's what keeps the world feeling endless.
- Each region type brings its own terrain shape, props, lighting and weather, monsters,
  materials and points of interest. The story levels' art and monsters can be reused here.

### 3. Distance rings: the further out, the wilder

Rings out from home decide difficulty and strangeness, independent of the region type:

- **Near home:** gentle versions, easy monsters, common crafting materials.
- **Further out:** harder variants (the Hard and Insane monsters already exist), rarer loot,
  mini-bosses in the middle of regions.
- **Far out:** region types and bosses that only appear past a certain distance.

This gives players a reason to keep pushing outward, and the difficulty modes already built can
plug straight in.

### 4. Two layers of randomness

- **Places (fixed by the seed):** terrain, regions, dungeons, camps, towns, boss lairs. Everyone
  on the same seed finds the same ones, so "meet me at the crystal caves north of the lake" works.
- **Events (random over time):** a goblin raid, a travelling merchant, a storm, a dragon passing
  over, a portal tearing open for a few minutes. These keep familiar places fresh. Events can use
  ordinary randomness; they don't need the seed.

### 5. Streaming, and the iPad

The open world never "ends", so it has to be built in pieces from the start:

- Load the land in **chunks** around the player and unload them behind. A chunk's contents come
  from the seed, so it rebuilds identically when you come back. Changes the player made are
  applied on top (see rule 2 below).
- Use **MultiMeshInstance3D** for trees, rocks and grass, and keep each region's monsters asleep
  until the player is near.
- Keep the **view distance short, with fog**. The README notes the forest fight was cut from about
  12,800 draw calls to about 2,300 to run smoothly on the iPad, so treat draw calls as the budget
  for the open world from day one.
- Terrain3D (TokisanGames/Terrain3D) is a Godot terrain plugin worth evaluating, but check it
  works with the web export before committing to it. A simple chunked heightmap mesh built from
  noise in GDScript also works fine; it's what Appearium does, in JavaScript.

## Multiplayer: what Jason decided

1. **Build the open world single-player first**, so one player can experience the whole thing.
2. **Build it multiplayer-ready** (the four rules below) so co-op can be added without a rewrite.
3. Then add **private invite codes**: a family host that only people Jason personally gives a code
   to can join. It's for playing together as a family, and also for **alpha and beta testers**.
   It's a back-end feature that stays hidden from the public game.
4. **Launch publicly as single-player.**
5. Use the income to build **public multiplayer** properly: a real server, accounts, moderation
   and safety for kids. Jason may hire someone for that part.

### The four multiplayer-ready rules

These cost little now and save a rewrite later:

1. **Everything random that shapes the world comes from the seed.**
2. **Changes to the world are recorded in one place**: "chest X opened," "boss Y defeated,"
   "player built Z here." That record is the save game now, and later it's exactly what the host
   shares with other players.
3. **Never assume there is only one player.** Monsters target the nearest or most threatening
   player, not "the player." Quests, loot and XP belong to someone.
4. **Keep game rules separate from what each screen shows.** Damage, loot rolls and AI decisions
   should live in code that one machine (later, the host) can run for everyone. Effects, sounds
   and camera stay local.

### Notes for when invite codes are built

- The web export can't use ENet. In the browser, Godot multiplayer goes over **WebSocket**
  (`WebSocketMultiplayerPeer`) or **WebRTC** (`WebRTCMultiplayerPeer`).
- GitHub Pages can only serve files, so even family codes need a small service somewhere: a
  matchmaking/signalling server, plus a TURN relay for players whose home networks block direct
  connections. Free tiers and cheap hosts are fine at family scale.
- If the game ever ships on **Steam**, Steam's friends, invites and free relay (via the MIT-licensed
  GodotSteam plugin) make the invite-code step much easier there.
- Godot's high-level multiplayer (`MultiplayerSpawner`, `MultiplayerSynchronizer`, RPCs) fits a
  host-authoritative co-op setup.

## The order of work I'd suggest

1. A portal at home that leads to a small open world: seed, chunk streaming, two or three region
   types, distance rings, Port Home. Reuse existing art and monsters.
2. Grow the list of region types and points of interest. This is where Jason and his son's
   ideas go.
3. Random events.
4. Crafting and home-base ties to the open world (materials that only come from certain regions or
   rings).
5. Private invite codes (family and testers).
6. Public launch, single-player.
7. Public multiplayer, later, done properly.

Good luck!

— the Appearium agent

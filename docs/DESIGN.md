# Slashboy: what was built and why

This document covers the second half of the native (Godot) build: Sectors 2–5, the abilities,
the bosses, and the systems underneath them. Sector 1 (Ring C) was the original introduction level.

## Design goals

The brief was a Metroid Prime-style first-person game: a futuristic ninja with a katana, set in a
dark, ambient space station, with quiet stretches between action, scares, unique enemy encounters,
and open spaces that funnel toward threats. Every sector follows the same rhythm:

1. **Arrive quietly.** A lift lands in a small room with a save station.
2. **Explore a large, sparse space.** Atmosphere first, with scannable lore.
3. **Funnel into an encounter.** Doors lock, music shifts, the fight is a puzzle as much as a brawl.
4. **Boss, then reward.** Every boss drops a new ability that changes how the world reads.
5. **Backtrack.** New abilities open hidden upgrades in earlier sectors.

Each sector has its own palette, ambience bed and enemy mix so the player always knows where they are.

## Progression

```
S1 Ring C ──lift──► S2 Undercity (hub)
                      ├─► S3 Foundry   → Warden    → Phase Step
                      ├─► S4 Archives  → Archivist → Kage Leap
                      ├─ Nest          → Matriarch → Kusari Grapple
                      └─► S5 Bloom Heart (needs Warden + Archivist) → Heart → Avatar → escape → ending
```

The Undercity is a hub so the player chooses the order of the Foundry and the Archives. The Bloom
Heart lift stays locked until both bosses are dead, so the ending can't be reached early.

| Ability | Key | Source | What it changes |
|---|---|---|---|
| Kusari Grapple | F | Matriarch | Zip to anchors, yank enemies, tear shields and generators off |
| Phase Step | Shift | Warden | Dash passes through phase barriers and light walls |
| Kage Leap | Space ×2 | Archivist | Double jump (about 2.3 m total) |

**12 hidden upgrades** (energy tanks, +25 energy; ki shards, +15 ki) are placed so that each ability
gates at least a few: grapple anchors, phase-sealed rooms, and ledges only a double jump reaches.
Items are tracked by id in the save, so they can never be collected twice.

## Sectors

**Sector 2, Undercity.** Rain-soaked neon chasm floor, night market, a collapsed overpass (the Gap)
that needs the grapple, and a subway station. Hounds (fast pack crawlers) and crawlers drop from
vents. *Why a hub:* it gives the player agency and a place to return to between sectors.

**Sector 3, Foundry.** Lava river, crushers on a fixed rhythm, turrets and a frontal-shield Bulwark.
Orange and hot, the opposite palette to the cold Archives. *Why:* it teaches environmental hazards
and tests the grapple and phase abilities in context.

**Sector 4, Archives.** Violet, cathedral-quiet, rows of data stacks. Phantoms are intangible
except while casting, so the player must watch for the cast flare. A three-monolith scan puzzle
opens the index door. *Why:* it makes the scan visor a gameplay tool, not just a lore reader.

**Sector 5, Bloom Heart.** Organic and red. A tunnel of spore pods, a 24 m vertical shaft, then the
Heart chamber. The shaft is deliberately easy to descend and hard to climb: the escape sequence
reuses the same space in reverse. *Why:* the best final act reuses what the player already knows,
under pressure.

## Bosses

Each boss is built around one idea that the matching ability or tool answers.

- **Matriarch**: bait her charge into a wall to stun her, then strike the sac. Teaches pillars and positioning.
- **Warden**: a shield dome fed by two back-mounted generators. Grapple them off, or parry its own missiles into them. Phase 2 adds lava vents. Teaches the grapple and the parry.
- **Archivist**: hovers out of reach. Parried orbs hurt it; the grapple drags it down; light walls demand Phase Step; decoys demand the scan visor. Tests every tool.
- **Bloom Heart**: armoured while its tentacles live. Tentacles can only be cut when embedded in the floor after a slam. Sever them all and the Heart sags open. Three cycles, each faster, with spore volleys from the second cycle on.
- **Avatar**: a bigger, harder Stalker. Enraging it spawns mites. It is a final exam in dodging, parrying and crowd control.

**The escape.** A 3-minute countdown, escape music, falling debris, and the way out is the shaft you
came down. Dying resets the timer. At the lift, the ending screen shows time, deaths and item count.

## Engine systems added

| System | Where | Purpose |
|---|---|---|
| `Level` base class and `SectorN` subclasses | `scripts/level.gd`, `scripts/sectors/` | One generic engine; each sector only declares layout, mood and script |
| Save stations and Continue | `level.gd`, `g.gd` | Auto-save, heal, refill ki; JSON in `user://` |
| Items | `level.gd`, `g.gd` | Tanks, shards, abilities; one collect path |
| Elevators | `level.gd`, `main.gd` | Sector travel with fade; gated by a condition (Bloom Heart lift) |
| Grapple anchors | `level.gd`, `player.gd` | Dicts so bosses can expose their own anchors (Warden generators) |
| Phase barriers | `level.gd`, shader | Collision layer 8, which the dash drops while Phase Step is owned |
| Hazards, lava, crushers | `level.gd` | Damage volumes, with timed `until` volumes for boss attacks |
| Zone mood | `director.gd` | Per-zone fog, exposure, ambient and ambience bed, with checkpoints |
| Boss base class | `enemies/boss.gd` | Damage scaling, shockwaves, shared helpers |
| Escape timer | `hud.gd`, `sector5.gd` | Countdown display, quake and debris |

**Why a generic engine.** Sector 1 was originally one hand-written file. Splitting it into a
reusable `Level` and per-sector scripts is what made it possible to build four more sectors without
copying code. It also keeps the automated tests simple: each sector is just a layout and a script.

## Decisions worth knowing about

- **Tentacle hit detection.** A tentacle's `center()` returns the point on its body nearest the player, so the sword connects anywhere along it, not just at its root.
- **Decoys.** The Archivist's clones are visual only. They shimmer red in scan mode, and when the real one is struck all decoys shatter. The real one is never ambiguous to a player who scans.
- **Boss damage gating.** Bosses ignore damage in their invulnerable states (shield up, Heart guarded, tentacle not embedded) instead of reducing it, so the player gets clear feedback and never feels they are chipping at nothing.
- **Frame rate.** Boss-room lights avoid shadows where possible. A shadow-casting point light renders its room six times; the Heart's glow light cost about 40 fps until I turned shadows off.
- **Emission textures.** Glowing grooves use the multiply emission operator, so the texture acts as a mask. The default additive operator turned whole walls into flat glowing blocks.
- **Leap ledges.** Heights were checked against the real jump numbers (about 1.1 m single jump, about 2.3 m double) so no collectible is out of reach.

## Testing

Every sector has a headless end-to-end scenario in `scripts/debug_tests.gd`, run with
`--sector=sN --entry=lift --abilities=... --scenario=sNflow`. They cover encounters clearing, boss
states and phases, ability and item pickups, grapple traversal, the escape climb and the ending
screen. See the README for commands.

**Limits.** None of this has been played by hand. Boss health, the Heart's open window and the
escape timer are first guesses and will need playtesting. The automated tests prove the logic runs;
they don't prove it's fun.

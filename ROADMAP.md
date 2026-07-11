# Roadmap

Masquerade is becoming a **general-purpose 2D game creation tool**: design characters with a built-in pose and animation studio, build levels with an in-game tileset editor, and iterate without leaving the running game.

This document tracks product direction and engineering priorities. For how systems connect today, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). For code that is being replaced, see [docs/LEGACY.md](docs/LEGACY.md).

## Vision

- **Characters first** — Create and animate diverse character rigs (sprite-based, pose markers, ragdoll-assisted) through in-game tooling.
- **Levels in the game** — Paint terrain, place entities, and tune gameplay layers from a build panel instead of only from the Godot editor.
- **Accessible workspace** — Prefer curated palettes and in-game placement over sprawling scene trees for common authoring tasks.
- **General-purpose foundation** — Movement, combat, and entity logic should eventually be reusable across player characters, NPCs, and enemies.

## Phase overview

| Phase | Focus | Status |
|-------|-------|--------|
| 0 | Project hygiene, folder layout, naming conventions | Done |
| 1 | Character animation studio (pose, timeline, ragdoll) | In progress |
| 2 | In-game tileset / level editor (`BuildPanel`) | In progress |
| 3 | Enemy and hazard art scale-up (16px legacy → 64px world) | Planned |
| 4 | General-purpose character controller (multi-actor, shared with enemies) | Planned |
| 5 | Polished studio UX, project/session model, publishing flow | Future |

## Near-term priorities

Ordered by current intent; details may shift as studio features land.

### 1. Character animation studio

Improve the pose and timeline workflow for authoring character animations without external tools.

- **Key paths:** `player/pose/`, `player/components/TimelineManager.gd`, `player/PoseMarker.tscn`, `player/ragdoll/`
- **Goals:** Smoother marker editing, timeline UX, animation library management, clearer pose vs gameplay mode separation.
- **Acceptance:** Authors can create, edit, and play back character animations entirely in-game on the current rig.

### 2. Tileset and level editor

Extend the prototype build panel into a dependable level authoring surface.

- **Key paths:** `player/build/BuildPanel.gd`, `resources/tilesets/`, `levels/`
- **Goals:** Stable painting on named layers, better tileset browsing, clearer build vs play mode, save/load level changes.
- **Acceptance:** Authors can lay out terrain, hazards, controls, and water layers from the in-game UI on a representative level.

### 3. Deprecate tile → scene spawn pipeline

Replace runtime conversion of hazard-tile paintings into scene instances with direct scene placement via the build editor.

- **Key paths:** `scenes/environment/hazards/hazards.gd`, `resources/tilesets/tileset_enemies.tres` (`spawn_scene` custom data)
- **Goals:** New content uses scene placement; tilemap spawn path frozen then removed.
- **Acceptance:** No new `spawn_scene` tile bindings; existing levels migrated or documented; `hazards.gd` conversion optional/removed.

### 4. Enemy and hazard scale harmonization

Align entity art, collision, and movement with the 64×64 environmental tile grid and larger player sprite (256×256+).

- **Key paths:** `scenes/enemies/`, `scenes/hazards/`, `assets/enemies/`, `scenes/enemies/BaseEnemy.gd`
- **Goals:** Consistent visual scale, hitboxes, and speeds relative to world tiles.
- **Acceptance:** Representative enemies and hazards look and feel correct on 64px terrain without legacy 16px assumptions.

### 5. General-purpose character controller

Refactor the player stack into a reusable controller usable for multiple local players and script-driven enemies.

- **Key paths:** `player/Player.gd`, `player/states/`, `scenes/enemies/BaseEnemy.gd`
- **Goals:** Shared movement/combat core; thin player-specific and enemy-specific layers.
- **Acceptance:** Second controllable actor prototype; one enemy variant driven by shared controller logic.

## Deprecations

| Item | Status | Replacement |
|------|--------|-------------|
| `spawn_scene` tile custom data on Hazards layer | Deprecated | In-game scene placement / build palette |
| 16×16 enemy art as source of truth | Legacy | Rescaled art + updated `BaseEnemy` collision |
| Monolithic `Player`-only movement | Legacy | Shared character controller module |

## Out of scope (for now)

- Online multiplayer
- 3D authoring
- External marketplace / asset store integration
- Full visual scripting layer

## How to propose changes

When opening a PR or agent task, tag which roadmap item it serves and whether it touches **legacy** systems listed in [docs/LEGACY.md](docs/LEGACY.md).

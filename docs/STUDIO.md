# Studio guide

How to use Masquerade’s in-game authoring tools. This covers the **character animation studio** and the **level editor**. Gameplay controls are unchanged from the underlying platform template unless noted.

For engineering priorities and phased delivery, see [ROADMAP.md](../ROADMAP.md).

## Studio layout

The player scene (`player/player.tscn`) bundles gameplay and authoring UI under `PoseHUD`. The intended layout has three zones:

```
┌─────────────────┐                              ┌──────────────┐
│ Play│Pose│Build │         (viewport)           │ Part panel   │
│  (left toolbar) │                              │ (hideable)   │
└─────────────────┘                              └──────────────┘

  Play:   bottom dock hidden; side panels hidden
  Pose:   ┌──────────────────────────────────────────────┐
          │  Timeline — steps, playback, key tools       │
          └──────────────────────────────────────────────┘
  Build:  ┌──────────────────────────────────────────────┐
          │  Build — layers, atlases, tile grid, tools  │
          └──────────────────────────────────────────────┘
```

| Zone | Scene nodes | Purpose |
|------|-------------|---------|
| **Left toolbar** | `PoseToolBar`, mode bar | Switch Play / Pose / Build |
| **Bottom centre** | `PoseTimelineDock` | Primary workspace — timeline in pose mode, build palette in build mode |
| **Right side** | `PoseDockRow`, `PosePartPanel` | Advanced marker configuration; hideable |

**Current implementation:** Play / Pose / Build tri-mode is in the left toolbar (`PoseModeBar`). The bottom-centre dock swaps between `PoseTimelinePanel` (pose) and `BuildPanel` (build). Play mode hides both docks and the right part panel.

### Dormant UI (`AnimSection`)

`AnimSection` contains `PoseAnimBrowser` and `PoseAssistantPanel`. It is **hidden by design** (`visible = false` in `player.tscn`). Useful assistant features were deliberately moved to `PoseTimelinePanel` (playback helpers, ragdoll toggles, export, hang/fall/clear, etc.). The section remains in the tree for possible future use — it is not missing functionality.

---

## Modes (target)

| Mode | Movement | Bottom dock | Side panels | Purpose |
|------|----------|-------------|-------------|---------|
| **Play** | On (default) | Hidden | Hidden | Run, jump, combat, interact with level |
| **Pose** | Off (`is_posing`) | Timeline panel | Part panel (advanced) | Edit markers and animations |
| **Build** | On (initial design) | Build panel | Hidden by default | Paint tiles; walk level while authoring |

**Play + build together:** Build mode initially keeps player movement enabled so authors can reach different parts of the level while painting. This may be revisited if hotkey bindings clash (e.g. paint vs jump/attack).

Mode switching uses three toolbar buttons in `PoseModeBar` (Play / Pose / Build).

---

## Character animation studio

### Where animators work

**Primary surface:** the bottom-centre **timeline** (`PoseTimelinePanel`).

- Animation selector, play/stop/record, step grid
- Mirror mode, key-all, loop, export
- Ragdoll group toggles, hang/fall/clear, pose reset
- Timing controls (steps, speed)

**Secondary surface:** the right **part panel** (`PosePartPanel`) for advanced per-marker work:

- Part strip and selection
- Sprite preview, file dialog, offset/scale/rotation
- Accessories, look-at, follow-rotation, constraints
- Live position/rotation readouts

Do not expect the hidden `AnimSection` assistant — use the timeline instead.

### Concepts

- **Pose markers (`PoseMarker`)** — Nodes on the character rig representing parts (head, limbs, torso). Drag, rotate, and constrain them to author poses.
- **PoseController** — Manages marker selection, groups, and hang/swap tools.
- **TimelineManager** — Step-based animation timeline tied to `AnimationPlayer`; records keyed poses over discrete steps.
- **Ragdoll helpers** — Optional skeleton-aligned polygons and bones (`RagdollManager`, `BodyPartSlot`) for aligning art to a physical rig.

### Typical workflow (pose mode)

1. Enter a level with the player spawned (e.g. `levels/test.tscn`).
2. Switch to **Pose** mode.
3. Select a body part from the part panel (right) or click markers in the viewport.
4. Use the **timeline** (bottom) to advance steps, key poses, and play back.
5. Use advanced constraints in the part panel when needed.
6. Animations persist as resources under `player/animations/` (`.res` clips referenced by the player scene).

### Tips

- Use mirror mode on the timeline for symmetrical poses.
- Prefer naming consistency in the part table — markers map to `BodyPartSlot` sprites on the armature.
- Ragdoll/scaffold tools under `player/ragdoll/` are editor-assist utilities; see `player/dev/run_body_polygon_scaffold.gd` for batch polygon fitting.

### Key files

| File | Role |
|------|------|
| `player/PoseMarker.tscn` | Marker scene instanced on the rig |
| `player/pose/PoseHUD.gd` | Studio UI shell and mode orchestration |
| `player/pose/PoseController.gd` | Marker logic |
| `player/pose/PoseTimelinePanel.gd` | **Primary animator UI** (bottom dock) |
| `player/pose/PosePartPanel.gd` | Advanced inspector (right dock) |
| `player/components/TimelineManager.gd` | Timeline and keying |
| `player/components/PlayerAnimator.gd` | Bridges gameplay anim ↔ pose |

---

## Level editor (BuildPanel)

### Where builders work

**Primary surface:** the bottom-centre **build dock** — visible on the **Build** tab.

```
[ Layer tabs… | Entities ] | [ tilesets or category ] | [ atlas / scene grid ] | * Save
```

Layer tabs are discovered automatically from every `TileMapLayer` in the current level (e.g. `Terrain`, `TerrainBackground`, `Water`, `TerrainForeground`).

### Concepts

| Tab | What it does |
|-----|----------------|
| **Tile layers** | One tab per `TileMapLayer` in the level; paints using that layer's tileset. The atlas picker shows the full tileset texture (contiguous, like the Godot editor). Drag on the atlas to select a single tile or a rectangular block; LMB paints the selection (multi-tile selections stamp as a `TileMapPattern`). |
| **Entities** | Place scene instances into `Enemies`, snapped to the 64×64 grid |

Entity thumbnails come from `spawn_scene` metadata in tilesets (catalog only via `EntityPalette.gd`).

### Keyboard and mouse (studio)

| Input | Build tab | Skin tab | Play tab |
|-------|-----------|----------|----------|
| **Ctrl + drag** | Pan camera | Pan camera | Pan camera |
| **Ctrl + scroll** | Zoom camera | Zoom camera | Zoom camera |
| **Space** | Jump | — (posing) | Jump |
| **LMB drag (atlas)** | Select tile(s) on the atlas picker | — | — |
| **LMB** | Paint tile / place or drag entity | Select markers | Gameplay |
| **RMB** | Erase tile / entity | — | — |
| **Delete** | Remove selected entity | — | — |
| **Ctrl + click** | — (camera pan) | Add/remove marker from selection | — |

Build tools are disabled while **Ctrl** is held so camera pan does not paint or move entities.

Unsaved level edits show a `*` indicator in the build panel; use **Save** when you are ready to persist.

### Typical workflow (build mode)

1. Run `levels/test.tscn`.
2. Open the **Build** tab.
3. Pick a **tile layer** tab and tileset source; drag on the **atlas** to select one tile or a block; LMB paint, RMB erase.
4. **Entities:** pick category and scene; LMB place; click instance to select; drag to reposition; RMB erase; Delete removes selection.
5. Click **Save** when the `*` dirty indicator appears. You can switch to **Play** to test without saving first.

### Key files

| File | Role |
|------|------|
| `player/build/BuildPanel.gd` | Build dock UI and input |
| `player/build/TileAtlasPicker.gd` | Contiguous atlas picker with drag selection |
| `player/build/TileLayerCatalog.gd` | Discovers `TileMapLayer` nodes in the level |
| `player/build/EntityPalette.gd` | Scene catalog |
| `player/build/LevelSave.gd` | Persist level to disk; unsaved prompt |

---

## Adding content

### New character animation

1. Work in **Pose** mode on the existing rig (or duplicate `player/player.tscn` for variants).
2. Record clips via the **timeline** (bottom dock).
3. Store animations under `player/animations/`.

### New enemy or entity

1. Create or duplicate a scene under `scenes/enemies/`, `scenes/platforms/`, etc.
2. To appear in the build palette, add a `spawn_scene` binding on an atlas tile in `tileset_enemies.tres` or `tileset_controls.tres` (catalog metadata for `EntityPalette.gd` — do not paint these tiles onto layers).
3. Or place instances manually under `Enemies` in the level scene.

### New terrain / props

Add atlas sources to `tileset_terrain.tres` or place decorative scenes under `scenes/environment/`. Keep tile size aligned to the 64×64 grid where possible.

---

## Levels reference

| Level | File | Notes |
|-------|------|-------|
| Test | `levels/test.tscn` | Main scene; studio authoring pilot |

Water rendering uses `levels/shaders/water.gdshader`.

---

## Troubleshooting

| Problem | Things to check |
|---------|-----------------|
| Build panel paints nothing | Select a tile layer tab; layer must be a `TileMapLayer` in the level |
| Entity place fails | Level has an `Enemies` node; scene root is `Node2D` |
| Save fails | Run from a saved level scene (`test.tscn`); `scene_file_path` must be set |
| Pose markers missing | Skin/Animate tab; `is_posing` enabled |
| Entity not in palette | Add `spawn_scene` binding in tileset for catalog entry |
| Enemy scale looks wrong | Known 16px art vs 64px tiles — see [LEGACY.md](LEGACY.md) |

---

## Related documents

- [ARCHITECTURE.md](ARCHITECTURE.md) — Technical structure
- [LEGACY.md](LEGACY.md) — Deprecated authoring paths
- [ROADMAP.md](../ROADMAP.md) — Phased studio improvements

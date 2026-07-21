# Studio guide

How to use Masquerade’s in-game authoring tools today, and where the product is headed.

For engineering milestones, see [ROADMAP.md](../ROADMAP.md).

---

## Product direction

Masquerade is a **game creation tool for building credible 2D games and teaching game design**. The target experience:

1. **Open a project** and browse a **library of characters**
2. **Skin** them with body parts and clothing; **animate** in the timeline
3. **Assemble characters** by attaching skins to **controllers** (player or enemy behaviour)
4. **Build levels** with separate art and collision layers
5. **Play** a full loop: combat, collect money and keys, buy power-ups, defeat bosses, reach the next level
6. Assign **music and SFX** from an audio panel

Much of this is **planned** (milestones M1–M10). The sections below describe **what works now** and **what is coming**.

---

## Home screen (M0)

The app boots into the **home screen** (`scenes/home/HomeScreen.tscn`):

1. **Open** a recent project from the list (newest first), or
2. **Create** one — type a name, pick a template (e.g. **Platformer**), press Create.

Opening a project applies its game rules (HP, keys to exit) and loads its current level with the studio UI. Projects live in `user://projects/<name>/`; deleting one asks for confirmation.

**Dev shortcut:** run `levels/test.tscn` directly from the Godot editor to skip projects entirely.

---

## Studio layout (current)

The player scene (`player/player.tscn`) bundles gameplay and authoring UI under `PoseHUD`. The **bottom-centre dock** is the primary workspace, switched by studio tabs:

```
┌──────────────────────────────────────────────────────────────────┐
│  Skin │ Animate │ Build │ Play          (bottom tab bar)         │
├──────────────────────────────────────────────────────────────────┤
│                     viewport (level + character)                  │
├──────────────────────────────────────────────────────────────────┤
│  Bottom dock: Part panel / Timeline / Build panel / Play stats   │
└──────────────────────────────────────────────────────────────────┘
```

| Tab | Bottom dock | Side / extra | Movement |
|-----|-------------|--------------|----------|
| **Skin** | Part panel (`PosePartPanel`) | Marker editing in viewport | Off (`is_posing`) |
| **Animate** | Timeline (`PoseTimelinePanel`) | — | Off |
| **Build** | Build panel (`BuildPanel`) | — | On |
| **Play** | Play stats (minimal) | — | On (gameplay) |

Tab orchestration: `PoseHUD._apply_studio_tab` via `StudioTabBar`.

**Legacy UI:** `PoseToolBar` / `PoseModeBar` (left Play/Pose/Build toolbar) is hidden. Do not extend it — use `StudioTabBar`.

### Dormant UI (`AnimSection`)

`AnimSection` (`PoseAnimBrowser` + `PoseAssistantPanel`) is **hidden by design**. Features live on `PoseTimelinePanel`. Kept in the tree for possible future use — not a missing feature.

---

## Workflows today

### Skin tab — appearance authoring

**Surface:** part panel (bottom dock) + viewport markers.

- Select body parts from the part strip or click markers
- Sprite preview, offset, scale, rotation
- Accessories, look-at, follow-rotation, constraints

**Key files:** `PosePartPanel.gd`, `PoseMarker.tscn`, `PoseController.gd`

**Planned (M2):** Parts library, clothing slots, save named skins to a library.

---

### Animate tab — animation authoring

**Surface:** timeline (bottom dock).

- Animation selector, play/stop/record, step grid
- Mirror mode, key-all, loop, export
- Ragdoll group toggles, hang/fall/clear, pose reset
- Timing controls (steps, speed)

**Typical workflow:**

1. Run `levels/test.tscn`
2. Open **Animate** tab
3. Select animation, advance steps, key poses, play back
4. Clips persist under `player/animations/` (`.res`)

**Key files:** `PoseTimelinePanel.gd`, `TimelineManager.gd`, `PlayerAnimator.gd`

**Planned (M1):** Open animator from character library preview.

---

### Build tab — level authoring

**Surface:** build dock (bottom).

```
[ Layer tabs… | Entities ] | [ tilesets or category ] | [ atlas / scene grid ] | * Save
```

| Sub-tab | What it does |
|---------|----------------|
| **Tile layers** | One tab per `TileMapLayer` in the level. Atlas picker (Godot-style drag selection). LMB paint, RMB erase. Drag on atlas to select a block; brush size matches selection. |
| **Entities** | Place scene instances into `Enemies`, snapped to 64×64 grid. Category filters: All, Enemies, Platforms, Collectibles, Hazards, Triggers. |

Layer tabs are discovered automatically (e.g. `Terrain`, `Water`, `TerrainForeground`).

**Entity workflow:**

1. Open **Entities** sub-tab and pick a category (optional).
2. Click a scene thumbnail to select it.
3. **LMB** in the viewport to place; click an existing entity to select it.
4. **Drag** a selected entity to reposition (grid-snapped).
5. **Delete** or **Backspace** removes the selected entity.
6. **RMB** erases the entity under the cursor.

**Tab behaviour (Build vs Play):**

- On **Build**, **Skin**, and **Animate**: placed entities are **frozen** (no AI/movement); navigation markers are **visible** for authoring.
- On **Play**: entities run normally; navigation markers are hidden.
- Switching **Build** ↔ **Play** does **not** prompt to save — use **Save** when the `*` dirty indicator appears.

Orchestration: `LevelAuthoring.apply_studio_tab` (called from `PoseHUD._apply_studio_tab`).

**Typical workflow:**

1. Open **Build** tab
2. Paint tiles on a layer; place entities from palette
3. Switch to **Play** to test
4. Click **Save** when the `*` dirty indicator appears

**Project levels (M0):** when a project is open, the Build header shows a **level picker** and **+ Level** button. Switching levels auto-saves pending edits, then loads the chosen level. **+ Level** appends a blank starter level (player, empty terrain layer, safety floor) and opens it. Reaching an open **exit** advances to the next project level; finishing the last level returns to the home screen.

**Key files:** `BuildPanel.gd`, `TileAtlasPicker.gd`, `TileLayerCatalog.gd`, `EntityPalette.gd`, `LevelSave.gd`, `LevelAuthoring.gd`

**Dev diagnostics:** `BuildPaintDebug.gd` traces paint/input routing when enabled (off by default).

**Planned (M4):** Dedicated **Collision** layer (shape tiles, hidden on Play). Art and map fully separated.

**Planned (M3/M7):** Place **characters** (skin + controller) and expanded hazard/collectable palettes.

---

### Play tab — test gameplay

**Surface:** minimal play stats; viewport is the game.

- Run, jump, combat (basic melee today)
- Collect coins, keys, hearts; checkpoints
- `GameManager` tracks HP, keys, points

**Planned (M5–M6):** Money wallet, shop, power-ups, improved combat feedback.

**Planned (M8):** Level music and event SFX from audio panel.

---

## Keyboard and mouse (current)

| Input | Build | Skin | Animate | Play |
|-------|-------|------|---------|------|
| **Ctrl + drag** | Pan camera | Pan camera | Pan camera | Pan camera |
| **Ctrl + scroll** | Zoom | Zoom | Zoom | Zoom |
| **Space** | Jump | — | — | Jump |
| **LMB drag (atlas)** | Select tile block | — | — | — |
| **LMB** | Paint tile / place or select entity | Select markers | — | Gameplay |
| **LMB drag (viewport)** | Drag selected entity | — | — | — |
| **RMB** | Erase tile / entity | — | — | — |
| **Delete / Backspace** | Remove selected entity | — | — | — |
| **Ctrl + click** | — (camera pan) | Add/remove marker from selection | — | — |

Build tools are disabled while **Ctrl** is held (camera pan).

---

## Planned workflows (roadmap)

### Character library (M1)

Browse premade characters → preview → open in Skin or Animate. No scene-file editing required.

### Skin composer (M2)

Parts library (heads, limbs, clothing) → customise → save to **My skins**.

### Character assembler (M3)

Pick **skin** + **controller** (player or enemy) → tune behaviour params (speed, attacks, AI) → save **character** → place in level.

### Gameplay loop (M5)

Kill enemies → collect **money** and **keys** → spend money on **power-ups** → use keys to reach **next level**.

### Combat (M6)

Hitboxes, knockback, enemy telegraphs, tunable damage — params on the controller.

### Audio (M8)

Studio panel for level music and event SFX (jump, attack, coin, hurt, boss).

### Bosses (M9)

Multi-phase boss controllers; defeat unlocks exit or drops key.

---

## Adding content (today)

### New animation

Work on the **Animate** tab; store clips under `player/animations/`.

### New enemy or entity

1. Scene under `scenes/enemies/`, `scenes/platforms/`, etc.
2. For build palette: `spawn_scene` binding on atlas tile in `tileset_enemies.tres` or `tileset_controls.tres` (catalog metadata only — do not paint onto layers).
3. Or place instances under `Enemies` in the level scene.

### New terrain

Add atlas sources to `tileset_terrain.tres`. Keep 64×64 grid alignment where possible.

---

## Levels reference

| Level | Location | Notes |
|-------|----------|-------|
| Project levels | `user://projects/<name>/levels/` | Owned copies; edit and save via Build tab |
| Test | `levels/test.tscn` | Template source; dev scene (run directly from editor) |
| Blank starter | `templates/platformer/blank_level.tscn` | Source for **+ Level**; do not edit at runtime |

---

## Troubleshooting

| Problem | Things to check |
|---------|-----------------|
| Build panel paints nothing | Select a tile layer tab; layer must be `TileMapLayer` in level |
| Entity place fails | Level has `Enemies` node; scene root is `Node2D` |
| Save fails | Level has `scene_file_path` (run from saved `.tscn`) |
| Pose markers missing | **Skin** or **Animate** tab; `is_posing` enabled |
| Entity not in palette | Add `spawn_scene` catalog binding in tileset |
| Enemy scale looks wrong | Legacy 16px art vs 64px tiles — see [LEGACY.md](LEGACY.md) |
| Entities move on Build tab | Expected: frozen until **Play** — see `LevelAuthoring.gd` |
| Atlas selection paints through panel | Input over bottom dock is suppressed; paint only in viewport |
| No level picker in Build header | Only visible with a project open; dev scenes have no project levels |
| Exit does nothing | Needs enough keys (`keys_to_exit` rule); outside a project it needs a `target_level` |
| Project missing from home screen | Check `user://projects/<slug>/project.cfg` exists and parses |

---

## Related documents

- [ROADMAP.md](../ROADMAP.md) — Milestones M0–M10
- [ARCHITECTURE.md](ARCHITECTURE.md) — Technical structure
- [LEGACY.md](LEGACY.md) — Deprecated authoring paths
- [DEVELOPMENT.md](DEVELOPMENT.md) — Local setup and validation checklist

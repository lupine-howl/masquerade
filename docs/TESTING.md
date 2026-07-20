# Testing guide

CI runs on every pull request and push to `main`: headless Godot import, main-scene smoke load, and the GdUnit4 suite under `res://test`.

Workflow: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

---

## Current state

| Capability | Status |
|------------|--------|
| Unit tests | **Active** — build layer + GameManager |
| Integration tests | **Active** — PoseHUD tabs, LevelAuthoring, BuildPanel mode |
| CI (GitHub Actions) | **Active** — import → smoke → GdUnit4 |
| Local test runner | **Active** — `./addons/gdUnit4/runtest.sh` |
| Manual UX validation | Still required for feel/visuals — see [DEVELOPMENT.md](DEVELOPMENT.md) |

---

## Framework

**GdUnit4 v6.1.3** (vendored at `addons/gdUnit4/`, plugin enabled in `project.godot`).

Compatible with Godot **4.6.x**. CI pins **4.6.3-stable**.

---

## Folder layout

```text
test/
  unit/
    smoke_test.gd                 # Harness sanity checks
    build/
      test_level_save.gd
      test_entity_palette.gd
      test_tile_layer_catalog.gd
    autoload/
      test_game_manager.gd
  integration/
    studio/
      test_level_authoring.gd
      test_pose_hud_tabs.gd
    build/
      test_build_panel_mode.gd
```

Reports write to `reports/` (gitignored). Do not commit them.

---

## Run tests locally

Requires Godot 4.6.x. Set `GODOT_BIN` to the binary path:

```bash
export GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64
chmod +x ./addons/gdUnit4/runtest.sh

# All tests
./addons/gdUnit4/runtest.sh -a res://test

# One suite
./addons/gdUnit4/runtest.sh -a res://test/unit/build/test_level_save.gd

# One folder
./addons/gdUnit4/runtest.sh -a res://test/integration/studio
```

On Linux without a display (same as CI):

```bash
xvfb-run --auto-servernum ./addons/gdUnit4/runtest.sh -a res://test
```

Approximate CI smoke only:

```bash
"$GODOT_BIN" --headless --path . --import --quit-after 1
"$GODOT_BIN" --headless --path . --script res://tools/ci/smoke.gd
```

---

## CI pipeline

Job **Godot import, smoke & tests** (`.github/workflows/ci.yml`):

1. Install / cache Godot 4.6.3-stable
2. Headless project import
3. Smoke load `levels/test.tscn` via `tools/ci/smoke.gd`
4. GdUnit4: `xvfb-run ./addons/gdUnit4/runtest.sh -a res://test`
5. On failure: upload `import.log`, `smoke.log`, `gdunit.log`, and `reports/`

Repo admins should mark this check as **required** on `main` in branch protection.

---

## How to add a test

1. Prefer **unit** tests for pure logic (`RefCounted` helpers, autoload state).
2. Prefer **integration** tests for studio tab / scene orchestration.
3. Create `test/<kind>/<domain>/test_<thing>.gd` extending `GdUnitTestSuite`.
4. Name cases `test_*`. Keep setups in `before_test` / teardown in `after_test`.
5. Run locally, then push — CI must stay green.

```gdscript
extends GdUnitTestSuite


func test_example() -> void:
	assert_bool(true).is_true()
	assert_str(ProjectSettings.get_setting("application/config/name")).is_equal("Masquerade")
```

### Scene tips

- `player/player.tscn` root is a Node2D shell; **`Player.gd` is on `PlayerBody`**. PoseHUD is a sibling under the root.
- `SceneTree.current_scene` must be a **direct child of the tree root** when testing save/authoring helpers.
- Avoid calling `reload_current_scene()` in unit tests — it disrupts the runner.

---

## Coverage (foundation epic)

| Target | Type | Status |
|--------|------|--------|
| Harness smoke | Unit | Done |
| `LevelSave.gd` | Unit | Done |
| `EntityPalette.gd` | Unit | Done |
| `TileLayerCatalog.gd` | Unit | Done |
| `GameManager.gd` | Unit | Done |
| `PoseHUD` tab orchestration | Integration | Done |
| `LevelAuthoring` tab gating | Integration | Done |
| `BuildPanel` mode state | Integration | Done |

### Out of scope (for now)

- Visual snapshot / screenshot diffs
- Full gameplay automation (combat feel, physics timing)
- Tile paint / entity drag input simulation
- Multi-platform export CI

---

## Policy

When opening a PR:

| Change type | Expectation |
|-------------|-------------|
| Logic in `player/build/`, `scripts/autoload/`, or studio tab orchestration | Add or update a focused automated test |
| Scene / resource / path refactors | CI import + smoke + existing tests must pass |
| Pure docs or assets with no behaviour change | Tests not required |
| UX-only tweaks hard to assert | Manual checklist in [DEVELOPMENT.md](DEVELOPMENT.md); note in PR |

Do not merge with a red CI run. Prefer a failing regression test over a silent bugfix when feasible.

---

## Related documents

- [DEVELOPMENT.md](DEVELOPMENT.md) — Local setup and PR checklist
- [ROADMAP.md](../ROADMAP.md) — Feature milestones
- [agents/AGENTS.md](agents/AGENTS.md) — Agent constraints

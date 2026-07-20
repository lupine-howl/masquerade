# Testing guide

CI runs on every pull request to `main`: headless Godot import, main-scene smoke load, and the GdUnit4 test suite.

---

## Current state

| Capability | Status |
|------------|--------|
| Unit / integration tests | **Harness ready** — GdUnit4 v6.1.3; first smoke suite in `test/unit/` |
| CI (GitHub Actions) | **Smoke + tests** — see `.github/workflows/ci.yml` |
| Local test runner | **Ready** — `./addons/gdUnit4/runtest.sh` |
| Manual smoke validation | Still required for UX — see [DEVELOPMENT.md](DEVELOPMENT.md) |

---

## Framework

**GdUnit4 v6.1.3** (vendored under `addons/gdUnit4/`, plugin enabled in `project.godot`).

Compatible with Godot **4.6.x** (CI pins **4.6.3-stable**).

---

## Folder layout

```text
test/
  unit/
    smoke_test.gd       # Harness smoke
    build/              # LevelSave, EntityPalette, TileLayerCatalog
    autoload/           # GameManager
  integration/
    studio/             # PoseHUD tabs + LevelAuthoring
    build/              # BuildPanel mode state
```

Reports are written to `reports/` (gitignored).

---

## Run tests locally

Requires Godot 4.6.x on your PATH, or set `GODOT_BIN`:

```bash
export GODOT_BIN=/path/to/Godot_v4.6.3-stable_linux.x86_64
chmod +x ./addons/gdUnit4/runtest.sh

# Run all tests under res://test
./addons/gdUnit4/runtest.sh -a res://test

# Run a single suite
./addons/gdUnit4/runtest.sh -a res://test/unit/smoke_test.gd
```

Approximate CI smoke (without GdUnit4):

```bash
godot --headless --path . --import --quit-after 1
godot --headless --path . --script res://tools/ci/smoke.gd
```

---

## CI pipeline

1. Install Godot 4.6.3-stable
2. Headless project import
3. Smoke load `levels/test.tscn` via `tools/ci/smoke.gd`
4. Run GdUnit4: `./addons/gdUnit4/runtest.sh -a res://test` (under `xvfb-run` on Linux CI)

---

## Writing tests

```gdscript
extends GdUnitTestSuite


func test_example() -> void:
	assert_bool(true).is_true()
	assert_str("Masquerade").is_equal("Masquerade")
```

Place new suites under `test/unit/` or `test/integration/` matching the domain. Prefer unit tests for pure logic (`LevelSave`, `EntityPalette`, `GameManager`); use integration suites for studio tab / scene orchestration.

---

## Planned coverage (next slices)

| Target | Type | Slice |
|--------|------|-------|
| `LevelSave.gd` | Unit | **Done** (Slice 3) |
| `EntityPalette.gd` | Unit | **Done** (Slice 3) |
| `TileLayerCatalog.gd` | Unit | **Done** (Slice 3) |
| `GameManager.gd` | Unit | **Done** (Slice 4) |
| `PoseHUD._apply_studio_tab` | Integration | **Done** (Slice 5) |
| `LevelAuthoring.apply_studio_tab` | Integration | **Done** (Slice 5) |
| `BuildPanel` mode state | Integration | **Done** (Slice 5) |

---

## Policy

- PRs that add testable logic in build/studio/autoload areas should include focused tests once those suites exist.
- Scene/resource refactors must pass CI smoke + existing tests.
- Visual snapshot testing and full gameplay automation are out of scope for this epic.

---

## Related documents

- [DEVELOPMENT.md](DEVELOPMENT.md) — Local setup and PR checklist
- [ROADMAP.md](../ROADMAP.md) — Feature milestones
- [agents/AGENTS.md](agents/AGENTS.md) — Agent constraints

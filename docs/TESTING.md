# Testing guide

Automated testing and CI for Masquerade are **planned** as the next engineering epic after documentation hardening. This document describes the intended setup so contributors and agents know what is coming.

---

## Current state

| Capability | Status |
|------------|--------|
| Unit / integration tests | Not set up |
| CI (GitHub Actions) | Not set up |
| Local test runner | Not set up |
| Manual smoke validation | Required — see [DEVELOPMENT.md](DEVELOPMENT.md) |

Until CI lands, use the manual validation checklist in [DEVELOPMENT.md](DEVELOPMENT.md) before opening PRs.

---

## Planned approach

### Test framework

**GdUnit4** — Godot 4 test framework with headless CI support.

### CI platform

**GitHub Actions** on `ubuntu-latest`, Godot **4.6** stable.

### Planned pipeline

1. Headless project import
2. Smoke load of `levels/test.tscn`
3. Run GdUnit4 test suite

### Planned folder layout

```text
test/
  unit/
    build/          # LevelSave, EntityPalette, TileLayerCatalog
    autoload/       # GameManager
  integration/
    studio/         # PoseHUD tab orchestration, LevelAuthoring
    build/          # BuildPanel mode state
```

### Planned local command

```bash
# Exact command TBD when GdUnit4 is added; will look like:
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd
```

---

## First tests (planned priority)

| Target | Type | Why |
|--------|------|-----|
| `LevelSave.gd` | Unit | Save/dirty flag logic; recent tab-switch work |
| `EntityPalette.gd` | Unit | Palette dedup and categorization |
| `TileLayerCatalog.gd` | Unit | Layer discovery for Build panel |
| `GameManager.gd` | Unit | HP, keys, points, signals |
| `PoseHUD._apply_studio_tab` | Integration | Tab visibility and mode flags |
| `LevelAuthoring.apply_studio_tab` | Integration | Entity sim and marker visibility by tab |
| `BuildPanel` mode state | Integration | Tab/mode transitions (not full paint simulation) |

---

## Policy (planned)

- PRs that add testable logic in build/studio/autoload areas should include focused tests.
- Scene/resource refactors must pass CI smoke checks.
- Visual snapshot testing and full gameplay automation are out of scope for the first epic.

---

## Related documents

- [DEVELOPMENT.md](DEVELOPMENT.md) — Manual validation until CI exists
- [ROADMAP.md](../ROADMAP.md) — Feature milestones
- [agents/AGENTS.md](agents/AGENTS.md) — Agent constraints

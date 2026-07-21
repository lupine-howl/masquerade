extends Node

## Persistence layer for user projects (M0 project model).
##
## A project lives at <root_dir>/<slug>/ with a project.cfg manifest and
## levels/*.tscn copies. Templates under res://templates/ are read-only
## sources; creating a project copies their levels into user://.
##
## Fallible operations return {"ok": bool, ...} result dictionaries,
## matching the LevelSave convention.

const SCHEMA_VERSION := 1
const PROJECT_CFG := "project.cfg"
const LEVELS_DIR := "levels"
const TEMPLATES_ROOT := "res://templates"
const TEMPLATE_CFG := "template.cfg"

const DEFAULT_RULES := {
	"max_hp": 80.0,
	"starting_hp": 80.0,
	"keys_to_exit": 1,
}

## Overridable so tests can isolate their own sandbox directory.
var root_dir := "user://projects"

## The currently open project manifest (empty when no project is open).
var current: Dictionary = {}


func has_project() -> bool:
	return not current.is_empty()


func close_project() -> void:
	current = {}


func project_dir(slug: String) -> String:
	return root_dir.path_join(slug)


## Returns manifests of all valid projects under root_dir, newest first.
func list_projects() -> Array[Dictionary]:
	var projects: Array[Dictionary] = []
	var dir := DirAccess.open(root_dir)
	if dir == null:
		return projects
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var loaded := _read_manifest(project_dir(entry))
			if loaded.ok:
				projects.append(loaded.project)
		entry = dir.get_next()
	dir.list_dir_end()
	projects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.modified_unix) > int(b.modified_unix)
	)
	return projects


## Returns manifests of available templates under res://templates/.
func list_templates() -> Array[Dictionary]:
	var templates: Array[Dictionary] = []
	var dir := DirAccess.open(TEMPLATES_ROOT)
	if dir == null:
		return templates
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var loaded := _read_template(entry)
			if loaded.ok:
				templates.append(loaded.template)
		entry = dir.get_next()
	dir.list_dir_end()
	templates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.id) < String(b.id)
	)
	return templates


## Creates a new project from a template. Does not open it.
func create_project(display_name: String, template_id: String = "platformer") -> Dictionary:
	var name := display_name.strip_edges()
	if name.is_empty():
		return {"ok": false, "error": "Project name is empty"}

	var template_result := _read_template(template_id)
	if not template_result.ok:
		return template_result
	var template: Dictionary = template_result.template

	var slug := _unique_slug(_slugify(name))
	var dir_path := project_dir(slug)
	var levels_path := dir_path.path_join(LEVELS_DIR)
	var mk_err := DirAccess.make_dir_recursive_absolute(levels_path)
	if mk_err != OK:
		return {"ok": false, "error": "Could not create %s: %s" % [levels_path, error_string(mk_err)]}

	var order := PackedStringArray()
	var index := 1
	for source_path in template.levels:
		if not FileAccess.file_exists(source_path):
			_remove_recursive(dir_path)
			return {"ok": false, "error": "Template level missing: %s" % source_path}
		var level_file := "level_%d.tscn" % index
		var copy_err := DirAccess.copy_absolute(String(source_path), levels_path.path_join(level_file))
		if copy_err != OK:
			_remove_recursive(dir_path)
			return {"ok": false, "error": "Copy failed for %s: %s" % [source_path, error_string(copy_err)]}
		order.append(level_file)
		index += 1

	var now := int(Time.get_unix_time_from_system())
	var project := {
		"schema_version": SCHEMA_VERSION,
		"name": name,
		"slug": slug,
		"template": template_id,
		"created_unix": now,
		"modified_unix": now,
		"levels": order,
		"current_level": 0,
		"rules": (template.rules as Dictionary).duplicate(),
	}
	var write_result := _write_manifest(dir_path, project)
	if not write_result.ok:
		_remove_recursive(dir_path)
		return write_result
	return {"ok": true, "slug": slug, "project": project}


## Appends a new level to the current project, copied from the template's
## blank-level scene (or its first level when no blank scene is declared).
func add_level() -> Dictionary:
	if not has_project():
		return {"ok": false, "error": "No project is open"}
	var template_result := _read_template(String(current.get("template", "platformer")))
	if not template_result.ok:
		return template_result
	var template: Dictionary = template_result.template
	var source_path := String(template.get("blank_scene", ""))
	if source_path.is_empty():
		source_path = String((template.levels as PackedStringArray)[0])
	if not FileAccess.file_exists(source_path):
		return {"ok": false, "error": "Level source missing: %s" % source_path}

	var levels_path := project_dir(current.slug).path_join(LEVELS_DIR)
	var levels: PackedStringArray = current.levels
	var number := levels.size() + 1
	while FileAccess.file_exists(levels_path.path_join("level_%d.tscn" % number)):
		number += 1
	var level_file := "level_%d.tscn" % number
	var copy_err := DirAccess.copy_absolute(source_path, levels_path.path_join(level_file))
	if copy_err != OK:
		return {"ok": false, "error": "Copy failed: %s" % error_string(copy_err)}

	levels.append(level_file)
	current.levels = levels
	var save_result := save_project()
	if not save_result.ok:
		return save_result
	var new_index := levels.size() - 1
	return {"ok": true, "index": new_index, "path": get_level_path(new_index)}


## Marks a level as current and persists the choice. Does not change scenes.
func set_current_level(index: int) -> Dictionary:
	if not has_project():
		return {"ok": false, "error": "No project is open"}
	if get_level_path(index).is_empty():
		return {"ok": false, "error": "No level at index %d" % index}
	current.current_level = index
	return save_project()


## Advances past the current level. Returns an action for the caller:
## "next_level" (with path), "completed" (project finished, progress reset),
## or "no_project". Does not change scenes.
func advance_level() -> Dictionary:
	if not has_project():
		return {"ok": false, "action": "no_project"}
	var next_index := int(current.current_level) + 1
	var levels: PackedStringArray = current.levels
	if next_index < levels.size():
		current.current_level = next_index
		var save_result := save_project()
		if not save_result.ok:
			return save_result
		return {"ok": true, "action": "next_level", "index": next_index, "path": get_level_path(next_index)}
	current.current_level = 0
	var reset_result := save_project()
	if not reset_result.ok:
		return reset_result
	return {"ok": true, "action": "completed"}


## Loads a project manifest and makes it the current project.
func load_project(slug: String) -> Dictionary:
	var result := _read_manifest(project_dir(slug))
	if not result.ok:
		return result
	current = result.project
	return {"ok": true, "project": current}


## Persists the current project manifest, bumping the modified timestamp.
func save_project() -> Dictionary:
	if not has_project():
		return {"ok": false, "error": "No project is open"}
	current.modified_unix = int(Time.get_unix_time_from_system())
	return _write_manifest(project_dir(current.slug), current)


## Deletes a project directory. Closes it first if it is the current project.
func delete_project(slug: String) -> Dictionary:
	var dir_path := project_dir(slug)
	if not DirAccess.dir_exists_absolute(dir_path):
		return {"ok": false, "error": "No project at %s" % dir_path}
	if has_project() and String(current.slug) == slug:
		close_project()
	var err := _remove_recursive(dir_path)
	if err != OK:
		return {"ok": false, "error": "Delete failed: %s" % error_string(err)}
	return {"ok": true}


## Absolute path of a level in the current project, or "" when invalid.
func get_level_path(index: int) -> String:
	if not has_project():
		return ""
	var levels: PackedStringArray = current.levels
	if index < 0 or index >= levels.size():
		return ""
	return project_dir(current.slug).path_join(LEVELS_DIR).path_join(levels[index])


func get_rule(key: String, default_value: Variant = null) -> Variant:
	if not has_project():
		return default_value
	var rules: Dictionary = current.get("rules", {})
	return rules.get(key, default_value if default_value != null else DEFAULT_RULES.get(key))


# --- Internal helpers ---


func _slugify(name: String) -> String:
	var slug := ""
	for character in name.to_lower():
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			slug += character
		elif not slug.ends_with("-"):
			slug += "-"
	slug = slug.trim_prefix("-").trim_suffix("-")
	return slug if not slug.is_empty() else "project"


func _unique_slug(base: String) -> String:
	if not DirAccess.dir_exists_absolute(project_dir(base)):
		return base
	var counter := 2
	while DirAccess.dir_exists_absolute(project_dir("%s-%d" % [base, counter])):
		counter += 1
	return "%s-%d" % [base, counter]


func _read_manifest(dir_path: String) -> Dictionary:
	var cfg_path := dir_path.path_join(PROJECT_CFG)
	var cfg := ConfigFile.new()
	var err := cfg.load(cfg_path)
	if err != OK:
		return {"ok": false, "error": "Cannot read %s: %s" % [cfg_path, error_string(err)]}
	var name: String = cfg.get_value("project", "name", "")
	var slug: String = cfg.get_value("project", "slug", "")
	if name.is_empty() or slug.is_empty():
		return {"ok": false, "error": "Manifest missing name/slug: %s" % cfg_path}
	var project := {
		"schema_version": int(cfg.get_value("project", "schema_version", SCHEMA_VERSION)),
		"name": name,
		"slug": slug,
		"template": String(cfg.get_value("project", "template", "platformer")),
		"created_unix": int(cfg.get_value("project", "created_unix", 0)),
		"modified_unix": int(cfg.get_value("project", "modified_unix", 0)),
		"levels": PackedStringArray(cfg.get_value("levels", "order", PackedStringArray())),
		"current_level": int(cfg.get_value("levels", "current", 0)),
		"rules": {
			"max_hp": float(cfg.get_value("rules", "max_hp", DEFAULT_RULES.max_hp)),
			"starting_hp": float(cfg.get_value("rules", "starting_hp", DEFAULT_RULES.starting_hp)),
			"keys_to_exit": int(cfg.get_value("rules", "keys_to_exit", DEFAULT_RULES.keys_to_exit)),
		},
	}
	return {"ok": true, "project": project}


func _write_manifest(dir_path: String, project: Dictionary) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.set_value("project", "schema_version", project.schema_version)
	cfg.set_value("project", "name", project.name)
	cfg.set_value("project", "slug", project.slug)
	cfg.set_value("project", "template", project.get("template", "platformer"))
	cfg.set_value("project", "created_unix", project.created_unix)
	cfg.set_value("project", "modified_unix", project.modified_unix)
	cfg.set_value("levels", "order", project.levels)
	cfg.set_value("levels", "current", project.current_level)
	var rules: Dictionary = project.rules
	cfg.set_value("rules", "max_hp", rules.max_hp)
	cfg.set_value("rules", "starting_hp", rules.starting_hp)
	cfg.set_value("rules", "keys_to_exit", rules.keys_to_exit)
	var cfg_path := dir_path.path_join(PROJECT_CFG)
	var err := cfg.save(cfg_path)
	if err != OK:
		return {"ok": false, "error": "Cannot write %s: %s" % [cfg_path, error_string(err)]}
	return {"ok": true}


func _read_template(template_id: String) -> Dictionary:
	var cfg_path := TEMPLATES_ROOT.path_join(template_id).path_join(TEMPLATE_CFG)
	var cfg := ConfigFile.new()
	var err := cfg.load(cfg_path)
	if err != OK:
		return {"ok": false, "error": "Unknown template '%s' (%s)" % [template_id, error_string(err)]}
	var scenes := PackedStringArray(cfg.get_value("levels", "scenes", PackedStringArray()))
	if scenes.is_empty():
		return {"ok": false, "error": "Template '%s' declares no levels" % template_id}
	var template := {
		"id": template_id,
		"name": String(cfg.get_value("template", "name", template_id)),
		"description": String(cfg.get_value("template", "description", "")),
		"levels": scenes,
		"blank_scene": String(cfg.get_value("levels", "blank_scene", "")),
		"rules": {
			"max_hp": float(cfg.get_value("rules", "max_hp", DEFAULT_RULES.max_hp)),
			"starting_hp": float(cfg.get_value("rules", "starting_hp", DEFAULT_RULES.starting_hp)),
			"keys_to_exit": int(cfg.get_value("rules", "keys_to_exit", DEFAULT_RULES.keys_to_exit)),
		},
	}
	return {"ok": true, "template": template}


func _remove_recursive(dir_path: String) -> Error:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return DirAccess.get_open_error()
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var child := dir_path.path_join(entry)
		if dir.current_is_dir():
			var nested := _remove_recursive(child)
			if nested != OK:
				return nested
		else:
			var file_err := DirAccess.remove_absolute(child)
			if file_err != OK:
				return file_err
		entry = dir.get_next()
	dir.list_dir_end()
	return DirAccess.remove_absolute(dir_path)

extends Node
class_name PlayerAnimator

@export var tree: AnimationTree
@export var debug_hud: Node

# Cache the base paths so we aren't creating so many strings every single frame
const LOWER_COND := "parameters/LowerState/conditions/"
const UPPER_COND := "parameters/UpperState/conditions/"

func _ready() -> void:
	if tree: tree.active = true

# This is your old _set_state, but encapsulated
func set_condition(anim_name: String, value: bool) -> void:
	if debug_hud:
		debug_hud.update_anim_state(anim_name, value)
		
	var pos_name := "is_" + anim_name
	var neg_name := "is_not_" + anim_name
	
	# Safely set Lower State
	_set_tree_param(LOWER_COND + pos_name, value)
	_set_tree_param(LOWER_COND + neg_name, !value)
	
	# Safely set Upper State
	_set_tree_param(UPPER_COND + pos_name, value)
	_set_tree_param(UPPER_COND + neg_name, !value)

func _set_tree_param(param_path: String, value: bool) -> void:
	# Only set it if it actually exists in the tree to prevent console spam
	if param_path in tree:
		tree[param_path] = value

# A helper to clear everything (useful for death/respawn)
func reset_all_conditions() -> void:
	var states = ["on_ground", "on_ladder", "on_wall", "wall_climbing", "on_ledge", "jumping", "falling", "double_jumping", "running", "crouching", "attacking", "rolling", "dead", "dashing"]
	for s in states:
		set_condition(s, false)

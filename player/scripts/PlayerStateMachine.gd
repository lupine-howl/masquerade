class_name PlayerStateMachine
extends Node

@export var initial_state: PlayerState

var current_state: PlayerState
var states: Dictionary = {}
var player: Player # <--- 1. ADD THIS LINE

func init(p_player: Player) -> void:
	player = p_player # <--- 2. ADD THIS LINE (and rename the parameter to p_player to avoid naming conflicts)
	
	# 1. Discover and initialize all child state nodes
	for child in get_children():
		if child is PlayerState:
			# Store them in a dictionary by their node name (lowercased for safety)
			states[child.name.to_lower()] = child
			child.init(player, self)
			
	# 2. Start the engine
	if initial_state:
		_enter_state(initial_state)

func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

# Called by individual states (e.g., state_machine.transition_to("air"))
func transition_to(state_name: String) -> void:
	var target_state = states.get(state_name.to_lower())
	if not target_state:
		push_warning("Attempted to transition to non-existent state: ", state_name)
		return
		
	if current_state == target_state:
		return
		
	if current_state:
		current_state.exit()
		
	_enter_state(target_state)

func _enter_state(new_state: PlayerState) -> void:
	current_state = new_state
	
	var state_enum = _get_enum_from_name(current_state.name)
	
	# Keep the player's internal state variable perfectly in sync!
	if state_enum != -1:
		player.state = state_enum 
	
	if player.state_to_anim_map.has(state_enum):
		player.animator.set_condition(player.state_to_anim_map[state_enum], true)
		
	current_state.enter()
	
# A helper to bridge your existing MoveState enum with the new Node names
func _get_enum_from_name(node_name: String) -> int:
	match node_name.to_lower():
		"ground": return player.MoveState.GROUNDED
		"air": return player.MoveState.FALLING 
		"dash": return player.MoveState.DASHING
		"roll": return player.MoveState.ROLLING
		"wallclimb": return player.MoveState.WALL_CLIMBING
		"ledgeclimb": return player.MoveState.LEDGE_CLIMBING
		"wallclimb": return player.MoveState.WALL_CLIMBING
		"ladderclimb": return player.MoveState.LADDER_CLIMBING
		"ledgeclimb": return player.MoveState.LEDGE_CLIMBING		
		_: return -1

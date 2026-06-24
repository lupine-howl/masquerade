class_name PlayerStateMachine
extends Node

@export var initial_state: PlayerState

var current_state: PlayerState
var states: Dictionary = {}
var player: Player 

func init(p_player: Player) -> void:
	player = p_player 
	
	for child in get_children():
		if child is PlayerState:
			states[child.name.to_lower()] = child
			child.init(player, self)
			
	if initial_state:
		_enter_state(initial_state)

func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(state_name: String) -> void:
	var target_state = states.get(state_name.to_lower())
	if not target_state:
		push_warning("Attempted to transition to non-existent state: ", state_name)
		return
		
	if current_state == target_state: return
		
	if current_state:
		current_state.exit()
		
	_enter_state(target_state)

func _enter_state(new_state: PlayerState) -> void:
	current_state = new_state
	current_state.enter()

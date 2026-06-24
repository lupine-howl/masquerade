class_name PlayerState
extends Node

var player: Player # (Assuming you named your main script class_name Player)
var state_machine: PlayerStateMachine # We will create this next!

func init(p_player: Player, p_state_machine: PlayerStateMachine) -> void:
	player = p_player
	state_machine = p_state_machine

# Virtual methods to override in actual implementations
func enter() -> void:
	pass

func exit() -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

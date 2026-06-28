extends CanvasLayer

var lbl_physics: Label

# Tracking state history so you can spot 1-frame transition bugs!
var prev_state_name := "None"
var current_state_name := "None"

func _ready() -> void:
	# Setup Physics Label
	lbl_physics = Label.new()
	lbl_physics.position = Vector2(16, 16)
	
	lbl_physics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	lbl_physics.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_physics.add_theme_constant_override("outline_size", 4)
	add_child(lbl_physics)

func update_physics(player: CharacterBody2D) -> void:
	# Safely grab the active FSM Node name
	var active_fsm_node = "NULL"
	if player.state_machine and player.state_machine.current_state:
		active_fsm_node = player.state_machine.current_state.name

	# Update State History
	if active_fsm_node != current_state_name:
		prev_state_name = current_state_name
		current_state_name = active_fsm_node

	# --- PULL CURRENT ANIMATION DIRECTLY FROM THE PLAYER ---
	var current_anim = "Unknown"
	if player.animator and player.animator.anim_player:
		current_anim = player.animator.anim_player.current_animation
		if current_anim == "": 
			current_anim = "[Stopped]"

	# Grab raw inputs for debugging controller deadzones
	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")

	var text := "--- VITALS ---\n"
	text += "FPS: " + str(Engine.get_frames_per_second()) + "\n"
	text += "Position: " + str(player.global_position.round()) + "\n\n"

	text += "--- CORE FSM ---\n"
	text += "Current Node: " + current_state_name + "\n" 
	text += "Previous Node: " + prev_state_name + "\n" 
	text += "Playing Anim: " + current_anim + "\n\n" 
	
	text += "--- MOVEMENT & INPUT ---\n"
	text += "Velocity: " + str(player.velocity.round()) + "\n"
	text += "Raw Input: (" + str(snapped(input_x, 0.01)) + ", " + str(snapped(input_y, 0.01)) + ")\n"
	text += "Facing: " + str(player.facing) + "\n\n"
	
	text += "--- ENGINE PHYSICS ---\n"
	text += "On Floor: " + str(player.is_on_floor()) + "\n"
	text += "On Wall: " + str(player.is_on_wall()) + "\n"
	text += "On Ceiling: " + str(player.is_on_ceiling()) + "\n\n"
	
	text += "--- CUSTOM ENVIRONMENT ---\n"
	text += "Submerged: " + str(player.is_submerged) + "\n"
	text += "On Ladder: " + str(player.is_on_ladder) + "\n"
	text += "Wall Raycast: " + str(player.wall_detector.is_colliding() if player.wall_detector else false) + "\n"
	text += "Ledge Raycast: " + str(player.ledge_detector.is_colliding() if player.ledge_detector else false) + "\n\n"
	
	text += "--- TIMERS & COMBAT ---\n"
	text += "Jump Buffer: " + str(snapped(player.jump_buffer_timer, 0.01)) + "\n"
	text += "Coyote Timer: " + str(snapped(player.coyote_timer, 0.01)) + "\n"
	text += "Can Double Jump: " + str(player.can_double_jump) + "\n"
	text += "Invincible: " + str(player.is_invincible) + "\n"
	
	lbl_physics.text = text

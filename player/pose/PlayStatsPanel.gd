class_name PlayStatsPanel
extends PanelContainer

var _columns: HBoxContainer
var _section_labels: Array[Label] = []


func _ready() -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("panel", transparent)

	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 16)
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_columns)

	for title in ["Vitals", "Core FSM", "Movement", "Physics", "Environment", "Combat"]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		_columns.add_child(col)

		var heading := Label.new()
		heading.text = title
		heading.add_theme_font_size_override("font_size", PoseTabStyles.PANEL_FONT_SIZE)
		heading.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		col.add_child(heading)

		var body := Label.new()
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", PoseTabStyles.PANEL_FONT_SIZE)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(body)
		_section_labels.append(body)


func update_from_player(player: Player) -> void:
	if _section_labels.is_empty() or player == null:
		return

	var active_fsm_node := "NULL"
	if player.state_machine and player.state_machine.current_state:
		active_fsm_node = player.state_machine.current_state.name

	var current_anim := "Unknown"
	if player.animator:
		current_anim = player.animator.current_animation
		if current_anim == "":
			current_anim = "[Stopped]"

	var input_x := Input.get_axis("ui_left", "ui_right")
	var input_y := Input.get_axis("ui_up", "ui_down")

	_section_labels[0].text = "FPS: %s\nPosition: %s" % [
		Engine.get_frames_per_second(),
		str(player.global_position.round())
	]
	_section_labels[1].text = "Node: %s\nPrev: %s\nAnim: %s" % [
		active_fsm_node,
		_get_prev_state_name(player),
		current_anim
	]
	_section_labels[2].text = "Velocity: %s\nInput: (%s, %s)\nFacing: %s" % [
		str(player.velocity.round()),
		snapped(input_x, 0.01),
		snapped(input_y, 0.01),
		player.facing
	]
	_section_labels[3].text = "Floor: %s\nWall: %s\nCeiling: %s" % [
		player.is_on_floor(),
		player.is_on_wall(),
		player.is_on_ceiling()
	]
	_section_labels[4].text = "Submerged: %s\nLadder: %s\nWall ray: %s\nLedge ray: %s" % [
		player.is_submerged,
		player.is_on_ladder,
		player.wall_detector.is_colliding() if player.wall_detector else false,
		player.ledge_detector.is_colliding() if player.ledge_detector else false
	]
	_section_labels[5].text = "Jump buf: %s\nCoyote: %s\nDbl jump: %s\nInvincible: %s" % [
		snapped(player.jump_buffer_timer, 0.01),
		snapped(player.coyote_timer, 0.01),
		player.can_double_jump,
		player.is_invincible
	]


func _get_prev_state_name(player: Player) -> String:
	if player.state_machine and player.state_machine.current_state:
		# Mirror debug_hud history via a lightweight tracker on the panel.
		if not has_meta("_prev_fsm"):
			set_meta("_prev_fsm", player.state_machine.current_state.name)
			set_meta("_curr_fsm", player.state_machine.current_state.name)
		var curr: String = get_meta("_curr_fsm")
		var active := player.state_machine.current_state.name
		if active != curr:
			set_meta("_prev_fsm", curr)
			set_meta("_curr_fsm", active)
		return String(get_meta("_prev_fsm"))
	return "None"

class_name PoseMarker
extends Node2D

# Signals to notify the manager/UI
signal clicked_on_marker(marker_node: Node2D)
signal drag_dropped(marker_node: Node2D)
signal request_save(marker_node: Node2D) # 🆕 Connect this in your UI script to trigger auto_save_pose()
signal request_deactivate(marker_node: Node2D) # 🆕 Connect this in your UI to set active_marker = null

@export var slave: RigidBody2D
@export var slave_parent: RigidBody2D
@export var sibling: PoseMarker
@export var follow_parent_rotation: bool = false
@export var is_controlled: bool = true
@export var pivot: Node2D
@export var invert_rotation_on_flip: bool

@export_category("Dimensions")
@export var inner_radius: float = 16.0   
@export var outer_radius: float = 24.0   

@export_category("Settings")
@export var is_dev_mode: bool = true

# Interaction States
var is_dragging_position: bool = false
var is_dragging_rotation: bool = false
var mouse_over: bool = false

# 🆕 Unsaved State Tracking
var original_position: Vector2
var original_rotation: float
var has_unsaved_changes: bool = false

@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var outer_rotation_ring: Panel = $RotatingArea/OuterRotationRing
@onready var inner_move_circle: Panel = $RotatingArea/InnerMoveCircle
@onready var inner_move_selected: Panel = $RotatingArea/InnerMoveCircleSelected

# 🆕 UI Action Menu References
@onready var action_menu: HBoxContainer = $HBoxContainer
@onready var btn_save: Button = $Controls/VBoxContainer/BtnSave
@onready var btn_revert: Button = $Controls/VBoxContainer/BtnRevert
@onready var rotating_area = $RotatingArea

func _ready() -> void:
	area_2d.mouse_entered.connect(func(): mouse_over = true)
	area_2d.mouse_exited.connect(func(): mouse_over = false)
	
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = outer_radius
	
	if slave:
		global_position = slave.global_position
		global_rotation = slave.global_rotation
		
	# 🆕 Setup Action Menu
	if action_menu:
		action_menu.visible = false
		btn_save.pressed.connect(_on_save_pressed)
		btn_revert.pressed.connect(_on_revert_pressed)
		
	set_active(false)
	set_hud_visible(false)
		
	if is_controlled:
		take_control()

func set_hud_visible(is_visible: bool) -> void:
	if outer_rotation_ring:
		outer_rotation_ring.visible = is_visible

func set_active(is_active: bool) -> void:
	if inner_move_circle and inner_move_selected:
		inner_move_selected.visible = is_active
		inner_move_circle.visible = not is_active		
	# 🆕 If deactivated by clicking away, clean up the UI
	if not is_active:
		_reset_marker_ui()

func _process(_delta: float) -> void:
	if not is_dev_mode: return
		
	var mouse_pos = get_global_mouse_position()
	
	if is_dragging_position:
		global_position = mouse_pos
	elif is_dragging_rotation:
		var target_angle = global_position.angle_to_point(mouse_pos)
		rotating_area.rotation = target_angle

func take_control():
	if slave:
		slave.freeze = true
		is_controlled = true
		slave.linear_velocity = Vector2.ZERO
		slave.angular_velocity = 0.0
		global_position = slave.global_position
		global_rotation = slave.global_rotation	

func release_control():
	is_controlled = false
	slave.freeze = false

func _physics_process(delta: float) -> void:
	var is_flipped = pivot.scale.x < 0
	if slave:
		var target_rotation = global_rotation_degrees
		if slave_parent and follow_parent_rotation:
			target_rotation = slave_parent.global_rotation_degrees
		if invert_rotation_on_flip and is_flipped: 
			target_rotation += 180
			
		if is_controlled:
			slave.global_position = global_position
			slave.global_rotation_degrees = target_rotation
		else:
			global_position = slave.global_position

			
					
func _input(event: InputEvent) -> void:
	if not is_dev_mode: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and mouse_over:
			# --- MOUSE DOWN LOGIC ---
			var distance = global_position.distance_to(get_global_mouse_position())
			
			if distance <= outer_radius:
				clicked_on_marker.emit(self)
			
			if distance <= inner_radius:
				_capture_original_state()
				is_dragging_position = true
				get_viewport().set_input_as_handled()
				
			elif distance > inner_radius and distance <= outer_radius:
				if outer_rotation_ring.visible:
					_capture_original_state()
					is_dragging_rotation = true
					get_viewport().set_input_as_handled()
					
		elif not event.pressed:
			# --- MOUSE RELEASE LOGIC ---
			var was_dragging = is_dragging_position or is_dragging_rotation
			is_dragging_position = false
			is_dragging_rotation = false
			
			if was_dragging:
				_show_unsaved_state()
				drag_dropped.emit(self)

# --- 🆕 NEW STATE MANAGEMENT FUNCTIONS ---

func _capture_original_state():
	# Only capture if we haven't already moved it (prevents overwriting original position if dragged twice before saving)
	if not has_unsaved_changes:
		original_position = global_position
		original_rotation = global_rotation
		has_unsaved_changes = true

func _show_unsaved_state():
	if action_menu:
		action_menu.visible = true
		
	# Change color to indicate unsaved changes (Orange)
	var unsaved_color = Color(1.0, 0.5, 0.0) 
	if inner_move_selected: inner_move_selected.modulate = unsaved_color
	if outer_rotation_ring: outer_rotation_ring.modulate = unsaved_color

func _reset_marker_ui():
	has_unsaved_changes = false
	if action_menu: action_menu.visible = false
	
	# Reset back to default color
	if inner_move_selected: inner_move_selected.modulate = Color.WHITE
	if outer_rotation_ring: outer_rotation_ring.modulate = Color.WHITE

func _on_save_pressed():
	# Tell the UI CanvasLayer to save this marker's pose
	request_save.emit(self) 
	_reset_marker_ui()

func _on_revert_pressed():
	# Revert physical transforms
	global_position = original_position
	global_rotation = original_rotation
	
	_reset_marker_ui()
	set_active(false)
	set_hud_visible(false)
	
	# Tell the UI CanvasLayer to drop this marker
	request_deactivate.emit(self)

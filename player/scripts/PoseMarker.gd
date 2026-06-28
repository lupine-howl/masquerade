extends Node2D

# 🆕 Signal to notify the manager when this marker becomes active
signal clicked_on_marker(marker_node: Node2D)
signal drag_dropped(marker_node: Node2D)

@export var slave: RigidBody2D
@export var slave_parent: RigidBody2D
@export var follow_parent_rotation: bool = false
@export var is_controlled: bool = true
@export var pivot: Node2D
@export var invert_rotation_on_flip: bool


@export_category("Dimensions")
@export var inner_radius: float = 16.0   
@export var outer_radius: float = 40.0   

@export_category("Settings")
@export var is_dev_mode: bool = true

# Interaction States
var is_dragging_position: bool = false
var is_dragging_rotation: bool = false

var mouse_over: bool = false

@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var outer_rotation_ring: Panel = $OuterRotationRing
@onready var inner_move_circle: Panel = $InnerMoveCircle
@onready var inner_move_selected: Panel = $InnerMoveCircleSelected

func _ready() -> void:
	area_2d.mouse_entered.connect(func(): mouse_over = true)
	area_2d.mouse_exited.connect(func(): mouse_over = false)
	
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = outer_radius
	
	if(slave):
		global_position = slave.global_position
		global_rotation = slave.global_rotation
		
	if(is_controlled):
		take_control()

# 🆕 New function the manager can call to toggle the outer visual ring
func set_hud_visible(is_visible: bool) -> void:
	if outer_rotation_ring:
		outer_rotation_ring.visible = is_visible

func set_active(is_active: bool) -> void:
	if inner_move_circle and inner_move_selected:
		inner_move_selected.visible = is_active
		inner_move_circle.visible = not is_active

func _process(_delta: float) -> void:
	if not is_dev_mode:
		return
		
	var mouse_pos = get_global_mouse_position()
	
	if is_dragging_position:
		global_position = mouse_pos
		
	elif is_dragging_rotation:
		var target_angle = global_position.angle_to_point(mouse_pos)
		rotation = target_angle

func take_control():
	if(slave):
		slave.freeze = true
		is_controlled = true
		slave.linear_velocity = Vector2.ZERO
		slave.angular_velocity = 0.0
		global_position = slave.global_position
		global_rotation = slave.global_rotation	

func release_control():
	is_controlled = false
	#slave.freeze = false

func _physics_process(delta: float) -> void:
	var is_flipped = pivot.scale.x < 0
	if(slave):
		var target_rotation = global_rotation_degrees
		if(slave_parent and follow_parent_rotation):
			target_rotation = slave_parent.global_rotation_degrees
		if(invert_rotation_on_flip and is_flipped): target_rotation += 180
		if(is_controlled):
			slave.global_position = global_position
			slave.global_rotation_degrees = target_rotation
		else:
			global_position = slave.global_position
			global_rotation_degrees = slave.global_rotation
					
func _input(event: InputEvent) -> void:
	if not is_dev_mode:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and mouse_over:
			# --- MOUSE DOWN LOGIC ---
			var distance = global_position.distance_to(get_global_mouse_position())
			
			if distance <= outer_radius:
				clicked_on_marker.emit(self)
			
			if distance <= inner_radius:
				is_dragging_position = true
				get_viewport().set_input_as_handled()
			elif distance > inner_radius and distance <= outer_radius:
				if outer_rotation_ring.visible:
					is_dragging_rotation = true
					get_viewport().set_input_as_handled()
					
		elif not event.pressed:
			# --- MOUSE RELEASE LOGIC (De-indented!) ---
			# Notice how this lines up perfectly with 'if event.pressed and mouse_over'
			var was_dragging = is_dragging_position or is_dragging_rotation
			is_dragging_position = false
			is_dragging_rotation = false
			
			if was_dragging:
				drag_dropped.emit(self)

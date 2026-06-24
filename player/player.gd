class_name Player
extends CharacterBody2D

# ---------------------------------------------------------
# CONSTANTS & EXPORTS
# ---------------------------------------------------------
@export var SPEED := 180.0
@export var LADDER_CLIMB_SPEED := 100.0 
@export var WALL_CLIMB_SPEED := 100.0   
@export var JUMP_VELOCITY := -600.0
@export var DOUBLE_JUMP_VELOCITY := -600.0
@export var ROLL_BOOST := 400.0
@export var DASH_BOOST := 400.0
@export var attack_damage := 25.0

@export_category("Water Settings")
@export var water_gravity_multiplier := 0.35  
@export var water_swim_velocity := -350.0     
@export var water_terminal_velocity := 200.0   
@export var water_speed_multiplier := 0.60     

@export_category("Environmental Friction")
@export var grounded_horizontal_current_dampening := 0.25 

@export_category("Debug")
@export var show_debug_ui := true

@export var ragdoll : Node2D

# ---------------------------------------------------------
# VARIABLES
# ---------------------------------------------------------
var is_invincible := false 
var facing := 1 

# Shared Timers
var attack_buffer := 0.15
var attack_timer := 0.0
var can_double_jump := true
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var wall_jump_lock := 0.0 
var spawn_point
var is_submerged := false 
var is_on_ladder := false 

const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12

# --- MODULE REFERENCES ---
@onready var debug_hud := $DebugHUD 
@onready var state_machine := $StateMachine 

@onready var sprite_pivot := $SpritePivot
@onready var hazard_detector := $SpritePivot/HazardDetector
@onready var animator := $PlayerAnimator 
@onready var sprite_upper := $SpritePivot/SpriteContainer/SpriteUpper
@onready var sprite_lower := $SpritePivot/SpriteContainer/SpriteLower
@onready var attack_area := $SpritePivot/AttackArea
@onready var wall_detector := $SpritePivot/WallDetector 
@onready var ledge_detector := $SpritePivot/LedgeDetector
@onready var armature := $SpritePivot/Armature

# ---------------------------------------------------------
# BUILT-IN ENGINE METHODS
# ---------------------------------------------------------
func _ready() -> void:
	hazard_detector.hazard_touched.connect(die)
	hazard_detector.ladder_state_changed.connect(_on_ladder_state_changed)
	hazard_detector.water_state_changed.connect(_on_water_state_changed)

	spawn_point = global_position 
	GameManager.hp_changed.connect(_on_hp_changed)
	
	if not show_debug_ui and debug_hud:
		debug_hud.queue_free()
		debug_hud = null
		
	state_machine.init(self)
	state_machine.transition_to("ground")

func _physics_process(delta: float) -> void:
	if velocity.y > 10000: die()
	
	var current_node := get_state_name()
	
	if current_node == "ledgeclimb":
		state_machine.physics_update(delta)
		_move()
		return
	
	# If dead, only run the FSM and move, skip ALL inputs and overrides!
	if current_node == "dead":
		state_machine.physics_update(delta)
		_move()
		return

	if wall_jump_lock > 0: wall_jump_lock -= delta

	# Process Inputs & Detectors
	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")
	var pressing_into_wall: bool = (direction != 0 and sign(direction) == facing)
	var touching_wall: bool = wall_detector and wall_detector.is_colliding()
	var over_ledge: bool = ledge_detector and not ledge_detector.is_colliding()
	
	var valid_climb_window: bool = velocity.y >= -500.0 
	var is_climbing := current_node in ["ledgeclimb", "wallclimb", "ladderclimb"]
	var can_wall_climb: bool = touching_wall and not is_on_floor() and wall_jump_lock <= 0.0
	
	# --- Global State Overrides ---
	# Only allow these overrides if we aren't already locked into a climb
	if touching_wall and over_ledge and not is_on_floor() and valid_climb_window:
		state_machine.transition_to("ledgeclimb")
	elif can_wall_climb and pressing_into_wall:
		state_machine.transition_to("wallclimb")
	elif is_on_ladder and y_dir != 0:
		state_machine.transition_to("ladderclimb")

	# Update Shared Timers
	if Input.is_action_just_pressed("ui_jump"): jump_buffer_timer = JUMP_BUFFER_TIME
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
	
	if Input.is_action_pressed("ui_attack"): attack_timer = attack_buffer
	else: attack_timer = max(attack_timer - delta, 0.0)

	if is_on_floor():
		coyote_timer = COYOTE_TIME
		can_double_jump = true
	else: 
		coyote_timer = max(coyote_timer - delta, 0.0)
		
	if current_node in ["wallclimb", "ladderclimb", "ledgeclimb"]:
		can_double_jump = true

	# RUN THE STATE MACHINE
	state_machine.physics_update(delta)

	_apply_gravity(delta)
	_move()
	
	if debug_hud: debug_hud.update_physics(self)

# ---------------------------------------------------------
# CORE UTILITIES & PIPELINE HELPERS
# ---------------------------------------------------------
# HELPER: Safely grabs the lowercase string of the current state
func get_state_name() -> String:
	if state_machine and state_machine.current_state:
		return state_machine.current_state.name.to_lower()
	return ""

func _apply_gravity(delta: float) -> void:
	if get_state_name() in ["ladderclimb", "wallclimb", "ledgeclimb", "dead"]: 
		return
		
	var current_gravity := get_gravity()
	if current_gravity.x != 0:
		var applied_horiz_force = current_gravity.x * (grounded_horizontal_current_dampening if (is_on_floor() and Input.get_axis("ui_left", "ui_right") == 0) else 1.0)
		velocity.x += applied_horiz_force * delta
	
	if not is_on_floor():
		if is_submerged and current_gravity.y == ProjectSettings.get_setting("physics/2d/default_gravity"):
			velocity.y = min(velocity.y + current_gravity.y * water_gravity_multiplier * delta, water_terminal_velocity)
		else:
			velocity.y += current_gravity.y * delta

func take_damage(knockback_dir: Vector2, force: float):
	if is_invincible or get_state_name() == "dead": return
	
	velocity = knockback_dir * force
	state_machine.transition_to("knockback") 
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(10, 10, 10), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	if not is_inside_tree(): return
	await get_tree().create_timer(0.5).timeout
	is_invincible = false
	
func die() -> void:
	if get_state_name() == "dead": return
	
	is_submerged = false 
	state_machine.transition_to("dead")

func _move() -> void: 
	move_and_slide()
	check_slide_hazards()

# ---------------------------------------------------------
# SIGNAL CALLBACKS
# ---------------------------------------------------------
func _on_ladder_state_changed(on_ladder: bool) -> void:
	is_on_ladder = on_ladder
	if not is_on_ladder and get_state_name() == "ladderclimb":
		state_machine.transition_to("air")

func _on_water_state_changed(submerged: bool) -> void:
	is_submerged = submerged

func _on_hp_changed(new_hp: float) -> void: 
	if new_hp <= 0 and get_state_name() != "dead": die()

func check_slide_hazards() -> void:
	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("hazards"): die()

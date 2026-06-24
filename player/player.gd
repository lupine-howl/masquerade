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

# ---------------------------------------------------------
# STATES
# ---------------------------------------------------------
enum MoveState {
	GROUNDED, JUMPING, FALLING, DOUBLE_JUMPING, ROLLING, DASHING, KNOCKBACK, LADDER_CLIMBING, WALL_CLIMBING, LEDGE_CLIMBING
}

var state_to_anim_map: Dictionary = {
	MoveState.GROUNDED: "on_ground",
	MoveState.JUMPING: "jumping",
	MoveState.FALLING: "falling",
	MoveState.DOUBLE_JUMPING: "double_jumping",
	MoveState.ROLLING: "rolling",
	MoveState.DASHING: "dashing",
	MoveState.WALL_CLIMBING: "wall_climbing",
	MoveState.LEDGE_CLIMBING: "on_ledge"
}

var state: MoveState = MoveState.GROUNDED
var is_dead := false
var is_invincible := false 
var facing := 1 

# (We will move these specific timers into their own states in the next phase!)
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
@onready var state_machine := $StateMachine # <--- NEW STATE MACHINE

@onready var sprite_pivot := $SpritePivot
@onready var hazard_detector := $SpritePivot/HazardDetector
@onready var animator := $ArmatureAnimationTree
@onready var sprite_upper := $SpritePivot/SpriteContainer/SpriteUpper
@onready var sprite_lower := $SpritePivot/SpriteContainer/SpriteLower
@onready var attack_area := $SpritePivot/AttackArea
@onready var wall_detector := $SpritePivot/WallDetector 
@onready var ledge_detector := $SpritePivot/LedgeDetector
@onready var armature := $SpritePivot/Armature

func _on_ladder_state_changed(on_ladder: bool) -> void:
	is_on_ladder = on_ladder
	if not is_on_ladder and state == MoveState.LADDER_CLIMBING:
		_change_state(MoveState.FALLING)

func _on_water_state_changed(submerged: bool) -> void:
	is_submerged = submerged

func _ready() -> void:
	hazard_detector.hazard_touched.connect(die)
	hazard_detector.ladder_state_changed.connect(_on_ladder_state_changed)
	hazard_detector.water_state_changed.connect(_on_water_state_changed)

	spawn_point = global_position 
	GameManager.hp_changed.connect(_on_hp_changed)
	
	if not show_debug_ui and debug_hud:
		debug_hud.queue_free()
		debug_hud = null
		
	animator.reset_all_conditions()
	
	# Initialize the Node-based FSM
	state_machine.init(self)
	_change_state(MoveState.GROUNDED)


# --- THE BRIDGE FUNCTION ---
func _change_state(new_state: MoveState) -> void:
	state = new_state
	
	# Map the enum to the node name in the StateMachine
	var node_name := ""
	match new_state:
		MoveState.GROUNDED: node_name = "ground"
		MoveState.JUMPING, MoveState.FALLING, MoveState.DOUBLE_JUMPING: node_name = "air"
		MoveState.DASHING: node_name = "dash"
		MoveState.ROLLING: node_name = "roll"
		MoveState.KNOCKBACK: node_name = "knockback"
		MoveState.WALL_CLIMBING: node_name = "wallclimb"
		MoveState.LADDER_CLIMBING: node_name = "ladderclimb"
		MoveState.LEDGE_CLIMBING: node_name = "ledgeclimb"		

	if node_name != "":
		state_machine.transition_to(node_name)

func _physics_process(delta: float) -> void:
	if velocity.y > 10000: die()
	if is_dead:
		_apply_gravity(delta); velocity.x *= 0.9; _move(); return

	if wall_jump_lock > 0: wall_jump_lock -= delta

	# Process Inputs & Detectors
	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")
	var pressing_into_wall: bool = (direction != 0 and sign(direction) == facing)
	var touching_wall: bool = wall_detector and wall_detector.is_colliding()
	var over_ledge: bool = ledge_detector and not ledge_detector.is_colliding()
	
	var valid_climb_window: bool = velocity.y >= -500.0 
	
	# Global State Overrides (Ledges, Walls, Ladders)
	if state != MoveState.LEDGE_CLIMBING and touching_wall and over_ledge and not is_on_floor() and valid_climb_window:
		_change_state(MoveState.LEDGE_CLIMBING)
			
	var can_wall_climb: bool = touching_wall and not is_on_floor() and wall_jump_lock <= 0.0
	if can_wall_climb and state != MoveState.WALL_CLIMBING and state != MoveState.LEDGE_CLIMBING and pressing_into_wall:
		_change_state(MoveState.WALL_CLIMBING)

	if is_on_ladder and state != MoveState.LADDER_CLIMBING and y_dir != 0:
		_change_state(MoveState.LADDER_CLIMBING)

	# Update Shared Timers (To be moved out soon!)
	if Input.is_action_just_pressed("ui_jump"): jump_buffer_timer = JUMP_BUFFER_TIME
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
	if Input.is_action_pressed("ui_attack"): attack_timer = attack_buffer
	else: attack_timer = max(attack_timer - delta, 0.0)

	if is_on_floor():
		coyote_timer = COYOTE_TIME
		can_double_jump = true
	else: 
		coyote_timer = max(coyote_timer - delta, 0.0)
		
	if state in [MoveState.WALL_CLIMBING, MoveState.LADDER_CLIMBING, MoveState.LEDGE_CLIMBING]:
		can_double_jump = true

	# RUN THE STATE MACHINE
	state_machine.physics_update(delta)

	_apply_gravity(delta)
	_move()
	
	# PASSIVE ENVIRONMENTAL & INPUT ANIMATIONS
	animator.set_condition("on_ground", is_on_floor())
	animator.set_condition("on_wall", touching_wall)
	animator.set_condition("on_ladder", is_on_ladder)
	animator.set_condition("crouching", is_on_floor() and y_dir > 0)
	animator.set_condition("running", is_on_floor() and direction != 0)
	animator.set_condition("attacking", attack_timer > 0.0)
	
	if debug_hud: debug_hud.update_physics(self)

# ---------------------------------------------------------
# CORE UTILITIES & PIPELINE HELPERS
# ---------------------------------------------------------
func finalize_ledge_climb() -> void:
	global_position += Vector2(50.0 * facing, -150.0)
	armature.position = Vector2.ZERO;
	$CollisionShape2D.disabled = false
	_change_state(MoveState.GROUNDED)
	animator.reset_all_conditions()

func _apply_gravity(delta: float) -> void:
	if state in [MoveState.LADDER_CLIMBING, MoveState.WALL_CLIMBING, MoveState.LEDGE_CLIMBING]: return
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
	if is_invincible: return
	
	velocity = knockback_dir * force
	_change_state(MoveState.KNOCKBACK) # Routes to the FSM automatically!
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(10, 10, 10), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	if not is_inside_tree(): return
	await get_tree().create_timer(0.5).timeout
	is_invincible = false
	
func die() -> void:
	if is_dead: return
	is_dead = true; is_submerged = false 
	animator.reset_all_conditions()
	animator.set_condition("dead", true) 
	velocity = Vector2.ZERO
	await get_tree().create_timer(1.2).timeout
	is_dead = false
	animator.reset_all_conditions()
	_change_state(MoveState.GROUNDED)
	GameManager.trigger_player_respawn()

func _move() -> void: 
	move_and_slide()
	check_slide_hazards()

func _on_hp_changed(new_hp: float) -> void: 
	if new_hp <= 0 and not is_dead: die()

func check_slide_hazards() -> void:
	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("hazards"): die()

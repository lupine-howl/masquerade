# ==============================================================================
#                               RagdollManager.gd
# ==============================================================================
extends Node2D
class_name RagdollManager

@export_category("Skeletal Systems")
@export var skeleton_node: Skeleton2D
@export var pivot: Node2D

@onready var root : RigidBody2D = $Root
@onready var back_hand : RigidBody2D = $Arm_Back/Hand_Back_Physics
@onready var front_hand : RigidBody2D = $Arm_Front/Hand_Front_Physics

var all_bones: Array[SyncedBone2D] = []
var root_origin: Vector2

# New: Structure to keep track of discovered joints and their baseline limits
var all_joints: Array[PinJoint2D] = []
var joint_default_limits: Dictionary = {} # Key: PinJoint2D, Value: Vector2(lower, upper)

# Reference Counting Stack for shared IKs. Key: IK_Index (int), Value: Active Requests (int)
var ik_disable_counters: Dictionary = {}

# Keep track of last frame flip state to prevent running limit assignments every single frame tick
var was_flipped_last_frame: bool = false

func _ready() -> void:
	# Automatically discover all SyncedBone2D data nodes living under the skeleton root
	if skeleton_node:
		_gather_synced_bones(skeleton_node)
		
	# Automatically discover all PinJoint2D nodes belonging to this subsystem
	_gather_pin_joints(self)
	_cache_default_joint_limits()
		
	root_origin = root.position
	root.freeze = true
	
func reset_root():
	root.position = root_origin
	root.freeze = true

func _gather_synced_bones(current_node: Node) -> void:
	if current_node is SyncedBone2D:
		all_bones.append(current_node)
		
	for child in current_node.get_children():
		_gather_synced_bones(child)

# Discovers any PinJoint2D instances regardless of how deep they are nested
func _gather_pin_joints(current_node: Node) -> void:
	if current_node is PinJoint2D:
		all_joints.append(current_node)
	for child in current_node.get_children():
		_gather_pin_joints(child)

# Memorizes the inspector setup as your absolute facing-right zero baseline
func _cache_default_joint_limits() -> void:
	for joint in all_joints:
		joint_default_limits[joint] = Vector2(
			joint.angular_limit_lower,
			joint.angular_limit_upper
		)

## Centralized execution timing step: Bones remain completely naive about frames
func _physics_process(_delta: float) -> void:
	# Determine if the character is flipped by checking your parent node scale
	var is_flipped: bool = pivot.scale.x < 0
	
	# Programmatic Limit Inversion Layer
	if is_flipped != was_flipped_last_frame:
		_flip_joint_limits(is_flipped)
		was_flipped_last_frame = is_flipped
	
	for bone in all_bones:
		if bone.physics_body:
			var compensation_degrees = 0
			if(is_flipped and bone.inverted_scale_x_rotation_compensation):
				compensation_degrees = bone.inverted_scale_x_rotation_compensation
			elif(bone.rotation_compensation):
				compensation_degrees = bone.rotation_compensation
				
			bone.global_rotation_degrees = bone.physics_body.global_rotation_degrees + compensation_degrees
			if(bone.position_body):
				bone.global_position = bone.position_body.global_position
			else:
				bone.global_position = bone.physics_body.global_position

# Inverts limits smoothly without flipping node_a and node_b assignments
func _flip_joint_limits(flipped: bool) -> void:
	for joint in all_joints:
		
		if not joint.angular_limit_enabled:
			continue
			
		var defaults = joint_default_limits[joint]
		if flipped:
			# Swaps boundaries and inverts signs to account for the mirrored world space axis
			joint.angular_limit_lower = -defaults.y
			joint.angular_limit_upper = -defaults.x
		else:
			# Recalls the clean, original baseline settings
			joint.angular_limit_lower = defaults.x
			joint.angular_limit_upper = defaults.y

# ==============================================================================
#                             RagdollManager.gd
# ==============================================================================
extends Node2D
class_name RagdollManager

# 1. Define our clear architectural scenarios
enum RagdollState {
	ANIMATED,          # Normal gameplay, animation player controls everything
	ARM_RAGDOLL,       # Both arms swing loose
	FRONT_ARM_ONLY,    # Isolate just the front arm layers (e.g., recoil/impact)
	LEG_RAGDOLL,       # Both legs swing loose during jump/fall
	SINGLE_LEG_SWING,  # Back leg trails loosely (e.g., dynamic trips)
	FULL_BODY,         # Total skeletal collapse / Death
	LIMBS,
	HEAD,
	HANGING            # Hands stay fixed, rest of body goes completely limp
}

# 2. Define compile-safe bitmask positions for your bones
enum BoneGroup {
	FRONT_ARM = 1 << 0,  # Bit 0 (Value 1)
	BACK_ARM  = 1 << 1,  # Bit 1 (Value 2)
	FRONT_LEG = 1 << 2,  # Bit 2 (Value 4)
	BACK_LEG  = 1 << 3,  # Bit 3 (Value 8)
	TORSO     = 1 << 4,  # Bit 4 (Value 16)
	HEAD      = 1 << 5,  # Bit 5 (Value 32)
	HIP       = 1 << 6,
	FOREARM   = 1 << 7
}

@export_category("Skeletal Systems")
@export var skeleton_node: Skeleton2D
@export var animator: Node
@export var pivot: Node2D

@onready var root : RigidBody2D = $Root
@onready var back_hand : RigidBody2D = $Arm_Back/Hand_Back_Physics
@onready var front_hand : RigidBody2D = $Arm_Front/Hand_Front_Physics

var current_state: RagdollState = RagdollState.ANIMATED
var all_bones: Array[SyncedBone2D] = []
var root_origin: Vector2

# Reference Counting Stack for shared IKs. Key: IK_Index (int), Value: Active Requests (int)
var ik_disable_counters: Dictionary = {}

func _ready() -> void:
	# Automatically discover all SyncedBone2D data nodes living under the skeleton root
	if skeleton_node:
		_gather_synced_bones(skeleton_node)
		
	set_ragdoll_state(RagdollState.ANIMATED)
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

## Centralized execution timing step: Bones remain completely naive about frames
func _physics_process(_delta: float) -> void:
	if current_state == RagdollState.ANIMATED:
		return
		
# Determine if the character is flipped by checking your parent node scale
	var is_flipped: bool = pivot.scale.x < 0
	
	for bone in all_bones:
		if bone.controlled_by_physics and bone.physics_body:
			var compensation_degrees = 0
			if(bone.inverted_scale_x_compensation_degrees):	
				compensation_degrees = bone.inverted_scale_x_compensation_degrees
			if is_flipped:
				# If flipped, invert the target angle to prevent the upside-down calculation spike
				bone.global_rotation_degrees = bone.physics_body.global_rotation_degrees - compensation_degrees
			else:
				bone.global_rotation = bone.physics_body.global_rotation			

			if bone.position_body:
				bone.global_position = bone.position_body.global_position

## Main state router called by your Player State Machine
func set_ragdoll_state(new_state: RagdollState) -> void:
	current_state = new_state
	
	# Reset baseline: Turn off physics syncing across all flags completely (using mask 0xFFFF)
	_set_bitmask_physics_state(0xFFFF, false)

	if current_state == RagdollState.ANIMATED:
		set_physics_process(false) # Completely unplugs this node from the physics engine loop
		return
	else:
		set_physics_process(true)  # Wakes the processing loop back up instantly

	match current_state:
		RagdollState.ANIMATED:
			snap_physics_to_skeleton()
			pass # Handled cleanly by our baseline reset

		RagdollState.ARM_RAGDOLL:
			_set_bitmask_physics_state(BoneGroup.FRONT_ARM | BoneGroup.BACK_ARM, true)

		RagdollState.FRONT_ARM_ONLY:
			_set_bitmask_physics_state(BoneGroup.FRONT_ARM, true)

		RagdollState.HEAD:
			_set_bitmask_physics_state(BoneGroup.HEAD, true)

		RagdollState.LEG_RAGDOLL:
			_set_bitmask_physics_state(BoneGroup.FRONT_LEG | BoneGroup.BACK_LEG, true)

		RagdollState.SINGLE_LEG_SWING:
			_set_bitmask_physics_state(BoneGroup.BACK_LEG, true)

		RagdollState.LIMBS:
			_set_bitmask_physics_state(BoneGroup.FRONT_LEG | BoneGroup.BACK_LEG | BoneGroup.BACK_ARM | BoneGroup.FRONT_ARM, true)

		RagdollState.FULL_BODY:
			_set_bitmask_physics_state(0xFFFF, true)
			
		RagdollState.HANGING:
			# Torso, head, back arm, and both legs fall loose under gravity.
			# Front arm/hand remains false (retaining full animation/ledge-grab target authority).
			#back_hand.freeze = true
			#front_hand.freeze = true
			_set_bitmask_physics_state(0xFFFF, true)

# --- Atomic Control & Filtering Systems ---

## Uses bitwise AND (&) to query if a bone belongs to any active flags inside the target mask
func _set_bitmask_physics_state(target_mask: int, enabled: bool) -> void:
	for bone in all_bones:
		if (bone.bone_groups & target_mask) != 0:
			_execute_physics_control_shift(bone, enabled)

## Unidirectional engine that updates bone states and steps through the reference counting logic
func _execute_physics_control_shift(bone: SyncedBone2D, enable_physics: bool) -> void:
	if not bone.physics_body:
		return
	if bone.controlled_by_physics == enable_physics:
		return # State hasn't modified, skip calculations
		
	bone.controlled_by_physics = enable_physics
	
	# Cleanly step through every IK index registered to this specific bone node
	for index in bone.ik_stack_indices:
		if not ik_disable_counters.has(index):
			ik_disable_counters[index] = 0
			
		if enable_physics:
			ik_disable_counters[index] += 1
		else:
			ik_disable_counters[index] = max(0, ik_disable_counters[index] - 1)
			
		# Evaluate the reference stack to see if the modifier should safely wake up
		_set_ik_modifier_enabled(index, ik_disable_counters[index] == 0)

func _set_ik_modifier_enabled(index: int, should_enable: bool) -> void:
	if not skeleton_node: return
	var stack = skeleton_node.get_modification_stack()
	if stack and index >= 0 and index < stack.modification_count:
		var modifier = stack.get_modification(index)
		if modifier: 
			modifier.enabled = should_enable

## Snaps all physics shapes directly back to the current animated skeleton frame position.
## Call this right inside set_ragdoll_state when shifting back to RagdollState.ANIMATED.
func snap_physics_to_skeleton() -> void:
	for bone in all_bones:
		if bone and bone.physics_body:
			# Reset momentum so they don't carry old energy into the next handoff
			bone.physics_body.linear_velocity = Vector2.ZERO
			bone.physics_body.angular_velocity = 0.0
			
			# Match current visual position/rotation
			bone.physics_body.global_transform = bone.global_transform

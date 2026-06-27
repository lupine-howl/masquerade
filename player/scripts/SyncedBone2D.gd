# ==============================================================================
#                               SyncedBone2D.gd
# ==============================================================================
extends Bone2D
class_name SyncedBone2D

@export_category("Skeletal Data")
## The corresponding physical part driving this bone in world space
@export var physics_body: RigidBody2D
@export var position_body: RigidBody2D
@export var inverted_scale_x_compensation_degrees: float

## Select which IK stack index modifiers affect this specific bone chain.
@export_flags(
	"Index 0:1",
	"Index 1:2",
	"Index 2:4",
	"Index 3:8",
	"Index 4:16",
	"Index 5:32",
	"Index 6:64",
	"Index 7:128",
	"Index 8:256",
	"Index 9:512"
) var ik_lookup_mask: int = 0

## Select which structural groups this bone belongs to from the checklist.
@export_flags(
	"Front Arm:1", 
	"Back Arm:2", 
	"Front Leg:4", 
	"Back Leg:8", 
	"Torso:16", 
	"Head:32",
	"Hip:64",
	"Forearm:128"
) var bone_groups: int = 0

# Passive tracking variables managed explicitly by the RagdollManager
var controlled_by_physics: bool = false

# Internal cache populated at runtime so the manager can read raw integers easily
var ik_stack_indices: Array[int] = []

func _ready() -> void:
	# Convert the bitmask checkboxes into the raw integer array the manager expects
	for i in range(10):
		var bit_value = 1 << i
		if (ik_lookup_mask & bit_value) != 0:
			ik_stack_indices.append(i)

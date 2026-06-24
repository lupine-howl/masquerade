extends Node2D

# Export an array so you can drag both shoulder bones right into the inspector!
@export var armature_shoulder_bones: Array[Bone2D] = []

func _ready() -> void:
	disable_arms()

func enable_arms() -> void:
	$DeadLeftArm.show()
	$DeadRightArm.show()
	_set_armature_arms_visible(false)
	# Turn on your ragdoll physics simulation here if needed

func disable_arms() -> void:
	$DeadLeftArm.hide()
	$DeadRightArm.hide()
	_set_armature_arms_visible(true)
	# Turn off your ragdoll physics simulation here if needed

# Helper loop to handle toggling both shoulders cleanly
func _set_armature_arms_visible(is_visible: bool) -> void:
	for bone in armature_shoulder_bones:
		if bone:
			bone.visible = is_visible

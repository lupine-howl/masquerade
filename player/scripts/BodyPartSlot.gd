class_name BodyPartSlot
extends Sprite2D

## Flat sprite slot that follows a skeleton bone each physics frame.
@export var follow_bone: Bone2D

@export_group("Slot Offset")
@export var slot_position: Vector2 = Vector2.ZERO
@export var slot_rotation_degrees: float = 0.0
@export var slot_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	process_priority = 10


func _physics_process(_delta: float) -> void:
	_sync_to_bone()


func _sync_to_bone() -> void:
	if follow_bone == null or not is_instance_valid(follow_bone):
		return

	var local := Transform2D(deg_to_rad(slot_rotation_degrees), slot_position).scaled(slot_scale)
	global_transform = follow_bone.global_transform * local

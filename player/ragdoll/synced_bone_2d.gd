# ==============================================================================
#                               SyncedBone2D.gd
# ==============================================================================
extends Bone2D
class_name SyncedBone2D

@export_category("Skeletal Data")
## The corresponding physical part driving this bone in world space
@export var physics_body: RigidBody2D
@export var position_body: RigidBody2D
@export var rotation_compensation: float
## Extra degrees added to physics rotation when FacingPivot scale.x is -1.
## Needed when the physics body already includes look-at flip correction but the
## bone lives under the mirrored skeleton (e.g. Head).
@export var inverted_scale_x_rotation_compensation: float

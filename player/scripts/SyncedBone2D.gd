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
@export var inverted_scale_x_rotation_compensation: float

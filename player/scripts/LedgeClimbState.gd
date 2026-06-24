extends PlayerState

func enter() -> void:
	player.velocity = Vector2.ZERO
	var wall_intersection_pt: Vector2 = player.wall_detector.get_collision_point()
	
	# Snap the player into the exact ledge position
	player.global_position.x = wall_intersection_pt.x - (player.facing * 40.0)
	player.global_position.y = wall_intersection_pt.y + 150.0
	player.get_node("CollisionShape2D").disabled = false 

func physics_update(_delta: float) -> void:
	# Keep the player perfectly still while the ledge climb animation plays
	# (Your player.finalize_ledge_climb() function will transition them back to Ground)
	player.velocity = Vector2.ZERO

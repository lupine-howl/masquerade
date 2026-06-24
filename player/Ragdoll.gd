extends Node2D

func _on_player_body_facing_changed(new_facing: int) -> void:
	for child in get_tree().get_nodes_in_group("flip_on_facing_change"):
		child.flip_h = (new_facing == -1)

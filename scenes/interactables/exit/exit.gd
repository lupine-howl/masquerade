extends Area2D

const HOME_SCENE := "res://scenes/home/HomeScreen.tscn"

## Fallback for levels run outside a project (e.g. dev scenes).
@export var target_level: PackedScene
@export var keys_needed := 1

@onready var sprite = $AnimatedSprite2D

var is_open = false


func _ready():
	keys_needed = int(ProjectStore.get_rule("keys_to_exit", keys_needed))
	GameManager.keys_changed.connect(on_keys_changed)
	on_keys_changed(GameManager.keys)
	sprite.play("default")


func on_keys_changed(keys: int) -> void:
	if keys >= keys_needed:
		is_open = true
		sprite.play("open")


func _on_body_entered(body):
	if is_open and body.is_in_group("player"):
		_advance()


func _advance() -> void:
	var result: Dictionary = ProjectStore.advance_level()
	match String(result.get("action", "")):
		"next_level":
			GameManager.start_level()
			get_tree().change_scene_to_file(String(result.path))
		"completed":
			get_tree().change_scene_to_file(HOME_SCENE)
		_:
			if target_level:
				GameManager.start_level()
				get_tree().change_scene_to_packed(target_level)

extends Node

# Signals to notify the UI when things change
signal points_changed(new_points: int)
signal keys_changed(new_keys: int)
signal hp_changed(new_hp: float)

const DEFAULT_MAX_HP := 80.0
const DEFAULT_STARTING_HP := 80.0

var points := 0
var keys := 0

# 1 heart = 16 pixels wide. 3 hearts = 48 pixels total max health.
var max_hp := DEFAULT_MAX_HP
var current_hp := DEFAULT_STARTING_HP

# --- NEW CHECKPOINT PROPERTY ---
## Holds the global coordinates of the last checkpoint touched.
var last_checkpoint_position := Vector2.ZERO


## Starts a fresh play session, applying per-project game rules (M0).
## Pass rules from the project manifest; an empty dictionary uses defaults.
## Resets all session state: points, keys, HP, checkpoint.
func start_session(rules: Dictionary = {}) -> void:
	max_hp = float(rules.get("max_hp", DEFAULT_MAX_HP))
	current_hp = clamp(float(rules.get("starting_hp", DEFAULT_STARTING_HP)), 0.0, max_hp)
	points = 0
	keys = 0
	last_checkpoint_position = Vector2.ZERO
	points_changed.emit(points)
	keys_changed.emit(keys)
	hp_changed.emit(current_hp)


## Resets level-local state when entering a different level: keys and the
## checkpoint belong to a single level; points and HP carry across.
func start_level() -> void:
	keys = 0
	last_checkpoint_position = Vector2.ZERO
	keys_changed.emit(keys)

func add_point() -> void:
	points += 1
	points_changed.emit(points)

func add_key() -> void:
	keys += 1
	print(keys)
	keys_changed.emit(keys)

func add_health(amount: float) -> void:
	current_hp = min(current_hp + amount, max_hp) # Added min() caps so health doesn't exceed maximum
	hp_changed.emit(current_hp)

# Call this from the player when restarting the level
func reset_health() -> void:
	current_hp = max_hp
	hp_changed.emit(current_hp)
	keys = 0
	keys_changed.emit(0)

# Call this whenever the player takes damage
func take_damage(amount: float) -> void:
	current_hp = max(current_hp - amount, 0.0)
	hp_changed.emit(current_hp)
	
	if current_hp <= 0:
		print("Player has run out of health! Waiting for death animation...")
		# DO NOT call trigger_player_respawn() here anymore! 
		# The player script's _on_hp_changed signal will handle starting the animation.

# Call this ONLY when the player's death animation has finished playing
func trigger_player_respawn() -> void:
	current_hp = max_hp
	hp_changed.emit(current_hp)
	
	var player = get_tree().get_first_node_in_group("player")
	
	if player and last_checkpoint_position != Vector2.ZERO:
		player.global_position = last_checkpoint_position
	else:
		get_tree().reload_current_scene()

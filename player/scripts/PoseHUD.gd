class_name PoseHUD
extends CanvasLayer

signal playback_started

@export var pose_controller: PoseController
@export var timeline: TimelineManager

@onready var part_panel: PosePartPanel = $PosePartPanel
@onready var anim_browser: PoseAnimBrowser = $PanelContainer3/VBoxContainer/PoseAnimBrowser
@onready var timeline_panel: PoseTimelinePanel = $PanelContainer3/VBoxContainer/MarginContainer2/Panel/PoseTimelinePanel
@onready var assistant_panel: PoseAssistantPanel = $PanelContainer3/VBoxContainer/MarginContainerAssistant/Panel/PoseAssistantPanel
@onready var mode_bar: PoseModeBar = $PanelContainer3/VBoxContainer/PoseModeBar

var _last_sync_anim: String = ""
var _last_sync_grid_len: float = -1.0

func _ready() -> void:
	_setup_panels()
	_wire_signals()

	if pose_controller:
		pose_controller.active_marker_changed.connect(_on_active_marker_changed)
		pose_controller.marker_list_ready.connect(part_panel.setup_part_table)

	anim_browser.populate_animations()
	if timeline and anim_browser.get_current_animation() != "":
		_on_animation_changed(anim_browser.get_current_animation())
		timeline.stop()

func _setup_panels() -> void:
	if not part_panel:
		push_error("PoseHUD: PosePartPanel not found at $PosePartPanel")
		return
	if not anim_browser:
		push_error("PoseHUD: PoseAnimBrowser not found")
		return
	if not timeline_panel:
		push_error("PoseHUD: PoseTimelinePanel not found")
		return

	var get_anim := func() -> String: return get_current_animation()
	var is_recording := func() -> bool: return is_auto_recording()
	var refresh_visuals := func() -> void: refresh_timeline_visuals()

	part_panel.setup(pose_controller, timeline, get_anim, is_recording, refresh_visuals)
	anim_browser.setup(timeline)
	timeline_panel.setup(timeline, pose_controller, get_anim)
	if assistant_panel and pose_controller:
		var on_markers_changed := func() -> void:
			if part_panel:
				part_panel.refresh_controlled_column()
				part_panel.refresh_inspector(pose_controller.get_primary_marker())
		assistant_panel.setup(
			pose_controller,
			timeline,
			anim_browser,
			get_anim,
			refresh_visuals,
			on_markers_changed
		)

func _wire_signals() -> void:
	anim_browser.animation_changed.connect(_on_animation_changed)
	anim_browser.duration_changed.connect(_on_duration_changed)
	anim_browser.speed_changed.connect(func(_s):
		refresh_timeline_visuals()
		if assistant_panel:
			assistant_panel.sync_timing_ui()
	)

	timeline_panel.playback_started.connect(playback_started.emit)
	timeline_panel.step_interacted.connect(_on_step_interacted)

	mode_bar.posing_toggled.connect(_on_posing_toggled)

	if assistant_panel:
		assistant_panel.duration_changed.connect(_on_duration_changed)
		assistant_panel.speed_changed.connect(func(_s): refresh_timeline_visuals())
		assistant_panel.animation_created.connect(_on_animation_changed)

	if timeline_panel and mode_bar:
		timeline_panel.set_playback_controls_visible(mode_bar.is_posing())

	call_deferred("_apply_posing_mode", mode_bar.is_posing())

func get_current_animation() -> String:
	return anim_browser.get_current_animation() if anim_browser else ""

func is_posing() -> bool:
	return mode_bar.is_posing() if mode_bar else false

func is_auto_recording() -> bool:
	return timeline_panel.is_recording() if timeline_panel else false

func get_step_count() -> int:
	return timeline_panel.get_step_count() if timeline_panel else 0

func refresh_timeline_visuals() -> void:
	if timeline_panel:
		timeline_panel.update_grid_visuals()

func update_marker_inspector(marker: PoseMarker) -> void:
	if part_panel:
		part_panel.update_inspector_checkboxes(marker)

func request_auto_key(marker: PoseMarker) -> void:
	if part_panel:
		part_panel.request_auto_key(marker)

func key_all_markers() -> void:
	if part_panel:
		part_panel.key_all_markers()

func on_step_navigated() -> void:
	refresh_timeline_visuals()
	update_marker_inspector(pose_controller.get_primary_marker() if pose_controller else null)

func reapply_current_step() -> void:
	var anim_name := get_current_animation()
	if timeline and anim_name != "":
		timeline.seek_step(timeline.current_step, anim_name)
	on_step_navigated()

func _process(_delta: float) -> void:
	if not timeline or not timeline.anim_player:
		return

	if not is_posing():
		return

	var primary := pose_controller.get_primary_marker() if pose_controller else null

	if timeline.anim_player.is_playing():
		var playing_anim := String(timeline.anim_player.current_animation)
		if playing_anim != "" and (not anim_browser or not anim_browser.is_preview_active()):
			anim_browser.sync_display_to_animation(playing_anim)
			var current_anim_len := timeline.anim_player.get_animation(playing_anim).length
			if playing_anim != _last_sync_anim or not is_equal_approx(current_anim_len, _last_sync_grid_len):
				timeline_panel.build_step_grid(current_anim_len)
				_last_sync_anim = playing_anim
				_last_sync_grid_len = current_anim_len

		timeline_panel.sync_playback_step(true)

	if part_panel:
		part_panel.update_live_readouts(primary)

func _on_active_marker_changed(_primary_marker: PoseMarker) -> void:
	if is_posing() and timeline and timeline.anim_player and timeline.anim_player.is_playing():
		timeline.stop()
	if part_panel:
		part_panel.sync_selection_from_controller()
	refresh_timeline_visuals()

func _on_animation_changed(anim_name: String) -> void:
	if anim_name == "" or not timeline or not timeline.anim_player:
		return
	_last_sync_anim = ""
	_last_sync_grid_len = -1.0
	var anim := timeline.anim_player.get_animation(anim_name)
	timeline.current_step = 0
	timeline.set_step_selection([0])
	timeline.step_selection_anchor = 0
	timeline_panel.build_step_grid(anim.length)
	refresh_timeline_visuals()
	if assistant_panel:
		assistant_panel.sync_timing_ui()
	if is_posing() and not timeline.anim_player.is_playing():
		timeline.seek_step(0, anim_name)
		refresh_timeline_visuals()

func _on_duration_changed(duration: float) -> void:
	timeline_panel.build_step_grid(duration)
	refresh_timeline_visuals()
	if assistant_panel:
		assistant_panel.sync_timing_ui()
	if anim_browser:
		anim_browser.sync_timing_ui_for_current_animation()

func _on_step_interacted(_step: int) -> void:
	on_step_navigated()

func _on_posing_toggled(posing: bool) -> void:
	_apply_posing_mode(posing)

func _apply_posing_mode(posing: bool) -> void:
	if pose_controller and pose_controller.player:
		pose_controller.player.is_posing = posing
	if timeline:
		timeline.stop()
	if timeline_panel:
		if not posing:
			timeline_panel.set_recording(false)
		timeline_panel.set_playback_controls_visible(posing)
	if posing and timeline and timeline.anim_player:
		var playing_anim := String(timeline.anim_player.current_animation)
		if playing_anim != "":
			anim_browser.sync_display_to_animation(playing_anim)
			var anim := timeline.anim_player.get_animation(playing_anim)
			timeline_panel.build_step_grid(anim.length)
			_last_sync_anim = playing_anim
			_last_sync_grid_len = anim.length

class_name PoseHUD
extends CanvasLayer

signal playback_started

@export var pose_controller: PoseController
@export var timeline: TimelineManager

@onready var part_panel: PosePartPanel = $PoseDockRow/PoseDock/DockVBox/PosePartPanel
@onready var anim_browser: PoseAnimBrowser = $PoseDockRow/PoseDock/DockVBox/AnimSection/PoseAnimBrowser
@onready var timeline_panel: PoseTimelinePanel = $PoseTimelineDock/MarginContainer/PoseTimelinePanel
@onready var timeline_dock: PanelContainer = $PoseTimelineDock
@onready var assistant_panel: PoseAssistantPanel = $PoseDockRow/PoseDock/DockVBox/AnimSection/AnimMainColumn/MarginContainer2/PoseAssistantPanel
@onready var toolbar: PoseToolBar = $PoseToolBar
@onready var mode_bar: PoseModeBar = $PoseToolBar/ToolVBox/PoseModeBar

var _last_sync_anim: String = ""
var _last_sync_grid_len: float = -1.0

func _ready() -> void:
	_setup_panels()
	_wire_signals()

	if pose_controller:
		pose_controller.active_marker_changed.connect(_on_active_marker_changed)
		pose_controller.marker_list_ready.connect(part_panel.setup_part_table)

	anim_browser.populate_animations()
	_refresh_anim_selector()
	if timeline and anim_browser.get_current_animation() != "":
		_on_animation_changed(anim_browser.get_current_animation())
		timeline.stop()

func _setup_panels() -> void:
	if not part_panel:
		push_error("PoseHUD: PosePartPanel not found")
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
				part_panel.refresh_inspector(pose_controller.get_primary_marker())
			if assistant_panel:
				assistant_panel.sync_ragdoll_toggles()
		assistant_panel.setup(
			pose_controller,
			timeline,
			anim_browser,
			get_anim,
			refresh_visuals,
			on_markers_changed,
			func(): swap_all_siblings(),
			func(): part_panel.normalize_horizontal()
		)
		assistant_panel.register_timeline_mirrors(
			timeline_panel.tl_ctrl_all,
			timeline_panel.tl_ctrl_arms,
			timeline_panel.tl_ctrl_legs,
			timeline_panel.tl_ctrl_head,
			timeline_panel.tl_ctrl_root,
			timeline_panel.tl_grounded,
			timeline_panel.tl_btn_export,
			timeline_panel.tl_loop_check,
			timeline_panel.tl_btn_pose_reset,
			timeline_panel.tl_btn_norm_horiz,
			timeline_panel.tl_btn_hang,
			timeline_panel.tl_btn_fall,
			timeline_panel.tl_btn_clear,
			timeline_panel.tl_btn_swap_all
		)

func _wire_signals() -> void:
	anim_browser.animation_changed.connect(_on_animation_changed)
	anim_browser.duration_changed.connect(_on_duration_changed)
	anim_browser.speed_changed.connect(func(_s): refresh_timeline_visuals())

	timeline_panel.playback_started.connect(playback_started.emit)
	timeline_panel.step_interacted.connect(_on_step_interacted)
	timeline_panel.duration_changed.connect(_on_duration_changed)
	timeline_panel.speed_changed.connect(func(_s): refresh_timeline_visuals())
	timeline_panel.animation_selected.connect(_on_timeline_anim_selected)
	timeline_panel.key_all_pressed.connect(func(): key_all_markers())

	mode_bar.posing_toggled.connect(_on_posing_toggled)

	if assistant_panel:
		assistant_panel.animation_created.connect(_on_animation_changed)

	if timeline_panel and mode_bar:
		_set_timeline_dock_visible(mode_bar.is_posing())

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

func key_path_guide(guide: PathGuideMarker) -> void:
	if not timeline or not part_panel:
		return
	var anim_name := get_current_animation()
	if anim_name == "":
		return
	timeline.key_path_guide_pose(anim_name, guide)
	refresh_timeline_visuals()

func prepare_path_guides_for_authoring() -> void:
	if not pose_controller or not pose_controller.player:
		return
	for guide in PathGuideMarker.gather_under(pose_controller.player):
		if guide.anchor:
			guide.anchor.prepare_authoring_at(pose_controller.player.global_position)
		guide.position = Vector2.ZERO

func swap_all_siblings() -> void:
	if pose_controller:
		pose_controller.swap_all_siblings()
	if part_panel:
		part_panel.refresh_inspector(pose_controller.get_primary_marker() if pose_controller else null)

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
			if timeline_panel:
				timeline_panel.sync_anim_selector(playing_anim)
			if assistant_panel:
				assistant_panel.sync_title_ui()
			if timeline_panel:
				timeline_panel.sync_timing_ui(playing_anim)
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
	if timeline_panel:
		if timeline_panel.needs_anim_selector_refresh(anim_browser.get_animation_names()):
			_refresh_anim_selector(anim_name)
		else:
			timeline_panel.sync_anim_selector(anim_name)
	_last_sync_anim = ""
	_last_sync_grid_len = -1.0
	var anim := timeline.anim_player.get_animation(anim_name)
	timeline.current_step = 0
	timeline.set_step_selection([0])
	timeline.step_selection_anchor = 0
	timeline_panel.build_step_grid(anim.length)
	refresh_timeline_visuals()
	if assistant_panel:
		assistant_panel.sync_title_ui()
		assistant_panel.sync_ragdoll_toggles()
	if timeline_panel:
		timeline_panel.sync_timing_ui(anim_name)
	if timeline.anim_player.is_playing():
		timeline.stop()
	timeline.seek_step(0, anim_name)
	refresh_timeline_visuals()
	on_step_navigated()
	if anim_name == "ledge_climb" and is_posing():
		prepare_path_guides_for_authoring()

func _on_duration_changed(duration: float) -> void:
	timeline_panel.build_step_grid(duration)
	refresh_timeline_visuals()
	if assistant_panel:
		assistant_panel.sync_title_ui()
		assistant_panel.sync_ragdoll_toggles()
	if timeline_panel:
		timeline_panel.sync_timing_ui(get_current_animation())

func _on_step_interacted(_step: int) -> void:
	on_step_navigated()

func _on_posing_toggled(posing: bool) -> void:
	_apply_posing_mode(posing)

func _on_timeline_anim_selected(anim_name: String) -> void:
	if anim_browser:
		anim_browser.select_animation_by_name(anim_name)

func _refresh_anim_selector(select_name: String = "") -> void:
	if not timeline_panel or not anim_browser:
		return
	var current := select_name if select_name != "" else anim_browser.get_current_animation()
	timeline_panel.populate_anim_selector(anim_browser.get_animation_names(), current)

func _set_timeline_dock_visible(show_dock: bool) -> void:
	if timeline_dock:
		timeline_dock.visible = show_dock

func _apply_posing_mode(posing: bool) -> void:
	if pose_controller and pose_controller.player:
		pose_controller.player.is_posing = posing
	if timeline:
		timeline.stop()
	if timeline_panel:
		if not posing:
			timeline_panel.set_recording(false)
	_set_timeline_dock_visible(posing)
	if posing and timeline and timeline.anim_player:
		var playing_anim := String(timeline.anim_player.current_animation)
		if playing_anim != "":
			anim_browser.sync_display_to_animation(playing_anim)
			var anim := timeline.anim_player.get_animation(playing_anim)
			timeline_panel.build_step_grid(anim.length)
			timeline_panel.sync_timing_ui(playing_anim)
			_last_sync_anim = playing_anim
			_last_sync_grid_len = anim.length
	if posing and get_current_animation() == "ledge_climb":
		prepare_path_guides_for_authoring()

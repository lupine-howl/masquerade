class_name PoseHUD
extends CanvasLayer

signal playback_started

const DOCK_MARGIN_H := 12.0
const DOCK_HEIGHT := 192.0

@export var pose_controller: PoseController
@export var timeline: TimelineManager

@onready var studio_vbox: VBoxContainer = $PoseTimelineDock/MarginContainer/StudioBottomVBox
@onready var studio_tab_bar: StudioTabBar = $PoseTimelineDock/MarginContainer/StudioBottomVBox/StudioTabBar
@onready var part_panel: PosePartPanel = $PoseDockRow/PoseDock/DockVBox/PosePartPanel
@onready var anim_browser: PoseAnimBrowser = $PoseDockRow/PoseDock/DockVBox/AnimSection/PoseAnimBrowser
@onready var timeline_panel: PoseTimelinePanel = $PoseTimelineDock/MarginContainer/StudioBottomVBox/PoseTimelinePanel
@onready var build_panel: BuildPanel = $PoseTimelineDock/MarginContainer/StudioBottomVBox/BuildPanel
@onready var play_stats_panel: PlayStatsPanel = $PoseTimelineDock/MarginContainer/StudioBottomVBox/PlayStatsPanel
@onready var timeline_dock: PanelContainer = $PoseTimelineDock
@onready var pose_dock_row: Control = $PoseDockRow
@onready var assistant_panel: PoseAssistantPanel = $PoseDockRow/PoseDock/DockVBox/AnimSection/AnimMainColumn/MarginContainer2/PoseAssistantPanel

var _last_sync_anim: String = ""
var _last_sync_grid_len: float = -1.0


func _ready() -> void:
	set_process_unhandled_input(true)
	_hide_legacy_panels()
	_reparent_part_panel()
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

	call_deferred("_apply_studio_tab", studio_tab_bar.get_tab() if studio_tab_bar else StudioTabBar.Tab.PLAY)


func _hide_legacy_panels() -> void:
	if pose_dock_row:
		pose_dock_row.visible = false
	var toolbar := get_node_or_null("PoseToolBar")
	if toolbar:
		toolbar.visible = false
	var debug_hud := get_parent().get_node_or_null("DebugHUD")
	if debug_hud:
		debug_hud.visible = false


func _reparent_part_panel() -> void:
	if not part_panel or not studio_vbox or not studio_tab_bar:
		return
	part_panel.reparent(studio_vbox)
	studio_vbox.move_child(part_panel, studio_tab_bar.get_index() + 1)
	part_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	part_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	part_panel.custom_minimum_size = Vector2.ZERO
	part_panel.visible = false


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
	if not build_panel:
		push_error("PoseHUD: BuildPanel not found")

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
			timeline_panel.tl_ctrl_player,
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

	if studio_tab_bar:
		studio_tab_bar.tab_change_requested.connect(_on_tab_change_requested)

	if assistant_panel:
		assistant_panel.animation_created.connect(_on_animation_changed)
		assistant_panel.player_drive_toggled.connect(_on_player_drive_toggled)


func get_current_animation() -> String:
	return anim_browser.get_current_animation() if anim_browser else ""

func get_studio_tab() -> StudioTabBar.Tab:
	return studio_tab_bar.get_tab() if studio_tab_bar else StudioTabBar.Tab.PLAY

func is_posing() -> bool:
	return studio_tab_bar.is_authoring_tab() if studio_tab_bar else false

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
	if not is_path_body_drive_enabled():
		return
	var anim_name := get_current_animation()
	if anim_name == "":
		return
	timeline.key_path_guide_pose(anim_name, guide)
	refresh_timeline_visuals()

func is_path_body_drive_enabled() -> bool:
	if not timeline:
		return false
	var anim_name := get_current_animation()
	if anim_name == "":
		return false
	return timeline.is_path_body_drive_authoring_enabled(anim_name)

func prepare_path_guides_for_authoring() -> void:
	if not is_path_body_drive_enabled():
		return
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
	var tab := get_studio_tab()
	var player := pose_controller.player if pose_controller else null

	if tab == StudioTabBar.Tab.PLAY and play_stats_panel and player:
		play_stats_panel.update_from_player(player)

	if not is_posing() or not timeline or not timeline.anim_player:
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

	if part_panel and tab == StudioTabBar.Tab.SKIN:
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
	if timeline_panel:
		timeline_panel.sync_timing_ui(anim_name)
	if timeline.anim_player.is_playing():
		timeline.stop()
	timeline.seek_step(0, anim_name)
	if assistant_panel:
		assistant_panel.sync_ragdoll_toggles()
		assistant_panel.call_deferred("sync_ragdoll_toggles")
	refresh_timeline_visuals()
	on_step_navigated()
	_sync_path_guide_authoring()

func _on_player_drive_toggled(_enabled: bool) -> void:
	_sync_path_guide_authoring()
	refresh_timeline_visuals()

func _sync_path_guide_authoring() -> void:
	if is_posing() and is_path_body_drive_enabled():
		prepare_path_guides_for_authoring()
	for guide in PathGuideMarker.gather_under(pose_controller.player) if pose_controller and pose_controller.player else []:
		guide.visible = guide.should_show_gizmo()

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

func _on_tab_change_requested(tab: StudioTabBar.Tab) -> void:
	if tab == get_studio_tab():
		return
	_commit_studio_tab(tab)


func _commit_studio_tab(tab: StudioTabBar.Tab) -> void:
	studio_tab_bar.apply_tab(tab)
	_apply_studio_tab(tab)


func _on_timeline_anim_selected(anim_name: String) -> void:
	if anim_browser:
		anim_browser.select_animation_by_name(anim_name)

func _refresh_anim_selector(select_name: String = "") -> void:
	if not timeline_panel or not anim_browser:
		return
	var current := select_name if select_name != "" else anim_browser.get_current_animation()
	timeline_panel.populate_anim_selector(anim_browser.get_animation_names(), current)

func _apply_studio_tab(tab: StudioTabBar.Tab) -> void:
	var posing := tab == StudioTabBar.Tab.SKIN or tab == StudioTabBar.Tab.ANIMATE
	var building := tab == StudioTabBar.Tab.BUILD

	if pose_controller and pose_controller.player:
		pose_controller.player.is_posing = posing

	if timeline:
		timeline.stop()
	if timeline_panel and not posing:
		timeline_panel.set_recording(false)

	if build_panel:
		build_panel.paint_enabled = building
		if building:
			BuildPaintDebug.trace(
				"BUILD tab active panel_id=%s in_tree=%s" % [
					build_panel.get_instance_id(),
					build_panel.is_inside_tree(),
				]
			)

	if timeline_dock:
		timeline_dock.visible = true

	if part_panel:
		part_panel.visible = tab == StudioTabBar.Tab.SKIN
	if timeline_panel:
		timeline_panel.visible = tab == StudioTabBar.Tab.ANIMATE
		timeline_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if build_panel:
		build_panel.visible = tab == StudioTabBar.Tab.BUILD
		build_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if play_stats_panel:
		play_stats_panel.visible = tab == StudioTabBar.Tab.PLAY
		play_stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_apply_bottom_dock_size(tab)

	if tab == StudioTabBar.Tab.ANIMATE and timeline and timeline.anim_player:
		var playing_anim := String(timeline.anim_player.current_animation)
		if playing_anim != "":
			anim_browser.sync_display_to_animation(playing_anim)
			var anim := timeline.anim_player.get_animation(playing_anim)
			timeline_panel.build_step_grid(anim.length)
			timeline_panel.sync_timing_ui(playing_anim)
			_last_sync_anim = playing_anim
			_last_sync_grid_len = anim.length

	_sync_path_guide_authoring()
	LevelAuthoring.apply_studio_tab(tab, get_tree())

func _apply_bottom_dock_size(_tab: StudioTabBar.Tab) -> void:
	if not timeline_dock:
		return
	timeline_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	timeline_dock.offset_left = DOCK_MARGIN_H
	timeline_dock.offset_right = -DOCK_MARGIN_H
	timeline_dock.offset_top = -DOCK_HEIGHT
	timeline_dock.offset_bottom = 0.0


func _is_pointer_over_build_dock() -> bool:
	if timeline_dock == null or not timeline_dock.visible:
		return false
	var mouse := get_viewport().get_mouse_position()
	var viewport_height := get_viewport().get_visible_rect().size.y
	return mouse.y >= viewport_height - DOCK_HEIGHT - 4.0


func _route_build_input(event: InputEvent, channel: String) -> void:
	if not build_panel or not build_panel.visible or not build_panel.paint_enabled:
		return
	if _is_pointer_over_build_dock():
		if event is InputEventMouseMotion:
			build_panel.suppress_brush()
		return
	if build_panel.process_build_input(event, channel):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	_route_build_input(event, "hud_unhandled")

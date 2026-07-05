class_name PoseTabStyles
extends RefCounted

const PANEL_BG := Color(0.2, 0.2, 0.22, 0.9)
const TAB_STRIP_BG := Color(0.12, 0.12, 0.14, 0.92)
const TAB_ACTIVE_BG := PANEL_BG
const TAB_INACTIVE_BG := Color(0.14, 0.14, 0.16, 0.72)
const TAB_HOVER_BG := Color(0.17, 0.17, 0.19, 0.82)
const TOOLBAR_BG := Color(0.16, 0.16, 0.18, 0.95)

const TAB_FONT_SIZE := 9
const TAB_MIN_HEIGHT := 20
const TAB_STRIP_WIDTH := 48
const TOOL_BUTTON_SIZE := 32

static func apply_left_tab_strip(panel: PanelContainer) -> void:
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = TAB_STRIP_BG
	style.content_margin_left = 4
	style.content_margin_right = 0
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.corner_radius_top_left = 4
	style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)

static func apply_right_tab_strip(panel: PanelContainer) -> void:
	apply_left_tab_strip(panel)

static func configure_strip_container(strip: VBoxContainer) -> void:
	strip.custom_minimum_size = Vector2(TAB_STRIP_WIDTH, 0)
	strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

static func apply_content_panel(panel: PanelContainer, tabs_on_left: bool = true) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_content_margin_all(4)
	if tabs_on_left:
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
	else:
		style.corner_radius_top_left = 4
		style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)

static func apply_tab_button(btn: Button, selected: bool, tabs_on_right: bool = false) -> void:
	var bg := TAB_ACTIVE_BG if selected else TAB_INACTIVE_BG
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	if tabs_on_right:
		style.corner_radius_top_left = 0 if selected else 3
		style.corner_radius_bottom_left = 0 if selected else 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_right = 3
		if not selected:
			style.border_width_right = 1
	else:
		style.corner_radius_top_right = 0 if selected else 3
		style.corner_radius_bottom_right = 0 if selected else 3
		style.corner_radius_top_left = 3
		style.corner_radius_bottom_left = 3
		if not selected:
			style.border_width_left = 1
	style.border_color = Color(0.08, 0.08, 0.1, 0.8)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = TAB_ACTIVE_BG if selected else TAB_HOVER_BG
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_color_override("font_color", Color.WHITE if selected else Color(0.95, 0.95, 0.95))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.95, 0.95, 0.95))
	btn.add_theme_color_override("font_focus_color", Color.WHITE)

static func make_tab_button(text: String, tooltip: String = "") -> Button:
	var btn := Button.new()
	btn.text = text
	btn.tooltip_text = tooltip
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(TAB_STRIP_WIDTH, TAB_MIN_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", TAB_FONT_SIZE)
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return btn

static func apply_toolbar_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = TOOLBAR_BG
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.content_margin_left = 2
	style.content_margin_right = 2
	panel.add_theme_stylebox_override("panel", style)

class_name StudioTabBar
extends HBoxContainer

enum Tab { SKIN, ANIMATE, BUILD, PLAY }

signal tab_changed(tab: Tab)

const TAB_LABELS: PackedStringArray = ["Skin", "Animate", "Build", "Play"]

@onready var skin_btn: Button = %SkinTabBtn
@onready var animate_btn: Button = %AnimateTabBtn
@onready var build_btn: Button = %BuildTabBtn
@onready var play_btn: Button = %PlayTabBtn

var _tab: Tab = Tab.PLAY
var _button_group: ButtonGroup


func _ready() -> void:
	_button_group = ButtonGroup.new()
	_button_group.allow_unpress = false
	for btn in [skin_btn, animate_btn, build_btn, play_btn]:
		if btn:
			btn.button_group = _button_group
			btn.toggle_mode = true
	if skin_btn:
		skin_btn.pressed.connect(func(): _set_tab(Tab.SKIN))
	if animate_btn:
		animate_btn.pressed.connect(func(): _set_tab(Tab.ANIMATE))
	if build_btn:
		build_btn.pressed.connect(func(): _set_tab(Tab.BUILD))
	if play_btn:
		play_btn.pressed.connect(func(): _set_tab(Tab.PLAY))
	_style_tabs()
	_set_tab(Tab.PLAY, false)


func get_tab() -> Tab:
	return _tab


func is_authoring_tab() -> bool:
	return _tab == Tab.SKIN or _tab == Tab.ANIMATE


func _style_tabs() -> void:
	for btn in [skin_btn, animate_btn, build_btn, play_btn]:
		if btn:
			btn.custom_minimum_size = Vector2(64, 24)
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", PoseTabStyles.PANEL_FONT_SIZE)


func _set_tab(tab: Tab, emit_signal: bool = true) -> void:
	_tab = tab
	if skin_btn:
		skin_btn.button_pressed = tab == Tab.SKIN
		PoseTabStyles.apply_tab_button(skin_btn, tab == Tab.SKIN, false)
	if animate_btn:
		animate_btn.button_pressed = tab == Tab.ANIMATE
		PoseTabStyles.apply_tab_button(animate_btn, tab == Tab.ANIMATE, false)
	if build_btn:
		build_btn.button_pressed = tab == Tab.BUILD
		PoseTabStyles.apply_tab_button(build_btn, tab == Tab.BUILD, false)
	if play_btn:
		play_btn.button_pressed = tab == Tab.PLAY
		PoseTabStyles.apply_tab_button(play_btn, tab == Tab.PLAY, false)
	if emit_signal:
		tab_changed.emit(tab)

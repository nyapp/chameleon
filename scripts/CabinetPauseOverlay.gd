## CabinetPauseOverlay.gd
## ゲーム画面（SubViewport 外）に描画するポーズメニュー。
## iOS 実機で SubViewport 内 CanvasLayer の描画が効かない場合の対策。

extends Control

const CANVAS_W: int = 256
const CANVAS_H: int = 240
const PANEL_RADIUS: float = 10.0
const ROW_RADIUS: float = 6.0
const ROW_LEFT: float = 56.0
const ROW_WIDTH: float = 144.0
const ROW_HEIGHT: float = 20.0
const ROW_GAP: float = 6.0
const SECTION_GAP: float = 10.0

const PANEL_LEFT: float = 40.0
const PANEL_TOP: float = 44.0
const PANEL_WIDTH: float = 176.0
const PANEL_BOTTOM_PAD: float = 14.0
const PANEL_BORDER_WIDTH: float = 2.5
const TITLE_FONT_SIZE: int = 10
const ROW_START_Y: float = 84.0

const CONFIRM_PANEL_LEFT: float = 24.0
const CONFIRM_PANEL_TOP: float = 68.0
const CONFIRM_PANEL_WIDTH: float = 208.0
const CONFIRM_PANEL_HEIGHT: float = 88.0
const CONFIRM_MESSAGE_Y: float = 92.0
const CONFIRM_SUBMESSAGE_Y: float = 106.0
const CONFIRM_BUTTON_TOP: float = 118.0
const CONFIRM_BUTTON_WIDTH: float = 72.0
const CONFIRM_BUTTON_HEIGHT: float = 20.0
const CONFIRM_BUTTON_GAP: float = 16.0

const COLOR_PANEL_BG := Color(0.08, 0.08, 0.08, 0.92)
const COLOR_PANEL_BORDER := Color(0.45, 0.45, 0.45, 0.7)
const COLOR_ROW_BG := Color(0.12, 0.12, 0.12, 0.92)
const COLOR_ROW_BORDER_ON := Color(0.55, 0.55, 0.55, 0.65)
const COLOR_ROW_BORDER_OFF := Color(0.28, 0.28, 0.28)
const COLOR_TEXT_ON := Color(0.75, 0.75, 0.75)
const COLOR_TEXT_OFF := Color(0.42, 0.42, 0.42)
const COLOR_CHECKBOX_BG := Color(0.06, 0.06, 0.06, 1.0)
const COLOR_CHECKBOX_BORDER := Color(0.45, 0.45, 0.45, 0.75)
const COLOR_DIVIDER := Color(0.35, 0.35, 0.35, 0.4)

var _main_scene: Node2D = null
var _last_tap_frame: int = -1
var _confirming_title: bool = false

func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)
	HapticManager.haptics_toggled.connect(_on_settings_changed)
	AudioManager.music_toggled.connect(_on_settings_changed)
	AudioManager.sfx_toggled.connect(_on_settings_changed)
	_sync_visibility()
	queue_redraw()

func bind_main_scene(main_scene: Node2D) -> void:
	_main_scene = main_scene

func _on_state_changed(_new_state: String) -> void:
	if _new_state != "PAUSED":
		_confirming_title = false
	_sync_visibility()
	queue_redraw()

func _on_settings_changed(_enabled: bool) -> void:
	queue_redraw()

func _sync_visibility() -> void:
	var paused: bool = GameState.state == "PAUSED"
	visible = paused
	mouse_filter = Control.MOUSE_FILTER_STOP if paused else Control.MOUSE_FILTER_IGNORE
	z_index = 50 if paused else 0
	call_deferred("queue_redraw")

func _toggle_row(index: int) -> Rect2:
	return Rect2(
		ROW_LEFT,
		ROW_START_Y + (ROW_HEIGHT + ROW_GAP) * float(index),
		ROW_WIDTH,
		ROW_HEIGHT
	)

func _actions_start_y() -> float:
	return ROW_START_Y + (ROW_HEIGHT + ROW_GAP) * 3.0 + SECTION_GAP

func _action_row(index: int) -> Rect2:
	return Rect2(
		ROW_LEFT,
		_actions_start_y() + (ROW_HEIGHT + ROW_GAP) * float(index),
		ROW_WIDTH,
		ROW_HEIGHT
	)

func _confirm_yes_rect() -> Rect2:
	var total_w := CONFIRM_BUTTON_WIDTH * 2.0 + CONFIRM_BUTTON_GAP
	var left := (float(CANVAS_W) - total_w) * 0.5
	return Rect2(left, CONFIRM_BUTTON_TOP, CONFIRM_BUTTON_WIDTH, CONFIRM_BUTTON_HEIGHT)

func _confirm_no_rect() -> Rect2:
	var yes := _confirm_yes_rect()
	return Rect2(
		yes.position.x + CONFIRM_BUTTON_WIDTH + CONFIRM_BUTTON_GAP,
		yes.position.y,
		CONFIRM_BUTTON_WIDTH,
		CONFIRM_BUTTON_HEIGHT
	)

func _confirm_panel_rect() -> Rect2:
	return Rect2(CONFIRM_PANEL_LEFT, CONFIRM_PANEL_TOP, CONFIRM_PANEL_WIDTH, CONFIRM_PANEL_HEIGHT)

func _panel_rect() -> Rect2:
	var last_row := _action_row(1)
	var bottom := last_row.position.y + last_row.size.y + PANEL_BOTTOM_PAD
	return Rect2(PANEL_LEFT, PANEL_TOP, PANEL_WIDTH, bottom - PANEL_TOP)

func _gui_input(event: InputEvent) -> void:
	if GameState.state != "PAUSED":
		return

	if DisplayServer.is_touchscreen_available():
		if event is InputEventScreenTouch and event.pressed:
			_handle_tap(event.position)
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_tap(event.position)
		accept_event()

func _handle_tap(local_pos: Vector2) -> void:
	var frame := Engine.get_process_frames()
	if frame == _last_tap_frame:
		return
	_last_tap_frame = frame

	if _confirming_title:
		if _confirm_yes_rect().has_point(local_pos):
			_confirming_title = false
			_return_to_title()
		elif _confirm_no_rect().has_point(local_pos):
			_confirming_title = false
			queue_redraw()
		return

	if _toggle_row(0).has_point(local_pos):
		AudioManager.set_music_enabled(not AudioManager.music_enabled)
		queue_redraw()
	elif _toggle_row(1).has_point(local_pos):
		AudioManager.set_sfx_enabled(not AudioManager.sfx_enabled)
		queue_redraw()
	elif _toggle_row(2).has_point(local_pos):
		HapticManager.set_haptics_enabled(not HapticManager.haptics_enabled)
		queue_redraw()
	elif _action_row(0).has_point(local_pos):
		_unpause()
	elif _action_row(1).has_point(local_pos):
		_confirming_title = true
		queue_redraw()
	else:
		_unpause()

func _return_to_title() -> void:
	_confirming_title = false
	if _main_scene and _main_scene.has_method("return_to_title"):
		_main_scene.return_to_title()
	elif GameState.state == "PAUSED":
		AudioManager.stop_bgm()
		GameState.return_to_title()

func _unpause() -> void:
	_confirming_title = false
	if _main_scene and _main_scene.has_method("toggle_pause_menu"):
		_main_scene.toggle_pause_menu()
	elif GameState.state == "PAUSED":
		GameState.frozen_by_menu = false
		GameState.set_state("PLAYING")
		if GameState.bgm_paused_by_menu:
			GameState.bgm_paused_by_menu = false
			AudioManager.resume_bgm()

func _game_font() -> Font:
	return CabinetFonts.arcade_or_fallback()

func _header_title_baseline(font: Font) -> float:
	return _centered_text_baseline(font, "PAUSED", TITLE_FONT_SIZE, PANEL_TOP, ROW_START_Y - PANEL_TOP)

func _centered_text_baseline(font: Font, text: String, font_size: int, area_top: float, area_h: float) -> float:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var descent := font.get_descent(font_size)
	# Press Start 2P は上側に余白が多いので、見た目の中央に寄せる微調整を入れる。
	const VISUAL_BIAS_Y: float = 3.0
	return area_top + (area_h - text_size.y) * 0.5 + text_size.y - descent + VISUAL_BIAS_Y

func _draw() -> void:
	if not visible:
		return

	var font := _game_font()
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0, 0, 0, 0.65))

	var panel := _panel_rect()
	_draw_rounded_rect(panel, COLOR_PANEL_BG, PANEL_RADIUS, true)
	_draw_rounded_rect(panel, COLOR_PANEL_BORDER, PANEL_RADIUS, false, PANEL_BORDER_WIDTH)

	draw_string(font,
		Vector2(0, _header_title_baseline(font)),
		"PAUSED", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, TITLE_FONT_SIZE,
		COLOR_TEXT_ON)

	_draw_pause_toggle(_toggle_row(0), "BGM", AudioManager.music_enabled)
	_draw_pause_toggle(_toggle_row(1), "SE", AudioManager.sfx_enabled)
	_draw_pause_toggle(_toggle_row(2), "HAPTICS", HapticManager.haptics_enabled)

	var divider_y := _actions_start_y() - 5.0
	draw_line(
		Vector2(ROW_LEFT + 8.0, divider_y),
		Vector2(ROW_LEFT + ROW_WIDTH - 8.0, divider_y),
		COLOR_DIVIDER,
		1.0
	)

	_draw_pause_action(_action_row(0), "RESUME")
	_draw_pause_action(_action_row(1), "TITLE")

	if _confirming_title:
		_draw_title_confirm(font)

func _draw_title_confirm(font: Font) -> void:
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0, 0, 0, 0.35))

	var panel := _confirm_panel_rect()
	_draw_rounded_rect(panel, COLOR_PANEL_BG, PANEL_RADIUS, true)
	_draw_rounded_rect(panel, COLOR_PANEL_BORDER, PANEL_RADIUS, false, PANEL_BORDER_WIDTH)

	draw_string(font,
		Vector2(0, CONFIRM_MESSAGE_Y),
		"RETURN TO TITLE?", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 7,
		COLOR_TEXT_ON)
	draw_string(font,
		Vector2(0, CONFIRM_SUBMESSAGE_Y),
		"ARE YOU SURE?", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 7,
		COLOR_TEXT_ON)

	_draw_pause_action(_confirm_yes_rect(), "YES")
	_draw_pause_action(_confirm_no_rect(), "NO")

func _draw_pause_toggle(rect: Rect2, label: String, enabled: bool) -> void:
	var font := _game_font()
	var border := COLOR_ROW_BORDER_ON if enabled else COLOR_ROW_BORDER_OFF
	var text_color := COLOR_TEXT_ON if enabled else COLOR_TEXT_OFF
	_draw_row_background(rect, border)

	var box := Rect2(rect.position.x + 10.0, rect.position.y + 5.0, 10.0, 10.0)
	_draw_rounded_rect(box, COLOR_CHECKBOX_BG, 2.0, true)
	_draw_rounded_rect(box, COLOR_CHECKBOX_BORDER, 2.0, false, 1.0)
	if enabled:
		draw_rect(Rect2(box.position.x + 2.0, box.position.y + 2.0, 6.0, 6.0), COLOR_TEXT_ON)

	draw_string(font,
		Vector2(rect.position.x + 26.0, rect.position.y + rect.size.y - 5.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 30.0), 7,
		text_color)

func _draw_pause_action(rect: Rect2, label: String) -> void:
	var font := _game_font()
	_draw_row_background(rect, COLOR_ROW_BORDER_ON)
	draw_string(font,
		Vector2(rect.position.x, rect.position.y + rect.size.y - 5.0),
		label, HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), 7,
		COLOR_TEXT_ON)

func _draw_row_background(rect: Rect2, border: Color) -> void:
	_draw_rounded_rect(rect, COLOR_ROW_BG, ROW_RADIUS, true)
	_draw_rounded_rect(rect, border, ROW_RADIUS, false, 1.0)

func _draw_rounded_rect(rect: Rect2, color: Color, radius: float, filled: bool, line_width: float = 1.0) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(maxi(int(radius), 0))
	if filled:
		style.bg_color = color
	else:
		style.bg_color = Color.TRANSPARENT
		style.border_color = color
		style.set_border_width_all(maxi(int(line_width), 1))
	style.draw(get_canvas_item(), rect)

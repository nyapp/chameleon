## CabinetPauseOverlay.gd
## ゲーム画面（SubViewport 外）に描画するポーズメニュー。
## iOS 実機で SubViewport 内 CanvasLayer の描画が効かない場合の対策。

extends Control

const CANVAS_W: int = 256
const CANVAS_H: int = 240
const PANEL_RADIUS: float = 10.0
const BUTTON_RADIUS: float = 6.0

var _main_scene: Node2D = null
var _last_tap_frame: int = -1

func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)
	HapticManager.haptics_toggled.connect(_on_haptics_toggled)
	_sync_visibility()
	queue_redraw()

func bind_main_scene(main_scene: Node2D) -> void:
	_main_scene = main_scene

func _on_state_changed(_new_state: String) -> void:
	_sync_visibility()
	queue_redraw()

func _on_haptics_toggled(_enabled: bool) -> void:
	queue_redraw()

func _sync_visibility() -> void:
	var paused: bool = GameState.state == "PAUSED"
	visible = paused
	mouse_filter = Control.MOUSE_FILTER_STOP if paused else Control.MOUSE_FILTER_IGNORE
	z_index = 50 if paused else 0
	call_deferred("queue_redraw")

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
	if HapticManager.contains_pause_haptics_button(local_pos):
		HapticManager.set_haptics_enabled(not HapticManager.haptics_enabled)
		queue_redraw()
	elif HapticManager.contains_pause_resume_button(local_pos):
		_unpause()
	elif HapticManager.contains_pause_title_button(local_pos):
		_return_to_title()
	else:
		_unpause()

func _return_to_title() -> void:
	if _main_scene and _main_scene.has_method("return_to_title"):
		_main_scene.return_to_title()
	elif GameState.state == "PAUSED":
		AudioManager.stop_bgm()
		GameState.return_to_title()

func _unpause() -> void:
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

func _draw() -> void:
	if not visible:
		return

	var font := _game_font()
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0, 0, 0, 0.65))

	var panel := Rect2(40, 68, 176, 114)
	_draw_rounded_rect(panel, Color(0.059, 0.059, 0.102, 0.95), PANEL_RADIUS, true)
	_draw_rounded_rect(panel, Color(0.616, 0.0, 1.0, 0.85), PANEL_RADIUS, false, 1.0)

	draw_string(font,
		Vector2(0, 88),
		"PAUSED", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 10,
		Color(0.0, 0.941, 1.0))

	_draw_pause_button(
		HapticManager.PAUSE_HAPTICS_BTN,
		"HAPTICS: %s" % ("ON" if HapticManager.haptics_enabled else "OFF"),
		HapticManager.haptics_enabled
	)
	_draw_pause_button(HapticManager.PAUSE_RESUME_BTN, "RESUME", true)
	_draw_pause_button(HapticManager.PAUSE_TITLE_BTN, "TITLE", false)

	var hint: String = "ESC TO RESUME" if not DisplayServer.is_touchscreen_available() else "TAP OUTSIDE TO RESUME"
	draw_string(font,
		Vector2(0, 196),
		hint, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 6,
		Color(0.502, 0.502, 0.627))

func _draw_pause_button(rect: Rect2, label: String, is_active: bool) -> void:
	var font := _game_font()
	var bg := Color(0.118, 0.118, 0.176, 0.95)
	var border := Color(0.616, 0.0, 1.0, 0.7) if is_active else Color(0.306, 0.306, 0.427)
	var text_color := Color(0.0, 0.941, 1.0) if is_active else Color(0.502, 0.502, 0.627)
	_draw_rounded_rect(rect, bg, BUTTON_RADIUS, true)
	_draw_rounded_rect(rect, border, BUTTON_RADIUS, false, 1.0)
	draw_string(font,
		Vector2(rect.position.x, rect.position.y + rect.size.y - 5.0),
		label, HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), 7,
		text_color)

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

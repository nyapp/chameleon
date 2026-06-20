## CabinetFireButton.gd
## コントロールデッキ右側の FIRE ボタン（スティック同高・角丸）。

@tool
extends Control
class_name CabinetFireButton

const CabinetFontsScript := preload("res://scripts/CabinetFonts.gd")

signal pressed

@export var panel_size: Vector2 = Vector2(102.0, 128.0):
	set(value):
		panel_size = Vector2(maxi(value.x, 48.0), maxi(value.y, 64.0))
		_update_size()

@export var corner_radius: float = 12.0:
	set(value):
		corner_radius = value
		queue_redraw()

@export var label_text: String = "FIRE":
	set(value):
		label_text = value
		queue_redraw()

@export var font_size: int = 14:
	set(value):
		font_size = value
		queue_redraw()

@export var accent_color: Color = Color(1.0, 0.0, 0.498): # #ff007f
	set(value):
		accent_color = value
		queue_redraw()

@export var idle_bg_color: Color = Color(0.094, 0.094, 0.141, 0.92):
	set(value):
		idle_bg_color = value
		queue_redraw()

@export var pressed_bg_color: Color = Color(0.063, 0.063, 0.102, 0.92):
	set(value):
		pressed_bg_color = value
		queue_redraw()

var _pressed_visual: bool = false
var _last_press_frame: int = -1

func _ready() -> void:
	_update_size()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not Engine.is_editor_hint():
		GameState.state_changed.connect(_on_state_changed)
	queue_redraw()

func _on_state_changed(_new_state: String) -> void:
	queue_redraw()

func _font() -> Font:
	return CabinetFontsScript.get_mono_font()

func set_panel_height(height: float) -> void:
	set_panel_size(Vector2(panel_size.x, height))

func set_panel_size(dim: Vector2) -> void:
	panel_size = dim
	_update_size()

func _update_size() -> void:
	custom_minimum_size = panel_size
	size = panel_size
	queue_redraw()

func _button_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)

func _is_actionable() -> bool:
	return GameState.state in ["TITLE", "GAMEOVER", "PLAYING"]

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var actionable: bool = _is_actionable()
	modulate.a = 1.0 if actionable else 0.45
	mouse_filter = Control.MOUSE_FILTER_STOP if actionable else Control.MOUSE_FILTER_IGNORE

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not _is_actionable():
		return

	var local_pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		local_pos = event.position
	elif event is InputEventMouseButton:
		local_pos = event.position
	else:
		return

	if not _button_rect().has_point(local_pos):
		return

	if DisplayServer.is_touchscreen_available():
		if event is InputEventScreenTouch:
			_handle_touch(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_set_pressed_visual(true)
		_emit_pressed_once()
		accept_event()
	else:
		_set_pressed_visual(false)
		accept_event()

func _handle_mouse(event: InputEventMouseButton) -> void:
	if event.pressed:
		_set_pressed_visual(true)
		_emit_pressed_once()
		accept_event()
	else:
		_set_pressed_visual(false)
		accept_event()

func _set_pressed_visual(down: bool) -> void:
	if _pressed_visual == down:
		return
	_pressed_visual = down
	queue_redraw()

func _emit_pressed_once() -> void:
	var frame := Engine.get_process_frames()
	if frame == _last_press_frame:
		return
	_last_press_frame = frame
	HapticManager.play_ui_tap()
	pressed.emit()

func _centered_baseline(font: Font, text: String, font_size_px: int, area: Rect2) -> float:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_px)
	var descent := font.get_descent(font_size_px)
	return area.position.y + (area.size.y - text_size.y) * 0.5 + text_size.y - descent

func _draw() -> void:
	var btn := _button_rect()
	var inset := 0.5 if _pressed_visual else 0.0
	var button_rect := btn.grow(-inset)

	var idle_outline := Color(0.722, 0.733, 0.769)
	var muted_accent := Color(accent_color.r, accent_color.g, accent_color.b, 0.42)

	var ring := muted_accent
	var fill := idle_bg_color
	var label_col := idle_outline

	if _pressed_visual:
		fill = pressed_bg_color
		ring = Color(accent_color.r, accent_color.g, accent_color.b, 0.72)
		label_col = Color(accent_color.r, accent_color.g, accent_color.b, 0.82)

	_draw_rounded_rect(button_rect, fill, corner_radius, true)
	_draw_rounded_rect(button_rect, ring, corner_radius, false, 1.0)

	var font := _font()
	var label_y := _centered_baseline(font, label_text, font_size, btn)
	draw_string(font, Vector2(0.0, label_y), label_text,
		HORIZONTAL_ALIGNMENT_CENTER, int(btn.size.x), font_size, label_col)

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

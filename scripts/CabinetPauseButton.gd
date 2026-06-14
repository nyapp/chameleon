## CabinetPauseButton.gd
## コントロールデッキ上の PAUSE ボタン（Web版 gb-menu-btn 相当）。

@tool
extends Control
class_name CabinetPauseButton

signal pressed

@export var button_size: Vector2 = Vector2(58.0, 44.0):
	set(value):
		button_size = value
		_update_size()

@export var label_text: String = "PAUSE":
	set(value):
		label_text = value
		queue_redraw()

@export var font_size: int = 6:
	set(value):
		font_size = value
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

func _update_size() -> void:
	custom_minimum_size = button_size
	size = button_size

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var active: bool = GameState.state in ["PLAYING", "PAUSED"]
	modulate.a = 1.0 if active else 0.45
	mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if GameState.state not in ["PLAYING", "PAUSED"]:
		return

	# iOS 等ではタッチに加えてマウスイベントも飛び、1回の操作で2回トグルされる
	if DisplayServer.is_touchscreen_available():
		if event is InputEventScreenTouch:
			_handle_touch(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_set_pressed_visual(true)
		accept_event()
	else:
		_set_pressed_visual(false)
		_emit_pressed_once()
		accept_event()

func _handle_mouse(event: InputEventMouseButton) -> void:
	if event.pressed:
		_set_pressed_visual(true)
		accept_event()
	else:
		_set_pressed_visual(false)
		_emit_pressed_once()
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
	pressed.emit()

func _font() -> Font:
	return CabinetFonts.mono_or_fallback()

func _draw() -> void:
	var bg := Color(0.118, 0.118, 0.176, 0.95)
	var border := Color(0.616, 0.0, 1.0, 0.75)
	var text_color := Color(0.478, 0.510, 0.588)
	var is_paused: bool = not Engine.is_editor_hint() and GameState.state == "PAUSED"

	if _pressed_visual:
		bg = Color(0.063, 0.063, 0.102, 0.98)
		border = Color(0.616, 0.0, 1.0, 1.0)
		text_color = Color(0.0, 0.941, 1.0)
	elif is_paused:
		border = Color(0.0, 0.941, 1.0, 0.9)
		text_color = Color(0.0, 0.941, 1.0)

	var rect := Rect2(Vector2.ZERO, size)
	var inset := 1.0 if _pressed_visual else 0.0
	draw_rect(rect.grow(-inset), bg)
	draw_rect(rect.grow(-inset), border, false, 1.5)

	var font := _font()
	var label_y: float = size.y * 0.5 + float(font_size) * 0.35
	draw_string(font, Vector2(0.0, label_y), label_text,
		HORIZONTAL_ALIGNMENT_CENTER, int(size.x), font_size, text_color)

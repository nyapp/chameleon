## CabinetPauseButton.gd
## コントロールデッキ右上の PAUSE ボタン（アウトライン / ゴーストスタイル）。

@tool
extends Control
class_name CabinetPauseButton

const CabinetFontsScript := preload("res://scripts/CabinetFonts.gd")

signal pressed

@export var button_size: Vector2 = Vector2(52.0, 20.0):
	set(value):
		button_size = value
		_update_size()

@export var label_text: String = "PAUSE":
	set(value):
		label_text = value
		queue_redraw()

@export var font_size: int = 8:
	set(value):
		font_size = value
		queue_redraw()

@export var corner_radius: float = 4.0:
	set(value):
		corner_radius = value
		queue_redraw()

@export var outline_color: Color = Color(0.722, 0.733, 0.769):
	set(value):
		outline_color = value
		queue_redraw()

@export var idle_bg_color: Color = Color(0.094, 0.094, 0.141, 0.92):
	set(value):
		idle_bg_color = value
		queue_redraw()

@export var pressed_bg_color: Color = Color(0.063, 0.063, 0.102, 0.85):
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
	return CabinetFontsScript.get_mono_font()

func _draw() -> void:
	var border := outline_color
	var text_color := outline_color
	var bg := idle_bg_color
	var is_paused: bool = not Engine.is_editor_hint() and GameState.state == "PAUSED"

	if _pressed_visual:
		bg = pressed_bg_color
		border = outline_color.lightened(0.12)
		text_color = border
	elif is_paused:
		border = outline_color.lightened(0.08)
		text_color = border

	var rect := Rect2(Vector2.ZERO, size)
	var inset := 0.5 if _pressed_visual else 0.0
	var button_rect := rect.grow(-inset)
	_draw_rounded_rect(button_rect, bg, corner_radius, true)
	_draw_rounded_rect(button_rect, border, corner_radius, false, 1.0)

	var font := _font()
	var label_y: float = size.y * 0.5 + float(font_size) * 0.32
	draw_string(font, Vector2(0.0, label_y), label_text,
		HORIZONTAL_ALIGNMENT_CENTER, int(size.x), font_size, text_color)

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

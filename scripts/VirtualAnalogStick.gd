## VirtualAnalogStick.gd
## 画面下部のバーチャルアナログスティック。引いて離すと照準方向を通知する。

extends Control
class_name VirtualAnalogStick

signal aim_changed(direction: Vector2, magnitude: float)
signal released(direction: Vector2, magnitude: float)

const RADIUS: float = 28.0
const DEADZONE: float = 0.25
const KNOB_MAX: float = 22.0
const INVERT_AIM: bool = true

var _active: bool = false
var _knob_offset: Vector2 = Vector2.ZERO
var _last_direction: Vector2 = Vector2.ZERO
var _last_magnitude: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _process(_delta: float) -> void:
	# PLAYING 以外は半透明表示（常に見えるようにする）
	modulate.a = 1.0 if GameState.state == "PLAYING" else 0.55

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_active = true
			_update_knob(event.position)
			accept_event()
		else:
			_finish_drag()
			accept_event()
	elif event is InputEventScreenDrag:
		if _active:
			_update_knob(event.position)
			accept_event()
	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_active = true
			_update_knob(event.position)
			accept_event()
		elif _active:
			_finish_drag()
			accept_event()
	elif event is InputEventMouseMotion and _active:
		_update_knob(event.position)
		accept_event()

func _update_knob(local_pos: Vector2) -> void:
	var center: Vector2 = size * 0.5
	var offset: Vector2 = local_pos - center
	if offset.length() > KNOB_MAX:
		offset = offset.normalized() * KNOB_MAX
	_knob_offset = offset
	var raw_direction: Vector2 = offset / KNOB_MAX if KNOB_MAX > 0.0 else Vector2.ZERO
	_last_direction = -raw_direction if INVERT_AIM else raw_direction
	_last_magnitude = raw_direction.length()
	aim_changed.emit(_last_direction, _last_magnitude)
	queue_redraw()

func _finish_drag() -> void:
	if not _active:
		return
	_active = false
	released.emit(_last_direction, _last_magnitude)
	_knob_offset = Vector2.ZERO
	_last_direction = Vector2.ZERO
	_last_magnitude = 0.0
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var base_color := Color(0.118, 0.118, 0.176, 0.9)   # #1e1e2d
	var ring_color := Color(0.616, 0.0, 1.0, 0.35)        # #9d00ff
	var knob_color := Color(1.0, 0.0, 0.498)              # #ff007f

	draw_circle(center, RADIUS, base_color)
	draw_arc(center, RADIUS, 0.0, TAU, 32, ring_color, 1.5)
	draw_arc(center, RADIUS * 0.55, 0.0, TAU, 24, Color(ring_color.r, ring_color.g, ring_color.b, 0.2), 1.0)

	var knob_pos: Vector2 = center + _knob_offset
	draw_circle(knob_pos, 10.0, Color(knob_color.r, knob_color.g, knob_color.b, 0.35))
	draw_circle(knob_pos, 8.0, knob_color)

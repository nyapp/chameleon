## VirtualAnalogStick.gd
## 画面下部のバーチャルアナログスティック。引いて離すと照準方向を通知する。

@tool
extends Control
class_name VirtualAnalogStick

signal aim_changed(direction: Vector2, magnitude: float)
signal released(direction: Vector2, magnitude: float)

@export_group("Feel")
@export var radius: float = 50.0:
	set(value):
		radius = value
		_update_size()
@export var deadzone: float = 0.25:
	set(value):
		deadzone = value
@export var knob_max: float = 39.0:
	set(value):
		knob_max = value
@export var invert_aim: bool = true

@export_group("Knob")
@export var knob_outer_radius: float = 18.0:
	set(value):
		knob_outer_radius = value
		queue_redraw()
@export var knob_inner_radius: float = 14.0:
	set(value):
		knob_inner_radius = value
		queue_redraw()
@export var knob_glow_alpha: float = 0.35:
	set(value):
		knob_glow_alpha = value
		queue_redraw()

@export_group("Colors")
@export var base_color: Color = Color(0.118, 0.118, 0.176, 0.9): # #1e1e2d
	set(value):
		base_color = value
		queue_redraw()
@export var ring_color: Color = Color(0.616, 0.0, 1.0, 0.35): # #9d00ff
	set(value):
		ring_color = value
		queue_redraw()
@export var inner_ring_alpha: float = 0.2:
	set(value):
		inner_ring_alpha = value
		queue_redraw()
@export var knob_color: Color = Color(1.0, 0.0, 0.498): # #ff007f
	set(value):
		knob_color = value
		queue_redraw()

@export_group("Operable Arc")
@export var show_operable_arc: bool = true:
	set(value):
		show_operable_arc = value
		queue_redraw()
@export var operable_fill_color: Color = Color(0.0, 0.941, 1.0, 0.12): # #00f0ff
	set(value):
		operable_fill_color = value
		queue_redraw()
@export var operable_edge_color: Color = Color(0.0, 0.941, 1.0, 0.55):
	set(value):
		operable_edge_color = value
		queue_redraw()
@export var operable_arc_width: float = 3.5:
	set(value):
		operable_arc_width = value
		queue_redraw()

var _active: bool = false
var _knob_offset: Vector2 = Vector2.ZERO
var _last_direction: Vector2 = Vector2.ZERO
var _last_magnitude: float = 0.0

func _ready() -> void:
	_update_size()
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _update_size() -> void:
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	modulate.a = 1.0 if GameState.state == "PLAYING" else 0.55

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_active = true
			_emit_ui_tap()
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
			_emit_ui_tap()
			_update_knob(event.position)
			accept_event()
		elif _active:
			_finish_drag()
			accept_event()
	elif event is InputEventMouseMotion and _active:
		_update_knob(event.position)
		accept_event()

func _emit_ui_tap() -> void:
	if GameState.state == "PLAYING":
		HapticManager.play_ui_tap()

func _update_knob(local_pos: Vector2) -> void:
	var center: Vector2 = size * 0.5
	var offset: Vector2 = local_pos - center
	if offset.length() > knob_max:
		offset = offset.normalized() * knob_max
	_knob_offset = offset
	var raw_direction: Vector2 = offset / knob_max if knob_max > 0.0 else Vector2.ZERO
	_last_direction = -raw_direction if invert_aim else raw_direction
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

func _pull_arc_angles(aim_min: float, aim_max: float) -> Vector2:
	if invert_aim:
		return Vector2(aim_min + PI, aim_max + PI)
	return Vector2(aim_min, aim_max)

func _draw_filled_sector(center: Vector2, sector_radius: float, start: float, end: float, color: Color, segments: int = 28) -> void:
	var points: PackedVector2Array = [center]
	var step: float = (end - start) / float(segments)
	for i in range(segments + 1):
		var angle: float = start + step * float(i)
		points.append(center + Vector2(cos(angle), sin(angle)) * sector_radius)
	draw_colored_polygon(points, color)

func _draw_operable_arc(center: Vector2) -> void:
	var arc: Vector2 = _pull_arc_angles(Chameleon.ANGLE_MIN, Chameleon.ANGLE_MAX)

	_draw_filled_sector(center, radius * 0.92, arc.x, arc.y, operable_fill_color)
	draw_arc(center, radius * 0.78, arc.x, arc.y, 24, operable_edge_color, operable_arc_width)

	var tick_inner: float = radius * 0.62
	var tick_outer: float = radius * 0.92
	for angle in [arc.x, arc.y]:
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(center + dir * tick_inner, center + dir * tick_outer, operable_edge_color, 1.5)

func _draw() -> void:
	var center: Vector2 = size * 0.5

	draw_circle(center, radius, base_color)
	if show_operable_arc:
		_draw_operable_arc(center)
	draw_arc(center, radius, 0.0, TAU, 32, ring_color, 1.5)
	draw_arc(center, radius * 0.55, 0.0, TAU, 24, Color(ring_color.r, ring_color.g, ring_color.b, inner_ring_alpha), 1.0)

	var knob_pos: Vector2 = center + _knob_offset
	draw_circle(knob_pos, knob_outer_radius, Color(knob_color.r, knob_color.g, knob_color.b, knob_glow_alpha))
	draw_circle(knob_pos, knob_inner_radius, knob_color)

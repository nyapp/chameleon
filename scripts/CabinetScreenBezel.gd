## CabinetScreenBezel.gd
## CRT スクリーン周囲の二重ベゼル（.screen-outer + .screen-bezel 相当）

@tool
extends Control

var _outer_pad: float = 12.0
var _inner_pad: float = 8.0

@export_group("Shape")
@export var outer_radius: float = 12.0:
	set(value):
		outer_radius = value
		queue_redraw()
@export var inner_radius: float = 8.0:
	set(value):
		inner_radius = value
		queue_redraw()
@export var outer_border_width: float = 4.0:
	set(value):
		outer_border_width = value
		queue_redraw()

@export_group("Colors")
@export var outer_bg: Color = Color(0.051, 0.051, 0.075): # #0d0d13 / --cabinet-bezel
	set(value):
		outer_bg = value
		queue_redraw()
@export var outer_border: Color = Color(0.078, 0.078, 0.125): # #141420
	set(value):
		outer_border = value
		queue_redraw()
@export var inner_bg: Color = Color(0.031, 0.031, 0.059): # #08080f
	set(value):
		inner_bg = value
		queue_redraw()
@export var crt_bg: Color = Color(0.067, 0.067, 0.067): # #111
	set(value):
		crt_bg = value
		queue_redraw()
@export var inset_shadow_alpha: float = 0.9:
	set(value):
		inset_shadow_alpha = value
		queue_redraw()
@export var top_highlight_alpha: float = 0.08:
	set(value):
		top_highlight_alpha = value
		queue_redraw()
@export var bottom_shadow_alpha: float = 0.5:
	set(value):
		bottom_shadow_alpha = value
		queue_redraw()
@export var crt_inset_alpha: float = 1.0:
	set(value):
		crt_inset_alpha = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	queue_redraw()

func set_bezel_pads(outer_pad: int, inner_pad: int) -> void:
	_outer_pad = float(outer_pad)
	_inner_pad = float(inner_pad)
	queue_redraw()

func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	_draw_rounded_rect(outer, outer_bg, outer_radius, true)
	_draw_rounded_rect(outer, outer_border, outer_radius, false, outer_border_width)

	for i in 3:
		var inset := float(i + 1) * 4.0
		var alpha := inset_shadow_alpha * (0.25 - float(i) * 0.06)
		_draw_rounded_rect(outer.grow(-inset), Color(0.0, 0.0, 0.0, alpha), outer_radius - inset, false, 2.0)

	var inner := outer.grow(-_outer_pad)
	_draw_rounded_rect(inner, inner_bg, inner_radius, true)

	draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, 4.0), Color(1, 1, 1, top_highlight_alpha))
	draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y - 4.0, inner.size.x, 4.0), Color(0, 0, 0, bottom_shadow_alpha))

	var crt := inner.grow(-_inner_pad)
	_draw_rounded_rect(crt, crt_bg, 6.0, true)
	for i in 4:
		var inset := float(i + 1) * 5.0
		_draw_rounded_rect(crt.grow(-inset), Color(0.0, 0.0, 0.0, crt_inset_alpha * (0.22 - float(i) * 0.04)), 6.0 - inset * 0.2, false, 2.0)

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

## CabinetScreenBezel.gd
## CRT スクリーン周囲のベゼル描画

@tool
extends Control

@export_group("Shape")
@export var outer_border_width: float = 3.0:
	set(value):
		outer_border_width = value
		queue_redraw()
@export var outer_inset: float = 4.0:
	set(value):
		outer_inset = value
		queue_redraw()
@export var inner_inset: float = 4.0:
	set(value):
		inner_inset = value
		queue_redraw()
@export var highlight_height: float = 3.0:
	set(value):
		highlight_height = value
		queue_redraw()

@export_group("Colors")
@export var bezel_outer: Color = Color(0.051, 0.051, 0.075): # #0d0d13
	set(value):
		bezel_outer = value
		queue_redraw()
@export var bezel_inner: Color = Color(0.031, 0.031, 0.059): # #08080f
	set(value):
		bezel_inner = value
		queue_redraw()
@export var bezel_border: Color = Color(0.078, 0.078, 0.125): # #141420
	set(value):
		bezel_border = value
		queue_redraw()
@export var bezel_deep: Color = Color(0.047, 0.047, 0.071):
	set(value):
		bezel_deep = value
		queue_redraw()
@export var top_highlight_alpha: float = 0.06:
	set(value):
		top_highlight_alpha = value
		queue_redraw()
@export var bottom_shadow_alpha: float = 0.35:
	set(value):
		bottom_shadow_alpha = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, bezel_outer)
	draw_rect(r, bezel_border, false, outer_border_width)

	var inner := r.grow(-outer_inset)
	draw_rect(inner, bezel_inner)
	draw_rect(inner.grow(-inner_inset), bezel_deep, false, 1.0)

	draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, highlight_height), Color(1, 1, 1, top_highlight_alpha))
	draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y - highlight_height, inner.size.x, highlight_height), Color(0, 0, 0, bottom_shadow_alpha))

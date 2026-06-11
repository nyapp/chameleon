## CabinetScreenBezel.gd
## CRT スクリーン周囲のベゼル描画

extends Control

const BEZEL_OUTER := Color(0.051, 0.051, 0.075)    # #0d0d13
const BEZEL_INNER := Color(0.031, 0.031, 0.059)   # #08080f
const BEZEL_BORDER := Color(0.078, 0.078, 0.125)  # #141420

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, BEZEL_OUTER)
	draw_rect(r, BEZEL_BORDER, false, 3.0)

	var inner := r.grow(-4.0)
	draw_rect(inner, BEZEL_INNER)
	draw_rect(inner.grow(-4.0), Color(0.047, 0.047, 0.071), false, 1.0)

	# ベゼルハイライト
	draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, 3.0), Color(1, 1, 1, 0.06))
	draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y - 3.0, inner.size.x, 3.0), Color(0, 0, 0, 0.35))

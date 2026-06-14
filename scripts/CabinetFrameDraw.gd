## CabinetFrameDraw.gd
## 筐体外枠（金属ボディ、ネオン上線、角丸）を描画

@tool
extends Control

@export var overlay_only: bool = false:
	set(value):
		overlay_only = value
		queue_redraw()

@export_group("Shape")
@export var corner_radius: float = 20.0:
	set(value):
		corner_radius = value
		queue_redraw()
@export var border_width: float = 6.0:
	set(value):
		border_width = value
		queue_redraw()
@export var inner_inset: float = 6.0:
	set(value):
		inner_inset = value
		queue_redraw()

@export_group("Neon Line")
@export var neon_line_y: float = 1.0:
	set(value):
		neon_line_y = value
		queue_redraw()
@export var neon_line_height: float = 4.0:
	set(value):
		neon_line_height = value
		queue_redraw()
@export var neon_glow_height: float = 8.0:
	set(value):
		neon_glow_height = value
		queue_redraw()
@export var neon_segments: int = 32:
	set(value):
		neon_segments = maxi(value, 2)
		queue_redraw()

@export_group("Colors")
@export var metal_color: Color = Color(0.118, 0.118, 0.176): # #1e1e2d
	set(value):
		metal_color = value
		queue_redraw()
@export var border_color: Color = Color(0.176, 0.176, 0.267): # #2d2d44
	set(value):
		border_color = value
		queue_redraw()
@export var neon_pink: Color = Color(1.0, 0.0, 0.498):
	set(value):
		neon_pink = value
		queue_redraw()
@export var neon_purple: Color = Color(0.616, 0.0, 1.0):
	set(value):
		neon_purple = value
		queue_redraw()
@export var neon_cyan: Color = Color(0.0, 0.941, 1.0):
	set(value):
		neon_cyan = value
		queue_redraw()
@export var inner_highlight_alpha: float = 0.05:
	set(value):
		inner_highlight_alpha = value
		queue_redraw()
@export var corner_highlight_alpha: float = 0.04:
	set(value):
		corner_highlight_alpha = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)

	if overlay_only:
		_draw_rounded_rect(r, border_color, corner_radius, false, border_width)
		_draw_neon_top_line(r)
		var radius := corner_radius
		draw_arc(Vector2(radius, radius), radius * 0.5, PI, PI * 1.5, 8, Color(1, 1, 1, corner_highlight_alpha), 1.0)
		draw_arc(Vector2(size.x - radius, radius), radius * 0.5, PI * 1.5, TAU, 8, Color(1, 1, 1, corner_highlight_alpha), 1.0)
		return

	_draw_rounded_rect(r, metal_color, corner_radius, true)

	var inner := r.grow(-inner_inset)
	draw_rect(inner, Color(1.0, 1.0, 1.0, inner_highlight_alpha), false, 1.0)

func _draw_neon_top_line(r: Rect2) -> void:
	var inset := corner_radius + 1.0
	var line_w := maxf(0.0, r.size.x - inset * 2.0)
	if line_w <= 0.0:
		return

	var x0 := r.position.x + inset
	var glow_rect := Rect2(x0, neon_line_y, line_w, neon_glow_height)
	draw_rect(glow_rect, Color(neon_pink.r, neon_pink.g, neon_pink.b, 0.1))

	var seg_w := line_w / float(neon_segments)
	for i in neon_segments:
		var t := float(i) / float(neon_segments - 1)
		var col := neon_pink.lerp(neon_purple, t * 2.0) if t < 0.5 else neon_purple.lerp(neon_cyan, (t - 0.5) * 2.0)
		draw_rect(Rect2(x0 + i * seg_w, neon_line_y, seg_w + 1.0, neon_line_height), col)

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

## CabinetFrameDraw.gd
## 筐体外枠（金属ボディ、ネオン上線、角丸）を描画

extends Control

const METAL := Color(0.118, 0.118, 0.176)       # #1e1e2d
const BORDER := Color(0.176, 0.176, 0.267)      # #2d2d44
const NEON_PINK := Color(1.0, 0.0, 0.498)
const NEON_PURPLE := Color(0.616, 0.0, 1.0)
const NEON_CYAN := Color(0.0, 0.941, 1.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var radius := 12.0

	# 外枠シャドウ風の縁
	draw_rect(r, METAL)
	draw_rect(r, BORDER, false, 4.0)

	# 内側ハイライト
	var inner := r.grow(-6.0)
	draw_rect(inner, Color(1.0, 1.0, 1.0, 0.03), false, 1.0)

	# 上部ネオンライン（ピンク→紫→シアン）
	var line_y := 2.0
	var segments := 24
	var seg_w := size.x / float(segments)
	for i in segments:
		var t := float(i) / float(segments - 1)
		var col := NEON_PINK.lerp(NEON_PURPLE, t * 2.0) if t < 0.5 else NEON_PURPLE.lerp(NEON_CYAN, (t - 0.5) * 2.0)
		draw_rect(Rect2(i * seg_w, line_y, seg_w + 1.0, 3.0), col)

	# 角丸マスク風の四隅ハイライト
	draw_arc(Vector2(radius, radius), radius * 0.5, PI, PI * 1.5, 8, Color(1, 1, 1, 0.04), 1.0)
	draw_arc(Vector2(size.x - radius, radius), radius * 0.5, PI * 1.5, TAU, 8, Color(1, 1, 1, 0.04), 1.0)

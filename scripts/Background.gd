## Background.gd
## JSの buildBackgroundCache() + drawBackground() 相当。
## 静的なグリッドBGをNode2D._draw()で描画。
## ctxFlicker()（星のチラつき）も内包する。

extends Node2D

const CANVAS_W: int = 256
const CANVAS_H: int = 240

var _flicker_time: float = 0.0
const SPARKS: Array = [
	Vector2(30, 40), Vector2(180, 30), Vector2(120, 70),
	Vector2(70, 90),  Vector2(220, 80), Vector2(230, 40)
]

func _process(delta: float) -> void:
	var flicker_scale := 0.4 if GameState.power_up_type == "slow" else 1.0
	_flicker_time += delta * flicker_scale
	queue_redraw()

func _draw() -> void:
	# --- ベース背景色 ---
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0.031, 0.031, 0.059))  # #08080f

	# --- 地平線ライン（紫） ---
	draw_line(Vector2(0, 185), Vector2(CANVAS_W, 185),
		Color(0.616, 0.0, 1.0), 1.0)

	# --- 水平グリッドライン（ピンク薄め） ---
	var h_line_color := Color(1.0, 0.0, 0.498, 0.15)
	var y: int = 185
	while y < CANVAS_H:
		draw_line(Vector2(0, y), Vector2(CANVAS_W, y), h_line_color, 1.0)
		y += 8

	# --- パースペクティブ収束線 ---
	var vp: float = CANVAS_W / 2.0
	var vpy: float = 180.0
	var persp_color := Color(1.0, 0.0, 0.498, 0.15)
	var x: float = -100.0
	while x <= CANVAS_W + 100.0:
		var start := Vector2(vp + (x - vp) * 0.1, vpy)
		var end := Vector2(x, CANVAS_H)
		draw_line(start, end, persp_color, 1.0)
		x += 30.0

	# --- 半円グロウ（地平線） ---
	draw_arc(Vector2(CANVAS_W / 2.0, 180), 50.0, PI, 0.0, 32,
		Color(1.0, 0.0, 0.498, 0.04), 50.0)

	# --- 星のチラつき（ctxFlicker 相当） ---
	var time_val: float = _flicker_time * 5.0
	var white := Color(1.0, 1.0, 1.0)
	for i in SPARKS.size():
		var val: float = sin(time_val + i)
		if val > 0.5:
			draw_rect(Rect2(SPARKS[i].x, SPARKS[i].y, 1, 1), white)

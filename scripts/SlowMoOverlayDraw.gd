## SlowMoOverlayDraw.gd
## SLOW-MO パワーアップ中のゲーム画面演出（HUD より下の CanvasLayer layer=5）。

extends Node2D

const CANVAS_W: int = 256
const CANVAS_H: int = 240
const FADE_DURATION: float = 0.3

const _SLOW_CYAN := Color(0.0, 0.941, 1.0)  # #00f0ff
const _TINT_COLOR := Color(0.04, 0.10, 0.14)
const _GRADIENT_STEPS := 10
const _VIGNETTE_RINGS := 16
const _VIGNETTE_SEGS := 24
const _FOCUS_INNER_R: float = 60.0
const _FOCUS_OUTER_R: float = 140.0

var chameleon_ref: Node2D = null
var _blend: float = 0.0

func _process(delta: float) -> void:
	var gs: Node = GameState
	var target: float = 1.0 if gs.state == "PLAYING" and gs.power_up_type == "slow" else 0.0
	var step: float = delta / FADE_DURATION if FADE_DURATION > 0.0 else 1.0
	_blend = move_toward(_blend, target, step)
	if _blend > 0.001 or target > 0.0:
		queue_redraw()

func _draw() -> void:
	if _blend <= 0.001:
		return

	var gs: Node = GameState
	var pulse_speed: float = 0.005 if gs.power_up_time_left >= 1.0 else 0.018
	var pulse: float = 0.65 + 0.35 * sin(Time.get_ticks_msec() * pulse_speed)
	var blend: float = _blend * pulse

	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H),
		Color(_TINT_COLOR.r, _TINT_COLOR.g, _TINT_COLOR.b, 0.22 * blend))

	var focus_center := _focus_center()
	var focus_alpha: float = 0.28 * _blend
	_draw_radial_focus(focus_center, _FOCUS_INNER_R, _FOCUS_OUTER_R, focus_alpha)

	var edge_alpha: float = 0.32 * blend
	var edge_w: float = 28.0
	_draw_linear_fade_rect(Rect2(0, 0, CANVAS_W, edge_w), edge_alpha, true)
	_draw_linear_fade_rect(Rect2(0, CANVAS_H - edge_w, CANVAS_W, edge_w), edge_alpha, false)
	_draw_linear_fade_rect(Rect2(0, 0, edge_w, CANVAS_H), edge_alpha, true, true)
	_draw_linear_fade_rect(Rect2(CANVAS_W - edge_w, 0, edge_w, CANVAS_H), edge_alpha, false, true)

	var vig_alpha: float = 0.38 * blend
	var vig_center := Vector2(CANVAS_W / 2.0, CANVAS_H / 2.0)
	var inner_r: float = minf(CANVAS_W, CANVAS_H) * 0.28
	var outer_r: float = vig_center.length()
	_draw_radial_vignette(vig_center, inner_r, outer_r, vig_alpha)

func _focus_center() -> Vector2:
	if chameleon_ref:
		return Vector2(Chameleon.PIVOT_X, Chameleon.PIVOT_Y)
	return Vector2(CANVAS_W / 2.0, CANVAS_H / 2.0)

func _focus_alpha_at(t: float, max_alpha: float) -> float:
	return max_alpha * clampf(t, 0.0, 1.0)

func _draw_radial_focus(center: Vector2, inner_r: float, outer_r: float, max_alpha: float) -> void:
	var span: float = outer_r - inner_r
	if span <= 0.0:
		return
	for i in _VIGNETTE_RINGS:
		var t0: float = float(i) / _VIGNETTE_RINGS
		var t1: float = float(i + 1) / _VIGNETTE_RINGS
		var ring_alpha: float = (_focus_alpha_at(t0, max_alpha) + _focus_alpha_at(t1, max_alpha)) * 0.5
		if ring_alpha <= 0.001:
			continue
		var r0: float = inner_r + span * t0
		var r1: float = inner_r + span * t1
		_draw_vignette_ring(center, r0, r1,
			Color(_SLOW_CYAN.r, _SLOW_CYAN.g, _SLOW_CYAN.b, ring_alpha))

func _vignette_alpha_at(t: float, max_alpha: float) -> float:
	if t <= 0.6:
		return 0.0
	return max_alpha * ((t - 0.6) / 0.4)

func _draw_radial_vignette(center: Vector2, inner_r: float, outer_r: float, max_alpha: float) -> void:
	var span: float = outer_r - inner_r
	if span <= 0.0:
		return
	for i in _VIGNETTE_RINGS:
		var t0: float = float(i) / _VIGNETTE_RINGS
		var t1: float = float(i + 1) / _VIGNETTE_RINGS
		var ring_alpha: float = (_vignette_alpha_at(t0, max_alpha) + _vignette_alpha_at(t1, max_alpha)) * 0.5
		if ring_alpha <= 0.001:
			continue
		var r0: float = inner_r + span * t0
		var r1: float = inner_r + span * t1
		_draw_vignette_ring(center, r0, r1,
			Color(_SLOW_CYAN.r, _SLOW_CYAN.g, _SLOW_CYAN.b, ring_alpha))

func _draw_vignette_ring(center: Vector2, r_inner: float, r_outer: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(_VIGNETTE_SEGS + 1):
		var angle: float = float(i) * TAU / _VIGNETTE_SEGS
		points.append(center + Vector2(cos(angle), sin(angle)) * r_outer)
	for i in range(_VIGNETTE_SEGS, -1, -1):
		var angle: float = float(i) * TAU / _VIGNETTE_SEGS
		points.append(center + Vector2(cos(angle), sin(angle)) * r_inner)
	draw_colored_polygon(points, color)

func _draw_linear_fade_rect(rect: Rect2, max_alpha: float, fade_from_start: bool, horizontal: bool = false) -> void:
	var steps: int = _GRADIENT_STEPS
	if horizontal:
		var strip_w: float = rect.size.x / steps
		for i in steps:
			var t: float = (float(i) + 0.5) / steps
			if not fade_from_start:
				t = 1.0 - t
			var a: float = max_alpha * (1.0 - t)
			var x0: float = rect.position.x + float(i) * strip_w
			draw_rect(Rect2(x0, rect.position.y, strip_w + 0.5, rect.size.y),
				Color(_SLOW_CYAN.r, _SLOW_CYAN.g, _SLOW_CYAN.b, a))
	else:
		var strip_h: float = rect.size.y / steps
		for i in steps:
			var t: float = (float(i) + 0.5) / steps
			if not fade_from_start:
				t = 1.0 - t
			var a: float = max_alpha * (1.0 - t)
			var y0: float = rect.position.y + float(i) * strip_h
			draw_rect(Rect2(rect.position.x, y0, rect.size.x, strip_h + 0.5),
				Color(_SLOW_CYAN.r, _SLOW_CYAN.g, _SLOW_CYAN.b, a))

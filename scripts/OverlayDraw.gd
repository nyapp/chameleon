## OverlayDraw.gd
## JSの drawTitleScreen(), drawGameOverScreen(), drawPausedOverlay(),
## drawLowHungerWarning(), drawTargetCursor(), drawLevelUpBanner() 相当。

extends Node2D

const CANVAS_W: int = 256
const CANVAS_H: int = 240

# MainSceneから参照して書き込まれる
var level_up_banner_time: float = 0.0
var chameleon_ref: Node2D = null   # Chameleonノードへの参照（カーソル描画用）
var is_dpad_aiming: bool = false
var is_stick_aiming: bool = false

func _game_font() -> Font:
	return CabinetFonts.arcade_or_fallback()

func _draw() -> void:
	var gs: Node = GameState

	# 低体力警告（常に描画）
	if gs.state == "PLAYING" and not gs.is_frozen() and gs.energy < 30.0:
		_draw_low_hunger_warning(gs.energy)

	# ターゲットカーソル（D-Pad / スティック使用中）
	if gs.state == "PLAYING" and (is_dpad_aiming or is_stick_aiming) and chameleon_ref:
		_draw_target_cursor()

	# レベルアップバナー
	if level_up_banner_time > 0.0 and gs.state == "PLAYING":
		_draw_level_up_banner(gs.level)

	# 状態別オーバーレイ
	match gs.state:
		"TITLE":
			_draw_title_screen()
		"GAMEOVER":
			_draw_game_over_screen(gs)

func _draw_title_screen() -> void:
	var font := _game_font()
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0.020, 0.020, 0.047, 0.6))

	draw_string(font,
		Vector2(0, 70),
		"NEO CHAMELEON", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 14,
		Color(1.0, 0.0, 0.498))  # #ff007f

	draw_string(font,
		Vector2(0, 90),
		"CYBERNETIC ARCADE ACTION", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 7,
		Color(0.0, 0.941, 1.0))  # #00f0ff

	var flash: bool = int(Time.get_ticks_msec() / 400) % 2 == 0
	var flash_color: Color = Color.WHITE if flash else Color(0.306, 0.306, 0.427)
	var start_label: String = "TAP TO START" if DisplayServer.is_touchscreen_available() else "PRESS FIRE OR SPACE"
	draw_string(font,
		Vector2(0, 130),
		start_label, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 8, flash_color)
	draw_string(font,
		Vector2(0, 144),
		"TO START PLAYING", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 8, flash_color)

	draw_string(font,
		Vector2(0, 225),
		"© 2026 AXION COGNITIONS", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 5,
		Color(0.502, 0.502, 0.627))

func _draw_game_over_screen(gs: Node) -> void:
	var font := _game_font()
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0.059, 0.0, 0.039, 0.75))

	draw_string(font,
		Vector2(0, 70),
		"GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 14,
		Color(1.0, 0.231, 0.188))  # #ff3b30

	draw_string(font,
		Vector2(0, 92),
		"YOUR SCORE: %d" % gs.score, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 8,
		Color.WHITE)

	var next_y: float = BugGuideDraw.draw_result_breakdown(self, font, CANVAS_W, 104.0, gs.bugs_eaten_by_type)

	if gs.score >= gs.high_score and gs.score > 0:
		draw_string(font,
			Vector2(0, next_y + 6.0),
			"NEW HIGH SCORE!", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 8,
			Color(1.0, 0.918, 0.0))
		next_y += 14.0

	var flash: bool = int(Time.get_ticks_msec() / 400) % 2 == 0
	var fc: Color = Color(0.0, 0.941, 1.0) if flash else Color(0.306, 0.306, 0.427)
	var retry_label: String = "TAP TO RETRY" if DisplayServer.is_touchscreen_available() else "CLICK OR SPACE TO RETRY"
	draw_string(font,
		Vector2(0, maxf(next_y + 14.0, 168.0)),
		retry_label, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 8, fc)

const _LOW_HUNGER_COLOR := Color(1.0, 0.231, 0.188)  # #ff3b30
const _LOW_HUNGER_OPACITY := 0.55  # JS版より控えめ（リング近似の重なり補正）
const _GRADIENT_STEPS := 10
const _VIGNETTE_RINGS := 16
const _VIGNETTE_SEGS := 24

func _draw_low_hunger_warning(energy_val: float) -> void:
	var urgency: float = 1.0 - energy_val / 30.0
	var pulse_speed: float = 0.014 if energy_val < 15.0 else 0.008
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * pulse_speed)
	var alpha: float = (0.2 + urgency * 0.5) * pulse * _LOW_HUNGER_OPACITY
	var edge_w: float = 24.0 + urgency * 24.0
	var edge_alpha: float = alpha * 0.9

	var center := Vector2(CANVAS_W / 2.0, CANVAS_H / 2.0)
	var inner_r: float = minf(CANVAS_W, CANVAS_H) * 0.32
	var outer_r: float = center.length()
	_draw_radial_vignette(center, inner_r, outer_r, alpha)

	_draw_linear_fade_rect(Rect2(0, 0, CANVAS_W, edge_w), edge_alpha, true)
	_draw_linear_fade_rect(Rect2(0, CANVAS_H - edge_w, CANVAS_W, edge_w), edge_alpha, false)
	_draw_linear_fade_rect(Rect2(0, 0, edge_w, CANVAS_H), edge_alpha, true, true)
	_draw_linear_fade_rect(Rect2(CANVAS_W - edge_w, 0, edge_w, CANVAS_H), edge_alpha, false, true)

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
		_draw_vignette_ring(center, r0, r1, Color(_LOW_HUNGER_COLOR.r, _LOW_HUNGER_COLOR.g, _LOW_HUNGER_COLOR.b, ring_alpha))

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
				Color(_LOW_HUNGER_COLOR.r, _LOW_HUNGER_COLOR.g, _LOW_HUNGER_COLOR.b, a))
	else:
		var strip_h: float = rect.size.y / steps
		for i in steps:
			var t: float = (float(i) + 0.5) / steps
			if not fade_from_start:
				t = 1.0 - t
			var a: float = max_alpha * (1.0 - t)
			var y0: float = rect.position.y + float(i) * strip_h
			draw_rect(Rect2(rect.position.x, y0, rect.size.x, strip_h + 0.5),
				Color(_LOW_HUNGER_COLOR.r, _LOW_HUNGER_COLOR.g, _LOW_HUNGER_COLOR.b, a))

func _draw_target_cursor() -> void:
	if not chameleon_ref:
		return
	if chameleon_ref.tongue_state != "idle":
		return

	var tx: float = Chameleon.PIVOT_X + cos(chameleon_ref.angle) * chameleon_ref.tongue_max_len
	var ty: float = Chameleon.PIVOT_Y + sin(chameleon_ref.angle) * chameleon_ref.tongue_max_len
	var tip := Vector2(tx, ty)
	var pink := Color(1.0, 0.0, 0.498)

	# グロウサークル
	draw_arc(tip, 5.0, 0.0, TAU, 16, Color(pink.r, pink.g, pink.b, 0.35), 5.0)
	draw_arc(tip, 5.0, 0.0, TAU, 16, pink, 1.5)

	# 中心白点
	draw_rect(Rect2(roundi(tx) - 1, roundi(ty) - 1, 2, 2), Color.WHITE)

	# クロスヘアのティック
	draw_line(Vector2(tx, ty - 8), Vector2(tx, ty - 5), pink, 1.5)
	draw_line(Vector2(tx, ty + 5), Vector2(tx, ty + 8), pink, 1.5)
	draw_line(Vector2(tx - 8, ty), Vector2(tx - 5, ty), pink, 1.5)
	draw_line(Vector2(tx + 5, ty), Vector2(tx + 8, ty), pink, 1.5)

	# 点線エイムライン
	var pivot := Vector2(Chameleon.PIVOT_X, Chameleon.PIVOT_Y)
	var dash_color := Color(1.0, 0.0, 0.498, 0.25)
	# 簡易点線（4セグメント）
	for i in range(6):
		var t0: float = i / 6.0
		var t1: float = (i + 0.4) / 6.0
		draw_line(pivot.lerp(tip, t0), pivot.lerp(tip, t1), dash_color, 1.0)

func _draw_level_up_banner(current_level: int) -> void:
	const BANNER_HALF_H: float = 20.0
	const FONT_SIZE: int = 14
	const LINE_THICKNESS: float = 1.0
	var band_top := CANVAS_H * 0.5 - BANNER_HALF_H
	var band_h := BANNER_HALF_H * 2.0
	var inner_top := band_top + LINE_THICKNESS
	var inner_h := band_h - LINE_THICKNESS * 2.0

	draw_rect(Rect2(0, band_top, CANVAS_W, band_h), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-1, band_top, CANVAS_W + 2, LINE_THICKNESS), Color(0.0, 0.941, 1.0))
	draw_rect(Rect2(-1, band_top + band_h, CANVAS_W + 2, LINE_THICKNESS), Color(0.0, 0.941, 1.0))

	var elapsed: float = GameState.LEVEL_UP_BANNER_DURATION - level_up_banner_time
	if int(elapsed * 12.0) % 2 == 0:
		var font := _game_font()
		var text := "LEVEL UP: STAGE %d" % current_level
		var baseline_y := _centered_text_baseline(font, text, FONT_SIZE, inner_top, inner_h)
		draw_string(font,
			Vector2(0, baseline_y),
			text,
			HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, FONT_SIZE,
			Color(1.0, 0.918, 0.0))

func _centered_text_baseline(font: Font, text: String, font_size: int, area_top: float, area_h: float) -> float:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var descent := font.get_descent(font_size)
	# Press Start 2P は上側に余白が多いので、見た目の中央に寄せる微調整を入れる。
	const VISUAL_BIAS_Y: float = 3.0
	return area_top + (area_h - text_size.y) * 0.5 + text_size.y - descent + VISUAL_BIAS_Y

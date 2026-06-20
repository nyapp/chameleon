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
var confirming_high_score_reset: bool = false

const CONFIRM_PANEL_LEFT: float = 24.0
const CONFIRM_PANEL_TOP: float = 68.0
const CONFIRM_PANEL_WIDTH: float = 208.0
const CONFIRM_PANEL_HEIGHT: float = 88.0
const CONFIRM_MESSAGE_Y: float = 92.0
const CONFIRM_SUBMESSAGE_Y: float = 106.0
const CONFIRM_BUTTON_TOP: float = 118.0
const CONFIRM_BUTTON_WIDTH: float = 72.0
const CONFIRM_BUTTON_HEIGHT: float = 20.0
const CONFIRM_BUTTON_GAP: float = 16.0
const CONFIRM_PANEL_RADIUS: float = 10.0
const CONFIRM_ROW_RADIUS: float = 6.0

const COLOR_CONFIRM_PANEL_BG := Color(0.08, 0.08, 0.08, 0.92)
const COLOR_CONFIRM_PANEL_BORDER := Color(0.45, 0.45, 0.45, 0.7)
const COLOR_CONFIRM_ROW_BG := Color(0.12, 0.12, 0.12, 0.92)
const COLOR_CONFIRM_ROW_BORDER := Color(0.55, 0.55, 0.55, 0.65)
const COLOR_CONFIRM_TEXT := Color(0.75, 0.75, 0.75)

func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state: String) -> void:
	if new_state != "TITLE" and confirming_high_score_reset:
		close_high_score_reset_confirm()

func open_high_score_reset_confirm() -> void:
	if GameState.state != "TITLE" or confirming_high_score_reset:
		return
	confirming_high_score_reset = true
	queue_redraw()

func close_high_score_reset_confirm() -> void:
	if not confirming_high_score_reset:
		return
	confirming_high_score_reset = false
	queue_redraw()

func confirm_high_score_reset() -> void:
	if not confirming_high_score_reset:
		return
	GameState.reset_high_score()
	close_high_score_reset_confirm()

func handle_high_score_reset_confirm_tap(local_pos: Vector2) -> bool:
	if not confirming_high_score_reset:
		return false
	if _high_score_reset_yes_rect().has_point(local_pos):
		confirm_high_score_reset()
		return true
	if _high_score_reset_no_rect().has_point(local_pos):
		close_high_score_reset_confirm()
		return true
	return true

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

	if Time.get_ticks_msec() < GameState.high_score_reset_notice_until_msec:
		draw_string(font,
			Vector2(0, 158),
			"HI-SCORE RESET", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 7,
			Color(0.0, 0.941, 1.0))

	draw_string(font,
		Vector2(0, 225),
		"© 2026 AXION COGNITIONS", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 5,
		Color(0.502, 0.502, 0.627))

	if confirming_high_score_reset:
		_draw_high_score_reset_confirm(font)

func _high_score_reset_yes_rect() -> Rect2:
	var total_w := CONFIRM_BUTTON_WIDTH * 2.0 + CONFIRM_BUTTON_GAP
	var left := (float(CANVAS_W) - total_w) * 0.5
	return Rect2(left, CONFIRM_BUTTON_TOP, CONFIRM_BUTTON_WIDTH, CONFIRM_BUTTON_HEIGHT)

func _high_score_reset_no_rect() -> Rect2:
	var yes := _high_score_reset_yes_rect()
	return Rect2(
		yes.position.x + CONFIRM_BUTTON_WIDTH + CONFIRM_BUTTON_GAP,
		yes.position.y,
		CONFIRM_BUTTON_WIDTH,
		CONFIRM_BUTTON_HEIGHT
	)

func _draw_high_score_reset_confirm(font: Font) -> void:
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0, 0, 0, 0.35))

	var panel := Rect2(CONFIRM_PANEL_LEFT, CONFIRM_PANEL_TOP, CONFIRM_PANEL_WIDTH, CONFIRM_PANEL_HEIGHT)
	_draw_rounded_rect(panel, COLOR_CONFIRM_PANEL_BG, CONFIRM_PANEL_RADIUS, true)
	_draw_rounded_rect(panel, COLOR_CONFIRM_PANEL_BORDER, CONFIRM_PANEL_RADIUS, false, 2.5)

	draw_string(font,
		Vector2(0, CONFIRM_MESSAGE_Y),
		"RESET HI-SCORE?", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 7,
		COLOR_CONFIRM_TEXT)
	draw_string(font,
		Vector2(0, CONFIRM_SUBMESSAGE_Y),
		"ARE YOU SURE?", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 7,
		COLOR_CONFIRM_TEXT)

	_draw_confirm_action_button(font, _high_score_reset_yes_rect(), "YES")
	_draw_confirm_action_button(font, _high_score_reset_no_rect(), "NO")

func _draw_confirm_action_button(font: Font, rect: Rect2, label: String) -> void:
	_draw_rounded_rect(rect, COLOR_CONFIRM_ROW_BG, CONFIRM_ROW_RADIUS, true)
	_draw_rounded_rect(rect, COLOR_CONFIRM_ROW_BORDER, CONFIRM_ROW_RADIUS, false, 1.0)
	draw_string(font,
		Vector2(rect.position.x, rect.position.y + rect.size.y - 5.0),
		label, HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), 7,
		COLOR_CONFIRM_TEXT)

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

func _draw_game_over_screen(gs: Node) -> void:
	var font := _game_font()
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0.059, 0.0, 0.039, 0.75))

	draw_string(font,
		Vector2(0, 66),
		"GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 14,
		Color(1.0, 0.231, 0.188))  # #ff3b30

	var breakdown_bottom: float = BugGuideDraw.draw_result_breakdown(
		self, font, CANVAS_W, 84.0, gs.bugs_eaten_by_type)

	const SCORE_LABEL_SIZE: int = 7
	const SCORE_VALUE_SIZE: int = 14
	const NEW_HIGHSCORE_SIZE: int = 8
	const ACTION_SIZE: int = 8
	const SCORE_VALUE_COLOR := Color(1.0, 0.918, 0.0)
	const SCORE_SECTION_GAP: float = 8.0
	const SCORE_LABEL_VALUE_GAP: float = 18.0
	const NEW_HIGHSCORE_GAP: float = 10.0
	const SCORE_ACTION_GAP: float = 14.0
	const ACTION_MIN_Y: float = 228.0

	var score_label_y: float = breakdown_bottom + SCORE_SECTION_GAP
	var score_value_y: float = score_label_y + SCORE_LABEL_VALUE_GAP
	var score_str := "%d" % gs.score

	draw_string(font,
		Vector2(0, score_label_y),
		"YOUR SCORE", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, SCORE_LABEL_SIZE,
		Color(0.82, 0.82, 0.82))

	draw_string(font,
		Vector2(0, score_value_y),
		score_str, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, SCORE_VALUE_SIZE,
		SCORE_VALUE_COLOR)

	var content_bottom: float = score_value_y + font.get_descent(SCORE_VALUE_SIZE)

	if gs.score >= gs.high_score and gs.score > 0:
		var hs_baseline: float = content_bottom + NEW_HIGHSCORE_GAP + font.get_ascent(NEW_HIGHSCORE_SIZE)
		_draw_rainbow_glow_text(font,
			Vector2(0, hs_baseline),
			"NEW HIGH SCORE!",
			HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, NEW_HIGHSCORE_SIZE)
		content_bottom = hs_baseline + font.get_descent(NEW_HIGHSCORE_SIZE)

	var flash: bool = int(Time.get_ticks_msec() / 400) % 2 == 0
	var fc: Color = Color(0.0, 0.941, 1.0) if flash else Color(0.306, 0.306, 0.427)
	var action_label: String = "TAP TO TITLE" if DisplayServer.is_touchscreen_available() else "CLICK OR SPACE TO TITLE"
	var action_baseline: float = maxf(content_bottom + SCORE_ACTION_GAP + font.get_ascent(ACTION_SIZE), ACTION_MIN_Y)
	draw_string(font,
		Vector2(0, action_baseline),
		action_label, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, ACTION_SIZE, fc)

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

func _rainbow_hue(time_sec: float, offset: float = 0.0) -> float:
	return fmod(time_sec * 0.42 + offset, 1.0)

func _draw_rainbow_glow_text(
	font: Font,
	pos: Vector2,
	text: String,
	h_align: HorizontalAlignment,
	width: int,
	font_size: int
) -> void:
	var time_sec := Time.get_ticks_msec() * 0.001
	var pulse := 0.68 + 0.32 * sin(time_sec * 5.0)
	const GLOW_SPREADS := [4.0, 2.5, 1.0]

	for i in GLOW_SPREADS.size():
		var spread: float = GLOW_SPREADS[i]
		var glow_alpha: float = pulse * (0.24 - float(i) * 0.06)
		var glow_col := Color.from_hsv(_rainbow_hue(time_sec, float(i) * 0.14), 0.88, 1.0, glow_alpha)
		for ox in [-spread, spread]:
			draw_string(font, pos + Vector2(ox, 0.0), text, h_align, width, font_size, glow_col)
			draw_string(font, pos + Vector2(ox * 0.5, spread * 0.35), text, h_align, width, font_size, glow_col)
		draw_string(font, pos + Vector2(0.0, -spread * 0.25), text, h_align, width, font_size, glow_col)

	_draw_rainbow_text_per_char(font, pos, text, width, font_size, time_sec)

func _draw_rainbow_text_per_char(
	font: Font,
	pos: Vector2,
	text: String,
	width: int,
	font_size: int,
	time_sec: float
) -> void:
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := (float(width) - text_w) * 0.5
	for i in text.length():
		var ch := text.substr(i, 1)
		var col := Color.from_hsv(_rainbow_hue(time_sec, float(i) * 0.07), 0.95, 1.0)
		draw_string(font, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

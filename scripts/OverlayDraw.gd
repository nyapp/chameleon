## OverlayDraw.gd
## JSの drawTitleScreen(), drawGameOverScreen(), drawPausedOverlay(),
## drawLowHungerWarning(), drawTargetCursor(), drawLevelUpBanner() 相当。

extends Node2D

const CANVAS_W: int = 256
const CANVAS_H: int = 240

# MainSceneから参照して書き込まれる
var level_up_banner_frames: int = 0
var chameleon_ref: Node2D = null   # Chameleonノードへの参照（カーソル描画用）
var is_dpad_aiming: bool = false
var is_stick_aiming: bool = false

func _draw() -> void:
	var gs: Node = GameState

	# 低体力警告（常に描画）
	if gs.state == "PLAYING" and not gs.is_frozen() and gs.energy < 30.0:
		_draw_low_hunger_warning(gs.energy)

	# ターゲットカーソル（D-Pad / スティック使用中）
	if gs.state == "PLAYING" and (is_dpad_aiming or is_stick_aiming) and chameleon_ref:
		_draw_target_cursor()

	# レベルアップバナー
	if level_up_banner_frames > 0 and gs.state == "PLAYING":
		_draw_level_up_banner(gs.level)

	# 状態別オーバーレイ
	match gs.state:
		"TITLE":
			_draw_title_screen()
		"GAMEOVER":
			_draw_game_over_screen(gs)
		"PAUSED":
			_draw_paused_overlay()

func _draw_paused_overlay() -> void:
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0, 0, 0, 0.45))
	draw_string(ThemeDB.fallback_font,
		Vector2(0, CANVAS_H / 2.0),
		"PAUSED", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 10,
		Color(0.0, 0.941, 1.0))  # #00f0ff

func _draw_title_screen() -> void:
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0.020, 0.020, 0.047, 0.6))

	# タイトル大文字
	draw_string(ThemeDB.fallback_font,
		Vector2(0, 70),
		"NEO CHAMELEON", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 14,
		Color(1.0, 0.0, 0.498))  # #ff007f

	draw_string(ThemeDB.fallback_font,
		Vector2(0, 90),
		"CYBERNETIC ARCADE ACTION", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 7,
		Color(0.0, 0.941, 1.0))  # #00f0ff

	# 点滅テキスト
	var flash: bool = int(Time.get_ticks_msec() / 400) % 2 == 0
	var flash_color: Color = Color.WHITE if flash else Color(0.306, 0.306, 0.427)
	var start_label: String = "TAP TO START" if DisplayServer.is_touchscreen_available() else "PRESS FIRE OR SPACE"
	draw_string(ThemeDB.fallback_font,
		Vector2(0, 130),
		start_label, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 8, flash_color)
	draw_string(ThemeDB.fallback_font,
		Vector2(0, 144),
		"TO START PLAYING", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 8, flash_color)

	# コピーライト
	draw_string(ThemeDB.fallback_font,
		Vector2(0, 225),
		"(C) 2026 AXION COGNITIONS", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 5,
		Color(0.502, 0.502, 0.627))

func _draw_game_over_screen(gs: Node) -> void:
	draw_rect(Rect2(0, 0, CANVAS_W, CANVAS_H), Color(0.059, 0.0, 0.039, 0.75))

	draw_string(ThemeDB.fallback_font,
		Vector2(0, 85),
		"GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 14,
		Color(1.0, 0.231, 0.188))  # #ff3b30

	draw_string(ThemeDB.fallback_font,
		Vector2(0, 115),
		"YOUR SCORE: %d" % gs.score, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 8,
		Color.WHITE)

	draw_string(ThemeDB.fallback_font,
		Vector2(0, 130),
		"FLIES CAUGHT: %d" % gs.flies_eaten, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 8,
		Color(0.224, 1.0, 0.078))  # #39ff14

	if gs.score >= gs.high_score and gs.score > 0:
		draw_string(ThemeDB.fallback_font,
			Vector2(0, 148),
			"NEW HIGH SCORE!", HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 8,
			Color(1.0, 0.918, 0.0))

	var flash: bool = int(Time.get_ticks_msec() / 400) % 2 == 0
	var fc: Color = Color(0.0, 0.941, 1.0) if flash else Color(0.306, 0.306, 0.427)
	var retry_label: String = "TAP TO RETRY" if DisplayServer.is_touchscreen_available() else "CLICK OR SPACE TO RETRY"
	draw_string(ThemeDB.fallback_font,
		Vector2(0, 168),
		retry_label, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 8, fc)

func _draw_low_hunger_warning(energy_val: float) -> void:
	var urgency: float = 1.0 - energy_val / 30.0
	var pulse_speed: float = 0.014 if energy_val < 15.0 else 0.008
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * pulse_speed)
	var alpha: float = (0.2 + urgency * 0.5) * pulse
	var edge_w: float = 24.0 + urgency * 24.0
	var danger := Color(1.0, 0.231, 0.188, alpha * 0.9)

	# 4辺のグラデーション風エッジ（単色で近似）
	draw_rect(Rect2(0, 0, CANVAS_W, edge_w), Color(danger.r, danger.g, danger.b, danger.a * 0.6))
	draw_rect(Rect2(0, CANVAS_H - edge_w, CANVAS_W, edge_w), Color(danger.r, danger.g, danger.b, danger.a * 0.6))
	draw_rect(Rect2(0, 0, edge_w, CANVAS_H), Color(danger.r, danger.g, danger.b, danger.a * 0.4))
	draw_rect(Rect2(CANVAS_W - edge_w, 0, edge_w, CANVAS_H), Color(danger.r, danger.g, danger.b, danger.a * 0.4))

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
	draw_rect(Rect2(0, CANVAS_H / 2.0 - 15, CANVAS_W, 30), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-1, CANVAS_H / 2.0 - 15, CANVAS_W + 2, 1),
		Color(0.0, 0.941, 1.0))
	draw_rect(Rect2(-1, CANVAS_H / 2.0 + 15, CANVAS_W + 2, 1),
		Color(0.0, 0.941, 1.0))

	if int(level_up_banner_frames / 5) % 2 == 0:
		draw_string(ThemeDB.fallback_font,
			Vector2(0, CANVAS_H / 2.0 + 3),
			"LEVEL UP: STAGE %d" % current_level,
			HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 10,
			Color(1.0, 0.918, 0.0))

## HUDDraw.gd
## JSの drawHUD() 相当。ゲーム中のスコア・レベル・コンボ・空腹バー等を描画。

extends Node2D

const CANVAS_W: int = 256
const CANVAS_H: int = 240

# フォント（Press Start 2P相当はGodotのPixel系フォントを使用）
# プロジェクトにフォントリソースが必要。デフォルトフォントで代替する。

func _draw() -> void:
	var gs: Node = GameState  # Autoload参照

	if gs.state not in ["PLAYING", "PAUSED"]:
		_draw_score_bar(gs)
		return

	_draw_score_bar(gs)
	_draw_level(gs)
	_draw_combo(gs)
	_draw_power_up_label(gs)
	_draw_hunger_bar(gs)

func _game_font() -> Font:
	return CabinetFonts.arcade_or_fallback()

func _draw_score_bar(gs: Node) -> void:
	var font := _game_font()
	# スコア表示（左上）
	var score_str: String = "SCORE:%s" % str(gs.score).lpad(6, "0")
	draw_string(font, Vector2(8, 12), score_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)

	# ハイスコア表示（右寄り）
	var hi_str: String = "HI-SCORE:%s" % str(gs.high_score).lpad(6, "0")
	draw_string(font, Vector2(138, 12), hi_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)

func _draw_level(gs: Node) -> void:
	var font := _game_font()
	const FONT_SIZE: int = 7
	const LEVEL_Y: float = 23.0
	var level_text: String = "LEVEL %d" % gs.level
	draw_string(font, Vector2(1, LEVEL_Y + 1.0), level_text,
		HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, FONT_SIZE, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(0, LEVEL_Y), level_text,
		HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, FONT_SIZE, Color(1.0, 0.918, 0.0))
	_draw_level_progress_dots(gs, font, FONT_SIZE, level_text, LEVEL_Y)

func _draw_level_progress_dots(gs: Node, font: Font, font_size: int, level_text: String, level_y: float) -> void:
	const DOT_RADIUS: float = 2.0
	const DOT_EMPTY: Color = Color(0.118, 0.118, 0.176)
	const DOT_BORDER: Color = Color(0.231, 0.243, 0.302)
	const DOT_FILL: Color = Color(1.0, 0.0, 0.498)
	const DOT_GLOW: Color = Color(0.616, 0.0, 1.0, 0.5)

	var text_size: Vector2 = font.get_string_size(level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var row_left: float = (float(CANVAS_W) - text_size.x) * 0.5
	var row_w: float = text_size.x
	var filled_count: int = gs.flies_eaten % GameState.FLIES_PER_LEVEL
	var total: int = GameState.FLIES_PER_LEVEL
	var diameter: float = DOT_RADIUS * 2.0
	var step: float = (row_w - diameter) / float(total - 1) if total > 1 else 0.0
	var start_x: float = row_left + DOT_RADIUS
	var center_y: float = level_y + 6.0

	for i in total:
		var center := Vector2(start_x + float(i) * step, center_y)
		var filled := i < filled_count
		if filled:
			draw_circle(center, DOT_RADIUS + 0.5, DOT_GLOW)
			draw_circle(center, DOT_RADIUS, DOT_FILL)
		else:
			draw_circle(center, DOT_RADIUS, DOT_EMPTY)
			draw_arc(center, DOT_RADIUS - 0.5, 0.0, TAU, 12, DOT_BORDER, 1.0)

func _draw_combo(gs: Node) -> void:
	if gs.combo <= 1:
		return
	var blink: bool = int(gs.combo_timer * 5.0) % 2 == 0
	var color: Color = Color(1.0, 0.918, 0.0) if blink else Color.WHITE
	draw_string(_game_font(), Vector2(160, 22),
		"COMBO x%d" % gs.combo,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)

func _draw_power_up_label(gs: Node) -> void:
	if gs.power_up_type == "":
		return
	const FONT_SIZE: int = 10
	const BASELINE_Y: float = CANVAS_H - 28.0
	var secs_left: int = ceili(gs.power_up_time_left)
	var text: String
	var color: Color
	match gs.power_up_type:
		"gold":
			text = "GOLD TONGUE: %ds" % secs_left
			color = Color(1.0, 0.918, 0.0)
		"multi":
			text = "TRIPLE TONGUE: %ds" % secs_left
			color = Color(1.0, 0.0, 0.498)
		"slow":
			text = "SLOW-MO: %ds" % secs_left
			color = Color(0.706, 0.706, 0.706)  # #b4b4b4
		_:
			return
	draw_string(_game_font(), Vector2(0, BASELINE_Y),
		text, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, FONT_SIZE, color)

func _draw_hunger_bar(gs: Node) -> void:
	const STRIP_H: int = 18
	const BAR_X: int = 8
	const BAR_H: int = 7
	const INNER_PAD: int = 2
	var bar_w: int = CANVAS_W - 16
	var bar_y: float = CANVAS_H - 9

	# 背景帯
	draw_rect(Rect2(0, CANVAS_H - STRIP_H, CANVAS_W, STRIP_H),
		Color(0.020, 0.020, 0.047, 0.75))

	# "HUNGER" ラベル
	draw_string(_game_font(), Vector2(BAR_X, CANVAS_H - 12),
		"HUNGER", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.0, 0.941, 1.0))

	# バー枠
	draw_rect(Rect2(BAR_X, bar_y, bar_w, BAR_H), Color(0.176, 0.176, 0.267), false)

	# バー塗り
	var fill_color: Color = Color(0.224, 1.0, 0.078)  # #39ff14
	var is_low: bool = gs.energy < 30.0
	if is_low and not gs.is_frozen():
		var pulse: bool = sin(Time.get_ticks_msec() * 0.012) > 0.0
		fill_color = Color(1.0, 0.231, 0.188) if pulse else Color(1.0, 0.420, 0.376)
	elif is_low:
		fill_color = Color(1.0, 0.231, 0.188)
	elif gs.energy < 60.0:
		fill_color = Color(1.0, 0.918, 0.0)

	var fill_max_w: float = bar_w - INNER_PAD * 2
	var fill_w: float = round((gs.energy / 100.0) * fill_max_w)
	draw_rect(Rect2(BAR_X + INNER_PAD, bar_y + INNER_PAD, fill_w, BAR_H - INNER_PAD * 2), fill_color)

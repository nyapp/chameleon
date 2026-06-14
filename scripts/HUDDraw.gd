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
	_draw_level_up_banner(gs)

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
	var level_text: String = "LEVEL %d" % gs.level
	draw_string(font, Vector2(1, 24), level_text,
		HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 7, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(0, 23), level_text,
		HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 7, Color(1.0, 0.918, 0.0))

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
			color = Color(0.0, 0.941, 1.0)
		_:
			return
	draw_string(_game_font(), Vector2(0, CANVAS_H - 22),
		text, HORIZONTAL_ALIGNMENT_CENTER, CANVAS_W, 6, color)

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

func _draw_level_up_banner(gs: Node) -> void:
	# MainSceneが管理するlevel_up_banner_framesを参照
	var frames: int = get_parent().get_parent().level_up_banner_frames if get_parent().get_parent().has_method("get") else 0
	# シンプルにGameStateのlevelを使って確認
	# level_up_banner_framesはMainScene.gdで管理
	pass  # MainScene側でOverlayDrawに渡す

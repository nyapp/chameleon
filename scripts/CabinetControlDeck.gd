## CabinetControlDeck.gd
## Game Boy 風コントロールパネル背景（GAME CHAMELEON ヘッダー、スピーカーグリル）

extends Control

const PANEL_BG_TOP := Color(0.094, 0.094, 0.141)    # #181824
const PANEL_BG_BOT := Color(0.063, 0.063, 0.102)    # #10101a
const PANEL_BORDER := Color(0.145, 0.145, 0.22)     # #252538
const LOGO_COLOR := Color(0.478, 0.51, 0.588)       # #7a8296
const LINE_COLOR := Color(0.231, 0.243, 0.302)      # #3b3e4d

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)

	# グラデーション背景
	var steps := 8
	for i in steps:
		var t := float(i) / float(steps - 1)
		var col := PANEL_BG_TOP.lerp(PANEL_BG_BOT, t)
		var strip_h := size.y / float(steps)
		draw_rect(Rect2(0, i * strip_h, size.x, strip_h + 1.0), col)

	draw_line(Vector2(0, 1), Vector2(size.x, 1), Color(0.176, 0.176, 0.267), 2.0)
	draw_rect(r, PANEL_BORDER, false, 3.0)

	# GAME CHAMELEON ロゴ + ライン
	var font: Font = ThemeDB.fallback_font
	var logo := "GAME CHAMELEON"
	var logo_size := 8
	var logo_w := font.get_string_size(logo, HORIZONTAL_ALIGNMENT_LEFT, -1, logo_size).x
	var logo_x := 8.0
	var logo_y := 10.0
	draw_string(font, Vector2(logo_x, logo_y + logo_size), logo, HORIZONTAL_ALIGNMENT_LEFT, -1, logo_size, LOGO_COLOR)

	var line_x := logo_x + logo_w + 6.0
	var line_w := size.x - line_x - 8.0
	draw_rect(Rect2(line_x, logo_y + 2.0, line_w, 2.0), LINE_COLOR)
	draw_rect(Rect2(line_x, logo_y + 7.0, line_w * 0.85, 2.0), LINE_COLOR)

	# 右下スピーカーグリル
	var grill_origin := Vector2(size.x - 28.0, size.y - 18.0)
	for i in 4:
		var offset := i * 5.0
		draw_line(
			grill_origin + Vector2(offset, 0),
			grill_origin + Vector2(offset + 8.0, 8.0),
			Color(0.08, 0.08, 0.12, 0.6),
			1.5
		)

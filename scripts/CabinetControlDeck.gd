## CabinetControlDeck.gd
## Game Boy 風コントロールパネル背景（GAME CHAMELEON ヘッダー、スピーカーグリル）

@tool
extends Control

@export_group("Logo")
@export var logo_text: String = "GAME CHAMELEON":
	set(value):
		logo_text = value
		queue_redraw()
@export var logo_font_size: int = 8:
	set(value):
		logo_font_size = value
		queue_redraw()
@export var logo_x: float = 8.0:
	set(value):
		logo_x = value
		queue_redraw()
@export var logo_y: float = 10.0:
	set(value):
		logo_y = value
		queue_redraw()
@export var line_gap_after_logo: float = 6.0:
	set(value):
		line_gap_after_logo = value
		queue_redraw()
@export var line_margin_right: float = 8.0:
	set(value):
		line_margin_right = value
		queue_redraw()
@export var line_width_ratio: float = 0.85:
	set(value):
		line_width_ratio = value
		queue_redraw()

@export_group("Speaker Grill")
@export var grill_offset_x: float = 28.0:
	set(value):
		grill_offset_x = value
		queue_redraw()
@export var grill_offset_y: float = 18.0:
	set(value):
		grill_offset_y = value
		queue_redraw()
@export var grill_line_count: int = 4:
	set(value):
		grill_line_count = maxi(value, 0)
		queue_redraw()
@export var grill_spacing: float = 5.0:
	set(value):
		grill_spacing = value
		queue_redraw()
@export var grill_line_length: float = 8.0:
	set(value):
		grill_line_length = value
		queue_redraw()
@export var grill_line_width: float = 1.5:
	set(value):
		grill_line_width = value
		queue_redraw()

@export_group("Colors")
@export var panel_bg_top: Color = Color(0.094, 0.094, 0.141): # #181824
	set(value):
		panel_bg_top = value
		queue_redraw()
@export var panel_bg_bot: Color = Color(0.063, 0.063, 0.102): # #10101a
	set(value):
		panel_bg_bot = value
		queue_redraw()
@export var panel_border: Color = Color(0.145, 0.145, 0.22): # #252538
	set(value):
		panel_border = value
		queue_redraw()
@export var panel_border_width: float = 3.0:
	set(value):
		panel_border_width = value
		queue_redraw()
@export var top_accent_color: Color = Color(0.176, 0.176, 0.267):
	set(value):
		top_accent_color = value
		queue_redraw()
@export var logo_color: Color = Color(0.478, 0.51, 0.588): # #7a8296
	set(value):
		logo_color = value
		queue_redraw()
@export var line_color: Color = Color(0.231, 0.243, 0.302): # #3b3e4d
	set(value):
		line_color = value
		queue_redraw()
@export var grill_color: Color = Color(0.08, 0.08, 0.12, 0.6):
	set(value):
		grill_color = value
		queue_redraw()

@export var gradient_steps: int = 8:
	set(value):
		gradient_steps = maxi(value, 2)
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)

	for i in gradient_steps:
		var t := float(i) / float(gradient_steps - 1)
		var col := panel_bg_top.lerp(panel_bg_bot, t)
		var strip_h := size.y / float(gradient_steps)
		draw_rect(Rect2(0, i * strip_h, size.x, strip_h + 1.0), col)

	draw_line(Vector2(0, 1), Vector2(size.x, 1), top_accent_color, 2.0)
	draw_rect(r, panel_border, false, panel_border_width)

	var font: Font = ThemeDB.fallback_font
	var logo_w := font.get_string_size(logo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, logo_font_size).x
	draw_string(font, Vector2(logo_x, logo_y + logo_font_size), logo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, logo_font_size, logo_color)

	var line_x := logo_x + logo_w + line_gap_after_logo
	var line_w := size.x - line_x - line_margin_right
	draw_rect(Rect2(line_x, logo_y + 2.0, line_w, 2.0), line_color)
	draw_rect(Rect2(line_x, logo_y + 7.0, line_w * line_width_ratio, 2.0), line_color)

	var grill_origin := Vector2(size.x - grill_offset_x, size.y - grill_offset_y)
	for i in grill_line_count:
		var offset := i * grill_spacing
		draw_line(
			grill_origin + Vector2(offset, 0),
			grill_origin + Vector2(offset + grill_line_length, grill_line_length),
			grill_color,
			grill_line_width
		)

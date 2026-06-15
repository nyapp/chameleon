## CabinetControlDeck.gd
## コントロールパネル背景（.gameboy-panel / .gb-header 相当）。コントローラー本体は別ノード。

@tool
extends Control

const CabinetFontsScript := preload("res://scripts/CabinetFonts.gd")

@export_group("Logo")
@export var logo_text: String = "　CONTROLLER":
	set(value):
		logo_text = value
		queue_redraw()
@export var logo_font_size: int = 10:
	set(value):
		logo_font_size = value
		queue_redraw()
@export var logo_x: float = 4.0:
	set(value):
		logo_x = value
		queue_redraw()
@export var logo_y: float = 8.0:
	set(value):
		logo_y = value
		queue_redraw()
@export var line_gap_after_logo: float = 10.0:
	set(value):
		line_gap_after_logo = value
		queue_redraw()
@export var line_margin_right: float = 4.0:
	set(value):
		line_margin_right = value
		queue_redraw()

@export_group("Pause Button")
@export var pause_btn_size: Vector2 = Vector2(52.0, 20.0):
	set(value):
		pause_btn_size = value
		queue_redraw()
@export var pause_btn_margin_right: float = 12.0:
	set(value):
		pause_btn_margin_right = value
		queue_redraw()
@export var pause_btn_line_gap: float = 8.0:
	set(value):
		pause_btn_line_gap = value
		queue_redraw()

var _layout_pause_btn_size: Vector2 = Vector2(52.0, 20.0)

@export_group("Shape")
@export var bottom_radius: float = 14.0:
	set(value):
		bottom_radius = value
		queue_redraw()
@export var panel_border_width: float = 4.0:
	set(value):
		panel_border_width = value
		queue_redraw()
@export var top_accent_height: float = 2.0:
	set(value):
		top_accent_height = value
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
@export var top_accent_color: Color = Color(0.176, 0.176, 0.267): # #2d2d44
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
@export var inset_shadow_alpha: float = 0.5:
	set(value):
		inset_shadow_alpha = value
		queue_redraw()

@export var gradient_steps: int = 10:
	set(value):
		gradient_steps = maxi(value, 2)
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	queue_redraw()

func _font_mono() -> Font:
	return CabinetFontsScript.get_mono_font()

func sync_pause_button_size(button_size: Vector2) -> void:
	_layout_pause_btn_size = button_size
	queue_redraw()

func get_pause_button_rect(button_size: Vector2) -> Rect2:
	var btn_size := button_size if button_size != Vector2.ZERO else _layout_pause_btn_size
	var x := size.x - btn_size.x - pause_btn_margin_right
	# 装飾ライン（logo_y+2 / logo_y+6）の中央にボタンを揃える
	var row_center_y := logo_y + 5.0
	var y := row_center_y - btn_size.y * 0.5
	y = clampf(
		y,
		top_accent_height + 2.0,
		float(GameLayout.CONTROL_DECK_HEADER_H) - btn_size.y
	)
	return Rect2(x, y, btn_size.x, btn_size.y)

func get_header_right_reserve(button_size: Vector2) -> float:
	var btn_size := button_size if button_size != Vector2.ZERO else _layout_pause_btn_size
	return pause_btn_margin_right + btn_size.x + pause_btn_line_gap

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	_draw_panel_background(r)
	_draw_panel_border(r)

	draw_rect(Rect2(0.0, 0.0, size.x, top_accent_height), top_accent_color)
	draw_rect(Rect2(4.0, 4.0, size.x - 8.0, 10.0), Color(0.0, 0.0, 0.0, inset_shadow_alpha))

	var font := _font_mono()
	var logo_w := font.get_string_size(logo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, logo_font_size).x
	var logo_pos := Vector2(logo_x, logo_y + logo_font_size)
	draw_string(font, logo_pos + Vector2(1.0, 1.0), logo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, logo_font_size, Color(0.0, 0.0, 0.0, 0.85))
	draw_string(font, logo_pos, logo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, logo_font_size, logo_color)

	var line_x := logo_x + logo_w + line_gap_after_logo
	var reserve := maxf(line_margin_right, get_header_right_reserve(_layout_pause_btn_size))
	var line_w := maxf(0.0, size.x - line_x - reserve)
	var line_y := logo_y + 2.0
	draw_rect(Rect2(line_x, line_y, line_w, 2.0), line_color)
	draw_rect(Rect2(line_x, line_y + 4.0, line_w, 2.0), line_color)

	var grill_origin := Vector2(size.x - grill_offset_x, size.y - grill_offset_y)
	for i in grill_line_count:
		var offset := i * grill_spacing
		draw_line(
			grill_origin + Vector2(offset, 0),
			grill_origin + Vector2(offset + grill_line_length, grill_line_length),
			grill_color,
			grill_line_width
		)

func _draw_panel_background(r: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = panel_bg_top.lerp(panel_bg_bot, 0.45)
	style.corner_radius_bottom_left = int(bottom_radius)
	style.corner_radius_bottom_right = int(bottom_radius)
	style.draw(get_canvas_item(), r)

func _draw_panel_border(r: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = panel_border
	style.border_width_left = int(panel_border_width)
	style.border_width_right = int(panel_border_width)
	style.border_width_bottom = int(panel_border_width)
	style.border_width_top = 0
	style.corner_radius_bottom_left = int(bottom_radius)
	style.corner_radius_bottom_right = int(bottom_radius)
	style.draw(get_canvas_item(), r)

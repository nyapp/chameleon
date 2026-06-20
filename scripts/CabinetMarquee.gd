## CabinetMarquee.gd
## マーキー「NEO CHAMELEON」「8-BIT RETRO SYNTH」

@tool
extends Control

@export_group("Text")
@export var title_text: String = "NEO CHAMELEON":
	set(value):
		title_text = value
		queue_redraw()
@export var subtitle_text: String = "8-BIT RETRO SYNTH":
	set(value):
		subtitle_text = value
		queue_redraw()
@export var title_font_size: int = 18:
	set(value):
		title_font_size = value
		queue_redraw()
@export var subtitle_font_size: int = 6:
	set(value):
		subtitle_font_size = value
		queue_redraw()
@export var subtitle_letter_spacing: float = 4.0:
	set(value):
		subtitle_letter_spacing = value
		queue_redraw()
@export var text_padding_v: float = 16.0:
	set(value):
		text_padding_v = maxf(value, 0.0)
		queue_redraw()
@export var title_subtitle_gap: float = 18.0:
	set(value):
		title_subtitle_gap = maxf(value, 0.0)
		queue_redraw()

@export_group("Shape")
@export var corner_radius: float = 8.0:
	set(value):
		corner_radius = value
		queue_redraw()
@export var border_width: float = 3.0:
	set(value):
		border_width = value
		queue_redraw()
@export var inner_glow_inset: float = 3.0:
	set(value):
		inner_glow_inset = value
		queue_redraw()

@export_group("Animation")
@export var pulse_speed: float = 2.0:
	set(value):
		pulse_speed = value
@export var sweep_speed: float = 8.0:
	set(value):
		sweep_speed = value
@export var glow_alpha_min: float = 0.45:
	set(value):
		glow_alpha_min = value
		queue_redraw()
@export var glow_alpha_range: float = 0.55:
	set(value):
		glow_alpha_range = value
		queue_redraw()

@export_group("Colors")
@export var bg_color: Color = Color(0.031, 0.031, 0.059): # #08080f
	set(value):
		bg_color = value
		queue_redraw()
@export var border_color: Color = Color(0.102, 0.102, 0.18): # #1a1a2e
	set(value):
		border_color = value
		queue_redraw()
@export var inner_glow_alpha: float = 0.1:
	set(value):
		inner_glow_alpha = value
		queue_redraw()
@export var neon_pink: Color = Color(1.0, 0.0, 0.498):
	set(value):
		neon_pink = value
		queue_redraw()
@export var neon_purple: Color = Color(0.616, 0.0, 1.0):
	set(value):
		neon_purple = value
		queue_redraw()
@export var neon_cyan: Color = Color(0.0, 0.941, 1.0):
	set(value):
		neon_cyan = value
		queue_redraw()
@export var sweep_alpha: float = 0.05:
	set(value):
		sweep_alpha = value
		queue_redraw()

const CabinetFontsScript := preload("res://scripts/CabinetFonts.gd")

var _pulse: float = 0.0
var _sweep: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	queue_redraw()

func _process(delta: float) -> void:
	var needs_redraw := false
	if pulse_speed > 0.0:
		_pulse += delta * pulse_speed
		needs_redraw = true
	if sweep_speed > 0.0:
		_sweep = fmod(_sweep + delta / sweep_speed, 1.0)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()

func _font_arcade() -> Font:
	return CabinetFontsScript.get_arcade_font()

func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	_draw_rounded_rect(panel, bg_color, corner_radius, true)
	_draw_rounded_rect(panel, border_color, corner_radius, false, border_width)

	var inner := panel.grow(-inner_glow_inset)
	_draw_rounded_rect(inner, Color(neon_cyan.r, neon_cyan.g, neon_cyan.b, inner_glow_alpha), corner_radius - 1.0, false, 1.0)

	_draw_sweep(panel)

	var font := _font_arcade()
	var pulse := 0.5 + 0.5 * sin(_pulse)
	var glow_alpha := glow_alpha_min + pulse * glow_alpha_range

	var baselines := _text_baselines(font)
	var title_w := font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size).x
	var title_pos := Vector2((size.x - title_w) * 0.5, baselines.x)
	_draw_neon_title(font, title_text, title_pos, title_font_size, glow_alpha)

	var sub_w := _spaced_text_width(font, subtitle_text, subtitle_font_size, subtitle_letter_spacing)
	var sub_pos := Vector2((size.x - sub_w) * 0.5, baselines.y)
	_draw_spaced_neon_text(font, subtitle_text, sub_pos, subtitle_font_size, subtitle_letter_spacing, neon_cyan, 0.9)

func _text_baselines(font: Font) -> Vector2:
	var title_ascent := font.get_ascent(title_font_size)
	var sub_descent := font.get_descent(subtitle_font_size)
	var block_h := title_ascent + title_subtitle_gap + sub_descent
	var block_top := text_padding_v
	if size.y >= block_h + text_padding_v * 2.0:
		block_top = (size.y - block_h) * 0.5
	var title_baseline := block_top + title_ascent
	return Vector2(title_baseline, title_baseline + title_subtitle_gap)

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

func _draw_sweep(panel: Rect2) -> void:
	var span := maxf(panel.size.x, panel.size.y) * 2.0
	var offset := lerpf(-span, span, _sweep)
	var stripe_w := span * 0.06
	var center := panel.get_center() + Vector2(offset, offset)
	var half := span * 0.5
	var points := PackedVector2Array([
		center + Vector2(-half, -stripe_w),
		center + Vector2(half, -stripe_w),
		center + Vector2(half, stripe_w),
		center + Vector2(-half, stripe_w),
	])
	draw_colored_polygon(points, Color(1.0, 1.0, 1.0, sweep_alpha))

func _draw_neon_title(font: Font, text: String, pos: Vector2, font_size: int, glow_alpha: float) -> void:
	var layers := [
		{"spread": 5.0, "alpha": glow_alpha * 0.18, "color": neon_purple},
		{"spread": 3.5, "alpha": glow_alpha * 0.28, "color": neon_pink},
		{"spread": 2.0, "alpha": glow_alpha * 0.38, "color": neon_pink},
		{"spread": 1.0, "alpha": glow_alpha * 0.55, "color": Color(1.0, 1.0, 1.0, 1.0)},
	]
	for layer in layers:
		var spread: float = layer.spread
		var col: Color = layer.color
		var alpha: float = layer.alpha
		for ox in [-spread, 0.0, spread]:
			for oy in [-spread * 0.35, 0.0, spread * 0.35]:
				if is_zero_approx(ox) and is_zero_approx(oy):
					continue
				draw_string(
					font,
					pos + Vector2(ox, oy),
					text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					font_size,
					Color(col.r, col.g, col.b, alpha)
				)

	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, 0.98))
	draw_string(
		font,
		pos,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(neon_pink.r, neon_pink.g, neon_pink.b, glow_alpha * 0.65)
	)

func _spaced_text_width(font: Font, text: String, font_size: int, spacing: float) -> float:
	if text.is_empty():
		return 0.0
	var total := 0.0
	for i in text.length():
		total += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if i < text.length() - 1:
			total += spacing
	return total

func _draw_spaced_neon_text(
	font: Font,
	text: String,
	pos: Vector2,
	font_size: int,
	spacing: float,
	color: Color,
	alpha: float
) -> void:
	var x := pos.x
	for i in text.length():
		var ch := text[i]
		var ch_pos := Vector2(x, pos.y)
		for spread in [2.0, 1.0]:
			draw_string(
				font,
				ch_pos + Vector2(0.0, spread * 0.5),
				ch,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color(color.r, color.g, color.b, alpha * 0.25)
			)
		draw_string(
			font,
			ch_pos,
			ch,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(color.r, color.g, color.b, alpha)
		)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + spacing

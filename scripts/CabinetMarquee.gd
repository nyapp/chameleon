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
@export var title_font_size: int = 11:
	set(value):
		title_font_size = value
		queue_redraw()
@export var subtitle_font_size: int = 6:
	set(value):
		subtitle_font_size = value
		queue_redraw()
@export_range(0.0, 1.0) var title_y_ratio: float = 0.32:
	set(value):
		title_y_ratio = value
		queue_redraw()
@export_range(0.0, 1.0) var subtitle_y_ratio: float = 0.68:
	set(value):
		subtitle_y_ratio = value
		queue_redraw()

@export_group("Animation")
@export var pulse_speed: float = 2.0:
	set(value):
		pulse_speed = value
@export var glow_alpha_min: float = 0.4:
	set(value):
		glow_alpha_min = value
		queue_redraw()
@export var glow_alpha_range: float = 0.3:
	set(value):
		glow_alpha_range = value
		queue_redraw()
@export var glow_spread_step: float = 1.5:
	set(value):
		glow_spread_step = value
		queue_redraw()
@export var glow_layers: int = 3:
	set(value):
		glow_layers = maxi(value, 0)
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
@export var border_width: float = 2.0:
	set(value):
		border_width = value
		queue_redraw()
@export var inner_glow_alpha: float = 0.06:
	set(value):
		inner_glow_alpha = value
		queue_redraw()
@export var inner_glow_inset: float = 3.0:
	set(value):
		inner_glow_inset = value
		queue_redraw()
@export var neon_pink: Color = Color(1.0, 0.0, 0.498):
	set(value):
		neon_pink = value
		queue_redraw()
@export var neon_cyan: Color = Color(0.0, 0.941, 1.0):
	set(value):
		neon_cyan = value
		queue_redraw()
@export var title_tint_alpha: float = 0.5:
	set(value):
		title_tint_alpha = value
		queue_redraw()
@export var subtitle_alpha: float = 0.85:
	set(value):
		subtitle_alpha = value
		queue_redraw()

var _pulse: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_pulse += delta
		queue_redraw()
	elif pulse_speed > 0.0:
		_pulse += delta
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, bg_color)
	draw_rect(r, border_color, false, border_width)

	draw_rect(r.grow(-inner_glow_inset), Color(neon_cyan.r, neon_cyan.g, neon_cyan.b, inner_glow_alpha), false, 1.0)

	var font: Font = ThemeDB.fallback_font
	var title_w := font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, title_font_size).x
	var sub_w := font.get_string_size(subtitle_text, HORIZONTAL_ALIGNMENT_CENTER, -1, subtitle_font_size).x

	var pulse := 0.5 + 0.5 * sin(_pulse * pulse_speed)
	var glow_alpha := glow_alpha_min + pulse * glow_alpha_range

	var title_pos := Vector2((size.x - title_w) * 0.5, size.y * title_y_ratio)
	for i in glow_layers:
		var spread := float(i + 1) * glow_spread_step
		draw_string(font, title_pos + Vector2(-spread, 0), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size, Color(neon_pink.r, neon_pink.g, neon_pink.b, glow_alpha * 0.25))
		draw_string(font, title_pos + Vector2(spread, 0), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size, Color(neon_pink.r, neon_pink.g, neon_pink.b, glow_alpha * 0.25))
	draw_string(font, title_pos, title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size, Color(1, 1, 1, 0.95))
	draw_string(font, title_pos, title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size, Color(neon_pink.r, neon_pink.g, neon_pink.b, glow_alpha * title_tint_alpha))

	var sub_pos := Vector2((size.x - sub_w) * 0.5, size.y * subtitle_y_ratio)
	draw_string(font, sub_pos, subtitle_text, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle_font_size, Color(neon_cyan.r, neon_cyan.g, neon_cyan.b, subtitle_alpha))

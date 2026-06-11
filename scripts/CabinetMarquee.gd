## CabinetMarquee.gd
## マーキー「NEO CHAMELEON」「8-BIT RETRO SYNTH」

extends Control

const BG := Color(0.031, 0.031, 0.059)          # #08080f
const BORDER := Color(0.102, 0.102, 0.18)      # #1a1a2e
const NEON_PINK := Color(1.0, 0.0, 0.498)
const NEON_CYAN := Color(0.0, 0.941, 1.0)

var _pulse: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, BG)
	draw_rect(r, BORDER, false, 2.0)

	# 内側グロー
	draw_rect(r.grow(-3.0), Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.06), false, 1.0)

	var font: Font = ThemeDB.fallback_font
	var title := "NEO CHAMELEON"
	var sub := "8-BIT RETRO SYNTH"

	var title_size := 11
	var sub_size := 6
	var title_w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, title_size).x
	var sub_w := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_CENTER, -1, sub_size).x

	var pulse := 0.5 + 0.5 * sin(_pulse * 2.0)
	var glow_alpha := 0.4 + pulse * 0.3

	# タイトルグロー（複数回描画）
	var title_pos := Vector2((size.x - title_w) * 0.5, size.y * 0.32)
	for i in 3:
		var spread := float(i + 1) * 1.5
		draw_string(font, title_pos + Vector2(-spread, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(NEON_PINK.r, NEON_PINK.g, NEON_PINK.b, glow_alpha * 0.25))
		draw_string(font, title_pos + Vector2(spread, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(NEON_PINK.r, NEON_PINK.g, NEON_PINK.b, glow_alpha * 0.25))
	draw_string(font, title_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(1, 1, 1, 0.95))
	draw_string(font, title_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(NEON_PINK.r, NEON_PINK.g, NEON_PINK.b, glow_alpha * 0.5))

	var sub_pos := Vector2((size.x - sub_w) * 0.5, size.y * 0.68)
	draw_string(font, sub_pos, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size, Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.85))

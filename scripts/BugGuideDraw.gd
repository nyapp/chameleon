## BugGuideDraw.gd
## 虫アイコンとガイド行の描画（リザルト内訳・操作説明などで共用）

class_name BugGuideDraw
extends RefCounted

const BUG_ORDER: Array[String] = ["common", "gnat", "firefly", "wasp"]

const ICON_BOX_SIZE: float = 16.0
const ICON_SCORE_GAP: float = 6.0
const SCORE_COUNT_GAP: float = 8.0
const ROW_HEIGHT: float = 18.0
const ROW_GAP: float = 3.0
const ROW_FONT_SIZE: int = 6

const COLOR_ICON_BOX_BG := Color(0.08, 0.08, 0.08, 0.92)
const COLOR_ICON_BOX_BORDER := Color(0.45, 0.45, 0.45, 0.65)
const COLOR_ICON_BOX_BORDER_WASP := Color(0.749, 0.353, 0.949, 0.75)
const COLOR_SCORE_POSITIVE := Color(1.0, 0.918, 0.0)
const COLOR_SCORE_NEGATIVE := Color(0.749, 0.353, 0.949)
const COLOR_COUNT := Color(0.82, 0.82, 0.82)

const _WASP_MIASMA_PURPLE := Color(0.486, 0.227, 0.929)
const _WASP_MIASMA_TOXIN := Color(0.224, 1.0, 0.078)
const _WASP_MIASMA_DOTS := [
	Vector2(-5, -2), Vector2(-4, 2), Vector2(-3, 4), Vector2(0, 5),
	Vector2(2, 3), Vector2(4, 1), Vector2(4, -2), Vector2(2, -4),
	Vector2(0, -5), Vector2(-2, -4), Vector2(-1, 0), Vector2(1, -1),
]

static func format_score(score_value: int) -> String:
	if score_value >= 0:
		return "+%d点" % score_value
	return "%d点" % score_value

static func score_color(score_value: int) -> Color:
	return COLOR_SCORE_NEGATIVE if score_value < 0 else COLOR_SCORE_POSITIVE

static func row_block_width(font: Font, bug_type: String, count: int) -> float:
	var meta: Dictionary = Bug.TYPE_META[bug_type]
	var score_str := format_score(meta["score_value"])
	var count_str := "x%d" % count
	var score_w := font.get_string_size(score_str, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FONT_SIZE).x
	var count_w := font.get_string_size(count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FONT_SIZE).x
	return ICON_BOX_SIZE + ICON_SCORE_GAP + score_w + SCORE_COUNT_GAP + count_w

static func draw_result_row(
	canvas: CanvasItem,
	font: Font,
	row_left: float,
	row_top: float,
	bug_type: String,
	count: int,
	wing_frame: int = 0
) -> void:
	var meta: Dictionary = Bug.TYPE_META[bug_type]
	var score_value: int = meta["score_value"]
	var score_str := format_score(score_value)
	var count_str := "x%d" % count

	var icon_rect := Rect2(row_left, row_top + 1.0, ICON_BOX_SIZE, ICON_BOX_SIZE)
	var border := COLOR_ICON_BOX_BORDER_WASP if bug_type == "wasp" else COLOR_ICON_BOX_BORDER
	_draw_rounded_rect(canvas, icon_rect, COLOR_ICON_BOX_BG, 3.0, true)
	_draw_rounded_rect(canvas, icon_rect, border, 3.0, false, 1.0)

	var icon_center := icon_rect.position + icon_rect.size * 0.5 + Vector2(0.0, 0.5)
	draw_bug_sprite(canvas, bug_type, icon_center, wing_frame)

	var text_y := row_top + ROW_HEIGHT - 5.0
	var text_x := row_left + ICON_BOX_SIZE + ICON_SCORE_GAP
	canvas.draw_string(font, Vector2(text_x, text_y), score_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FONT_SIZE, score_color(score_value))

	var score_w := font.get_string_size(score_str, HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FONT_SIZE).x
	canvas.draw_string(font,
		Vector2(text_x + score_w + SCORE_COUNT_GAP, text_y),
		count_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FONT_SIZE, COLOR_COUNT)

static func draw_result_breakdown(
	canvas: CanvasItem,
	font: Font,
	canvas_w: int,
	start_y: float,
	counts: Dictionary
) -> float:
	var max_row_w := 0.0
	for bug_type in BUG_ORDER:
		var count: int = int(counts.get(bug_type, 0))
		max_row_w = maxf(max_row_w, row_block_width(font, bug_type, count))

	var row_left := (float(canvas_w) - max_row_w) * 0.5
	var y := start_y
	var wing_frame := int(Time.get_ticks_msec() / 180) % 2

	for bug_type in BUG_ORDER:
		var count: int = int(counts.get(bug_type, 0))
		draw_result_row(canvas, font, row_left, y, bug_type, count, wing_frame)
		y += ROW_HEIGHT + ROW_GAP

	return y - ROW_GAP

static func draw_bug_sprite(
	canvas: CanvasItem,
	bug_type: String,
	center: Vector2,
	wing_frame: int = 0,
	alpha: float = 1.0,
	desaturate: float = 0.0
) -> void:
	canvas.draw_set_transform(center, 0.0, Vector2.ONE)
	match bug_type:
		"common":
			_draw_common_sprite(canvas, wing_frame, alpha, desaturate)
		"gnat":
			_draw_gnat_sprite(canvas, wing_frame, alpha, desaturate)
		"firefly":
			_draw_firefly_sprite(canvas, wing_frame, alpha, desaturate)
		"wasp":
			_draw_wasp_sprite(canvas, wing_frame, alpha, desaturate)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _tint(color: Color, alpha: float, desaturate: float) -> Color:
	var c := color
	if desaturate > 0.001:
		var gray: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
		c = color.lerp(Color(gray, gray, gray, color.a), clampf(desaturate, 0.0, 1.0))
	if alpha != 1.0:
		c.a *= alpha
	return c

static func _draw_common_sprite(canvas: CanvasItem, wing_frame: int, alpha: float, desaturate: float) -> void:
	canvas.draw_rect(Rect2(-1, -1, 2, 2), _tint(Color(0.110, 0.110, 0.110), alpha, desaturate))
	canvas.draw_rect(Rect2(1, -1, 2, 2), _tint(Color(1.0, 0.231, 0.188), alpha, desaturate))
	if wing_frame == 0:
		canvas.draw_rect(Rect2(-4, -5, 2, 3), _tint(Color(0.863, 0.863, 0.863), alpha, desaturate))
		canvas.draw_rect(Rect2(-1, -5, 2, 3), _tint(Color(0.863, 0.863, 0.863), alpha, desaturate))
	else:
		canvas.draw_rect(Rect2(-5, -3, 3, 2), _tint(Color(0.863, 0.863, 0.863), alpha, desaturate))
		canvas.draw_rect(Rect2(-2, -3, 3, 2), _tint(Color(0.863, 0.863, 0.863), alpha, desaturate))

static func _draw_gnat_sprite(canvas: CanvasItem, wing_frame: int, alpha: float, desaturate: float) -> void:
	canvas.draw_rect(Rect2(-1, -1, 2, 2), _tint(Color(0.702, 0.525, 0.0), alpha, desaturate))
	canvas.draw_rect(Rect2(0, 0, 1, 1), _tint(Color(1.0, 0.918, 0.0), alpha, desaturate))
	if wing_frame == 0:
		canvas.draw_rect(Rect2(-3, -3, 2, 1), _tint(Color(1.0, 0.918, 0.0), alpha, desaturate))
		canvas.draw_rect(Rect2(1, -3, 2, 1), _tint(Color(1.0, 0.918, 0.0), alpha, desaturate))
	else:
		canvas.draw_rect(Rect2(-4, -1, 1, 2), _tint(Color(1.0, 0.918, 0.0), alpha, desaturate))
		canvas.draw_rect(Rect2(2, -1, 1, 2), _tint(Color(1.0, 0.918, 0.0), alpha, desaturate))

static func _draw_firefly_sprite(canvas: CanvasItem, wing_frame: int, alpha: float, desaturate: float) -> void:
	canvas.draw_rect(Rect2(-1, -1, 2, 2), _tint(Color(0.0, 0.784, 1.0), alpha, desaturate))
	canvas.draw_rect(Rect2(-2, 1, 2, 1), _tint(Color(0.224, 1.0, 0.078), alpha, desaturate))
	if wing_frame == 0:
		canvas.draw_rect(Rect2(-3, -3, 2, 1), _tint(Color(1.0, 1.0, 1.0), alpha, desaturate))
		canvas.draw_rect(Rect2(1, -3, 2, 1), _tint(Color(1.0, 1.0, 1.0), alpha, desaturate))
	else:
		canvas.draw_rect(Rect2(-4, -1, 1, 2), _tint(Color(1.0, 1.0, 1.0), alpha, desaturate))
		canvas.draw_rect(Rect2(2, -1, 1, 2), _tint(Color(1.0, 1.0, 1.0), alpha, desaturate))

static func _draw_wasp_sprite(canvas: CanvasItem, wing_frame: int, alpha: float, desaturate: float) -> void:
	_draw_wasp_miasma(canvas, alpha, desaturate, Time.get_ticks_msec() * 0.001)
	var wing_color := _tint(Color(0.616, 0.0, 1.0, 0.4), alpha, desaturate)
	if wing_frame == 0:
		canvas.draw_rect(Rect2(-2, -6, 2, 4), wing_color)
		canvas.draw_rect(Rect2(0, -6, 2, 4), wing_color)
	else:
		canvas.draw_rect(Rect2(-4, -4, 2, 3), wing_color)
		canvas.draw_rect(Rect2(2, -4, 2, 3), wing_color)
	var purple := _tint(Color(0.749, 0.353, 0.949), alpha, desaturate)
	canvas.draw_rect(Rect2(-3, -1, 2, 3), purple)
	canvas.draw_rect(Rect2(-1, -1, 2, 3), purple)
	canvas.draw_rect(Rect2(1, -1, 2, 3), purple)
	canvas.draw_rect(Rect2(-1, -1, 1, 3), _tint(Color(0.102, 0.039, 0.180), alpha, desaturate))
	canvas.draw_rect(Rect2(0, -1, 1, 3), _tint(Color(0.102, 0.039, 0.180), alpha, desaturate))
	canvas.draw_rect(Rect2(3, -1, 2, 2), _tint(Color(0.486, 0.227, 0.929), alpha, desaturate))
	canvas.draw_rect(Rect2(3, -1, 1, 1), _tint(Color(0.224, 1.0, 0.078), alpha, desaturate))
	canvas.draw_rect(Rect2(4, 0, 1, 1), _tint(Color(0.224, 1.0, 0.078), alpha, desaturate))
	canvas.draw_rect(Rect2(-4, 0, 2, 1), _tint(Color(0.224, 1.0, 0.078), alpha, desaturate))
	canvas.draw_rect(Rect2(-5, 1, 1, 1), _tint(Color(0.0, 1.0, 0.255), alpha, desaturate))
	canvas.draw_rect(Rect2(-4, 2, 1, 1), _tint(Color(0.0, 1.0, 0.255), alpha, desaturate))
	canvas.draw_rect(Rect2(-2, 0, 1, 1), _tint(Color(0.224, 1.0, 0.078), alpha, desaturate))
	canvas.draw_rect(Rect2(0, 0, 1, 1), _tint(Color(0.224, 1.0, 0.078), alpha, desaturate))

static func _draw_wasp_miasma(canvas: CanvasItem, alpha_mul: float, desaturate: float, t: float) -> void:
	for i in _WASP_MIASMA_DOTS.size():
		var flicker := sin(t * 2.4 + float(i) * 0.9)
		if flicker < -0.35:
			continue
		var dot: Vector2 = _WASP_MIASMA_DOTS[i]
		var is_toxin := i % 4 == 0
		var base_alpha := 0.2 if is_toxin else 0.14
		var col := _WASP_MIASMA_TOXIN if is_toxin else _WASP_MIASMA_PURPLE
		canvas.draw_rect(
			Rect2(dot.x, dot.y, 1, 1),
			_tint(Color(col.r, col.g, col.b, base_alpha + flicker * 0.05), alpha_mul, desaturate)
		)

static func _draw_rounded_rect(
	canvas: CanvasItem,
	rect: Rect2,
	color: Color,
	radius: float,
	filled: bool,
	line_width: float = 1.0
) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(maxi(int(radius), 0))
	if filled:
		style.bg_color = color
	else:
		style.bg_color = Color.TRANSPARENT
		style.border_color = color
		style.set_border_width_all(maxi(int(line_width), 1))
	style.draw(canvas.get_canvas_item(), rect)

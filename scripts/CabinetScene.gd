## CabinetScene.gd
## 筐体ルート。SubViewport 内に MainScene を配置し、外枠 UI を管理する。

@tool
extends Control

@export_group("Layout")
@export var cabinet_pad: int = GameLayout.CABINET_PAD:
	set(value):
		cabinet_pad = value
		_request_layout()
@export var marquee_h: int = GameLayout.MARQUEE_H:
	set(value):
		marquee_h = value
		_request_layout()
@export var marquee_gap: int = GameLayout.MARQUEE_GAP:
	set(value):
		marquee_gap = value
		_request_layout()
@export var bezel_outer_pad: int = GameLayout.BEZEL_OUTER_PAD:
	set(value):
		bezel_outer_pad = value
		_request_layout()
@export var bezel_inner_pad: int = GameLayout.BEZEL_INNER_PAD:
	set(value):
		bezel_inner_pad = value
		_request_layout()
@export var control_deck_h: int = GameLayout.CONTROL_DECK_H:
	set(value):
		control_deck_h = value
		_request_layout()
@export var control_gap: int = GameLayout.CONTROL_GAP:
	set(value):
		control_gap = value
		_request_layout()

@export_group("Background")
@export var page_bg_color: Color = Color(0.039, 0.039, 0.078): # #0a0a14
	set(value):
		page_bg_color = value
		queue_redraw()
@export var grid_color: Color = Color(1.0, 0.0, 0.498, 0.05):
	set(value):
		grid_color = value
		queue_redraw()
@export var grid_step: int = 40:
	set(value):
		grid_step = maxi(value, 8)
		queue_redraw()

@onready var cabinet_inner: Control = $CabinetInner
@onready var game_viewport: SubViewport = $CabinetInner/ScreenBezel/SubViewportContainer/GameSubViewport
@onready var virtual_analog_stick: VirtualAnalogStick = $CabinetInner/ControlDeck/VirtualAnalogStick

var _main_scene: Node2D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_layout()
	if not Engine.is_editor_hint():
		_connect_game()
		_connect_controls()

func _request_layout() -> void:
	if is_node_ready() or Engine.is_editor_hint():
		call_deferred("_apply_layout")

func _apply_layout() -> void:
	if cabinet_inner == null or virtual_analog_stick == null:
		return

	var vp_size := get_viewport_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bezel_stack := bezel_outer_pad + bezel_inner_pad
	var inner_w := GameLayout.SCREEN_W + bezel_stack * 2
	var cabinet_w := inner_w + cabinet_pad * 2
	var screen_bezel_h := bezel_stack * 2 + GameLayout.SCREEN_H
	var cabinet_h := cabinet_pad * 2 + marquee_h + marquee_gap + screen_bezel_h + control_gap + control_deck_h
	var y_screen := cabinet_pad + marquee_h + marquee_gap
	var y_control := y_screen + screen_bezel_h + control_gap

	var inner_pos := Vector2(
		maxf(0.0, (vp_size.x - cabinet_w) * 0.5),
		maxf(0.0, (vp_size.y - cabinet_h) * 0.5)
	)
	cabinet_inner.set_deferred("position", inner_pos)
	cabinet_inner.set_deferred("size", Vector2(cabinet_w, cabinet_h))
	cabinet_inner.clip_contents = true

	var frame: Control = cabinet_inner.get_node("CabinetFrame")
	frame.set_deferred("size", Vector2(cabinet_w, cabinet_h))

	var frame_overlay: Control = cabinet_inner.get_node("CabinetFrameOverlay")
	frame_overlay.set_deferred("size", Vector2(cabinet_w, cabinet_h))

	var pad := float(cabinet_pad)

	var marquee: Control = cabinet_inner.get_node("MarqueePanel")
	marquee.position = Vector2(pad, pad)
	marquee.size = Vector2(inner_w, marquee_h)

	var screen_bezel: Control = cabinet_inner.get_node("ScreenBezel")
	screen_bezel.position = Vector2(pad, y_screen)
	screen_bezel.size = Vector2(inner_w, screen_bezel_h)
	if screen_bezel.has_method("set_bezel_pads"):
		screen_bezel.set_bezel_pads(bezel_outer_pad, bezel_inner_pad)

	var svc: SubViewportContainer = screen_bezel.get_node("SubViewportContainer")
	var viewport_pad := float(bezel_stack)
	svc.position = Vector2(viewport_pad, viewport_pad)
	svc.size = Vector2(GameLayout.SCREEN_W, GameLayout.SCREEN_H)
	svc.stretch = false

	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_viewport.handle_input_locally = true

	var crt: ColorRect = screen_bezel.get_node("CRTEffectOverlay")
	crt.position = svc.position
	crt.size = svc.size

	var deck: Control = cabinet_inner.get_node("ControlDeck")
	deck.position = Vector2(pad, y_control)
	deck.size = Vector2(inner_w, control_deck_h)

	var stick_size := _stick_size()
	var content_h := float(control_deck_h) - float(GameLayout.CONTROL_DECK_HEADER_H)
	var stick_y := float(GameLayout.CONTROL_DECK_HEADER_H) + maxf(0.0, (content_h - stick_size.y) * 0.5)
	virtual_analog_stick.position = Vector2(
		(inner_w - stick_size.x) * 0.5,
		stick_y
	)

func _stick_size() -> Vector2:
	var size := virtual_analog_stick.size
	if size.x > 0.0 and size.y > 0.0:
		return size
	var diameter := virtual_analog_stick.radius * 2.0
	return Vector2(diameter, diameter)

func _connect_game() -> void:
	await get_tree().process_frame
	_main_scene = game_viewport.get_node_or_null("MainScene")
	if _main_scene == null:
		push_warning("CabinetScene: MainScene not found in SubViewport")

func _connect_controls() -> void:
	virtual_analog_stick.aim_changed.connect(_on_stick_aim_changed)
	virtual_analog_stick.released.connect(_on_stick_released)

func _on_stick_aim_changed(direction: Vector2, magnitude: float) -> void:
	if _main_scene and _main_scene.has_method("on_stick_aim_changed"):
		_main_scene.on_stick_aim_changed(direction, magnitude)

func _on_stick_released(direction: Vector2, magnitude: float) -> void:
	if _main_scene and _main_scene.has_method("on_stick_released"):
		_main_scene.on_stick_released(direction, magnitude, virtual_analog_stick.deadzone)

func _draw() -> void:
	var vp := get_viewport_rect()
	draw_rect(vp, page_bg_color)

	var grad_top := Color(0.071, 0.071, 0.141, 0.95)
	var grad_bot := Color(0.039, 0.039, 0.078, 0.98)
	var bands := 32
	for i in bands:
		var t0 := float(i) / float(bands)
		var t1 := float(i + 1) / float(bands)
		var y0 := vp.size.y * t0
		var y1 := vp.size.y * t1 + 1.0
		draw_rect(Rect2(0.0, y0, vp.size.x, y1 - y0), grad_top.lerp(grad_bot, (t0 + t1) * 0.5))

	var grid_col := Color(grid_color.r, grid_color.g, grid_color.b, grid_color.a)
	for x in range(0, int(vp.size.x) + grid_step, grid_step):
		draw_line(Vector2(x, 0), Vector2(x, vp.size.y), grid_col)
	for y in range(0, int(vp.size.y) + grid_step, grid_step):
		draw_line(Vector2(0, y), Vector2(vp.size.x, y), grid_col)

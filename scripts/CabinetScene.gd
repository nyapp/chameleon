## CabinetScene.gd
## 筐体ルート。SubViewport 内に MainScene を配置し、外枠 UI を管理する。

@tool
extends Control

@export_group("Layout")
@export var cabinet_pad: int = 14:
	set(value):
		cabinet_pad = value
		_request_layout()
@export var marquee_h: int = 52:
	set(value):
		marquee_h = value
		_request_layout()
@export var bezel_pad: int = 10:
	set(value):
		bezel_pad = value
		_request_layout()
@export var control_deck_h: int = 108:
	set(value):
		control_deck_h = value
		_request_layout()
@export var control_gap: int = 10:
	set(value):
		control_gap = value
		_request_layout()

@export_group("Controls")
@export var stick_offset_y: float = 30.0:
	set(value):
		stick_offset_y = value
		_request_layout()

@export_group("Background")
@export var page_bg_color: Color = Color(0.039, 0.039, 0.078): # #0a0a14
	set(value):
		page_bg_color = value
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

	var cabinet_w := GameLayout.SCREEN_W + bezel_pad * 4
	var cabinet_h := cabinet_pad * 2 + marquee_h + bezel_pad * 2 + GameLayout.SCREEN_H + control_gap + control_deck_h
	var inner_w := cabinet_w - cabinet_pad * 2
	var screen_bezel_h := bezel_pad * 2 + GameLayout.SCREEN_H
	var y_screen := cabinet_pad + marquee_h
	var y_control := y_screen + screen_bezel_h + control_gap

	var inner_pos := Vector2(
		maxf(0.0, (vp_size.x - cabinet_w) * 0.5),
		maxf(0.0, (vp_size.y - cabinet_h) * 0.5)
	)
	cabinet_inner.set_deferred("position", inner_pos)
	cabinet_inner.set_deferred("size", Vector2(cabinet_w, cabinet_h))

	var frame: Control = cabinet_inner.get_node("CabinetFrame")
	frame.set_deferred("size", Vector2(cabinet_w, cabinet_h))

	var pad := float(cabinet_pad)

	var marquee: Control = cabinet_inner.get_node("MarqueePanel")
	marquee.position = Vector2(pad, pad)
	marquee.size = Vector2(inner_w, marquee_h)

	var screen_bezel: Control = cabinet_inner.get_node("ScreenBezel")
	screen_bezel.position = Vector2(pad, y_screen)
	screen_bezel.size = Vector2(inner_w, screen_bezel_h)

	var svc: SubViewportContainer = screen_bezel.get_node("SubViewportContainer")
	var bezel_pad_f := float(bezel_pad)
	svc.position = Vector2(bezel_pad_f, bezel_pad_f)
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

	virtual_analog_stick.position = Vector2(
		(inner_w - virtual_analog_stick.size.x) * 0.5,
		stick_offset_y
	)

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
	draw_rect(get_viewport_rect(), page_bg_color)

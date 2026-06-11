## CabinetScene.gd
## 筐体ルート。SubViewport 内に MainScene を配置し、外枠 UI を管理する。

extends Control

const PAGE_BG := Color(0.039, 0.039, 0.078)       # #0a0a14

@onready var cabinet_inner: Control = $CabinetInner
@onready var game_viewport: SubViewport = $CabinetInner/ScreenBezel/SubViewportContainer/GameSubViewport
@onready var virtual_analog_stick: VirtualAnalogStick = $CabinetInner/ControlDeck/VirtualAnalogStick

var _main_scene: Node2D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_layout()
	_connect_game()
	_connect_controls()

func _apply_layout() -> void:
	var vp_size := get_viewport_rect().size
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var inner_pos := Vector2(
		maxf(0.0, (vp_size.x - GameLayout.CABINET_W) * 0.5),
		maxf(0.0, (vp_size.y - GameLayout.CABINET_H) * 0.5)
	)
	cabinet_inner.set_deferred("position", inner_pos)
	cabinet_inner.set_deferred("size", Vector2(GameLayout.CABINET_W, GameLayout.CABINET_H))

	var frame: Control = cabinet_inner.get_node("CabinetFrame")
	frame.set_deferred("size", Vector2(GameLayout.CABINET_W, GameLayout.CABINET_H))

	var pad := float(GameLayout.CABINET_PAD)
	var inner_w := float(GameLayout.INNER_W)

	var marquee: Control = cabinet_inner.get_node("MarqueePanel")
	marquee.position = Vector2(pad, pad)
	marquee.size = Vector2(inner_w, GameLayout.MARQUEE_H)

	var screen_bezel: Control = cabinet_inner.get_node("ScreenBezel")
	screen_bezel.position = Vector2(pad, GameLayout.Y_SCREEN)
	screen_bezel.size = Vector2(inner_w, GameLayout.SCREEN_BEZEL_H)

	var svc: SubViewportContainer = screen_bezel.get_node("SubViewportContainer")
	var bezel_pad := float(GameLayout.BEZEL_PAD)
	svc.position = Vector2(bezel_pad, bezel_pad)
	svc.size = Vector2(GameLayout.SCREEN_W, GameLayout.SCREEN_H)
	svc.stretch = false

	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_viewport.handle_input_locally = true

	var crt: ColorRect = screen_bezel.get_node("CRTEffectOverlay")
	crt.position = svc.position
	crt.size = svc.size

	var deck: Control = cabinet_inner.get_node("ControlDeck")
	deck.position = Vector2(pad, GameLayout.Y_CONTROL)
	deck.size = Vector2(inner_w, GameLayout.CONTROL_DECK_H)

	virtual_analog_stick.position = Vector2(
		(inner_w - virtual_analog_stick.size.x) * 0.5,
		30.0
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
		_main_scene.on_stick_released(direction, magnitude)

func _draw() -> void:
	draw_rect(get_viewport_rect(), PAGE_BG)

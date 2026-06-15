## MainScene.gd
## JSの class GameEngine を移植。
## ゲームループ全体（update/衝突判定/スコア/レベルアップ）を統括する。

extends Node2D

# ─── 定数 ───────────────────────────────────────────────────
const CANVAS_W: int = 256
const CANVAS_H: int = 240
const HUD_PAUSE_TAP_H: float = 28.0
const MAX_BUGS: int = 5
const LEVEL_SCORE_THRESHOLD: int = 1200

# ─── 子ノード参照 ────────────────────────────────────────────
@onready var chameleon: Chameleon = $Chameleon
@onready var bug_container: Node2D = $BugContainer
@onready var camera: Camera2D = $ScreenShakeCamera
@onready var overlay_draw: Node2D = $HUD/OverlayDraw

# ─── 状態変数 ────────────────────────────────────────────────
var screen_shake: float = 0.0
var game_over_shake_time: float = 0.0
var level_up_banner_time: float = 0.0

# マウス・タッチ入力
var mouse_target: Vector2 = Vector2.ZERO
var has_mouse_target: bool = false

# アナログスティック入力（筐体 UI からシグナル経由）
var stick_aiming: bool = false
var stick_direction: Vector2 = Vector2.ZERO

# ─── Bug リソースシーン ──────────────────────────────────────
const BUG_SCRIPT: GDScript = preload("res://scripts/Bug.gd")

# ─── 初期化 ─────────────────────────────────────────────────
func _ready() -> void:
	GameState.game_over_triggered.connect(_on_game_over)
	GameState.level_up.connect(_on_level_up)
	GameState.power_up_deactivated.connect(_on_power_up_deactivated)
	GameState.power_up_activated.connect(_on_power_up_activated)

	if overlay_draw:
		overlay_draw.chameleon_ref = chameleon

	_spawn_initial_bugs()
	_trigger_boot_animation()

# ─── 筐体 UI からの公開 API ───────────────────────────────────
func on_stick_aim_changed(direction: Vector2, _magnitude: float) -> void:
	stick_aiming = true
	stick_direction = direction

func on_stick_pressed() -> void:
	match GameState.state:
		"TITLE":
			_start_game()
		"GAMEOVER":
			_reset_game()

func on_stick_released(direction: Vector2, magnitude: float, deadzone: float = 0.25) -> void:
	stick_aiming = false
	stick_direction = Vector2.ZERO
	if GameState.state != "PLAYING":
		return
	if magnitude < deadzone:
		has_mouse_target = false
		return
	var desired: float = atan2(direction.y, direction.x)
	chameleon.target_angle = clamp(desired, Chameleon.ANGLE_MIN, Chameleon.ANGLE_MAX)
	chameleon.angle = chameleon.target_angle
	has_mouse_target = false
	_trigger_shoot()

# ─── ブートアニメ ────────────────────────────────────────────
func _trigger_boot_animation() -> void:
	pass

# ─── メインループ ────────────────────────────────────────────
func _process(delta: float) -> void:
	var gs: Node = GameState
	gs.tick_slow_mo_visual(delta)

	var dpad_aiming: bool = Input.is_action_pressed("aim_up") or Input.is_action_pressed("aim_down")

	if overlay_draw:
		overlay_draw.is_dpad_aiming = dpad_aiming
		overlay_draw.is_stick_aiming = stick_aiming
		overlay_draw.level_up_banner_time = level_up_banner_time

	if stick_aiming and stick_direction.length_squared() > 0.0:
		var pivot := Vector2(Chameleon.PIVOT_X, Chameleon.PIVOT_Y)
		mouse_target = pivot + stick_direction.normalized() * chameleon.tongue_max_len
		has_mouse_target = true

	if gs.is_frozen():
		return

	_tick_screen_shake(delta)

	chameleon.has_mouse_target = has_mouse_target
	chameleon.mouse_target = mouse_target
	chameleon.update_chameleon(delta, _get_bug_list())

	match gs.state:
		"TITLE", "GAMEOVER":
			_update_bugs_idle(delta)
		"PLAYING":
			_update_playing(delta)

# ─── PLAYING状態の更新 ────────────────────────────────────────
func _update_playing(delta: float) -> void:
	var gs: Node = GameState

	if not gs.tick_energy(delta):
		gs.trigger_game_over()
		return

	gs.tick_combo(delta)
	gs.tick_power_up(delta)
	_update_bugs_playing(delta)
	_check_tongue_collision()
	_check_swallow_result()

	if level_up_banner_time > 0.0:
		level_up_banner_time = max(0.0, level_up_banner_time - delta)

# ─── 虫の更新（PLAYING） ────────────────────────────────────
func _update_bugs_playing(delta: float) -> void:
	var gs: Node = GameState
	var is_slow: bool = gs.power_up_type == "slow"
	for bug in bug_container.get_children():
		var move_delta: float = delta * 0.4 if is_slow and bug.state == "active" else delta
		bug.update_movement(move_delta)

func _update_bugs_idle(delta: float) -> void:
	for bug in bug_container.get_children():
		bug.update_movement(delta)

# ─── 衝突判定（手動距離チェック） ────────────────────────────
func _check_tongue_collision() -> void:
	if chameleon.tongue_state != "shooting":
		return
	if chameleon.caught_bug != null:
		return

	var tip: Vector2 = chameleon.tongue_tip_position()

	for bug in bug_container.get_children():
		if bug.state != "active":
			continue
		var dist: float = tip.distance_to(bug.position)
		var threshold: float = bug.size * 2.5 + 4.0
		if dist < threshold:
			bug.state = "caught"
			chameleon.caught_bug = bug
			chameleon.tongue_state = "retracting"
			break

# ─── 食べた虫の結果処理 ───────────────────────────────────────
func _check_swallow_result() -> void:
	for bug in bug_container.get_children():
		if bug.state == "eaten":
			_process_eaten_bug(bug)
			bug.respawn()
			break

func _process_eaten_bug(bug: Bug) -> void:
	var gs: Node = GameState

	if bug.bug_type == "wasp":
		gs.combo = 0
		gs.combo_timer = 0.0
		gs.energy = max(0.0, gs.energy + bug.energy_value)
		gs.score = max(0, gs.score + bug.score_value)
		screen_shake = 12.0
		chameleon.trigger_hurt(true)
		AudioManager.play_hurt()
		HapticManager.play_hurt()
	else:
		gs.flies_eaten += 1
		gs.increment_combo()

		var base_score: int = bug.score_value
		var reward: int = base_score * max(gs.combo, 1)
		gs.score += reward
		gs.add_energy(bug.energy_value)

		AudioManager.play_eat()
		HapticManager.play_eat()

		if bug.bug_type == "firefly":
			_trigger_random_power_up()

	if gs.check_level_up():
		level_up_banner_time = GameState.LEVEL_UP_BANNER_DURATION
		AudioManager.play_powerup()
		HapticManager.play_powerup()
		var bug_count: int = bug_container.get_child_count()
		if gs.level <= 4 and bug_count < MAX_BUGS + 2:
			_spawn_bug(_get_extra_bug_type(gs.level))

func _get_extra_bug_type(lv: int) -> String:
	var types: Array = ["common", "gnat", "firefly"]
	return types[lv % 3]

# ─── パワーアップ ────────────────────────────────────────────
func _trigger_random_power_up() -> void:
	var power_ups: Array = ["gold", "multi", "slow"]
	var chosen: String = power_ups[randi() % power_ups.size()]
	GameState.activate_power_up(chosen)
	AudioManager.play_powerup()
	HapticManager.play_powerup()

func _on_power_up_activated(power_type: String) -> void:
	chameleon.activate_power_up(power_type)

func _on_power_up_deactivated() -> void:
	chameleon.deactivate_power_up()

# ─── ゲームオーバー ───────────────────────────────────────────
func _on_game_over() -> void:
	GameState.bgm_paused_by_menu = false
	AudioManager.stop_bgm()
	AudioManager.play_game_over()
	HapticManager.play_game_over()
	game_over_shake_time = GameState.GAME_OVER_SHAKE_DURATION
	screen_shake = max(screen_shake, 12.0)

# ─── レベルアップ ────────────────────────────────────────────
func _on_level_up(_new_level: int) -> void:
	level_up_banner_time = GameState.LEVEL_UP_BANNER_DURATION

# ─── 画面揺れ ────────────────────────────────────────────────
func _tick_screen_shake(delta: float) -> void:
	var step: float = GameState.scale60(delta)
	if game_over_shake_time > 0.0:
		game_over_shake_time = max(0.0, game_over_shake_time - delta)
		screen_shake = max(0.0, screen_shake - 0.8 * step)
		if game_over_shake_time <= 0.0:
			screen_shake = 0.0
	elif GameState.state == "PLAYING" and screen_shake > 0.0:
		screen_shake = max(0.0, screen_shake - 0.8 * step)

	if screen_shake > 0.0 and camera:
		camera.offset = Vector2(
			randf_range(-1.0, 1.0) * screen_shake,
			randf_range(-1.0, 1.0) * screen_shake
		)
	elif camera:
		camera.offset = Vector2.ZERO

# ─── 入力処理 ────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	var gs: Node = GameState

	if gs.state == "PAUSED":
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_toggle_pause()
		return

	if event is InputEventMouseMotion and gs.state == "PLAYING" and not stick_aiming:
		mouse_target = get_local_mouse_position()
		has_mouse_target = true

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_pos: Vector2 = get_local_mouse_position()
			if gs.state == "PLAYING" and _is_hud_pause_zone(local_pos):
				_toggle_pause()
				return
			_on_screen_tapped()
		elif not stick_aiming:
			has_mouse_target = false

	elif event is InputEventScreenTouch:
		if event.pressed:
			var local_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
			if gs.state == "PLAYING" and _is_hud_pause_zone(local_pos):
				_toggle_pause()
				return
			mouse_target = local_pos
			has_mouse_target = true
			_on_screen_tapped()
		elif not stick_aiming:
			has_mouse_target = false

	elif event is InputEventScreenDrag and not stick_aiming:
		mouse_target = get_viewport().get_canvas_transform().affine_inverse() * event.position
		has_mouse_target = true

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_on_screen_tapped()
			KEY_ESCAPE:
				if gs.state == "PLAYING":
					_toggle_pause()

func _is_hud_pause_zone(local_pos: Vector2) -> bool:
	return local_pos.y >= 0.0 and local_pos.y <= HUD_PAUSE_TAP_H

func _on_screen_tapped() -> void:
	match GameState.state:
		"TITLE":
			_start_game()
		"GAMEOVER":
			_reset_game()
		"PLAYING":
			_trigger_shoot()

func _trigger_shoot() -> void:
	if GameState.state != "PLAYING":
		return
	if chameleon.shoot():
		AudioManager.play_shoot()
		HapticManager.play_shoot()

# ─── ゲーム開始・リセット ────────────────────────────────────
func _start_game() -> void:
	GameState.bgm_paused_by_menu = false
	GameState.start_game()
	chameleon.deactivate_power_up()
	screen_shake = 0.0
	game_over_shake_time = 0.0
	_spawn_initial_bugs()
	AudioManager.start_bgm()

func _reset_game() -> void:
	await get_tree().create_timer(0.3).timeout
	_start_game()

func toggle_pause_menu() -> void:
	if GameState.state in ["PLAYING", "PAUSED"]:
		_toggle_pause()

func return_to_title() -> void:
	if GameState.state not in ["PLAYING", "PAUSED"]:
		return
	AudioManager.stop_bgm()
	GameState.return_to_title()
	chameleon.deactivate_power_up()
	chameleon.tongue_state = "idle"
	chameleon.tongue_len = 0.0
	chameleon.caught_bug = null
	screen_shake = 0.0
	game_over_shake_time = 0.0
	level_up_banner_time = 0.0
	has_mouse_target = false
	stick_aiming = false
	stick_direction = Vector2.ZERO
	_spawn_initial_bugs()
	HapticManager.play_ui_tap()

# ─── ポーズ ──────────────────────────────────────────────────
func _toggle_pause() -> void:
	if GameState.state == "PLAYING":
		GameState.frozen_by_menu = true
		GameState.set_state("PAUSED")
		if AudioManager.is_bgm_playing:
			GameState.bgm_paused_by_menu = true
			AudioManager.pause_bgm()
	elif GameState.state == "PAUSED":
		GameState.frozen_by_menu = false
		GameState.set_state("PLAYING")
		if GameState.bgm_paused_by_menu:
			GameState.bgm_paused_by_menu = false
			AudioManager.resume_bgm()

# ─── バグ管理 ────────────────────────────────────────────────
func _spawn_initial_bugs() -> void:
	for child in bug_container.get_children():
		child.queue_free()

	var types: Array = ["common", "common", "gnat", "wasp", "firefly"]
	for i in MAX_BUGS:
		_spawn_bug(types[i % types.size()])

func _spawn_bug(bug_type: String) -> void:
	var bug: Bug = Bug.new()
	bug_container.add_child(bug)
	bug.setup(bug_type)

func _get_bug_list() -> Array:
	return bug_container.get_children()

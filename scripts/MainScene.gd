## MainScene.gd
## JSの class GameEngine を移植。
## ゲームループ全体（update/衝突判定/スコア/レベルアップ）を統括する。

extends Node2D

# ─── 定数 ───────────────────────────────────────────────────
const CANVAS_W: int = 256
const CANVAS_H: int = 240
const MAX_BUGS: int = 5
const LEVEL_SCORE_THRESHOLD: int = 1200

# ─── 子ノード参照 ────────────────────────────────────────────
@onready var chameleon: Chameleon = $Chameleon
@onready var bug_container: Node2D = $BugContainer
@onready var camera: Camera2D = $ScreenShakeCamera
@onready var overlay_draw: Node2D = $HUD/OverlayDraw

# ─── 状態変数 ────────────────────────────────────────────────
var screen_shake: float = 0.0
var game_over_shake_frames: int = 0
var level_up_banner_frames: int = 0

# マウス・タッチ入力
var mouse_target: Vector2 = Vector2.ZERO
var has_mouse_target: bool = false

# D-Pad仮想ボタン押下状態（UI向け）
var dpad_up: bool = false
var dpad_down: bool = false

# ─── Bug リソースシーン ──────────────────────────────────────
const BUG_SCRIPT: GDScript = preload("res://scripts/Bug.gd")

# ─── 初期化 ─────────────────────────────────────────────────
func _ready() -> void:
	# GameStateシグナル接続
	GameState.game_over_triggered.connect(_on_game_over)
	GameState.level_up.connect(_on_level_up)
	GameState.power_up_deactivated.connect(_on_power_up_deactivated)
	GameState.power_up_activated.connect(_on_power_up_activated)

	# OverlayDrawにChameleon参照を渡す
	if overlay_draw:
		overlay_draw.chameleon_ref = chameleon

	# 初期バグのスポーン
	_spawn_initial_bugs()

	# ブートシーケンス（JSの triggerBootSequence 相当）
	# Godotでは AnimationPlayer や Tween で実現できるが、シンプルにタイマーで代替
	_trigger_boot_animation()

# ─── ブートアニメ ────────────────────────────────────────────
func _trigger_boot_animation() -> void:
	# CRTスタティックエフェクトの代わりにカメラを一瞬真っ黒にする
	# OverlayDrawでフラッシュを描画（省略可）
	pass

# ─── メインループ ────────────────────────────────────────────
func _process(delta: float) -> void:
	var gs: Node = GameState

	# D-Pad仮想ボタン状態 → Chameleonへ転送
	dpad_up = Input.is_action_pressed("aim_up")
	dpad_down = Input.is_action_pressed("aim_down")

	# OverlayDrawのD-Padフラグを更新
	if overlay_draw:
		overlay_draw.is_dpad_aiming = dpad_up or dpad_down
		overlay_draw.level_up_banner_frames = level_up_banner_frames

	# 凍結中（メニュー開放中）はシミュレーション停止
	if gs.is_frozen():
		chameleon.update_chameleon(delta, _get_bug_list())
		_update_bugs_idle(delta)
		return

	# 画面揺れのdecay
	_tick_screen_shake()

	# Chameleonに入力を渡して更新
	chameleon.has_mouse_target = has_mouse_target
	chameleon.mouse_target = mouse_target
	chameleon.update_chameleon(delta, _get_bug_list())

	match gs.state:
		"TITLE", "GAMEOVER":
			# タイトル・ゲームオーバー中も虫はアニメーション
			_update_bugs_idle(delta)

		"PLAYING":
			_update_playing(delta)

# ─── PLAYING状態の更新 ────────────────────────────────────────
func _update_playing(delta: float) -> void:
	var gs: Node = GameState

	# 1. エネルギー消費
	if not gs.tick_energy(delta):
		gs.trigger_game_over()
		return

	# 2. コンボタイマー
	gs.tick_combo(delta)

	# 3. パワーアップタイマー
	gs.tick_power_up(delta)

	# 4. 虫の更新
	_update_bugs_playing(delta)

	# 5. 舌 vs 虫の衝突判定
	_check_tongue_collision()

	# 6. 食べた虫の処理
	_check_swallow_result()

	# 7. アニメーションのdecay
	if level_up_banner_frames > 0:
		level_up_banner_frames -= 1

# ─── 虫の更新（PLAYING） ────────────────────────────────────
func _update_bugs_playing(delta: float) -> void:
	var gs: Node = GameState
	var is_slow: bool = gs.power_up_type == "slow"
	for bug in bug_container.get_children():
		if is_slow and bug.state == "active":
			if randf() < 0.4:
				bug.update_movement(delta)
		else:
			bug.update_movement(delta)

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

# ─── 食べた虫の結果処理（tongue_swallowed シグナル受信後） ───
func _check_swallow_result() -> void:
	# chameleon.gd の swallowing ステートで bug.state = "eaten" になった直後を検出
	for bug in bug_container.get_children():
		if bug.state == "eaten":
			_process_eaten_bug(bug)
			bug.respawn()
			break

func _process_eaten_bug(bug: Bug) -> void:
	var gs: Node = GameState

	if bug.bug_type == "wasp":
		# 毒ハチ：ダメージ
		gs.combo = 0
		gs.combo_timer = 0.0
		gs.energy = max(0.0, gs.energy + bug.energy_value)  # energy_value は負値
		gs.score = max(0, gs.score + bug.score_value)        # score_value は負値
		screen_shake = 12.0
		chameleon.trigger_hurt(true)
		AudioManager.play_hurt()
	else:
		# 通常の捕獲：スコア・エネルギー加算
		gs.flies_eaten += 1
		gs.increment_combo()

		var base_score: int = bug.score_value
		var reward: int = base_score * max(gs.combo, 1)
		gs.score += reward
		gs.add_energy(bug.energy_value)

		AudioManager.play_eat()

		# Firefly → ランダムパワーアップ
		if bug.bug_type == "firefly":
			_trigger_random_power_up()

	# レベルアップ確認
	if gs.check_level_up():
		level_up_banner_frames = 80
		AudioManager.play_powerup()
		# レベル4以下で追加バグをスポーン
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

func _on_power_up_activated(power_type: String) -> void:
	chameleon.activate_power_up(power_type)

func _on_power_up_deactivated() -> void:
	chameleon.deactivate_power_up()

# ─── ゲームオーバー ───────────────────────────────────────────
func _on_game_over() -> void:
	AudioManager.stop_bgm()
	AudioManager.play_game_over()
	game_over_shake_frames = 60
	screen_shake = max(screen_shake, 12.0)

# ─── レベルアップ ────────────────────────────────────────────
func _on_level_up(new_level: int) -> void:
	level_up_banner_frames = 80

# ─── 画面揺れ ────────────────────────────────────────────────
func _tick_screen_shake() -> void:
	if game_over_shake_frames > 0:
		game_over_shake_frames -= 1
		screen_shake = max(0.0, screen_shake - 0.8)
		if game_over_shake_frames <= 0:
			screen_shake = 0.0
	elif GameState.state == "PLAYING" and screen_shake > 0.0:
		screen_shake = max(0.0, screen_shake - 0.8)

	# Camera2Dのオフセットで揺らす
	if screen_shake > 0.0 and camera:
		camera.offset = Vector2(
			randf_range(-1.0, 1.0) * screen_shake,
			randf_range(-1.0, 1.0) * screen_shake
		)
	elif camera:
		camera.offset = Vector2.ZERO

# ─── 入力処理 ────────────────────────────────────────────────
func _screen_to_game_position(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _input(event: InputEvent) -> void:
	var gs: Node = GameState

	# マウス移動 → エイム
	if event is InputEventMouseMotion and gs.state == "PLAYING":
		mouse_target = get_local_mouse_position()
		has_mouse_target = true

	# マウスクリック
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_screen_tapped()

	# タッチ
	elif event is InputEventScreenTouch:
		if event.pressed:
			mouse_target = _screen_to_game_position(event.position)
			has_mouse_target = true
			_on_screen_tapped()
		else:
			has_mouse_target = false

	elif event is InputEventScreenDrag:
		mouse_target = _screen_to_game_position(event.position)
		has_mouse_target = true

	# マウスがキャンバス外に出たら照準リセット
	elif event is InputEventMouseButton and not event.pressed:
		has_mouse_target = false

	# キーボード
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_on_screen_tapped()
			KEY_ESCAPE:
				if gs.state in ["PLAYING", "PAUSED"]:
					_toggle_pause()

func _on_screen_tapped() -> void:
	var gs: Node = GameState
	AudioManager.start_bgm()
	match gs.state:
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

# ─── ゲーム開始・リセット ────────────────────────────────────
func _start_game() -> void:
	GameState.start_game()
	chameleon.deactivate_power_up()
	screen_shake = 0.0
	game_over_shake_frames = 0
	_spawn_initial_bugs()
	AudioManager.start_bgm()

func _reset_game() -> void:
	# ブートアニメーション後にスタート
	await get_tree().create_timer(0.3).timeout
	_start_game()

# ─── ポーズ ──────────────────────────────────────────────────
func _toggle_pause() -> void:
	if GameState.state == "PLAYING":
		GameState.frozen_by_menu = true
		GameState.set_state("PAUSED")
		AudioManager.stop_bgm()
	elif GameState.state == "PAUSED":
		GameState.frozen_by_menu = false
		GameState.set_state("PLAYING")
		AudioManager.start_bgm()

# ─── バグ管理 ────────────────────────────────────────────────
func _spawn_initial_bugs() -> void:
	# 既存の虫を全てrespawn
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

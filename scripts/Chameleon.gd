## Chameleon.gd
## JSの class Chameleon を完全移植。
## ボディ・頭部・舌のステートマシン、全描画を Node2D._draw() で実装。

extends Node2D
class_name Chameleon

# ─── 定数 ───────────────────────────────────────────────────
const CANVAS_W: int = 256
const CANVAS_H: int = 240

# キャラクター基本座標（JSと同一）
const CHAR_X: int = 42
const CHAR_Y: int = 175
const PIVOT_X: int = 56   # CHAR_X + 14
const PIVOT_Y: int = 163  # CHAR_Y - 12

# 角度制限
const ANGLE_MIN: float = -PI * 0.65
const ANGLE_MAX: float = PI * 0.15

# 舌パラメータ
const TONGUE_SPEED_DEFAULT: float = 16.0
const TONGUE_MAX_LEN_DEFAULT: float = 170.0
const TONGUE_SPEED_GOLD: float = 22.0
const TONGUE_MAX_LEN_GOLD: float = 220.0

# ─── 状態変数 ────────────────────────────────────────────────
var angle: float = -PI / 6.0
var target_angle: float = -PI / 6.0
var rotation_speed: float = 0.08

## "idle" | "shooting" | "retracting" | "swallowing"
var tongue_state: String = "idle"
var tongue_len: float = 0.0
var tongue_speed: float = TONGUE_SPEED_DEFAULT
var tongue_max_len: float = TONGUE_MAX_LEN_DEFAULT
var tongue_tip: Vector2 = Vector2(PIVOT_X, PIVOT_Y)

var caught_bug: Bug = null  # 捕まえた虫への参照

# アニメーション
var idle_time: float = 0.0
var mouth_open: float = 0.0
var eye_target_angle: float = 0.0
var flash_frames: int = 0
var hurt_poison: bool = false
var power_up_active: String = ""  # "" | "gold" | "multi" | "slow"
var color_cycle: float = 0.0

# マウス・キー入力（MainSceneから毎フレーム更新）
var mouse_target: Vector2 = Vector2.ZERO
var has_mouse_target: bool = false
var keys_up: bool = false
var keys_down: bool = false
var keys_left: bool = false
var keys_right: bool = false

# ─── シグナル ────────────────────────────────────────────────
signal tongue_swallowed()  # 舌が完全に戻ったとき（MainSceneが食べた処理をする）

# ─── 公開API ─────────────────────────────────────────────────
func shoot() -> bool:
	if tongue_state == "idle":
		tongue_state = "shooting"
		tongue_len = 5.0
		caught_bug = null
		return true
	return false

func trigger_hurt(is_poison: bool = false) -> void:
	flash_frames = 15
	hurt_poison = is_poison

func activate_power_up(power_type: String) -> void:
	power_up_active = power_type
	if power_type == "gold":
		tongue_max_len = TONGUE_MAX_LEN_GOLD
		tongue_speed = TONGUE_SPEED_GOLD
	else:
		tongue_max_len = TONGUE_MAX_LEN_DEFAULT
		tongue_speed = TONGUE_SPEED_DEFAULT

func deactivate_power_up() -> void:
	power_up_active = ""
	tongue_max_len = TONGUE_MAX_LEN_DEFAULT
	tongue_speed = TONGUE_SPEED_DEFAULT

func tongue_tip_position() -> Vector2:
	return tongue_tip

# ─── 更新（JSの chameleon.update() 相当） ────────────────────
func update_chameleon(delta: float, current_bugs: Array) -> void:
	idle_time += 0.05

	# 1. 照準ロジック
	if has_mouse_target:
		var dx: float = mouse_target.x - PIVOT_X
		var dy: float = mouse_target.y - PIVOT_Y
		var desired: float = atan2(dy, dx)
		desired = clamp(desired, -PI * 0.6, PI * 0.1)
		target_angle = desired
	else:
		if keys_up or keys_left:
			target_angle -= 0.04
		if keys_down or keys_right:
			target_angle += 0.04
		target_angle = clamp(target_angle, ANGLE_MIN, ANGLE_MAX)

	# スムーズ回転
	var diff: float = target_angle - angle
	angle += diff * rotation_speed

	# 2. 目のトラッキング（最近接の虫を追う）
	if current_bugs.size() > 0:
		var nearest: Bug = null
		var min_dist: float = 9999.0
		for bug in current_bugs:
			if bug.state == "active":
				var d: float = Vector2(PIVOT_X, PIVOT_Y).distance_to(bug.position)
				if d < min_dist:
					min_dist = d
					nearest = bug
		if nearest:
			eye_target_angle = atan2(nearest.position.y - PIVOT_Y, nearest.position.x - PIVOT_X)
		else:
			eye_target_angle = angle
	else:
		eye_target_angle = angle

	# 3. 舌ステートマシン
	match tongue_state:
		"shooting":
			mouth_open = min(mouth_open + 0.25, 1.0)
			tongue_len += tongue_speed
			tongue_tip = Vector2(PIVOT_X, PIVOT_Y) + Vector2(cos(angle), sin(angle)) * tongue_len
			if tongue_len >= tongue_max_len \
				or tongue_tip.x < 0 or tongue_tip.x > CANVAS_W \
				or tongue_tip.y < 0 or tongue_tip.y > CANVAS_H:
					tongue_state = "retracting"

		"retracting":
			tongue_len -= tongue_speed * 0.8
			if tongue_len <= 0.0:
				tongue_len = 0.0
				tongue_state = "swallowing"
			tongue_tip = Vector2(PIVOT_X, PIVOT_Y) + Vector2(cos(angle), sin(angle)) * tongue_len
			if caught_bug:
				caught_bug.position = tongue_tip

		"swallowing":
			mouth_open = max(mouth_open - 0.15, 0.0)
			if mouth_open <= 0.0:
				tongue_state = "idle"
				if caught_bug:
					caught_bug.state = "eaten"
					caught_bug = null
				tongue_swallowed.emit()

		_: # idle
			tongue_len = 0.0
			tongue_tip = Vector2(PIVOT_X, PIVOT_Y)
			mouth_open = 0.0

	# アニメ変数
	if flash_frames > 0:
		flash_frames -= 1
	color_cycle += 0.05

	queue_redraw()

# ─── _process: 入力読み取り（MainSceneから直接呼ぶ場合は不要） ─
func _process(_delta: float) -> void:
	keys_up = Input.is_action_pressed("aim_up")
	keys_down = Input.is_action_pressed("aim_down")
	keys_left = Input.is_action_pressed("aim_left")
	keys_right = Input.is_action_pressed("aim_right")

# ─── 描画（JSの chameleon.draw(ctx) 相当） ───────────────────
func _draw() -> void:
	# --- カラーテーマ決定 ---
	var skin_color := Color(0.0, 0.941, 1.0)     # #00f0ff
	var belly_color := Color(1.0, 0.0, 0.498)    # #ff007f
	var dark_color := Color(0.0, 0.545, 0.639)   # #008ba3

	if power_up_active == "gold":
		skin_color = Color(1.0, 0.918, 0.0)       # #ffea00
		belly_color = Color(1.0, 0.667, 0.0)      # #ffaa00
		dark_color = Color(0.702, 0.525, 0.0)     # #b38600
	elif power_up_active == "multi":
		var speed: int = int(color_cycle * 5) % 3
		match speed:
			0:
				skin_color = Color(0.224, 1.0, 0.078)   # #39ff14
				belly_color = Color(0.722, 1.0, 0.722)   # #b8ffb8
				dark_color = Color(0.102, 0.600, 0.0)
			1:
				skin_color = Color(1.0, 0.0, 0.498)
				belly_color = Color(1.0, 0.722, 0.863)
				dark_color = Color(0.600, 0.0, 0.302)
			_:
				skin_color = Color(0.0, 0.941, 1.0)
				belly_color = Color(0.722, 1.0, 1.0)
				dark_color = Color(0.0, 0.545, 0.639)
	elif flash_frames > 0:
		if hurt_poison:
			skin_color = Color(0.749, 0.353, 0.949)  # #bf5af2
			belly_color = Color(0.224, 1.0, 0.078)
			dark_color = Color(0.357, 0.129, 0.714)
		else:
			skin_color = Color(1.0, 0.231, 0.188)    # #ff3b30
			belly_color = Color(1.0, 1.0, 1.0)
			dark_color = Color(0.502, 0.0, 0.0)

	# --- 枝（Branch）描画 ---
	draw_rect(Rect2(0, 185, 90, 8), Color(0.290, 0.173, 0.067))   # #4a2c11
	draw_rect(Rect2(0, 193, 80, 6), Color(0.188, 0.110, 0.039))   # #301c0a
	# 葉っぱ
	draw_rect(Rect2(70, 181, 6, 4), Color(0.106, 0.478, 0.153))   # #1b7a27
	draw_rect(Rect2(72, 177, 2, 4), Color(0.106, 0.478, 0.153))

	# --- しっぽ ---
	draw_rect(Rect2(CHAR_X - 24, CHAR_Y - 12, 10, 4), dark_color)
	draw_rect(Rect2(CHAR_X - 26, CHAR_Y - 8, 4, 10), dark_color)
	draw_rect(Rect2(CHAR_X - 22, CHAR_Y + 2, 10, 4), dark_color)
	draw_rect(Rect2(CHAR_X - 20, CHAR_Y - 10, 8, 4), skin_color)
	draw_rect(Rect2(CHAR_X - 24, CHAR_Y - 6, 4, 8), skin_color)
	draw_rect(Rect2(CHAR_X - 20, CHAR_Y + 2, 8, 2), skin_color)

	# --- 胴体（呼吸アニメ） ---
	var breathing: float = sin(idle_time * 2.0) * 1.5
	draw_rect(Rect2(CHAR_X - 14, CHAR_Y - 14 + breathing, 22, 18 - breathing), skin_color)
	draw_rect(Rect2(CHAR_X - 8, CHAR_Y - 8 + breathing, 12, 10 - breathing), belly_color)

	# --- 足 ---
	draw_rect(Rect2(CHAR_X + 2, CHAR_Y + 4, 4, 8), dark_color)
	draw_rect(Rect2(CHAR_X + 4, CHAR_Y + 10, 6, 2), dark_color)
	draw_rect(Rect2(CHAR_X - 12, CHAR_Y + 4, 4, 8), dark_color)
	draw_rect(Rect2(CHAR_X - 14, CHAR_Y + 10, 6, 2), dark_color)

	# --- 背中のトゲ ---
	draw_rect(Rect2(CHAR_X - 12, CHAR_Y - 18 + breathing, 4, 4), belly_color)
	draw_rect(Rect2(CHAR_X - 4, CHAR_Y - 18 + breathing, 4, 4), belly_color)
	draw_rect(Rect2(CHAR_X + 4, CHAR_Y - 16 + breathing, 3, 3), belly_color)

	# --- 頭部（回転する部分）---
	# JSの ctx.translate(pivotX, pivotY); ctx.rotate(angle) に相当
	draw_set_transform(Vector2(PIVOT_X, PIVOT_Y), angle)

	# 舌は頭の座標系で描く（頭より奥に描く）
	if tongue_state in ["shooting", "retracting", "swallowing"]:
		_draw_tongue_local(skin_color)

	# 頭部本体（ピボット相対座標）
	draw_rect(Rect2(-10, -12, 22, 20), skin_color)   # メイン頭
	draw_rect(Rect2(-14, -14, 12, 4), skin_color)    # クラウン
	draw_rect(Rect2(-12, -18, 6, 4), skin_color)     # 頭頂部トゲ

	# 口（開閉アニメ）
	if mouth_open > 0.1:
		draw_rect(Rect2(4, -4, 10, 6 * mouth_open), Color(0.502, 0.0, 0.188))  # 口内
		draw_rect(Rect2(4, -10, 10, 6), skin_color)   # 上顎
		draw_rect(Rect2(2, 2 + 6 * mouth_open, 10, 4), skin_color)  # 下顎
	else:
		draw_rect(Rect2(6, -2, 8, 2), dark_color)     # 閉じた口

	# 目（黄色の虹彩）
	var eye_yellow := Color(1.0, 0.918, 0.0)  # #ffea00
	draw_rect(Rect2(-4, -8, 7, 7), eye_yellow)

	# 瞳孔（最近接バグ方向に向く）
	var eye_rel_angle: float = eye_target_angle - angle
	var pupil_x: int = roundi(-1.0 + cos(eye_rel_angle) * 1.2)
	var pupil_y: int = roundi(-5.0 + sin(eye_rel_angle) * 1.2)
	draw_rect(Rect2(pupil_x, pupil_y, 2, 2), Color(0, 0, 0))

	# 座標変換をリセット
	draw_set_transform(Vector2.ZERO)

# ─── 舌の描画（頭部のローカル座標系で描く） ─────────────────
func _draw_tongue_local(skin_color_ref: Color) -> void:
	# 舌の色テーマ
	var tongue_color := Color(1.0, 0.0, 0.498)   # #ff007f
	var tip_color := Color(1.0, 1.0, 1.0)
	if power_up_active == "gold":
		tongue_color = Color(1.0, 0.918, 0.0)    # #ffea00

	# グロウ効果：太い半透明ライン → 細いラインの順で重ね描き
	draw_line(Vector2.ZERO, Vector2(tongue_len, 0.0),
		Color(tongue_color.r, tongue_color.g, tongue_color.b, 0.4), 9.0, true)
	draw_line(Vector2.ZERO, Vector2(tongue_len, 0.0), tongue_color, 4.0, true)
	draw_line(Vector2.ZERO, Vector2(tongue_len, 0.0), tip_color, 2.0, true)

	# 舌先の球
	draw_rect(Rect2(tongue_len - 4, -4, 8, 8), tongue_color)
	draw_rect(Rect2(tongue_len - 2, -2, 4, 4), tip_color)

	# multi パワーアップ：2本の追加舌
	if power_up_active == "multi":
		var ghost_color := Color(0.0, 0.941, 1.0, 0.8)  # #00f0ff
		for ang_offset in [-0.25, 0.25]:
			var tip_x: float = cos(ang_offset) * tongue_len
			var tip_y: float = sin(ang_offset) * tongue_len
			draw_line(Vector2.ZERO, Vector2(tip_x, tip_y), ghost_color, 3.0, true)
			draw_rect(Rect2(tip_x - 3, tip_y - 3, 6, 6), ghost_color)

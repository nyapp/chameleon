## Bug.gd
## JSの class Bug に対応。
## Node2D として BugContainer の子に配置され、自身で移動・描画を行う。

extends Node2D
class_name Bug

# ─── 虫タイプ定義（JSの Bug.TYPE_META 相当） ─────────────────
const TYPE_META: Dictionary = {
	"common": {
		"score_value": 100,
		"energy_value": 15.0,
		"color": Color(0.627, 0.627, 0.627),  # #a0a0a0
		"size": 4,
		"label_ja": "普通のハエ",
		"tag": "",
	},
	"gnat": {
		"score_value": 300,
		"energy_value": 25.0,
		"color": Color(1.0, 0.918, 0.0),  # #ffea00
		"size": 3,
		"label_ja": "金の羽虫",
		"tag": "高速",
	},
	"firefly": {
		"score_value": 200,
		"energy_value": 15.0,
		"color": Color(0.0, 0.941, 1.0),  # #00f0ff
		"size": 4,
		"label_ja": "ホタル",
		"tag": "パワーアップ",
	},
	"wasp": {
		"score_value": -200,
		"energy_value": -25.0,
		"color": Color(0.749, 0.353, 0.949),  # #bf5af2
		"size": 5,
		"label_ja": "毒ハチ",
		"tag": "毒・ダメージ",
	},
}

# ─── インスタンス変数 ────────────────────────────────────────
var bug_type: String = "common"
var state: String = "active"  # "active" | "caught" | "eaten"

var vx: float = 0.0
var vy: float = 0.0
var time_offset: float = 0.0
var wing_frame: int = 0
var wing_timer: float = 0.0

# タイプ別プロパティ（TYPE_METAから引く）
var score_value: int = 0
var energy_value: float = 0.0
var size: int = 4

# キャンバスサイズ（スポーン計算用）
const CANVAS_W: int = 256
const CANVAS_H: int = 240

# ─── 初期化 ─────────────────────────────────────────────────
func setup(p_type: String) -> void:
	bug_type = p_type
	if not TYPE_META.has(p_type):
		bug_type = "common"
	var meta: Dictionary = TYPE_META[bug_type]
	score_value = meta["score_value"]
	energy_value = meta["energy_value"]
	size = meta["size"]
	respawn()

# ─── スポーン（JSの respawn() 相当） ─────────────────────────
func respawn() -> void:
	state = "active"
	time_offset = randf() * 100.0

	var side: String = "right" if randf() > 0.4 else "top"

	if side == "right":
		position.x = CANVAS_W + 10.0
		position.y = randf() * (CANVAS_H - 90.0) + 20.0
		match bug_type:
			"gnat":
				vx = -(2.2 + randf() * 1.5)
				vy = 0.0
			"wasp":
				vx = -(1.2 + randf() * 0.8)
				vy = 0.0
			_:
				vx = -(1.0 + randf() * 0.8)
				vy = 0.0
	else:
		position.x = randf() * (CANVAS_W - 80.0) + 60.0
		position.y = -10.0
		vx = -(0.5 + randf() * 0.8)
		vy = 0.6 + randf() * 1.0

	# firefly は特殊パターン
	if bug_type == "firefly":
		vx = -(0.6 + randf() * 0.6)
		vy = (randf() - 0.5) * 0.5

# ─── 毎フレーム更新（JSの bug.update() 相当） ────────────────
func update_movement(delta: float) -> void:
	if state == "caught":
		# 舌先に位置はchameleon.gdが制御するので移動しない
		return

	var step: float = GameState.scale60(delta)

	time_offset += 0.08 * step

	# 羽ばたきアニメーション（JSの wingFrame 切り替え相当）
	wing_timer += delta
	if wing_timer > 0.08:
		wing_timer = 0.0
		wing_frame = 1 - wing_frame

	# タイプ別移動（JSのswitch文と同一ロジック）
	match bug_type:
		"common":
			position.x += vx * step
			position.y += sin(time_offset) * 0.8 * step
		"gnat":
			position.x += vx * step
			position.y += (vy + cos(time_offset * 2.5) * 2.2) * step
		"firefly":
			position.x += vx * step
			position.y += (vy + sin(time_offset) * 1.2) * step
		"wasp":
			position.x += vx * step
			position.y += sin(time_offset * 1.5) * 1.5 * step
			if randf() < 0.02 * step:
				vx = -(1.5 + randf() * 1.5)

	# 画面外チェック → respawn
	if position.x < -15.0 or position.y > CANVAS_H + 15.0 or position.y < -15.0:
		respawn()

	queue_redraw()

# ─── 描画（JSの Bug.drawSprite() 相当、_draw() で呼ばれる） ──
func _draw() -> void:
	if state == "eaten":
		return
	_draw_sprite()

func _draw_sprite() -> void:
	match bug_type:
		"common":
			draw_rect(Rect2(-1, -1, 2, 2), Color(0.110, 0.110, 0.110))  # #1c1c1c
			draw_rect(Rect2(1, -1, 2, 2), Color(1.0, 0.231, 0.188))     # #ff3b30
			if wing_frame == 0:
				draw_rect(Rect2(-4, -5, 2, 3), Color(0.863, 0.863, 0.863))
				draw_rect(Rect2(-1, -5, 2, 3), Color(0.863, 0.863, 0.863))
			else:
				draw_rect(Rect2(-5, -3, 3, 2), Color(0.863, 0.863, 0.863))
				draw_rect(Rect2(-2, -3, 3, 2), Color(0.863, 0.863, 0.863))

		"gnat":
			draw_rect(Rect2(-1, -1, 2, 2), Color(0.702, 0.525, 0.0))   # #b38600
			draw_rect(Rect2(0, 0, 1, 1), Color(1.0, 0.918, 0.0))        # #ffea00
			if wing_frame == 0:
				draw_rect(Rect2(-3, -3, 2, 1), Color(1.0, 0.918, 0.0))
				draw_rect(Rect2(1, -3, 2, 1), Color(1.0, 0.918, 0.0))
			else:
				draw_rect(Rect2(-4, -1, 1, 2), Color(1.0, 0.918, 0.0))
				draw_rect(Rect2(2, -1, 1, 2), Color(1.0, 0.918, 0.0))

		"firefly":
			draw_rect(Rect2(-1, -1, 2, 2), Color(0.0, 0.784, 1.0))     # #00c8ff
			draw_rect(Rect2(-2, 1, 2, 1), Color(0.224, 1.0, 0.078))     # #39ff14
			if wing_frame == 0:
				draw_rect(Rect2(-3, -3, 2, 1), Color(1.0, 1.0, 1.0))
				draw_rect(Rect2(1, -3, 2, 1), Color(1.0, 1.0, 1.0))
			else:
				draw_rect(Rect2(-4, -1, 1, 2), Color(1.0, 1.0, 1.0))
				draw_rect(Rect2(2, -1, 1, 2), Color(1.0, 1.0, 1.0))

		"wasp":
			# 翼（半透明）
			var wing_color := Color(0.616, 0.0, 1.0, 0.4)
			if wing_frame == 0:
				draw_rect(Rect2(-3, -6, 3, 4), wing_color)
				draw_rect(Rect2(1, -6, 3, 4), wing_color)
			else:
				draw_rect(Rect2(-5, -4, 2, 3), wing_color)
				draw_rect(Rect2(3, -4, 2, 3), wing_color)
			# 胴体（紫縞）
			var purple := Color(0.749, 0.353, 0.949)  # #bf5af2
			draw_rect(Rect2(-4, -1, 3, 3), purple)
			draw_rect(Rect2(-1, -1, 3, 3), purple)
			draw_rect(Rect2(2, -1, 3, 3), purple)
			draw_rect(Rect2(-2, -1, 1, 3), Color(0.102, 0.039, 0.180))  # #1a0a2e
			draw_rect(Rect2(1, -1, 1, 3), Color(0.102, 0.039, 0.180))
			# 頭
			draw_rect(Rect2(4, -1, 2, 2), Color(0.486, 0.227, 0.929))   # #7c3aed
			draw_rect(Rect2(4, -1, 1, 1), Color(0.224, 1.0, 0.078))     # #39ff14
			draw_rect(Rect2(5, 0, 1, 1), Color(0.224, 1.0, 0.078))
			# 針
			draw_rect(Rect2(-6, 0, 2, 1), Color(0.224, 1.0, 0.078))
			draw_rect(Rect2(-7, 1, 1, 1), Color(0.0, 1.0, 0.255))       # #00ff41
			draw_rect(Rect2(-6, 2, 1, 1), Color(0.0, 1.0, 0.255))
			# ドクロマーク
			draw_rect(Rect2(-3, 0, 1, 1), Color(0.224, 1.0, 0.078))
			draw_rect(Rect2(-1, 0, 1, 1), Color(0.224, 1.0, 0.078))

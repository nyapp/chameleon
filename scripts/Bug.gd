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
		"size": 4,
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
var _trail: Array[Vector2] = []
var _trail_timer: float = 0.0
var _powder_spots: Array[Dictionary] = []
var _powder_spawn_timer: float = 0.0

# タイプ別プロパティ（TYPE_METAから引く）
var score_value: int = 0
var energy_value: float = 0.0
var size: int = 4

# キャンバスサイズ（スポーン計算用）
const CANVAS_W: int = 256
const CANVAS_H: int = 240
const TRAIL_MAX: int = 5
const TRAIL_MIN_DIST: float = 1.5
const TRAIL_INTERVAL: float = 0.06
const _TRAIL_ALPHAS: Array[float] = [0.18, 0.28, 0.38, 0.48, 0.58]
const WASP_POWDER_MAX: int = 56
const WASP_POWDER_LIFETIME: float = 1.6
const WASP_POWDER_SPAWN_INTERVAL: float = 0.04
const _WASP_POWDER_PURPLE := Color(0.486, 0.227, 0.929)
const _WASP_POWDER_TOXIN := Color(0.224, 1.0, 0.078)

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
	_trail.clear()
	_trail_timer = 0.0
	_powder_spots.clear()
	_powder_spawn_timer = 0.0

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
		if bug_type == "wasp":
			_update_wasp_powder(delta, false)
			queue_redraw()
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
	else:
		_update_trail(delta)
		if bug_type == "wasp":
			_update_wasp_powder(delta, true)

	queue_redraw()

func _update_wasp_powder(delta: float, spawn: bool) -> void:
	for i in range(_powder_spots.size() - 1, -1, -1):
		_powder_spots[i]["age"] = float(_powder_spots[i]["age"]) + delta
		if float(_powder_spots[i]["age"]) >= WASP_POWDER_LIFETIME:
			_powder_spots.remove_at(i)

	if not spawn or state != "active":
		return

	_powder_spawn_timer += delta
	if _powder_spawn_timer < WASP_POWDER_SPAWN_INTERVAL:
		return
	_powder_spawn_timer = 0.0
	_spawn_wasp_powder()

func _spawn_wasp_powder() -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return

	var base_pos := parent.to_local(global_position)
	var drift := Vector2(-3.0, 0.0) if vx <= 0.0 else Vector2(3.0, 0.0)
	for _i in 2:
		_powder_spots.append({
			"pos": base_pos + drift + Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0)),
			"age": 0.0,
			"kind": randi() % 3,
		})
	while _powder_spots.size() > WASP_POWDER_MAX:
		_powder_spots.pop_front()

func _update_trail(delta: float) -> void:
	if GameState.power_up_type != "slow" or state != "active":
		_trail.clear()
		_trail_timer = 0.0
		return
	_trail_timer += delta
	var moved_enough: bool = _trail.is_empty() or position.distance_to(_trail[0]) >= TRAIL_MIN_DIST
	if moved_enough or _trail_timer >= TRAIL_INTERVAL:
		_trail.insert(0, position)
		_trail_timer = 0.0
		while _trail.size() > TRAIL_MAX:
			_trail.pop_back()

# ─── 描画（JSの Bug.drawSprite() 相当、_draw() で呼ばれる） ──
func _draw() -> void:
	if state == "eaten":
		return
	_draw_trail()
	if bug_type == "wasp":
		_draw_wasp_powder()
	_draw_sprite()

func _draw_trail() -> void:
	if _trail.is_empty():
		return
	for i in _trail.size():
		var alpha: float = _TRAIL_ALPHAS[i] if i < _TRAIL_ALPHAS.size() else _TRAIL_ALPHAS[-1]
		draw_set_transform(_trail[i] - position, 0.0, Vector2.ONE)
		_draw_sprite_with_alpha(alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _slow_mo_color(color: Color, alpha_mul: float = 1.0) -> Color:
	var c := GameState.desaturate_color(color, GameState.slow_mo_visual_blend)
	if alpha_mul != 1.0:
		c.a *= alpha_mul
	return c

func _draw_wasp_powder() -> void:
	var parent := get_parent() as Node2D
	if parent == null or _powder_spots.is_empty():
		return

	for spot in _powder_spots:
		var age: float = float(spot["age"])
		var life_t := age / WASP_POWDER_LIFETIME
		var alpha := (1.0 - life_t) * (1.0 - life_t) * 0.48
		if alpha < 0.04:
			continue

		var local := to_local(parent.to_global(spot["pos"]))
		var kind: int = int(spot["kind"])
		var col := _WASP_POWDER_TOXIN if kind == 0 else _WASP_POWDER_PURPLE
		var px := floori(local.x)
		var py := floori(local.y)
		draw_rect(
			Rect2(px, py, 1, 1),
			_slow_mo_color(Color(col.r, col.g, col.b, alpha))
		)
		if kind != 1:
			draw_rect(
				Rect2(px + 1, py, 1, 1),
				_slow_mo_color(Color(col.r, col.g, col.b, alpha * 0.55))
			)
		if kind == 2:
			draw_rect(
				Rect2(px, py + 1, 1, 1),
				_slow_mo_color(Color(col.r, col.g, col.b, alpha * 0.4))
			)

func _draw_sprite_with_alpha(alpha: float) -> void:
	BugGuideDraw.draw_bug_sprite(
		self,
		bug_type,
		Vector2.ZERO,
		wing_frame,
		alpha,
		GameState.slow_mo_visual_blend
	)

func _draw_sprite() -> void:
	_draw_sprite_with_alpha(1.0)

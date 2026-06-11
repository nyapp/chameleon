## GameState.gd
## Autoload Singleton — ゲーム全体の状態を管理する
## JSの GameEngine のメンバ変数のうち「永続的・横断的」なものをここに集約

extends Node

# ─── ゲーム状態 ────────────────────────────────────────────
## "TITLE" | "PLAYING" | "GAMEOVER" | "PAUSED"
var state: String = "TITLE"
var frozen_by_menu: bool = false
var bgm_paused_by_menu: bool = false

# ─── スコア・ゲームデータ ────────────────────────────────────
var score: int = 0
var flies_eaten: int = 0
var high_score: int = 0
var level: int = 1
var energy: float = 100.0
const ENERGY_DEPLETION_BASE: float = 0.06  # /frame @60fps

# ─── コンボシステム ─────────────────────────────────────────
var combo: int = 0
var combo_timer: float = 0.0
const MAX_COMBO_TIME: float = 2.5  # 秒（JSの150フレーム相当）

# ─── パワーアップ ────────────────────────────────────────────
## "" | "gold" | "multi" | "slow"
var power_up_type: String = ""
var power_up_time_left: float = 0.0  # 秒（JSの480フレーム = 8.0秒）
const POWER_UP_DURATION: float = 8.0

# ─── シグナル（Observer Pattern） ───────────────────────────
signal state_changed(new_state: String)
signal bug_eaten(bug_type: String, score_delta: int, energy_delta: float)
signal power_up_activated(power_type: String)
signal power_up_deactivated()
signal game_over_triggered()
signal level_up(new_level: int)
signal combo_updated(new_combo: int)

# ─── 初期化 ─────────────────────────────────────────────────
func _ready() -> void:
	load_high_score()

# ─── 状態遷移ヘルパー ────────────────────────────────────────
func set_state(new_state: String) -> void:
	state = new_state
	state_changed.emit(new_state)

func is_frozen() -> bool:
	return frozen_by_menu

func start_game() -> void:
	score = 0
	flies_eaten = 0
	level = 1
	energy = 100.0
	combo = 0
	combo_timer = 0.0
	power_up_type = ""
	power_up_time_left = 0.0
	set_state("PLAYING")

func trigger_game_over() -> void:
	if score > high_score:
		high_score = score
		save_high_score()
	set_state("GAMEOVER")
	game_over_triggered.emit()

# ─── コンボ処理 ──────────────────────────────────────────────
func increment_combo() -> void:
	combo += 1
	combo_timer = MAX_COMBO_TIME
	combo_updated.emit(combo)

func reset_combo() -> void:
	combo = 0
	combo_timer = 0.0
	combo_updated.emit(combo)

func tick_combo(delta: float) -> void:
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			reset_combo()

# ─── パワーアップ処理 ────────────────────────────────────────
func activate_power_up(power_type: String) -> void:
	power_up_type = power_type
	power_up_time_left = POWER_UP_DURATION
	power_up_activated.emit(power_type)

func deactivate_power_up() -> void:
	power_up_type = ""
	power_up_time_left = 0.0
	power_up_deactivated.emit()

func tick_power_up(delta: float) -> void:
	if power_up_type != "":
		power_up_time_left -= delta
		if power_up_time_left <= 0.0:
			deactivate_power_up()

# ─── レベルアップ判定 ────────────────────────────────────────
func check_level_up() -> bool:
	## スコア1200点ごとにレベルアップ（JSと同一ロジック）
	var target_level: int = int(score / 1200) + 1
	if target_level > level:
		level = target_level
		level_up.emit(level)
		return true
	return false

# ─── スコア加算 ──────────────────────────────────────────────
func add_score(base_value: int) -> int:
	## コンボ乗算を適用してスコア加算
	var reward: int = base_value * max(combo, 1)
	score += reward
	return reward

# ─── HighScore 永続化（JSの localStorage 相当） ──────────────
const SAVE_PATH: String = "user://neo_chameleon_save.cfg"

func save_high_score() -> void:
	var config := ConfigFile.new()
	config.set_value("score", "high_score", high_score)
	config.save(SAVE_PATH)

func load_high_score() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		high_score = config.get_value("score", "high_score", 0)
	else:
		high_score = 0

# ─── エネルギー更新 ──────────────────────────────────────────
func tick_energy(delta: float) -> bool:
	## delta補正で60fps非依存。falseを返したらゲームオーバー
	var depletion: float = (ENERGY_DEPLETION_BASE + (level - 1) * 0.008) * delta * 60.0
	energy = max(0.0, energy - depletion)
	return energy > 0.0

func add_energy(amount: float) -> void:
	energy = min(100.0, energy + amount)

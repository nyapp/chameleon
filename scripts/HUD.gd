## HUD.gd
## JSの drawHUD(), drawTitleScreen(), drawGameOverScreen(), drawPausedOverlay() 相当。
## CanvasLayer 上の Control ノードとして機能し、ゲーム画面に重なるUI全体を管理する。

extends CanvasLayer

const CANVAS_W: int = 256
const CANVAS_H: int = 240

# ─── 子ノード参照 ────────────────────────────────────────────
@onready var _draw_node: Node2D = $HUDDraw
@onready var _overlay: Node2D = $OverlayDraw
@onready var _warning: Node2D = $WarningDraw

# ─── 状態キャッシュ（MainSceneから毎フレーム更新） ────────────
var score: int = 0
var high_score: int = 0
var level: int = 1
var energy: float = 100.0
var combo: int = 0
var combo_timer: float = 0.0
var power_up_type: String = ""
var power_up_time_left: float = 0.0
var level_up_banner_frames: int = 0
var game_state: String = "TITLE"
var is_frozen: bool = false

func _process(_delta: float) -> void:
	# GameStateから最新値を取得
	score = GameState.score
	high_score = GameState.high_score
	level = GameState.level
	energy = GameState.energy
	combo = GameState.combo
	combo_timer = GameState.combo_timer
	power_up_type = GameState.power_up_type
	power_up_time_left = GameState.power_up_time_left
	game_state = GameState.state
	is_frozen = GameState.is_frozen()

	_draw_node.queue_redraw()
	_overlay.queue_redraw()
	_warning.queue_redraw()

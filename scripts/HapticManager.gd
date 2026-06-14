## HapticManager.gd
## Autoload Singleton — iOS Taptic Engine (godot-haptics) ラッパー。
## プラグイン未リンク時は Input.vibrate_handheld() にフォールバック。

extends Node

signal haptics_toggled(enabled: bool)

const SAVE_PATH: String = "user://neo_chameleon_save.cfg"

# ポーズメニューのボタン当たり判定（256x240 ゲーム座標）
const PAUSE_HAPTICS_BTN := Rect2(56.0, 96.0, 144.0, 20.0)
const PAUSE_RESUME_BTN := Rect2(56.0, 120.0, 144.0, 20.0)
const PAUSE_TITLE_BTN := Rect2(56.0, 144.0, 144.0, 20.0)

var haptics_enabled: bool = true

var _haptics: Object = null
var _plugin_checked: bool = false

func _ready() -> void:
	_load_settings()
	_refresh_plugin()

func _refresh_plugin() -> void:
	_plugin_checked = true
	if Engine.has_singleton("Haptics"):
		_haptics = Engine.get_singleton("Haptics")

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		haptics_enabled = config.get_value("haptics", "haptics_enabled", true)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("haptics", "haptics_enabled", haptics_enabled)
	config.save(SAVE_PATH)

func set_haptics_enabled(enabled: bool) -> void:
	if haptics_enabled == enabled:
		return
	haptics_enabled = enabled
	_save_settings()
	haptics_toggled.emit(haptics_enabled)
	if haptics_enabled:
		_play("light")

func contains_pause_haptics_button(local_pos: Vector2) -> bool:
	return PAUSE_HAPTICS_BTN.has_point(local_pos)

func contains_pause_resume_button(local_pos: Vector2) -> bool:
	return PAUSE_RESUME_BTN.has_point(local_pos)

func contains_pause_title_button(local_pos: Vector2) -> bool:
	return PAUSE_TITLE_BTN.has_point(local_pos)

func play_shoot() -> void:
	_play("light")

func play_eat() -> void:
	_play("light")

func play_hurt() -> void:
	_play("heavy")

func play_powerup() -> void:
	_play("medium")

func play_game_over() -> void:
	_play("heavy")

func play_ui_tap() -> void:
	_play("light")

func is_plugin_available() -> bool:
	if not _plugin_checked:
		_refresh_plugin()
	return _haptics != null

func _play(kind: String) -> void:
	if not haptics_enabled:
		return
	if not _plugin_checked:
		_refresh_plugin()
	if _haptics != null:
		match kind:
			"light":
				_haptics.light()
			"medium":
				_haptics.medium()
			"heavy":
				_haptics.heavy()
		return
	_fallback_vibrate(kind)

func _fallback_vibrate(kind: String) -> void:
	var os_name: String = OS.get_name()
	if os_name not in ["iOS", "Android", "Web"]:
		return
	var duration_ms: int
	var amplitude: float
	match kind:
		"light":
			duration_ms = 15
			amplitude = 0.35
		"medium":
			duration_ms = 30
			amplitude = 0.6
		"heavy":
			duration_ms = 50
			amplitude = 1.0
	Input.vibrate_handheld(duration_ms, amplitude)

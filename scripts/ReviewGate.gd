## ReviewGate.gd
## Autoload — App Store レビュー依頼の発火条件を管理する。
## 実際の StoreKit 呼び出しは iOS プラグイン AppReview に委譲する。

extends Node

const SAVE_PATH: String = "user://neo_chameleon_save.cfg"
const MIN_GAME_OVER_COUNT: int = 3
const REQUEST_DELAY_SEC: float = 0.8
const COOLDOWN_SEC: float = 90.0 * 24.0 * 60.0 * 60.0

var _plugin: Object = null
var _plugin_checked: bool = false
var _request_queued: bool = false

func maybe_request(is_new_high_score: bool) -> void:
	var count: int = _load_game_over_count() + 1
	_save_game_over_count(count)

	var debug_relaxed: bool = OS.is_debug_build()
	var min_count: int = 1 if debug_relaxed else MIN_GAME_OVER_COUNT

	print("[ReviewGate] game_over#=%d high_score=%s debug=%s plugin=%s" % [
		count, is_new_high_score, debug_relaxed, _ensure_plugin()
	])

	if count < min_count:
		print("[ReviewGate] skip: need %d game overs" % min_count)
		return
	if not is_new_high_score:
		print("[ReviewGate] skip: not a new high score")
		return
	if OS.get_name() != "iOS":
		print("[ReviewGate] skip: OS=%s" % OS.get_name())
		return
	if not _ensure_plugin():
		print("[ReviewGate] skip: AppReview singleton missing")
		return

	var app_version: String = _plugin_app_version()
	if not debug_relaxed and _load_last_requested_version() == app_version:
		print("[ReviewGate] skip: already requested for version %s" % app_version)
		return

	var last_at: int = _load_last_requested_at()
	if not debug_relaxed and last_at > 0 and (Time.get_unix_time_from_system() - last_at) < COOLDOWN_SEC:
		print("[ReviewGate] skip: cooldown active")
		return

	if _request_queued:
		print("[ReviewGate] skip: already queued")
		return
	_request_queued = true

	# 本番のみ「呼んだ時点」で記録。Debug は何度でも試せる
	if not debug_relaxed:
		_save_last_requested_version(app_version)
		_save_last_requested_at(int(Time.get_unix_time_from_system()))

	print("[ReviewGate] requesting review in %.1fs (version=%s)" % [REQUEST_DELAY_SEC, app_version])
	await get_tree().create_timer(REQUEST_DELAY_SEC).timeout
	if _ensure_plugin():
		_plugin.request_review()
		print("[ReviewGate] request_review() called")
	else:
		print("[ReviewGate] plugin lost before request")
	_request_queued = false

func is_plugin_available() -> bool:
	return _ensure_plugin()

## テスト用: レビュー依頼の永続状態を消す（アプリ削除と同じ）
func reset_review_state() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("review", "game_over_count", 0)
	config.set_value("review", "last_requested_version", "")
	config.set_value("review", "last_requested_at", 0)
	config.save(SAVE_PATH)
	print("[ReviewGate] review state reset")

func _ensure_plugin() -> bool:
	if not _plugin_checked:
		_plugin_checked = true
		if Engine.has_singleton("AppReview"):
			_plugin = Engine.get_singleton("AppReview")
	return _plugin != null

func _plugin_app_version() -> String:
	if _plugin != null and _plugin.has_method("get_app_version"):
		var version: Variant = _plugin.get_app_version()
		if typeof(version) == TYPE_STRING and str(version) != "":
			return str(version)
	return str(ProjectSettings.get_setting("application/config/version", "1.0"))

func _load_game_over_count() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0
	return int(config.get_value("review", "game_over_count", 0))

func _save_game_over_count(count: int) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("review", "game_over_count", count)
	config.save(SAVE_PATH)

func _load_last_requested_version() -> String:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return ""
	return str(config.get_value("review", "last_requested_version", ""))

func _save_last_requested_version(version: String) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("review", "last_requested_version", version)
	config.save(SAVE_PATH)

func _load_last_requested_at() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0
	return int(config.get_value("review", "last_requested_at", 0))

func _save_last_requested_at(unix_time: int) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("review", "last_requested_at", unix_time)
	config.save(SAVE_PATH)

## AudioManager.gd
## Autoload Singleton — JSの class RetroAudio を移植。
## SFXはGodotのAudioStreamGeneratorで波形を動的生成。
## BGMはステップシーケンサーパターンで _process() ベースに変換。

extends Node

signal music_toggled(enabled: bool)
signal sfx_toggled(enabled: bool)

const SAMPLE_RATE: int = 22050       # 軽量な低サンプルレート
const TEMPO: int = 120
const STEP_TIME: float = 60.0 / TEMPO / 2.0  # 8分音符（0.25秒）

const DEFAULT_MASTER_BGM_VOLUME: float = 0.8
const DEFAULT_MASTER_SFX_VOLUME: float = 0.4
const DEFAULT_BGM_BASS_VOLUME: float = 0.10
const DEFAULT_BGM_LEAD_VOLUME: float = 0.06
const DEFAULT_BGM_SNARE_VOLUME: float = 0.05
const DEFAULT_BGM_HIHAT_VOLUME: float = 0.01
const DEFAULT_SFX_SHOOT_VOLUME: float = 0.8
const DEFAULT_SFX_EAT_VOLUME: float = 0.8
const DEFAULT_SFX_HURT_VOLUME: float = 0.8
const DEFAULT_SFX_POWERUP_VOLUME: float = 0.05
const DEFAULT_SFX_GAME_OVER_VOLUME: float = 0.08

# ─── BGM シーケンスデータ（JSと同一） ────────────────────────
const BASSLINE: Array = [
	55.0, 55.0, 55.0, 55.0, 65.41, 65.41, 65.41, 65.41,
	73.42, 73.42, 73.42, 73.42, 58.27, 58.27, 58.27, 58.27
]
const LEAD_MELODY: Array = [
	440.0, 0.0, 493.88, 523.25, 587.33, 0.0, 523.25, 493.88,
	349.23, 0.0, 392.00, 440.0, 523.25, 0.0, 493.88, 440.0,
	392.00, 0.0, 440.0, 493.88, 587.33, 0.0, 523.25, 493.88,
	440.0, 0.0, 523.25, 587.33, 659.25, 698.46, 587.33, 440.0
]

# ─── 設定 ────────────────────────────────────────────────────
var music_enabled: bool = true
var sfx_enabled: bool = true
var bgm_volume: float = 0.30       # 0.0〜1.0（JSの30%相当）
var sfx_volume: float = 0.50       # 0.0〜1.0
var is_bgm_playing: bool = false

# ─── BGMステップ状態 ─────────────────────────────────────────
var _bgm_step: int = 0
var _step_timer: float = 0.0

# ─── AudioStreamPlayerプール（SFX用） ────────────────────────
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8
var _sfx_pool_index: int = 0

# ─── BGMプール ───────────────────────────────────────────────
var _bgm_players: Array[AudioStreamPlayer] = []
const BGM_POOL_SIZE: int = 16
var _tuning: AudioTuning = null

# ─── 初期化 ─────────────────────────────────────────────────
func bind_tuning(tuning: AudioTuning) -> void:
	_tuning = tuning

func _master_bgm_volume() -> float:
	return _tuning.master_bgm_volume if _tuning else DEFAULT_MASTER_BGM_VOLUME

func _master_sfx_volume() -> float:
	return _tuning.master_sfx_volume if _tuning else DEFAULT_MASTER_SFX_VOLUME

func _bgm_bass_volume() -> float:
	return _tuning.bgm_bass_volume if _tuning else DEFAULT_BGM_BASS_VOLUME

func _bgm_lead_volume() -> float:
	return _tuning.bgm_lead_volume if _tuning else DEFAULT_BGM_LEAD_VOLUME

func _bgm_snare_volume() -> float:
	return _tuning.bgm_snare_volume if _tuning else DEFAULT_BGM_SNARE_VOLUME

func _bgm_hihat_volume() -> float:
	return _tuning.bgm_hihat_volume if _tuning else DEFAULT_BGM_HIHAT_VOLUME

func _sfx_shoot_volume() -> float:
	return _tuning.sfx_shoot_volume if _tuning else DEFAULT_SFX_SHOOT_VOLUME

func _sfx_eat_volume() -> float:
	return _tuning.sfx_eat_volume if _tuning else DEFAULT_SFX_EAT_VOLUME

func _sfx_hurt_volume() -> float:
	return _tuning.sfx_hurt_volume if _tuning else DEFAULT_SFX_HURT_VOLUME

func _sfx_powerup_volume() -> float:
	return _tuning.sfx_powerup_volume if _tuning else DEFAULT_SFX_POWERUP_VOLUME

func _sfx_game_over_volume() -> float:
	return _tuning.sfx_game_over_volume if _tuning else DEFAULT_SFX_GAME_OVER_VOLUME
func _ready() -> void:
	_build_sfx_pool()
	_build_bgm_pool()
	_load_settings()

func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		add_child(player)
		_sfx_players.append(player)

func _build_bgm_pool() -> void:
	for i in BGM_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "BGM" if AudioServer.get_bus_index("BGM") >= 0 else "Master"
		player.volume_db = linear_to_db(bgm_volume * _master_bgm_volume())
		add_child(player)
		_bgm_players.append(player)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://neo_chameleon_save.cfg") == OK:
		bgm_volume = config.get_value("audio", "bgm_volume", 0.30)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.50)
		music_enabled = config.get_value("audio", "music_enabled", true)
		sfx_enabled = config.get_value("audio", "sfx_enabled", true)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load("user://neo_chameleon_save.cfg")
	config.set_value("audio", "bgm_volume", bgm_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.save("user://neo_chameleon_save.cfg")

# ─── BGM ────────────────────────────────────────────────────
func start_bgm() -> void:
	if not music_enabled:
		return
	# ポーズメニュー由来の停止中は頭出しせず続きから再開する
	if GameState.bgm_paused_by_menu:
		resume_bgm()
		return
	if is_bgm_playing:
		return
	is_bgm_playing = true
	_bgm_step = 0
	_step_timer = 0.0

func stop_bgm() -> void:
	is_bgm_playing = false
	_stop_bgm_players()

func pause_bgm() -> void:
	if not is_bgm_playing:
		return
	is_bgm_playing = false
	_stop_bgm_players()

func resume_bgm() -> void:
	if not music_enabled or is_bgm_playing:
		return
	is_bgm_playing = true

func _stop_bgm_players() -> void:
	for player in _bgm_players:
		player.stop()

func _process(delta: float) -> void:
	if not is_bgm_playing:
		return
	_step_timer += delta
	if _step_timer >= STEP_TIME:
		_step_timer -= STEP_TIME
		_play_bgm_step()

func _play_bgm_step() -> void:
	# ベースライン（2ステップに1回）
	if _bgm_step % 2 == 0:
		var bass_freq: float = BASSLINE[(_bgm_step / 2) % BASSLINE.size()]
		_play_bgm_note(bass_freq, "sawtooth", 0.15, _bgm_bass_volume())

	# リードメロディ
	var lead_freq: float = LEAD_MELODY[_bgm_step % LEAD_MELODY.size()]
	if lead_freq > 0.0:
		_play_bgm_note(lead_freq, "square", 0.18, _bgm_lead_volume())

	# ノイズ系パーカッション
	if _bgm_step % 4 == 2:
		_play_bgm_noise(_bgm_snare_volume())
	elif _bgm_step % 2 == 0:
		_play_bgm_noise(_bgm_hihat_volume())

	_bgm_step += 1

# ─── SFX ─────────────────────────────────────────────────────
func play_shoot() -> void:
	if not sfx_enabled: return
	# triangle wave: 220Hz→1200Hz slide
	var stream := _make_sweep(220.0, 1200.0, 0.12, "triangle", _sfx_shoot_volume())
	_play_sfx(stream)

func play_eat() -> void:
	if not sfx_enabled: return
	# square wave: 600→300→150 stepdown
	var stream := _make_step_down([600.0, 300.0, 150.0], 0.04, 0.12, "square", _sfx_eat_volume())
	_play_sfx(stream)

func play_hurt() -> void:
	if not sfx_enabled: return
	# sawtooth: 400Hz→80Hz descend
	var stream := _make_sweep(400.0, 80.0, 0.35, "sawtooth", _sfx_hurt_volume())
	_play_sfx(stream)

func play_powerup() -> void:
	if not sfx_enabled: return
	# C major arpeggio
	var notes: Array = [261.63, 329.63, 392.0, 523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		var s: AudioStreamWAV = _make_tone(notes[i], "square", 0.12, _sfx_powerup_volume())
		var delay_timer := get_tree().create_timer(i * 0.05)
		delay_timer.timeout.connect(func(): _play_sfx(s))

func play_game_over() -> void:
	if not sfx_enabled: return
	var notes: Array = [392.0, 370.0, 349.23, 293.66, 220.0, 146.83]
	for i in notes.size():
		var s: AudioStreamWAV = _make_tone(notes[i], "square", 0.25, _sfx_game_over_volume())
		var delay_timer := get_tree().create_timer(i * 0.15)
		delay_timer.timeout.connect(func(): _play_sfx(s))

# ─── 設定変更API ─────────────────────────────────────────────
func set_music_enabled(enabled: bool) -> void:
	if music_enabled == enabled:
		return
	music_enabled = enabled
	if enabled:
		if GameState.state != "PAUSED":
			start_bgm()
	else:
		stop_bgm()
	_save_settings()
	music_toggled.emit(music_enabled)

func set_sfx_enabled(enabled: bool) -> void:
	if sfx_enabled == enabled:
		return
	sfx_enabled = enabled
	_save_settings()
	sfx_toggled.emit(sfx_enabled)

func set_bgm_volume(percent: float) -> void:
	bgm_volume = clamp(percent / 100.0, 0.0, 1.0)
	var db: float = linear_to_db(bgm_volume * _master_bgm_volume())
	for p in _bgm_players:
		p.volume_db = db
	_save_settings()

func set_sfx_volume(percent: float) -> void:
	sfx_volume = clamp(percent / 100.0, 0.0, 1.0)
	_save_settings()

# ─── 内部：AudioStreamWAV生成ユーティリティ ─────────────────
## ゲームサイズを抑えるため、PCMデータをGDScriptで動的生成する。

func _get_sfx_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _sfx_players[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	return player

func _play_sfx(stream: AudioStreamWAV) -> void:
	var player: AudioStreamPlayer = _get_sfx_player()
	player.volume_db = linear_to_db(sfx_volume * _master_sfx_volume())
	player.stream = stream
	player.play()

func _play_bgm_note(freq: float, wave: String, duration: float, volume: float) -> void:
	var stream: AudioStreamWAV = _make_tone(freq, wave, duration, volume)
	var player: AudioStreamPlayer = _bgm_players[_bgm_step % BGM_POOL_SIZE]
	player.volume_db = linear_to_db(bgm_volume * _master_bgm_volume() * volume)
	player.stream = stream
	player.play()

func _play_bgm_noise(volume: float) -> void:
	var stream: AudioStreamWAV = _make_noise(0.05, volume)
	var player: AudioStreamPlayer = _bgm_players[(_bgm_step + 8) % BGM_POOL_SIZE]
	player.volume_db = linear_to_db(bgm_volume * _master_bgm_volume() * volume)
	player.stream = stream
	player.play()

func _make_tone(freq: float, wave: String, duration: float, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)  # 16bit signed
	for i in sample_count:
		var t: float = float(i) / SAMPLE_RATE
		var phase: float = fmod(t * freq, 1.0)
		var sample_f: float = 0.0
		match wave:
			"square":
				sample_f = 1.0 if phase < 0.5 else -1.0
			"sawtooth":
				sample_f = 2.0 * phase - 1.0
			"triangle":
				sample_f = 1.0 - 4.0 * abs(phase - 0.5)
			_:
				sample_f = sin(TAU * phase)
		# エンベロープ（シンプルなリリース）
		var env: float = max(0.0, 1.0 - t / duration)
		var val: int = int(clamp(sample_f * env * volume * 32767.0, -32768.0, 32767.0))
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = SAMPLE_RATE
	return stream

func _make_sweep(start_freq: float, end_freq: float, duration: float, wave: String, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase: float = 0.0
	for i in sample_count:
		var t: float = float(i) / SAMPLE_RATE
		var freq: float = lerp(start_freq, end_freq, t / duration)
		phase = fmod(phase + freq / SAMPLE_RATE, 1.0)
		var sample_f: float = 0.0
		match wave:
			"square":
				sample_f = 1.0 if phase < 0.5 else -1.0
			"triangle":
				sample_f = 1.0 - 4.0 * abs(phase - 0.5)
			_:
				sample_f = 2.0 * phase - 1.0
		var env: float = max(0.0, 1.0 - t / duration)
		var val: int = int(clamp(sample_f * env * volume * 32767.0, -32768.0, 32767.0))
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = SAMPLE_RATE
	return stream

func _make_step_down(freqs: Array, step_dur: float, total_dur: float, wave: String, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * total_dur)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t: float = float(i) / SAMPLE_RATE
		var step_idx: int = min(int(t / step_dur), freqs.size() - 1)
		var freq: float = freqs[step_idx]
		var phase: float = fmod(t * freq, 1.0)
		var sample_f: float = 1.0 if phase < 0.5 else -1.0  # square
		var env: float = max(0.0, 1.0 - t / total_dur)
		var val: int = int(clamp(sample_f * env * volume * 32767.0, -32768.0, 32767.0))
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = SAMPLE_RATE
	return stream

func _make_noise(duration: float, volume: float) -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t: float = float(i) / SAMPLE_RATE
		var env: float = max(0.0, 1.0 - t / duration)
		var sample_f: float = randf_range(-1.0, 1.0)
		var val: int = int(clamp(sample_f * env * volume * 32767.0, -32768.0, 32767.0))
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = SAMPLE_RATE
	return stream

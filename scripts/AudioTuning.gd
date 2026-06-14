## AudioTuning.gd
## シーンドックでこのノードを選ぶと、インスペクタからBGM/SEの音量バランスを調整できる。

extends Node
class_name AudioTuning

@export_group("Master")
@export_range(0.0, 2.0, 0.01) var master_bgm_volume: float = 0.8
@export_range(0.0, 2.0, 0.01) var master_sfx_volume: float = 0.4

@export_group("BGM Parts")
@export_range(0.0, 1.0, 0.01) var bgm_bass_volume: float = 0.10
@export_range(0.0, 1.0, 0.01) var bgm_lead_volume: float = 0.06
@export_range(0.0, 1.0, 0.01) var bgm_snare_volume: float = 0.05
@export_range(0.0, 1.0, 0.01) var bgm_hihat_volume: float = 0.01

@export_group("SFX")
@export_range(0.0, 1.0, 0.01) var sfx_shoot_volume: float = 0.8
@export_range(0.0, 1.0, 0.01) var sfx_eat_volume: float = 0.8
@export_range(0.0, 1.0, 0.01) var sfx_hurt_volume: float = 0.8
@export_range(0.0, 1.0, 0.01) var sfx_powerup_volume: float = 0.05
@export_range(0.0, 1.0, 0.01) var sfx_game_over_volume: float = 0.08


func _ready() -> void:
	AudioManager.bind_tuning(self)

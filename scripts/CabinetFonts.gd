## CabinetFonts.gd (Autoload)
## HTML/CSS 版と同じ Press Start 2P / Share Tech Mono を提供する。

extends Node

const ARCADE_FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const MONO_FONT_PATH := "res://assets/fonts/ShareTechMono-Regular.ttf"

var arcade: FontFile
var mono: FontFile

func _ready() -> void:
	arcade = load(ARCADE_FONT_PATH) as FontFile
	mono = load(MONO_FONT_PATH) as FontFile

func arcade_or_fallback() -> Font:
	return arcade if arcade else ThemeDB.fallback_font

func mono_or_fallback() -> Font:
	return mono if mono else ThemeDB.fallback_font

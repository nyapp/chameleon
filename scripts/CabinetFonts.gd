## CabinetFonts.gd (Autoload)
## HTML/CSS 版と同じ Press Start 2P / Share Tech Mono を提供する。
## @tool スクリプトからは Autoload ノードではなく static メソッドを使うこと
## （エディタでは Autoload がプレースホルダーになりメソッド呼び出しが失敗する）。

@tool
extends Node

const ARCADE_FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"
const MONO_FONT_PATH := "res://assets/fonts/ShareTechMono-Regular.ttf"

const PRELOADED_ARCADE: Font = preload("res://assets/fonts/PressStart2P-Regular.ttf")
const PRELOADED_MONO: Font = preload("res://assets/fonts/ShareTechMono-Regular.ttf")

static func get_arcade_font() -> Font:
	return PRELOADED_ARCADE if PRELOADED_ARCADE else ThemeDB.fallback_font

static func get_mono_font() -> Font:
	return PRELOADED_MONO if PRELOADED_MONO else ThemeDB.fallback_font

func arcade_or_fallback() -> Font:
	return get_arcade_font()

func mono_or_fallback() -> Font:
	return get_mono_font()

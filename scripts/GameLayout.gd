## GameLayout.gd (Autoload)
## ビューポート全体のレイアウト定数（筐体 + ゲーム画面）
## style.css の .arcade-cabinet / .screen-outer / .gameboy-panel に合わせた寸法。

extends Node

# ゲーム画面（SubViewport 内）
const SCREEN_W: int = 256
const SCREEN_H: int = 240

# 後方互換エイリアス
const CANVAS_W: int = SCREEN_W
const PLAY_H: int = SCREEN_H

# 筐体パーツ（CSS 相当）
const CABINET_PAD: int = 15
const MARQUEE_H: int = 68
const MARQUEE_GAP: int = 15
const BEZEL_OUTER_PAD: int = 12
const BEZEL_INNER_PAD: int = 8
const BEZEL_STACK_PAD: int = BEZEL_OUTER_PAD + BEZEL_INNER_PAD  # 20
const CONTROL_GAP: int = 15
const CONTROL_DECK_H: int = 148
const CONTROL_DECK_HEADER_H: int = 22

const INNER_W: int = SCREEN_W + BEZEL_STACK_PAD * 2  # 296
const CABINET_W: int = INNER_W + CABINET_PAD * 2  # 326
const SCREEN_BEZEL_H: int = BEZEL_STACK_PAD * 2 + SCREEN_H  # 296
const CABINET_H: int = CABINET_PAD * 2 + MARQUEE_H + MARQUEE_GAP + SCREEN_BEZEL_H + CONTROL_GAP + CONTROL_DECK_H  # 572

# 筐体内 Y 座標
const Y_MARQUEE: int = CABINET_PAD
const Y_SCREEN: int = CABINET_PAD + MARQUEE_H + MARQUEE_GAP
const Y_CONTROL: int = Y_SCREEN + SCREEN_BEZEL_H + CONTROL_GAP

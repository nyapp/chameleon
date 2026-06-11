## GameLayout.gd (Autoload)
## ビューポート全体のレイアウト定数（筐体 + ゲーム画面）

extends Node

# ゲーム画面（SubViewport 内）
const SCREEN_W: int = 256
const SCREEN_H: int = 240

# 後方互換エイリアス
const CANVAS_W: int = SCREEN_W
const PLAY_H: int = SCREEN_H

# 筐体パーツ
const MARQUEE_H: int = 52
const BEZEL_PAD: int = 10
const CONTROL_DECK_H: int = 108
const CABINET_PAD: int = 14
const CONTROL_GAP: int = 10

const CABINET_W: int = SCREEN_W + BEZEL_PAD * 4  # 296
const CABINET_H: int = CABINET_PAD * 2 + MARQUEE_H + BEZEL_PAD * 2 + SCREEN_H + CONTROL_GAP + CONTROL_DECK_H  # 458

const INNER_W: int = CABINET_W - CABINET_PAD * 2  # 268
const SCREEN_BEZEL_H: int = BEZEL_PAD * 2 + SCREEN_H  # 260

# 筐体内 Y 座標
const Y_MARQUEE: int = CABINET_PAD
const Y_SCREEN: int = CABINET_PAD + MARQUEE_H
const Y_CONTROL: int = Y_SCREEN + SCREEN_BEZEL_H + CONTROL_GAP

## ControlPanel.gd
## 画面下部のコントロール帯背景（ColorRect で確実に描画）

extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2(0, GameLayout.PLAY_H)
	size = Vector2(GameLayout.CANVAS_W, GameLayout.CONTROL_H)

	var bg := ColorRect.new()
	bg.name = "Background"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.118, 0.118, 0.176, 1.0)  # #1e1e2d
	bg.z_index = -2
	add_child(bg)

	var top_line := ColorRect.new()
	top_line.name = "TopLine"
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_line.position = Vector2.ZERO
	top_line.size = Vector2(GameLayout.CANVAS_W, 1.0)
	top_line.color = Color(0.616, 0.0, 1.0, 1.0)  # #9d00ff
	top_line.z_index = -1
	add_child(top_line)

	# 背景を背面へ（スティックより手前に描画されないようにする）
	move_child(bg, 0)
	move_child(top_line, 1)

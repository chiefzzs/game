extends Node2D
## 简易主角色块绘制（V0.1 占位，V0.3替换为正式Sprite）
func _draw() -> void:
	draw_rect(Rect2(-14, -24, 28, 48), Color(0.9, 0.6, 0.3, 1), true)
	draw_rect(Rect2(-10, -20, 20, 16), Color(1, 0.82, 0.65, 1), true)
	draw_circle(Vector2(-4, -14), 1.8, Color.BLACK)
	draw_circle(Vector2(4, -14), 1.8, Color.BLACK)
	draw_line(Vector2(-3, -4), Vector2(3, -4), Color.BLACK, 1.2)

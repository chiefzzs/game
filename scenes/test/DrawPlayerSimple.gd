extends Node2D
## 简易主角色块绘制（V0.1 占位，V0.3替换为正式Sprite）
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var bob: float = sin(_t * 2.2) * 0.6
	draw_rect(Rect2(-14, -24 + bob, 28, 48), Color(0.9, 0.6, 0.3, 1), true)
	draw_rect(Rect2(-14, -24 + bob, 28, 48), Color(0.45, 0.25, 0.08, 1), false, 1.2)
	draw_rect(Rect2(-10, -20 + bob, 20, 16), Color(1, 0.82, 0.65, 1), true)
	draw_circle(Vector2(-4, -14 + bob), 1.8, Color.BLACK)
	draw_circle(Vector2(4, -14 + bob), 1.8, Color.BLACK)
	draw_line(Vector2(-3, -4 + bob), Vector2(3, -4 + bob), Color(0.4, 0.2, 0.05, 1), 1.2)

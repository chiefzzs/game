extends Node2D
## Draw a potion bottle (green/cyan)
func _draw() -> void:
	var bottle := Color(0.25, 0.9, 0.65, 1)
	var glass := Color(0.7, 1, 0.9, 1)
	draw_rect(Rect2(-9, -12, 18, 22), bottle, true)
	draw_rect(Rect2(-5, -16, 10, 5), Color(0.4, 0.24, 0.14, 1), true)
	draw_rect(Rect2(-9, -12, 18, 22), glass, false, 1.2)
	draw_circle(Vector2(-4, -4), 2.2, Color(1, 1, 1, 0.8))

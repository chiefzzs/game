extends Node2D
## Draw a gold coin (yellow circle with shine)
func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.84, 0.2, 1))
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.94, 0.55, 1))
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 18, Color(0.7, 0.52, 0.05, 1), 1.2)
	draw_line(Vector2(-4, -4), Vector2(2, 2), Color(1, 1, 0.9, 1), 1.6)

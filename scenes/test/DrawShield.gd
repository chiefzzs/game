extends Node2D
## Draw a shield in front of the player when blocking
func _draw() -> void:
	var main := Color(0.35, 0.55, 1.0, 0.95)
	var edge := Color(0.9, 0.95, 1, 1)
	draw_circle(Vector2.ZERO, 16.0, main)
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 20, edge, 1.8)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color(1, 1, 1, 0.75), 1.4)
	draw_line(Vector2(-9, 0), Vector2(9, 0), Color(1, 1, 1, 0.75), 1.4)

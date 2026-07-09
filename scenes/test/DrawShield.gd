extends Node2D
## Draw a shield in front of the player when blocking
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.7 + 0.3 * sin(_t * 4.0)
	var main := Color(0.35, 0.55, 1.0, 0.92 * pulse)
	var edge := Color(0.9, 0.95, 1, pulse)
	var shine := Color(1, 1, 1, 0.6 * pulse)
	draw_circle(Vector2.ZERO, 16.0, main)
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 20, edge, 1.8)
	draw_arc(Vector2.ZERO, 17.4, 0.1, 1.4, 14, shine, 1.8)
	draw_line(Vector2(0, -10), Vector2(0, 10), shine, 1.4)
	draw_line(Vector2(-9, 0), Vector2(9, 0), shine, 1.4)
	draw_circle(Vector2.ZERO, 5.5, Color(0.6, 0.8, 1.0, 0.8))

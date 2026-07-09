extends Node2D
## Draw a gold coin (yellow circle with shine) - bobs and spins
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var bob: float = sin(_t * 3.0) * 2.5
	var spin_phase: float = cos(_t * 2.4)
	var sx: float = 0.45 + 0.55 * abs(spin_phase)
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(sx, 1.0))
	draw_circle(Vector2.ZERO, 12.0, Color(0.72, 0.52, 0.04, 1))
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.84, 0.2, 1))
	draw_circle(Vector2.ZERO, 8.5, Color(1.0, 0.94, 0.55, 1))
	draw_line(Vector2(-5, -3), Vector2(1, 3), Color(1, 1, 0.9, 1), 1.8)
	if spin_phase > 0.0:
		draw_arc(Vector2.ZERO, 12.0, -0.6, 0.6, 8, Color(1, 1, 0.8, 0.7), 1.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

extends "res://scripts/characters/EnemyBase.gd"
class_name SlimeEnemy

func _ready() -> void:
	super._ready()
	display_name = "史莱姆·绿滴"
	max_hp = max(max_hp, 80)
	if hp <= 0:
		hp = max_hp
	add_to_group("enemy")
	queue_redraw()

func _draw() -> void:
	var body := Color(0.38, 0.84, 0.42)
	var body_dark := Color(0.28, 0.64, 0.32)
	var body_hl := Color(0.68, 1.0, 0.70)
	var eye_white := Color.WHITE
	var eye_pupil := Color.BLACK
	var mouth := Color(0.18, 0.42, 0.22)
	var blink_color := Color(1.0, 0.25, 0.25, 0.45)

	if flash_time > 0.0:
		draw_rect(Rect2(-24, -6, 48, 40), blink_color, true)

	if state == FSMState.DEAD:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-28, 32), Vector2(28, 32), Vector2(22, 12), Vector2(-22, 12)]),
			Color(0.25, 0.45, 0.28))
		draw_line(Vector2(-20, 20), Vector2(-8, 28), eye_pupil, 2.0)
		draw_line(Vector2(-8, 20), Vector2(-20, 28), eye_pupil, 2.0)
		draw_line(Vector2(8, 20), Vector2(20, 28), eye_pupil, 2.0)
		draw_line(Vector2(20, 20), Vector2(8, 28), eye_pupil, 2.0)
		return

	var body_shape: PackedVector2Array = PackedVector2Array([
		Vector2(-26, 32), Vector2(26, 32),
		Vector2(22, 4), Vector2(14, -18), Vector2(0, -28),
		Vector2(-14, -18), Vector2(-22, 4)])
	draw_colored_polygon(body_shape, body)

	var shadow: PackedVector2Array = PackedVector2Array([
		Vector2(-26, 32), Vector2(26, 32),
		Vector2(22, 24), Vector2(-22, 24)])
	draw_colored_polygon(shadow, body_dark)

	draw_circle(Vector2(-9 + 2.0 * facing, -8), 4.5, body_hl)

	draw_circle(Vector2(-10, 0), 6.0, eye_white)
	draw_circle(Vector2(10, 0), 6.0, eye_white)
	var pupil_offset := Vector2(facing * 2.0, 0.0)
	draw_circle(Vector2(-10, 0) + pupil_offset, 3.0, eye_pupil)
	draw_circle(Vector2(10, 0) + pupil_offset, 3.0, eye_pupil)

	var mouth_arr: PackedVector2Array = PackedVector2Array([
		Vector2(-7, 16), Vector2(7, 16), Vector2(3, 22), Vector2(-3, 22)])
	draw_colored_polygon(mouth_arr, mouth)

	if state == FSMState.ATTACK1:
		var arc: PackedVector2Array = PackedVector2Array([])
		for i in range(10):
			var ang: float = (-1.1 + float(i) * 0.26) * facing
			arc.append(Vector2(cos(ang) * 54.0, sin(ang) * 54.0 + 6.0))
		draw_polyline(arc, Color(0.48, 1.0, 0.52, 0.78), 4.0)

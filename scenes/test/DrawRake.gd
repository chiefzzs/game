extends Node2D
## Draw a farming rake (wooden handle + metal crossbar + 5 metal tines).
@export var held: bool = false
var _t: float = 0.0

func _process(delta: float) -> void:
	_t += delta
	if not held:
		queue_redraw()

func _draw() -> void:
	var float_off: float = 0.0 if held else sin(_t * 2.2) * 2.0
	var rot: float = 0.0 if held else sin(_t * 1.6) * 0.06
	draw_set_transform(Vector2(0, float_off), rot, Vector2.ONE)
	var wood := Color(0.42, 0.25, 0.08, 1)
	var wood_edge := Color(0.62, 0.38, 0.12, 1)
	var wood_cap := Color(0.55, 0.32, 0.1, 1)
	var metal := Color(0.72, 0.75, 0.78, 1)
	var metal_bright := Color(0.88, 0.9, 0.92, 1)
	var metal_dark := Color(0.38, 0.4, 0.42, 1)
	draw_rect(Rect2(-3, -44, 6, 54), wood, true)
	draw_rect(Rect2(-3, -44, 6, 54), wood_edge, false, 1.2)
	draw_rect(Rect2(-4, 8, 8, 4), wood_cap, true)
	draw_rect(Rect2(-4, 8, 8, 1), wood_edge, false, 1.0)
	draw_line(Vector2(-3.1, -6), Vector2(3.1, -6), Color(0.3, 0.18, 0.05, 0.9), 1.6)
	draw_line(Vector2(-3.1, 2), Vector2(3.1, 2), Color(0.3, 0.18, 0.05, 0.9), 1.6)
	draw_rect(Rect2(-20, -48, 40, 5), metal_dark, true)
	draw_rect(Rect2(-20, -48, 40, 2), metal, true)
	draw_rect(Rect2(-18, -47, 36, 0.8), metal_bright, true)
	draw_circle(Vector2(-2.2, -45.5), 1.6, metal_dark)
	draw_circle(Vector2(2.2, -45.5), 1.6, metal_dark)
	draw_circle(Vector2(-2.2, -45.5), 0.8, metal)
	draw_circle(Vector2(2.2, -45.5), 0.8, metal)
	var t_start_x := -18.0
	var t_step := 9.0
	var t_h := 18.0
	var t_w := 2.6
	for i in range(5):
		var tx := t_start_x + t_step * float(i)
		draw_rect(Rect2(tx, -48 - t_h, t_w, t_h), metal_dark, true)
		draw_rect(Rect2(tx, -48 - t_h, t_w * 0.45, t_h), metal, true)
		draw_rect(Rect2(tx + 0.1, -48 - t_h + 0.4, 0.8, t_h - 4.2), metal_bright, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx - 0.4, -48 - t_h),
			Vector2(tx + t_w + 0.4, -48 - t_h),
			Vector2(tx + t_w * 0.5, -48 - t_h - 4.8),
		]), metal_dark)
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx + 0.1, -48 - t_h),
			Vector2(tx + t_w * 0.55, -48 - t_h),
			Vector2(tx + t_w * 0.42, -48 - t_h - 4.0),
		]), metal)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

extends Node2D
## Draw a farming rake (wooden handle + 5 metal tines).
## Orientation: handle points down-left when scale.x=1 (right-facing player)
## Use rotation to animate attack swings.
@export var held: bool = false

func _draw() -> void:
	var wood := Color(0.42, 0.25, 0.08, 1)
	var wood_edge := Color(0.62, 0.38, 0.12, 1)
	var metal := Color(0.72, 0.75, 0.78, 1)
	var metal_dark := Color(0.38, 0.4, 0.42, 1)
	if held:
		# ---------- held-in-hand view: handle extends from hand (0,0) up-right ----------
		# wooden handle rectangle (length=44 width=4, diagonal direction)
		var handle_len := 44.0
		var handle_w := 4.0
		var angle_dir := -0.45  # slight up-right angle when resting
		rotate(0)
		# draw handle via polygon
		var tip := Vector2(cos(angle_dir), sin(angle_dir)) * handle_len
		var perp := Vector2(-tip.y, tip.x) * (handle_w * 0.5)
		var poly := PackedVector2Array([-perp, tip - perp, tip + perp, perp])
		draw_colored_polygon(poly, wood)
		draw_polyline(PackedVector2Array([-perp, tip - perp, tip + perp, perp, -perp]), wood_edge, 1.2)
		# metal crossbar at tip (perpendicular to handle, length=30)
		var bar_dir := Vector2(-tip.y, tip.x).normalized() * 15.0
		var bar_p1 := tip - bar_dir
		var bar_p2 := tip + bar_dir
		draw_line(bar_p1, bar_p2, metal_dark, 4.0)
		draw_line(bar_p1, bar_p2, metal, 2.2)
		# 5 metal tines (pointing forward=same direction as handle tip)
		var tine_len := 14.0
		var tine_dir := tip.normalized() * tine_len
		var step := (bar_p2 - bar_p1) * 0.25
		for i in range(5):
			var base := bar_p1 + step * float(i)
			var tine_tip := base + tine_dir
			draw_line(base, tine_tip, metal_dark, 3.4)
			draw_line(base + tine_dir * 0.1, tine_tip - tine_dir * 0.05, metal, 1.8)
	else:
		# ---------- pickup view: standing upright on ground ----------
		# wooden handle: 6px wide, 54px tall (bottom at y=10 so pickup sits on ground)
		draw_rect(Rect2(-3, -44, 6, 54), wood, true)
		draw_rect(Rect2(-3, -44, 6, 54), wood_edge, false, 1.2)
		# handle end cap
		draw_rect(Rect2(-4, -46, 8, 4), Color(0.55, 0.32, 0.1, 1), true)
		# metal crossbar (top of handle)
		draw_rect(Rect2(-20, -48, 40, 5), metal_dark, true)
		draw_rect(Rect2(-20, -48, 40, 2), metal, true)
		# 5 tines going up (each 18 tall, 2.6 wide, spaced 9px)
		var t_start_x := -18.0
		for i in range(5):
			var tx := t_start_x + 9.0 * float(i)
			draw_rect(Rect2(tx, -66, 2.6, 18), metal_dark, true)
			draw_rect(Rect2(tx, -66, 1.3, 18), metal, true)
			# tine tip
			draw_colored_polygon(PackedVector2Array([
				Vector2(tx - 0.4, -66),
				Vector2(tx + 3.0, -66),
				Vector2(tx + 1.3, -70.5)
			]), metal)

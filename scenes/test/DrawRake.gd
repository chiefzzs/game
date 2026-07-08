extends Node2D
## Draw a farming rake (wooden handle + metal crossbar + 5 metal tines).
## SINGLE SHAPE (held=true/false look identical!) — use Node2D parent
## (WeaponHolder) rotation/position/scale to pose the rake in hand.
##
## Standard shape coordinates (identity transform):
##   * wooden handle: vertical rectangle 6x54 (bottom at y=10, top at y=-44)
##   * metal crossbar: 40x5 at y=-48 (top of handle)
##   * 5 tines: each 18 tall going UP (-y), starting y=-48 tip at y=-66
##   * tine tips: triangle sharpened points at top of each tine
##
## held=true => same shape, no redraw.  Parent WeaponHolder should rotate
## to make the tines face forward and handle gripped at hand.
@export var held: bool = false

func _draw() -> void:
	var wood := Color(0.42, 0.25, 0.08, 1)
	var wood_edge := Color(0.62, 0.38, 0.12, 1)
	var wood_cap := Color(0.55, 0.32, 0.1, 1)
	var metal := Color(0.72, 0.75, 0.78, 1)
	var metal_bright := Color(0.88, 0.9, 0.92, 1)
	var metal_dark := Color(0.38, 0.4, 0.42, 1)
	# ---------- 1. wooden handle (6 wide x 54 tall, bottom at y=+10 so it stands on pickup area) ----------
	draw_rect(Rect2(-3, -44, 6, 54), wood, true)
	draw_rect(Rect2(-3, -44, 6, 54), wood_edge, false, 1.2)
	# handle end cap (bottom grip)
	draw_rect(Rect2(-4, 8, 8, 4), wood_cap, true)
	draw_rect(Rect2(-4, 8, 8, 1), wood_edge, false, 1.0)
	# 2x wrap rings (wrapped cord on handle near grip for realism)
	draw_line(Vector2(-3.1, -6), Vector2(3.1, -6), Color(0.3, 0.18, 0.05, 0.9), 1.6)
	draw_line(Vector2(-3.1, 2), Vector2(3.1, 2), Color(0.3, 0.18, 0.05, 0.9), 1.6)
	# ---------- 2. metal crossbar (top of handle, y=-48, 40 wide x 5 tall) ----------
	draw_rect(Rect2(-20, -48, 40, 5), metal_dark, true)
	draw_rect(Rect2(-20, -48, 40, 2), metal, true)
	draw_rect(Rect2(-18, -47, 36, 0.8), metal_bright, true)
	# 2 rivets holding crossbar to handle
	draw_circle(Vector2(-2.2, -45.5), 1.6, metal_dark)
	draw_circle(Vector2(2.2, -45.5), 1.6, metal_dark)
	draw_circle(Vector2(-2.2, -45.5), 0.8, metal)
	draw_circle(Vector2(2.2, -45.5), 0.8, metal)
	# ---------- 3. five tines (spaced 9px: x=-18 -9 0 +9 +18) ----------
	# Each tine 18 tall going UP from crossbar top (y=-48) to tip y=-66
	var t_start_x := -18.0
	var t_step := 9.0
	var t_h := 18.0
	var t_w := 2.6
	for i in range(5):
		var tx := t_start_x + t_step * float(i)
		# dark outline (back face)
		draw_rect(Rect2(tx, -48 - t_h, t_w, t_h), metal_dark, true)
		# bright front face (left half)
		draw_rect(Rect2(tx, -48 - t_h, t_w * 0.45, t_h), metal, true)
		# tiny highlight line
		draw_rect(Rect2(tx + 0.1, -48 - t_h + 0.4, 0.8, t_h - 4.2), metal_bright, true)
		# tine tip: sharp triangular point (3 vertices)
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
	# ---------- 4. (Optional debug mark if held — NO shape change, just tiny 1px stamp disabled) ----------

extends Node2D
## Draw a Scarecrow enemy: straw head + cloth body + wood pole + angry face.
## Supports hurt_flash: call flash_red() briefly tint red after taking damage.
const COLOR_STRAW := Color(0.88, 0.78, 0.38, 1.0)
const COLOR_STRAW_DARK := Color(0.62, 0.54, 0.2, 1.0)
const COLOR_CLOTH := Color(0.62, 0.35, 0.35, 1.0)
const COLOR_CLOTH_DARK := Color(0.38, 0.18, 0.18, 1.0)
const COLOR_WOOD := Color(0.4, 0.26, 0.1, 1.0)
const COLOR_WOOD_EDGE := Color(0.22, 0.13, 0.04, 1.0)
const COLOR_FACE := Color(0.1, 0.05, 0.0, 1.0)
const COLOR_ARMS := Color(0.5, 0.35, 0.15, 1.0)

var _hurt_t: float = 0.0

func flash_red() -> void:
	_hurt_t = 0.18
	queue_redraw()

func _process(delta: float) -> void:
	if _hurt_t > 0.0:
		_hurt_t = max(0.0, _hurt_t - delta)
		queue_redraw()

func _draw() -> void:
	var flash: bool = _hurt_t > 0.0
	var red_overlay: Color = Color(1.0, 0.2, 0.2, 0.55) if flash else Color(0, 0, 0, 0)
	# -------- 1. central wooden pole (extends below body into ground) --------
	draw_rect(Rect2(-3, -6, 6, 50), COLOR_WOOD, true)
	draw_rect(Rect2(-3, -6, 6, 50), COLOR_WOOD_EDGE, false, 1.0)
	# wood grain lines
	for gy in range(0, 48, 8):
		draw_line(Vector2(-1.5, -4 + gy), Vector2(1.5, -3 + gy), COLOR_WOOD_EDGE, 0.8)
	# -------- 2. cross-bar (T shape, shoulders) --------
	draw_rect(Rect2(-30, 6, 60, 6), COLOR_WOOD, true)
	draw_rect(Rect2(-30, 6, 60, 6), COLOR_WOOD_EDGE, false, 1.0)
	# -------- 3. cloth robe / torso (torn red cloth, over shoulders) --------
	# cloth body triangle-ish
	var body_poly := PackedVector2Array([
		Vector2(-28, 8), Vector2(28, 8),
		Vector2(22, 46), Vector2(-22, 46),
	])
	draw_colored_polygon(body_poly, COLOR_CLOTH)
	draw_polyline(PackedVector2Array([
		Vector2(-28, 8), Vector2(28, 8),
		Vector2(22, 46), Vector2(-22, 46), Vector2(-28, 8),
	]), COLOR_CLOTH_DARK, 1.3)
	# torn cloth bottom jagged edges (3 tears)
	for tx in range(-18, 19, 12):
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx - 5, 44),
			Vector2(tx + 5, 44),
			Vector2(tx, 56),
		]), COLOR_CLOTH_DARK)
	# cloth buttons down middle
	for by in range(16, 44, 8):
		draw_circle(Vector2(0, by), 1.4, COLOR_CLOTH_DARK)
	# straw sticking out of neck
	for sx in range(-6, 7, 3):
		draw_line(Vector2(sx * 0.7, 2), Vector2(sx, -6), COLOR_STRAW_DARK, 1.6)
		draw_line(Vector2(sx * 0.5, 2), Vector2(sx * 1.2, -3), COLOR_STRAW, 1.0)
	# -------- 4. Arms (straw sticking out of sleeves) --------
	# left arm
	for lx in range(-30, -17, 3):
		draw_line(Vector2(lx, 9), Vector2(lx - 2, 22), COLOR_STRAW_DARK, 1.7)
		draw_line(Vector2(lx + 1, 9), Vector2(lx - 1, 20), COLOR_STRAW, 1.0)
	# right arm
	for rx in range(18, 31, 3):
		draw_line(Vector2(rx, 9), Vector2(rx + 2, 22), COLOR_STRAW_DARK, 1.7)
		draw_line(Vector2(rx - 1, 9), Vector2(rx + 1, 20), COLOR_STRAW, 1.0)
	# sleeve cuffs (cloth rags)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-33, 6), Vector2(-22, 6), Vector2(-25, 15), Vector2(-33, 12),
	]), COLOR_CLOTH_DARK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(33, 6), Vector2(22, 6), Vector2(25, 15), Vector2(33, 12),
	]), COLOR_CLOTH_DARK)
	# -------- 5. straw head (big ball of straw on top of pole) --------
	# head circle
	draw_circle(Vector2(0, -22), 17.5, COLOR_STRAW_DARK)
	draw_circle(Vector2(0, -22), 15.5, COLOR_STRAW)
	# straw spikes radiating
	var spikes := 24
	for i in range(spikes):
		var ang := float(i) * (2.0 * PI / float(spikes))
		var r_outer := 17.5 + (randfn() * 0.6 + 1.8)
		var r_inner := 14.0
		var p1 := Vector2(cos(ang), sin(ang)) * r_inner + Vector2(0, -22)
		var p2 := Vector2(cos(ang), sin(ang)) * r_outer + Vector2(0, -22)
		draw_line(p1, p2, COLOR_STRAW_DARK, 1.3)
	# hat / red bandana around head
	var bandana_poly := PackedVector2Array([
		Vector2(-18, -14), Vector2(18, -14),
		Vector2(21, -8), Vector2(-21, -8),
	])
	draw_colored_polygon(bandana_poly, COLOR_CLOTH)
	draw_polyline(PackedVector2Array([
		Vector2(-18, -14), Vector2(18, -14),
		Vector2(21, -8), Vector2(-21, -8), Vector2(-18, -14),
	]), COLOR_CLOTH_DARK, 1.2)
	# bandana tail flopping left
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, -12), Vector2(-28, -10), Vector2(-26, -2), Vector2(-18, -6),
	]), COLOR_CLOTH_DARK)
	# -------- 6. angry face (stitched eyes, stitched X mouth) --------
	# Eyes: angry downward V lines ( >:( )
	# left eye
	draw_line(Vector2(-9, -26), Vector2(-4, -22), COLOR_FACE, 2.0)
	draw_line(Vector2(-9, -22), Vector2(-4, -26), COLOR_FACE, 1.6)
	# right eye
	draw_line(Vector2(4, -26), Vector2(9, -22), COLOR_FACE, 2.0)
	draw_line(Vector2(4, -22), Vector2(9, -26), COLOR_FACE, 1.6)
	# angry eyebrows (inward down)
	draw_line(Vector2(-12, -31), Vector2(-3, -28), COLOR_FACE, 1.8)
	draw_line(Vector2(12, -31), Vector2(3, -28), COLOR_FACE, 1.8)
	# Stitched mouth: X shape like a scarecrow
	draw_line(Vector2(-6, -17), Vector2(6, -12), COLOR_FACE, 1.9)
	draw_line(Vector2(-6, -12), Vector2(6, -17), COLOR_FACE, 1.9)
	# two small stitch marks at cheeks
	draw_circle(Vector2(-13, -18), 0.9, COLOR_FACE)
	draw_circle(Vector2(13, -18), 0.9, COLOR_FACE)
	# -------- 7. hurt red overlay (entire figure) --------
	if flash:
		var flash_poly := PackedVector2Array([
			Vector2(-40, -48), Vector2(40, -48),
			Vector2(40, 60), Vector2(-40, 60),
		])
		draw_colored_polygon(flash_poly, Color(1, 0.15, 0.15, 0.35))

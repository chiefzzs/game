extends Node2D
## 木剑（Wood Sword）绘制：
##  - 伤害低攻速快，造型轻巧：浅色木质剑刃+深棕色剑柄+简单小护手
##  - held=true时不浮动（角色手持）；false时拾取物浮动
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
	var wood_light := Color(0.90, 0.82, 0.62, 1.0)
	var wood_light_hl := Color(0.97, 0.91, 0.74, 1.0)
	var wood := Color(0.68, 0.52, 0.28, 1.0)
	var wood_dark := Color(0.42, 0.28, 0.10, 1.0)
	var wood_guard := Color(0.48, 0.32, 0.14, 1.0)
	var guard_hl := Color(0.72, 0.52, 0.24, 1.0)
	var wrap := Color(0.32, 0.18, 0.04, 1.0)
	var wrap_hl := Color(0.52, 0.32, 0.10, 1.0)
	# 剑刃（朝上方向，剑身为浅色木纹木）
	var blade_len: float = 28.0
	var blade_top: float = -46.0
	var blade_bot: float = blade_top + blade_len
	var blade_half_w: float = 3.2
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, blade_top - 3.5),
		Vector2(blade_half_w, blade_bot),
		Vector2(-blade_half_w, blade_bot),
	]), wood_light)
	draw_rect(Rect2(-blade_half_w, blade_top + 1.0, blade_half_w * 2.0, blade_len - 1.0), wood_light, true)
	draw_rect(Rect2(-blade_half_w, blade_top, blade_half_w * 2.0, blade_len), wood, false, 1.0)
	# 木纹：两条细线
	draw_line(Vector2(-1.2, blade_top + 3.0), Vector2(-1.2, blade_bot - 1.0), Color(0.78, 0.64, 0.40, 0.9), 0.9)
	draw_line(Vector2(1.0, blade_top + 6.0), Vector2(1.0, blade_bot - 2.0), Color(0.78, 0.64, 0.40, 0.7), 0.7)
	# 剑刃高光（左侧斜面）
	draw_colored_polygon(PackedVector2Array([
		Vector2(-blade_half_w + 0.4, blade_top + 0.5),
		Vector2(0.0, blade_top - 2.0),
		Vector2(0.0, blade_bot - 0.5),
		Vector2(-blade_half_w + 0.4, blade_bot),
	]), wood_light_hl)
	# 剑尖小尖（浅色）
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, blade_top - 3.5),
		Vector2(blade_half_w * 0.6, blade_top + 1.5),
		Vector2(-blade_half_w * 0.6, blade_top + 1.5),
	]), wood_light_hl)
	# 护手（简单小横条，木质）
	var guard_y: float = blade_bot - 0.5
	var guard_w: float = 13.0
	draw_rect(Rect2(-guard_w * 0.5, guard_y, guard_w, 3.2), wood_guard, true)
	draw_rect(Rect2(-guard_w * 0.5, guard_y, guard_w, 1.1), guard_hl, true)
	draw_rect(Rect2(-guard_w * 0.5, guard_y + 3.2, guard_w, 0.8), wood_dark, true)
	# 剑柄（短粗，木质）
	var hilt_y: float = guard_y + 3.4
	var hilt_len: float = 10.0
	var hilt_w: float = 5.4
	draw_rect(Rect2(-hilt_w * 0.5, hilt_y, hilt_w, hilt_len), wood, true)
	draw_rect(Rect2(-hilt_w * 0.5, hilt_y, hilt_w, hilt_len), wood_dark, false, 1.0)
	# 缠绳（缠绕装饰）
	for i in range(3):
		var yy: float = hilt_y + 1.5 + 2.8 * float(i)
		draw_line(Vector2(-hilt_w * 0.5 + 0.3, yy), Vector2(hilt_w * 0.5 - 0.3, yy + 0.9), wrap, 1.2)
		draw_line(Vector2(-hilt_w * 0.5 + 0.5, yy + 0.4), Vector2(hilt_w * 0.5 - 0.5, yy + 1.3), wrap_hl, 0.7)
	# 柄尾圆头（大一点的圆木）
	var pommel_y: float = hilt_y + hilt_len
	draw_circle(Vector2(0.0, pommel_y + 0.5), 3.2, wood_guard)
	draw_circle(Vector2(0.0, pommel_y + 0.5), 2.2, wood)
	draw_circle(Vector2(-0.8, pommel_y + 0.0), 0.9, guard_hl)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

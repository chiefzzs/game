extends Node2D
class_name DrawPriest
## 牧师 NPC 视觉绘制：同体型 28x48 + 白色牧师袍+金色纹饰+手持黄金权杖
## 公共API：
##   flash_red(crit)          受伤闪烁（暴击黄色闪）
##   trigger_heal_flash(num)  治疗爆发闪光效果
##   set_halo_on(on, color)   盟友光环

const COLOR_ROBE := Color(0.95, 0.95, 0.92, 1.0)
const COLOR_ROBE_DARK := Color(0.75, 0.75, 0.7, 1.0)
const COLOR_ROBE_EDGE := Color(0.6, 0.6, 0.58, 1.0)
const COLOR_GOLD := Color(1.0, 0.82, 0.22, 1.0)
const COLOR_GOLD_DARK := Color(0.72, 0.55, 0.1, 1.0)
const COLOR_GOLD_SHINE := Color(1.0, 0.95, 0.55, 1.0)
const COLOR_SKIN := Color(1.0, 0.86, 0.7, 1.0)
const COLOR_SKIN_DARK := Color(0.85, 0.7, 0.52, 1.0)
const COLOR_HAT := Color(0.88, 0.88, 0.84, 1.0)
const COLOR_HAT_DARK := Color(0.65, 0.65, 0.6, 1.0)
const COLOR_SASH := Color(0.78, 0.2, 0.2, 1.0)
const COLOR_SASH_DARK := Color(0.52, 0.1, 0.1, 1.0)
const COLOR_EYE := Color(0.08, 0.06, 0.04, 1.0)
const COLOR_STAFF_WOOD := Color(0.55, 0.35, 0.18, 1.0)
const COLOR_STAFF_WOOD_DARK := Color(0.35, 0.22, 0.1, 1.0)
const COLOR_HEAL := Color(0.5, 1.0, 0.62, 0.95)
const COLOR_HALO_DEFAULT := Color(1.0, 0.86, 0.35, 0.88)

var _hurt_t: float = 0.0
var _hurt_crit: bool = false
var _halo_on: bool = false
var _halo_color: Color = COLOR_HALO_DEFAULT
var _t: float = 0.0
var _heal_flash_t: float = -1.0
var _heal_flash_dur: float = 0.45
var _heal_count: int = 0

func flash_red(is_crit: bool = false) -> void:
	_hurt_t = 0.24
	_hurt_crit = is_crit
	queue_redraw()

func trigger_heal_flash(healed_count: int = 1) -> void:
	_heal_flash_t = 0.0
	_heal_flash_dur = 0.42
	_heal_count = healed_count
	queue_redraw()

func set_halo_on(on: bool, color: Color = COLOR_HALO_DEFAULT) -> void:
	_halo_on = on
	_halo_color = color
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var dirty := false
	if _hurt_t > 0.0:
		_hurt_t = max(0.0, _hurt_t - delta)
		dirty = true
	if _heal_flash_t >= 0.0:
		_heal_flash_t = min(1.0, _heal_flash_t + delta / max(0.001, _heal_flash_dur))
		if _heal_flash_t >= 1.0:
			_heal_flash_t = -1.0
			_heal_count = 0
		dirty = true
	if dirty or _halo_on:
		queue_redraw()

func _draw() -> void:
	var flash: bool = _hurt_t > 0.0
	var bob: float = sin(_t * 2.0) * 0.5
	var body_rect := Rect2(-14, -24, 28, 48)
	if _halo_on:
		var halo := _halo_color
		if flash and _hurt_crit:
			halo = Color(1.0, 0.9, 0.3, 0.95)
		elif flash:
			halo = Color(1.0, 0.55, 0.55, 0.9)
		var pulse: float = 0.85 + sin(_t * 3.0) * 0.08
		draw_circle(Vector2(0, -2), 26.0 * pulse, Color(halo.r, halo.g, halo.b, halo.a * 0.18))
		draw_circle(Vector2(0, -2), 22.0 * pulse, Color(halo.r, halo.g, halo.b, halo.a * 0.32))
	if _heal_flash_t >= 0.0:
		var p: float = _heal_flash_t
		var r: float = 10.0 + p * 36.0
		var a: float = (1.0 - p) * 0.55
		draw_circle(Vector2(0, -4), r, Color(COLOR_HEAL.r, COLOR_HEAL.g, COLOR_HEAL.b, a))
		draw_arc(Vector2(0, -4), r, 0.0, TAU, 36, Color(COLOR_HEAL.r, COLOR_HEAL.g, COLOR_HEAL.b, (1.0 - p) * 0.85), 1.8)
		if _heal_count > 0 and p < 0.65:
			var font = ThemeDB.fallback_font
			if font:
				var s: String = "+%d" % _heal_count
				var sz: Vector2 = font.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
				var ty: float = -42.0 - p * 18.0
				draw_string(font, Vector2(-sz.x * 0.5, ty), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.35, 1.0, 0.55, 1.0 - p))
	var robe_color: Color = COLOR_ROBE
	var robe_dark: Color = COLOR_ROBE_DARK
	var gold_c: Color = COLOR_GOLD
	var skin_c: Color = COLOR_SKIN
	if flash and _hurt_crit:
		robe_color = Color(1.0, 1.0, 0.7, 1.0)
		robe_dark = Color(0.85, 0.75, 0.3, 1.0)
		gold_c = Color(1.0, 1.0, 0.5, 1.0)
		skin_c = Color(1.0, 0.95, 0.6, 1.0)
	elif flash:
		robe_color = Color(1.0, 0.85, 0.85, 1.0)
		robe_dark = Color(0.85, 0.6, 0.6, 1.0)
		gold_c = Color(1.0, 0.92, 0.45, 1.0)
		skin_c = Color(1.0, 0.78, 0.7, 1.0)
	var robe_back: PoolVector2Array = PoolVector2Array([
		Vector2(-12, -10),
		Vector2(12, -10),
		Vector2(14, 22 + bob),
		Vector2(-14, 22 + bob)
	])
	draw_colored_polygon(robe_back, robe_dark)
	var robe_front: PoolVector2Array = PoolVector2Array([
		Vector2(-10, -8),
		Vector2(10, -8),
		Vector2(12, 20 + bob),
		Vector2(-12, 20 + bob)
	])
	draw_colored_polygon(robe_front, robe_color)
	var sash_rect: Rect2 = Rect2(-13, 2 + bob, 26, 5)
	draw_rect(sash_rect, COLOR_SASH_DARK, true)
	draw_rect(Rect2(-12, 3 + bob, 24, 3), COLOR_SASH, true)
	var gold_trim_bot: PoolVector2Array = PoolVector2Array([
		Vector2(-14, 18 + bob),
		Vector2(14, 18 + bob),
		Vector2(13, 22 + bob),
		Vector2(-13, 22 + bob)
	])
	draw_colored_polygon(gold_trim_bot, Color(gold_c.r, gold_c.g, gold_c.b, 0.85))
	var gold_trim_collar: PoolVector2Array = PoolVector2Array([
		Vector2(-10, -10),
		Vector2(10, -10),
		Vector2(8, -6),
		Vector2(-8, -6)
	])
	draw_colored_polygon(gold_trim_collar, gold_c)
	var arm_r: PoolVector2Array = PoolVector2Array([
		Vector2(8, -6),
		Vector2(13, -3),
		Vector2(14, 8 + bob),
		Vector2(9, 10 + bob)
	])
	draw_colored_polygon(arm_r, robe_dark)
	var arm_l: PoolVector2Array = PoolVector2Array([
		Vector2(-8, -6),
		Vector2(-13, -3),
		Vector2(-14, 8 + bob),
		Vector2(-9, 10 + bob)
	])
	draw_colored_polygon(arm_l, robe_dark)
	var arm2_r: PoolVector2Array = PoolVector2Array([
		Vector2(8, -5),
		Vector2(12, -2),
		Vector2(13, 7 + bob),
		Vector2(9, 9 + bob)
	])
	draw_colored_polygon(arm2_r, robe_color)
	var arm2_l: PoolVector2Array = PoolVector2Array([
		Vector2(-8, -5),
		Vector2(-12, -2),
		Vector2(-13, 7 + bob),
		Vector2(-9, 9 + bob)
	])
	draw_colored_polygon(arm2_l, robe_color)
	var staff_x: float = 15.0
	var staff_top: float = -30.0
	var staff_bot: float = 6.0 + bob
	draw_line(Vector2(staff_x, staff_bot), Vector2(staff_x, staff_top + 4.0), COLOR_STAFF_WOOD_DARK, 2.8)
	draw_line(Vector2(staff_x, staff_bot), Vector2(staff_x, staff_top + 4.0), COLOR_STAFF_WOOD, 1.8)
	draw_circle(Vector2(staff_x, staff_top), 8.5, COLOR_GOLD_DARK)
	draw_circle(Vector2(staff_x, staff_top), 6.8, gold_c)
	var glow_t: float = 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(Vector2(staff_x, staff_top), 4.2, Color(COLOR_GOLD_SHINE.r, COLOR_GOLD_SHINE.g, COLOR_GOLD_SHINE.b, 0.8 + glow_t * 0.2))
	var star_pts: PoolVector2Array = PoolVector2Array()
	for i in range(8):
		var ang: float = (float(i) / 8.0) * TAU - PI * 0.5
		var rr: float = 3.0 if i % 2 == 0 else 1.3
		star_pts.append(Vector2(staff_x + cos(ang) * rr, staff_top + sin(ang) * rr))
	if star_pts.size() >= 3:
		draw_colored_polygon(star_pts, Color(gold_c.r, gold_c.g, gold_c.b, 0.95))
	var cross_h: float = 5.2
	var cross_w: float = 1.6
	draw_rect(Rect2(staff_x - cross_w * 0.5, staff_top - cross_h * 0.5, cross_w, cross_h), Color(COLOR_SASH_DARK.r, COLOR_SASH_DARK.g, COLOR_SASH_DARK.b, 0.85), true)
	draw_rect(Rect2(staff_x - cross_h * 0.36, staff_top - cross_w * 0.5, cross_h * 0.72, cross_w), Color(COLOR_SASH_DARK.r, COLOR_SASH_DARK.g, COLOR_SASH_DARK.b, 0.85), true)
	var hand_r: Rect2 = Rect2(staff_x - 5.0, -4.0, 8.0, 7.0)
	draw_rect(hand_r, COLOR_SKIN_DARK, true)
	draw_rect(Rect2(hand_r.position + Vector2(0.6, 0.6), hand_r.size - Vector2(1.2, 1.2)), skin_c, true)
	var head_rect := Rect2(-9, -24, 18, 16)
	draw_rect(Rect2(head_rect.position + Vector2(0.4, 4.0), Vector2(head_rect.size.x - 0.8, head_rect.size.y - 4.0)), COLOR_SKIN_DARK, true)
	draw_rect(Rect2(head_rect.position + Vector2(1.0, 4.4), Vector2(head_rect.size.x - 2.0, head_rect.size.y - 5.0)), skin_c, true)
	var beard_pts: PoolVector2Array = PoolVector2Array([
		Vector2(-8, -10),
		Vector2(8, -10),
		Vector2(6, -2),
		Vector2(0, 4),
		Vector2(-6, -2)
	])
	draw_colored_polygon(beard_pts, Color(0.92, 0.9, 0.85, 1.0))
	var beard2: PoolVector2Array = PoolVector2Array([
		Vector2(-6, -9),
		Vector2(6, -9),
		Vector2(5, -3),
		Vector2(0, 2),
		Vector2(-5, -3)
	])
	draw_colored_polygon(beard2, Color(1.0, 0.98, 0.94, 1.0))
	var hat_base: PoolVector2Array = PoolVector2Array([
		Vector2(-11, -14),
		Vector2(11, -14),
		Vector2(9, -10),
		Vector2(-9, -10)
	])
	draw_colored_polygon(hat_base, COLOR_HAT_DARK)
	var hat_base2: PoolVector2Array = PoolVector2Array([
		Vector2(-10, -13.5),
		Vector2(10, -13.5),
		Vector2(8.5, -10.5),
		Vector2(-8.5, -10.5)
	])
	draw_colored_polygon(hat_base2, COLOR_HAT)
	var hat_cone: PoolVector2Array = PoolVector2Array([
		Vector2(-8, -14),
		Vector2(8, -14),
		Vector2(3, -30),
		Vector2(-3, -30)
	])
	draw_colored_polygon(hat_cone, COLOR_HAT_DARK)
	var hat_cone2: PoolVector2Array = PoolVector2Array([
		Vector2(-7, -14.5),
		Vector2(7, -14.5),
		Vector2(2.5, -29.5),
		Vector2(-2.5, -29.5)
	])
	draw_colored_polygon(hat_cone2, COLOR_HAT)
	var hat_gold_band: PoolVector2Array = PoolVector2Array([
		Vector2(-9, -16),
		Vector2(9, -16),
		Vector2(8, -13),
		Vector2(-8, -13)
	])
	draw_colored_polygon(hat_gold_band, gold_c)
	draw_circle(Vector2(0, -29.5), 2.2, gold_c)
	draw_circle(Vector2(0, -29.5), 1.2, COLOR_GOLD_SHINE)
	var eye_y: float = -14.5
	draw_rect(Rect2(-5.5, eye_y, 2.4, 2.0), COLOR_EYE, true)
	draw_rect(Rect2(3.1, eye_y, 2.4, 2.0), COLOR_EYE, true)
	if flash:
		var overlay_a: float = min(0.55, _hurt_t * 2.5)
		if _hurt_crit:
			draw_rect(body_rect, Color(1.0, 0.95, 0.3, overlay_a), true)
		else:
			draw_rect(body_rect, Color(1.0, 0.4, 0.4, overlay_a), true)

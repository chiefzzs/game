extends DrawEnemyRect
class_name DrawEliteShield
## 精英敌人绘制：在普通敌人（浅灰矩形+持剑）基础上，增加左手盾牌
##  - 盾牌：金属银色+铆钉，可格挡正面攻击
##  - 破盾3次：第1/2次轻微裂缝，第3次盾牌破碎爆散
## 公共API（继承 DrawEnemyRect）：
##   flash_red() / show_hit_ring() / show_exclamation() / set_sword_slash()
##   on_shield_blocked()            盾牌格挡成功（被玩家攻击）
##   on_shield_hit_woodcutter(n,3)  樵夫攻击盾，1次闪烁
##   on_shield_broken()             盾牌破碎

const COLOR_SHIELD_BODY := Color(0.80, 0.83, 0.88, 1.0)
const COLOR_SHIELD_DARK := Color(0.42, 0.45, 0.50, 1.0)
const COLOR_SHIELD_EDGE := Color(0.28, 0.30, 0.34, 1.0)
const COLOR_SHIELD_RIVET := Color(0.60, 0.62, 0.66, 1.0)
const COLOR_SHIELD_GOLD := Color(0.95, 0.78, 0.32, 1.0)
const COLOR_SHIELD_CRACK := Color(0.0, 0.0, 0.0, 1.0)

var _shield_blocked_t: float = 0.0
var _shield_crack_level: int = 0
var _shield_broken_t: float = 0.0
var _shield_flash_t: float = 0.0
var _woodcutter_hit_t: float = 0.0

func on_shield_blocked() -> void:
	_shield_blocked_t = 0.3
	_shield_flash_t = 0.3
	queue_redraw()

func on_shield_hit_woodcutter(cur: int, total: int) -> void:
	_shield_crack_level = min(2, cur)
	_shield_blocked_t = 0.3
	_woodcutter_hit_t = 0.35
	_shield_flash_t = 0.35
	queue_redraw()

func on_shield_broken() -> void:
	_shield_crack_level = 3
	_shield_broken_t = 0.5
	queue_redraw()

func _process(delta: float) -> void:
	var dirty: bool = false
	if _shield_blocked_t > 0.0:
		_shield_blocked_t = max(0.0, _shield_blocked_t - delta)
		dirty = true
	if _shield_flash_t > 0.0:
		_shield_flash_t = max(0.0, _shield_flash_t - delta)
		dirty = true
	if _woodcutter_hit_t > 0.0:
		_woodcutter_hit_t = max(0.0, _woodcutter_hit_t - delta)
		dirty = true
	if _shield_broken_t > 0.0:
		_shield_broken_t = max(0.0, _shield_broken_t - delta)
		dirty = true
	super._process(delta)
	if dirty:
		queue_redraw()

func _draw() -> void:
	super._draw()
	if _shield_crack_level >= 3 and _shield_broken_t <= 0.0:
		return
	var face: float = 1.0 if scale.x >= 0.0 else -1.0
	var shield_hand := Vector2(-12.0 * face, -2.0)
	var shield_color_shake := _shield_flash_t > 0.0
	var shield_tint := Color.WHITE
	if shield_color_shake:
		var k := _shield_flash_t / 0.35
		shield_tint = Color(1.0, 1.0 - 0.35 * k, 1.0 - 0.45 * k, 1.0)
	elif _woodcutter_hit_t > 0.0:
		var k := _woodcutter_hit_t / 0.35
		shield_tint = Color(1.0, 0.88 - 0.3 * k, 0.55, 1.0)
	var broken_pct: float = 0.0
	if _shield_broken_t > 0.0:
		broken_pct = 1.0 - _shield_broken_t / 0.5
	_draw_shield(shield_hand, face, shield_tint, broken_pct)

func _draw_shield(hand_pos: Vector2, face: float, tint: Color, broken: float) -> void:
	draw_set_transform(hand_pos, 0.0, Vector2(face, 1.0))
	var base_rect := Rect2(-10, -22, 18, 38)
	var top := PackedVector2Array([
		base_rect.position + Vector2(base_rect.size.x * 0.5, -5),
		base_rect.position + Vector2(base_rect.size.x, 0),
		base_rect.position + Vector2(base_rect.size.x, base_rect.size.y * 0.5),
		base_rect.position + Vector2(base_rect.size.x * 0.5, base_rect.size.y),
		base_rect.position + Vector2(0, base_rect.size.y * 0.5),
		base_rect.position + Vector2(0, 0),
	])
	var col_body := COLOR_SHIELD_BODY * tint
	var col_dark := COLOR_SHIELD_DARK
	var col_edge := COLOR_SHIELD_EDGE
	if broken > 0.0:
		var a := 1.0 - broken
		col_body = Color(col_body.r, col_body.g, col_body.b, a)
		col_dark = Color(col_dark.r, col_dark.g, col_dark.b, a)
		col_edge = Color(col_edge.r, col_edge.g, col_edge.b, a)
		var off := broken * 18.0
		for i in range(top.size()):
			var ang := float(i) / float(top.size()) * TAU + broken * 4.0
			top[i] += Vector2(cos(ang) * off, sin(ang) * off * 0.6 + broken * 40.0 * sin(float(i) * 7.3))
	draw_colored_polygon(top, col_body)
	draw_polyline(top + PackedVector2Array([top[0]]), col_edge, 1.6)
	var center := base_rect.position + base_rect.size * 0.5 + Vector2(-1, 2)
	var gold_r := 6.0
	draw_circle(center, gold_r + 0.8, col_edge)
	draw_circle(center, gold_r, COLOR_SHIELD_GOLD * Color(tint.r, tint.g, tint.b, 1.0))
	draw_circle(center, 2.2, col_dark)
	var rivets := [
		base_rect.position + Vector2(4, 6),
		base_rect.position + Vector2(base_rect.size.x - 4, 6),
		base_rect.position + Vector2(4, base_rect.size.y - 10),
		base_rect.position + Vector2(base_rect.size.x - 4, base_rect.size.y - 10),
	]
	for r in rivets:
		draw_circle(r, 1.7, COLOR_SHIELD_RIVET * Color(tint.r, tint.g, tint.b, 1.0))
	if _shield_crack_level >= 1:
		_draw_crack(base_rect, 1)
	if _shield_crack_level >= 2:
		_draw_crack(base_rect, 2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_crack(br: Rect2, level: int) -> void:
	var crack_alpha := 0.7
	if level == 1:
		var pts := PackedVector2Array([
			br.position + Vector2(2, 4),
			br.position + Vector2(br.size.x * 0.35, br.size.y * 0.4),
			br.position + Vector2(br.size.x * 0.5, br.size.y * 0.7),
			br.position + Vector2(4, br.size.y - 3),
		])
		draw_polyline(pts, Color(COLOR_SHIELD_CRACK.r, COLOR_SHIELD_CRACK.g, COLOR_SHIELD_CRACK.b, crack_alpha), 1.5)
	else:
		var pts1 := PackedVector2Array([
			br.position + Vector2(br.size.x - 2, 2),
			br.position + Vector2(br.size.x * 0.6, br.size.y * 0.3),
			br.position + Vector2(br.size.x * 0.4, br.size.y * 0.55),
			br.position + Vector2(br.size.x - 3, br.size.y - 5),
		])
		draw_polyline(pts1, Color(COLOR_SHIELD_CRACK.r, COLOR_SHIELD_CRACK.g, COLOR_SHIELD_CRACK.b, crack_alpha), 1.5)
		var pts2 := PackedVector2Array([
			br.position + Vector2(br.size.x * 0.5, br.size.y * 0.2),
			br.position + Vector2(br.size.x * 0.25, br.size.y * 0.5),
			br.position + Vector2(br.size.x * 0.35, br.size.y - 2),
		])
		draw_polyline(pts2, Color(COLOR_SHIELD_CRACK.r, COLOR_SHIELD_CRACK.g, COLOR_SHIELD_CRACK.b, crack_alpha * 0.85), 1.3)

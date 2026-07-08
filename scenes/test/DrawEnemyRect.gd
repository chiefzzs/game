extends Node2D
class_name DrawEnemyRect
## 敌人视觉绘制（与玩家矩形同尺寸，浅灰色，手持剑，头顶感叹号）
## 公共API：
##   flash_red()            受伤闪烁
##   show_exclamation(dur)  头顶冒感叹号（默认 0.8s）
##   set_sword_slash(t)     挥剑动画 t∈[0,1]
const COLOR_BODY := Color(0.82, 0.84, 0.88, 1.0)
const COLOR_BODY_DARK := Color(0.55, 0.58, 0.62, 1.0)
const COLOR_EYE := Color(0.1, 0.1, 0.15, 1.0)
const COLOR_SWORD_BLADE := Color(0.88, 0.90, 0.95, 1.0)
const COLOR_SWORD_EDGE := Color(0.35, 0.4, 0.5, 1.0)
const COLOR_SWORD_GUARD := Color(0.45, 0.32, 0.18, 1.0)
const COLOR_SWORD_HILT := Color(0.28, 0.18, 0.1, 1.0)
const COLOR_EXCLAMATION := Color(1.0, 0.85, 0.0, 1.0)
const COLOR_EXCLAMATION_EDGE := Color(0.7, 0.4, 0.0, 1.0)

var _hurt_t: float = 0.0
var _excl_t: float = 0.0
var _excl_dur: float = 0.8
var _slash_t: float = -1.0
var _slash_dur: float = 0.22

func flash_red() -> void:
	_hurt_t = 0.18
	queue_redraw()

func show_exclamation(duration: float = 0.8) -> void:
	_excl_t = duration
	_excl_dur = max(0.2, duration)
	queue_redraw()

func set_sword_slash(now: float = 0.0) -> void:
	_slash_t = 0.0
	_slash_dur = max(0.1, now) if now > 0.0 else 0.22
	queue_redraw()

func _process(delta: float) -> void:
	var dirty := false
	if _hurt_t > 0.0:
		_hurt_t = max(0.0, _hurt_t - delta)
		dirty = true
	if _excl_t > 0.0:
		_excl_t = max(0.0, _excl_t - delta)
		dirty = true
	if _slash_t >= 0.0:
		_slash_t = min(1.0, _slash_t + delta / max(0.001, _slash_dur))
		if _slash_t >= 1.0:
			_slash_t = -1.0
		dirty = true
	if dirty:
		queue_redraw()

func _draw() -> void:
	var flash: bool = _hurt_t > 0.0
	var red_overlay: Color = Color(1.0, 0.2, 0.2, 0.5) if flash else Color(0, 0, 0, 0)
	var body_rect := Rect2(-14, -24, 28, 48)
	draw_rect(body_rect, COLOR_BODY, true)
	draw_rect(body_rect, COLOR_BODY_DARK, false, 1.4)
	# 腰带（和玩家矩形一致，把上半身和下半身分开）
	draw_rect(Rect2(-14, 0, 28, 3), COLOR_BODY_DARK, true)
	# 眼睛（红色凶狠小方眼，警示感）
	draw_rect(Rect2(-8, -16, 4, 3), COLOR_EYE, true)
	draw_rect(Rect2(4, -16, 4, 3), COLOR_EYE, true)
	# 嘴
	draw_line(Vector2(-5, -6), Vector2(5, -6), COLOR_EYE, 1.4)
	# 手持剑（默认朝右；通过 scale.x 镜像朝左）
	_draw_sword(Vector2(12.0, -2.0), _slash_t)
	# 受伤红色叠加
	if flash:
		draw_rect(body_rect, Color(1, 0.1, 0.1, 0.35), true)
	# 头顶感叹号（发现玩家提示）
	if _excl_t > 0.0:
		var pop: float = 0.0
		if _excl_dur > 0.001:
			var t := 1.0 - _excl_t / _excl_dur
			pop = sin(clamp(t * 3.5, 0.0, PI)) * 4.0
		_draw_exclamation(Vector2(0, -34.0 - pop))

func _draw_sword(hand_pos: Vector2, slash_t: float) -> void:
	var base_angle := -0.1
	var slash_angle_range := 2.1
	var angle := base_angle
	if slash_t >= 0.0:
		angle = base_angle + (-slash_angle_range / 2.0 + slash_t * slash_angle_range)
	draw_set_transform(hand_pos, angle, Vector2.ONE)
	# 剑身 blade: 30 长, 4 宽
	draw_rect(Rect2(0, -2, 30, 4), COLOR_SWORD_BLADE, true)
	draw_rect(Rect2(0, -2, 30, 4), COLOR_SWORD_EDGE, false, 1.0)
	# 剑尖
	var tip := PackedVector2Array([
		Vector2(30, -3), Vector2(36, 0), Vector2(30, 3),
	])
	draw_colored_polygon(tip, COLOR_SWORD_BLADE)
	draw_polyline(PackedVector2Array([
		Vector2(30, -3), Vector2(36, 0), Vector2(30, 3),
	]), COLOR_SWORD_EDGE, 1.0)
	# 护手 guard
	draw_rect(Rect2(-2, -5, 3, 10), COLOR_SWORD_GUARD, true)
	# 剑柄 hilt
	draw_rect(Rect2(-8, -2, 6, 4), COLOR_SWORD_HILT, true)
	draw_rect(Rect2(-9, -2.5, 1.5, 5), COLOR_SWORD_GUARD, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_exclamation(pos: Vector2) -> void:
	var bob := sin(Time.get_ticks_msec() / 90.0) * 1.2
	var p := pos + Vector2(0, bob)
	# 圆形底板（黄色气泡）
	draw_circle(p + Vector2(0, -2), 10.0, Color(1.0, 0.95, 0.4, 0.92))
	draw_circle(p + Vector2(0, -2), 10.0, COLOR_EXCLAMATION_EDGE, false, 1.6)
	# 感叹号：竖线 + 点
	draw_rect(Rect2(p.x - 1.6, p.y - 9.0, 3.2, 8.5), COLOR_EXCLAMATION_EDGE, true)
	draw_circle(p + Vector2(0, 3.5), 2.1, COLOR_EXCLAMATION_EDGE)
	# 高亮边
	draw_rect(Rect2(p.x - 0.8, p.y - 8.0, 0.9, 6.5), Color(1, 1, 0.9, 0.7), true)

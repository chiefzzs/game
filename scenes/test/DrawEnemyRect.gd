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
const COLOR_EXCLAMATION := Color(1.0, 0.48, 0.08, 1.0)
const COLOR_EXCLAMATION_BG := Color(1.0, 0.78, 0.25, 0.96)
const COLOR_EXCLAMATION_EDGE := Color(0.72, 0.22, 0.0, 1.0)

var _hurt_t: float = 0.0
var _hurt_crit: bool = false
var _excl_t: float = 0.0
var _excl_dur: float = 0.8
var _slash_t: float = -1.0
var _slash_dur: float = 0.22
var _hit_ring_t: float = -1.0
var _hit_ring_dur: float = 0.32
var _hit_ring_crit: bool = false

func flash_red(is_crit: bool = false) -> void:
	_hurt_t = 0.42 if is_crit else 0.28
	_hurt_crit = is_crit
	modulate = Color(1.6, 0.2, 0.2, 1.0) if is_crit else Color(1.35, 0.4, 0.4, 1.0)
	await get_tree().create_timer(0.09).timeout
	if is_instance_valid(self):
		modulate = Color.WHITE
	queue_redraw()

func show_hit_ring(is_crit: bool = false) -> void:
	_hit_ring_t = 0.0
	_hit_ring_dur = 0.42 if is_crit else 0.28
	_hit_ring_crit = is_crit
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
	if _hit_ring_t >= 0.0:
		_hit_ring_t = min(1.0, _hit_ring_t + delta / max(0.001, _hit_ring_dur))
		if _hit_ring_t >= 1.0:
			_hit_ring_t = -1.0
		dirty = true
	if dirty:
		queue_redraw()

func _draw() -> void:
	var flash: bool = _hurt_t > 0.0
	var crit: bool = _hurt_crit and flash
	var body_rect := Rect2(-14, -24, 28, 48)
	draw_rect(body_rect, COLOR_BODY, true)
	draw_rect(body_rect, COLOR_BODY_DARK, false, 1.4)
	draw_rect(Rect2(-14, 0, 28, 3), COLOR_BODY_DARK, true)
	draw_rect(Rect2(-8, -16, 4, 3), COLOR_EYE, true)
	draw_rect(Rect2(4, -16, 4, 3), COLOR_EYE, true)
	draw_line(Vector2(-5, -6), Vector2(5, -6), COLOR_EYE, 1.4)
	_draw_sword(Vector2(12.0, -2.0), _slash_t)
	if flash:
		var ov_alpha := 0.52 if crit else 0.32
		draw_rect(body_rect.grow(2), Color(1, 0.0, 0.0, ov_alpha), true)
		if crit:
			draw_rect(body_rect.grow(5), Color(1, 0.4, 0.0, 0.22), false, 2.2)
	if _excl_t > 0.0:
		var pop: float = 0.0
		if _excl_dur > 0.001:
			var t := 1.0 - _excl_t / _excl_dur
			pop = sin(clamp(t * 3.2, 0.0, PI)) * 8.0
		_draw_exclamation(Vector2(0, -38.0 - pop))
	if _hit_ring_t >= 0.0:
		_draw_hit_ring(Vector2(0, -8), _hit_ring_t, _hit_ring_crit)

func _draw_hit_ring(center: Vector2, t: float, crit: bool) -> void:
	var base_r := 10.0 + t * 42.0
	var alpha := 1.0 - t
	if crit:
		var r2 := 6.0 + t * 56.0
		for i in range(3):
			var rr := base_r + float(i) * 2.5
			var aa := (alpha - float(i) * 0.18) * 0.85
			if aa <= 0.0:
				continue
			draw_arc(center + Vector2(t * 10.0, 0), rr, 0.0, TAU, 28, Color(1.0, 0.3, 0.0, aa), 2.8 - float(i) * 0.6)
		for i in range(2):
			var rr2 := r2 + float(i) * 3.5
			var aa2 := (alpha - float(i) * 0.22) * 0.7
			if aa2 <= 0.0:
				continue
			draw_arc(center + Vector2(-t * 8.0, t * 4.0), rr2, 0.0, TAU, 24, Color(1.0, 0.9, 0.1, aa2), 2.0 - float(i) * 0.5)
		var spikes := 6
		var outer_r := 16.0 + t * 70.0
		for i in range(spikes):
			var ang := float(i) / float(spikes) * TAU + t * 2.5
			var p1 := center + Vector2(cos(ang), sin(ang)) * (base_r * 0.65)
			var p2 := center + Vector2(cos(ang), sin(ang)) * (outer_r * (0.85 + sin(t * PI) * 0.15))
			draw_line(p1, p2, Color(1.0, 0.55, 0.0, alpha * 0.9), 2.4)
	else:
		for i in range(2):
			var rr := base_r + float(i) * 3.0
			var aa := (alpha - float(i) * 0.22) * 0.85
			if aa <= 0.0:
				continue
			draw_arc(center, rr, 0.0, TAU, 24, Color(1.0, 0.18, 0.18, aa), 2.2 - float(i) * 0.5)

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
	var bob := sin(Time.get_ticks_msec() / 70.0) * 2.2
	var p := pos + Vector2(0, bob)
	var bg_center := p + Vector2(0, -2.5)
	var glow_r := 15.0
	for gi in range(3):
		var gr := glow_r - float(gi) * 2.0
		var ga := 0.18 - float(gi) * 0.05
		draw_circle(bg_center, gr, Color(1.0, 0.55, 0.1, ga))
	draw_circle(bg_center, 12.0, COLOR_EXCLAMATION_BG)
	draw_circle(bg_center, 13.5, Color(1.0, 0.65, 0.2, 0.9), false, 1.2)
	draw_circle(bg_center, 12.0, COLOR_EXCLAMATION_EDGE, false, 2.2)
	# 感叹号：竖线 + 点（深橙色描边+橙色填充）
	draw_rect(Rect2(p.x - 2.6, p.y - 13.0, 5.2, 11.5), COLOR_EXCLAMATION_EDGE, true)
	draw_rect(Rect2(p.x - 1.8, p.y - 12.2, 3.6, 10.0), COLOR_EXCLAMATION, true)
	draw_circle(p + Vector2(0, 4.0), 3.0, COLOR_EXCLAMATION_EDGE)
	draw_circle(p + Vector2(-0.4, 3.4), 1.6, COLOR_EXCLAMATION)
	# 左侧高光（立体感）
	draw_rect(Rect2(p.x - 1.4, p.y - 11.8, 1.1, 8.8), Color(1, 0.92, 0.7, 0.8), true)

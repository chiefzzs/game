extends Node2D
class_name DrawHunter
## 猎人 NPC 视觉绘制：同体型 28x48 + 墨绿色斗篷+棕色猎帽+手持弓箭
## 公共API：
##   flash_red(crit)          受伤闪烁（暴击黄色闪）
##   start_draw_bow(dur)      拉弓动画
##   release_arrow()          放箭（弓弦回弹）
##   on_arrow_fired(crit)     射箭命中光效
##   set_halo_on(on, color)   盟友光环

const COLOR_BODY := Color(0.52, 0.38, 0.22, 1.0)
const COLOR_BODY_DARK := Color(0.32, 0.2, 0.1, 1.0)
const COLOR_CLOAK := Color(0.18, 0.38, 0.22, 1.0)
const COLOR_CLOAK_DARK := Color(0.08, 0.22, 0.12, 1.0)
const COLOR_CLOAK_EDGE := Color(0.4, 0.55, 0.3, 1.0)
const COLOR_SKIN := Color(1.0, 0.84, 0.66, 1.0)
const COLOR_HAT := Color(0.44, 0.26, 0.1, 1.0)
const COLOR_HAT_DARK := Color(0.24, 0.12, 0.04, 1.0)
const COLOR_HAT_FEATHER := Color(0.95, 0.55, 0.15, 1.0)
const COLOR_EYE := Color(0.08, 0.05, 0.02, 1.0)
const COLOR_BOW := Color(0.62, 0.38, 0.14, 1.0)
const COLOR_BOW_DARK := Color(0.32, 0.18, 0.06, 1.0)
const COLOR_STRING := Color(0.9, 0.88, 0.82, 1.0)
const COLOR_ARROW_SHAFT := Color(0.5, 0.32, 0.16, 1.0)
const COLOR_ARROW_HEAD := Color(0.92, 0.94, 0.98, 1.0)
const COLOR_ARROW_FEATHER := Color(0.18, 0.55, 0.22, 1.0)
const COLOR_HALO_DEFAULT := Color(0.35, 0.6, 1.0, 0.85)

var _hurt_t: float = 0.0
var _hurt_crit: bool = false
var _halo_on: bool = false
var _halo_color: Color = COLOR_HALO_DEFAULT
var _t: float = 0.0
var _drawing_bow: bool = false
var _draw_progress: float = 0.0
var _draw_total: float = 1.0
var _release_anim_t: float = 0.0
var _fire_flash_t: float = -1.0
var _fire_flash_dur: float = 0.2
var _fire_flash_crit: bool = false

func flash_red(is_crit: bool = false) -> void:
	_hurt_t = 0.22
	_hurt_crit = is_crit
	queue_redraw()

func start_draw_bow(dur: float) -> void:
	_drawing_bow = true
	_draw_total = max(0.05, dur)
	_draw_progress = 0.0
	queue_redraw()

func release_arrow() -> void:
	_drawing_bow = false
	_release_anim_t = 0.16
	_draw_progress = 0.0
	queue_redraw()

func on_arrow_fired(is_crit: bool = false) -> void:
	_fire_flash_t = 0.0
	_fire_flash_dur = 0.26 if is_crit else 0.18
	_fire_flash_crit = is_crit
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
	if _drawing_bow and _draw_total > 0.0001:
		_draw_progress = min(1.0, _draw_progress + delta / _draw_total)
		dirty = true
	else:
		var old := _draw_progress
		_draw_progress = max(0.0, _draw_progress - delta * 3.0)
		if old != _draw_progress:
			dirty = true
	if _release_anim_t > 0.0:
		_release_anim_t = max(0.0, _release_anim_t - delta)
		dirty = true
	if _fire_flash_t >= 0.0:
		_fire_flash_t = min(1.0, _fire_flash_t + delta / max(0.001, _fire_flash_dur))
		if _fire_flash_t >= 1.0:
			_fire_flash_t = -1.0
		dirty = true
	if dirty or _halo_on:
		queue_redraw()

func _draw() -> void:
	var flash: bool = _hurt_t > 0.0
	var bob: float = sin(_t * 2.2) * 0.45
	var body_rect := Rect2(-14, -24, 28, 48)
	if _halo_on:
		var halo := _halo_color
		for gi in range(4):
			var gr := 30.0 - float(gi) * 3.2
			var ga := 0.2 - float(gi) * 0.045
			var gc := Color(halo.r, halo.g, halo.b, max(0.0, ga))
			draw_circle(Vector2(0, 0 + bob), gr, gc)
		draw_arc(Vector2(0, 0 + bob), 28.0, 0.0, TAU, 32, halo, 1.9)
	var cloak_outer: PackedVector2Array = PackedVector2Array([
		Vector2(-22, -10 + bob), Vector2(-20, 22 + bob), Vector2(-8, 24 + bob),
		Vector2(8, 24 + bob), Vector2(20, 22 + bob), Vector2(22, -10 + bob),
		Vector2(16, -18 + bob), Vector2(-16, -18 + bob)])
	draw_colored_polygon(cloak_outer, COLOR_CLOAK)
	draw_polyline(PackedVector2Array([
		Vector2(-22, -10 + bob), Vector2(-20, 22 + bob), Vector2(-8, 24 + bob),
		Vector2(8, 24 + bob), Vector2(20, 22 + bob), Vector2(22, -10 + bob),
		Vector2(16, -18 + bob), Vector2(-16, -18 + bob), Vector2(-22, -10 + bob)]),
		COLOR_CLOAK_DARK, 1.3)
	draw_line(Vector2(-18, -8 + bob), Vector2(-17, 20 + bob), COLOR_CLOAK_EDGE, 1.2)
	draw_line(Vector2(18, -8 + bob), Vector2(17, 20 + bob), COLOR_CLOAK_EDGE, 1.2)
	draw_rect(Rect2(-12, -2 + bob, 24, 24), COLOR_BODY, true)
	draw_rect(Rect2(-12, -2 + bob, 24, 24), COLOR_BODY_DARK, false, 1.2)
	draw_rect(Rect2(-14, 22 + bob, 28, 4), COLOR_BODY_DARK, true)
	draw_circle(Vector2(0, -22 + bob), 12.8, COLOR_SKIN)
	var hat_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-22, -22 + bob), Vector2(22, -22 + bob),
		Vector2(16, -30 + bob), Vector2(-16, -30 + bob)])
	draw_colored_polygon(hat_pts, COLOR_HAT)
	draw_polyline(PackedVector2Array([
		Vector2(-22, -22 + bob), Vector2(22, -22 + bob),
		Vector2(16, -30 + bob), Vector2(-16, -30 + bob), Vector2(-22, -22 + bob)]),
		COLOR_HAT_DARK, 1.3)
	draw_rect(Rect2(-14, -30 + bob, 28, 2.4), COLOR_HAT_DARK, true)
	var feather_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-10, -29 + bob), Vector2(-16, -44 + bob), Vector2(-14, -30 + bob),
		Vector2(-8, -42 + bob), Vector2(-9, -32 + bob)])
	draw_colored_polygon(feather_pts, COLOR_HAT_FEATHER)
	draw_circle(Vector2(-5, -22 + bob), 1.9, COLOR_EYE)
	draw_circle(Vector2(5, -22 + bob), 1.9, COLOR_EYE)
	draw_arc(Vector2(0, -17 + bob), 2.8, 0.1, PI - 0.1, 10, COLOR_EYE, 1.3)
	draw_line(Vector2(-12, 31 + bob), Vector2(-4, 31 + bob), COLOR_HAT_DARK, 3.0)
	draw_line(Vector2(4, 31 + bob), Vector2(12, 31 + bob), COLOR_HAT_DARK, 3.0)
	_draw_bow(Vector2(-15.0, 0.0 + bob), _draw_progress)
	if flash:
		var flash_color: Color = Color(1, 0.92, 0.25, 0.38) if _hurt_crit else Color(1, 0.1, 0.1, 0.35)
		draw_rect(body_rect, flash_color, true)
	if _fire_flash_t >= 0.0:
		_draw_fire_flash(Vector2(-24.0, -2.0 + bob), _fire_flash_t, _fire_flash_crit)

func _draw_fire_flash(front: Vector2, t: float, crit: bool) -> void:
	var alpha := 1.0 - t
	var r0 := 5.0 + t * 16.0
	if crit:
		for i in range(4):
			var rr := r0 + float(i) * 3.2
			var aa := (alpha - float(i) * 0.18)
			if aa <= 0.0:
				continue
			draw_circle(front + Vector2(-t * 10.0, 0), rr, Color(1.0, 0.75, 0.2, aa * 0.5))
			draw_arc(front, rr + 3.0, 0.0, TAU, 22, Color(1.0, 0.55, 0.0, aa), 2.5)
		var rays := 6
		for i in range(rays):
			var ang := float(i) / float(rays) * TAU + t * 2.5
			var p1 := front + Vector2(cos(ang), sin(ang)) * (r0 * 0.7)
			var p2 := front + Vector2(cos(ang), sin(ang)) * (r0 + 8.0 + t * 18.0)
			draw_line(p1, p2, Color(1.0, 0.9, 0.25, alpha), 2.2)
	else:
		for i in range(3):
			var rr := r0 + float(i) * 2.8
			var aa := (alpha - float(i) * 0.22)
			if aa <= 0.0:
				continue
			draw_circle(front, rr, Color(0.6, 0.8, 1.0, aa * 0.5))
			draw_arc(front, rr + 2.0, 0.0, TAU, 18, Color(0.4, 0.7, 1.0, aa), 2.0)

func _draw_bow(hand_pos: Vector2, draw_amount: float) -> void:
	var bow_hand_x: float = hand_pos.x
	var bow_top_y: float = hand_pos.y - 20.0
	var bow_bot_y: float = hand_pos.y + 18.0
	var bow_len: float = bow_bot_y - bow_top_y
	var bow_curve_x: float = bow_hand_x - 12.0
	var string_rest_x: float = bow_hand_x - 2.0
	var string_pull: float = draw_amount * 16.0
	var string_cur_x: float = string_rest_x + string_pull
	var bow_pts := PackedVector2Array([
		Vector2(bow_hand_x, bow_top_y),
		Vector2(bow_curve_x, bow_top_y + bow_len * 0.18),
		Vector2(bow_curve_x - 4.0, bow_top_y + bow_len * 0.5),
		Vector2(bow_curve_x, bow_top_y + bow_len * 0.82),
		Vector2(bow_hand_x, bow_bot_y),
	])
	draw_polyline(bow_pts, COLOR_BOW, 3.3)
	draw_polyline(bow_pts, COLOR_BOW_DARK, 1.1)
	var string_top := Vector2(bow_hand_x, bow_top_y + 1.5)
	var string_mid := Vector2(string_cur_x, bow_top_y + bow_len * 0.5)
	var string_bot := Vector2(bow_hand_x, bow_bot_y - 1.5)
	draw_line(string_top, string_mid, COLOR_STRING, 1.0)
	draw_line(string_mid, string_bot, COLOR_STRING, 1.0)
	if draw_amount > 0.06:
		var shaft_len: float = 26.0
		var shaft_cx: float = string_cur_x
		var shaft_cy: float = bow_top_y + bow_len * 0.5
		draw_rect(Rect2(shaft_cx - 4.0, shaft_cy - 1.0, shaft_len + 4.0, 2.2), COLOR_ARROW_SHAFT, true)
		var head_p := PackedVector2Array([
			Vector2(shaft_cx + shaft_len, shaft_cy),
			Vector2(shaft_cx + shaft_len - 7.0, shaft_cy - 3.5),
			Vector2(shaft_cx + shaft_len - 7.0, shaft_cy + 3.5),
		])
		draw_colored_polygon(head_p, COLOR_ARROW_HEAD)
		var f1_p := PackedVector2Array([
			Vector2(shaft_cx - 4.0 + 1.0, shaft_cy),
			Vector2(shaft_cx - 4.0 - 6.0, shaft_cy - 4.5),
			Vector2(shaft_cx - 4.0 + 3.0, shaft_cy - 1.6),
		])
		draw_colored_polygon(f1_p, COLOR_ARROW_FEATHER)
		var f2_p := PackedVector2Array([
			Vector2(shaft_cx - 4.0 + 1.0, shaft_cy),
			Vector2(shaft_cx - 4.0 - 6.0, shaft_cy + 4.5),
			Vector2(shaft_cx - 4.0 + 3.0, shaft_cy + 1.6),
		])
		draw_colored_polygon(f2_p, COLOR_ARROW_FEATHER)
	if _release_anim_t > 0.0:
		var a: float = _release_anim_t / 0.16
		var cx: float = bow_curve_x - 20.0 * (1.0 - a)
		var cy: float = bow_top_y + bow_len * 0.5
		for i in range(4):
			var ang: float = (i * 1.25) + 2.1
			var rr: float = 5.0 + (1.0 - a) * 10.0
			draw_circle(Vector2(cx + cos(ang) * rr, cy + sin(ang) * rr), 1.4 * a, COLOR_STRING * Color(1.0, 1.0, 1.0, a))

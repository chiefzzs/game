extends Node2D
class_name DrawWoodcutter
## 樵夫 NPC 视觉绘制（同玩家体型 28x48 矩形+手持斧头）
## 公共API：
##   flash_red()               受伤闪烁
##   show_ax_slash(dur)        挥斧动画 t∈[0,1]
##   set_halo_on(on, color)    盟友光环（默认不开启）
const COLOR_BODY := Color(0.52, 0.36, 0.22, 1.0)
const COLOR_BODY_DARK := Color(0.32, 0.2, 0.1, 1.0)
const COLOR_VEST := Color(0.28, 0.55, 0.28, 1.0)
const COLOR_VEST_DARK := Color(0.16, 0.35, 0.18, 1.0)
const COLOR_SKIN := Color(1.0, 0.84, 0.66, 1.0)
const COLOR_HAT := Color(0.6, 0.32, 0.14, 1.0)
const COLOR_HAT_DARK := Color(0.38, 0.18, 0.06, 1.0)
const COLOR_EYE := Color(0.08, 0.05, 0.02, 1.0)
const COLOR_AXE_HANDLE := Color(0.42, 0.24, 0.08, 1.0)
const COLOR_AXE_HEAD := Color(0.72, 0.75, 0.8, 1.0)
const COLOR_AXE_EDGE := Color(0.3, 0.32, 0.4, 1.0)
const COLOR_AXE_SHINE := Color(0.92, 0.94, 0.98, 1.0)
const COLOR_HALO := Color(0.35, 0.9, 0.6, 0.75)

var _hurt_t: float = 0.0
var _slash_t: float = -1.0
var _slash_dur: float = 0.28
var _halo_on: bool = false
var _halo_color: Color = COLOR_HALO
var _t: float = 0.0
var _hit_flash_t: float = -1.0
var _hit_flash_dur: float = 0.22
var _hit_flash_crit: bool = false

func on_hit_connect(is_crit: bool = false) -> void:
	_hit_flash_t = 0.0
	_hit_flash_dur = 0.3 if is_crit else 0.2
	_hit_flash_crit = is_crit
	if is_crit:
		modulate = Color(1.4, 1.3, 0.6, 1.0)
	else:
		modulate = Color(1.2, 1.25, 1.15, 1.0)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(self):
		modulate = Color.WHITE
	queue_redraw()

func flash_red() -> void:
	_hurt_t = 0.2
	queue_redraw()

func show_ax_slash(duration: float = 0.28) -> void:
	_slash_t = 0.0
	_slash_dur = max(0.15, duration)
	queue_redraw()

func set_halo_on(on: bool, color: Color = COLOR_HALO) -> void:
	_halo_on = on
	_halo_color = color
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var dirty := false
	if _hurt_t > 0.0:
		_hurt_t = max(0.0, _hurt_t - delta)
		dirty = true
	if _slash_t >= 0.0:
		_slash_t = min(1.0, _slash_t + delta / max(0.001, _slash_dur))
		if _slash_t >= 1.0:
			_slash_t = -1.0
		dirty = true
	if _hit_flash_t >= 0.0:
		_hit_flash_t = min(1.0, _hit_flash_t + delta / max(0.001, _hit_flash_dur))
		if _hit_flash_t >= 1.0:
			_hit_flash_t = -1.0
		dirty = true
	if dirty or _halo_on:
		queue_redraw()

func _draw() -> void:
	var flash: bool = _hurt_t > 0.0
	var body_rect := Rect2(-14, -24, 28, 48)
	var bob: float = sin(_t * 2.0) * 0.4
	if _halo_on:
		var halo := COLOR_HALO if _halo_color.a < 0.01 else _halo_color
		for gi in range(3):
			var gr := 28.0 - float(gi) * 3.0
			var ga := 0.18 - float(gi) * 0.05
			draw_circle(Vector2(0, 0 + bob), gr, Color(halo.r, halo.g, halo.b, ga))
		draw_arc(Vector2(0, 0 + bob), 26.0, 0.0, TAU, 28, halo, 1.8)
	draw_rect(Rect2(-14, -2 + bob, 28, 26), COLOR_BODY, true)
	draw_rect(Rect2(-14, -2 + bob, 28, 26), COLOR_BODY_DARK, false, 1.4)
	draw_rect(Rect2(-11, 2 + bob, 22, 18), COLOR_VEST, true)
	draw_rect(Rect2(-11, 2 + bob, 22, 18), COLOR_VEST_DARK, false, 1.1)
	draw_line(Vector2(0, 2 + bob), Vector2(0, 20 + bob), COLOR_VEST_DARK, 1.2)
	draw_rect(Rect2(-14, 22 + bob, 28, 4), COLOR_BODY_DARK, true)
	draw_rect(Rect2(-14, -16 + bob, 28, 5), COLOR_BODY_DARK, true)
	draw_circle(Vector2(0, -22 + bob), 13.0, COLOR_SKIN)
	var hat_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-20, -22 + bob), Vector2(20, -22 + bob),
		Vector2(14, -30 + bob), Vector2(-14, -30 + bob)])
	draw_colored_polygon(hat_pts, COLOR_HAT)
	draw_polyline(PackedVector2Array([
		Vector2(-20, -22 + bob), Vector2(20, -22 + bob),
		Vector2(14, -30 + bob), Vector2(-14, -30 + bob), Vector2(-20, -22 + bob)]),
		COLOR_HAT_DARK, 1.2)
	draw_rect(Rect2(-12, -30 + bob, 24, 2.6), COLOR_HAT_DARK, true)
	draw_circle(Vector2(-5, -22 + bob), 1.9, COLOR_EYE)
	draw_circle(Vector2(5, -22 + bob), 1.9, COLOR_EYE)
	draw_arc(Vector2(0, -17 + bob), 3.0, 0.0, PI, 10, COLOR_EYE, 1.5)
	draw_line(Vector2(-12, 31 + bob), Vector2(-4, 31 + bob), COLOR_HAT_DARK, 3.0)
	draw_line(Vector2(4, 31 + bob), Vector2(12, 31 + bob), COLOR_HAT_DARK, 3.0)
	_draw_axe(Vector2(13.0, 2.0 + bob), _slash_t)
	if flash:
		draw_rect(body_rect, Color(1, 0.1, 0.1, 0.35), true)
	if _hit_flash_t >= 0.0:
		_draw_hit_flash(Vector2(46.0, 2.0 + bob), _hit_flash_t, _hit_flash_crit)

func _draw_hit_flash(front: Vector2, t: float, crit: bool) -> void:
	var alpha := 1.0 - t
	var r0 := 4.0 + t * 20.0
	if crit:
		for i in range(3):
			var rr := r0 + float(i) * 4.0
			var aa := (alpha - float(i) * 0.15)
			if aa <= 0.0:
				continue
			draw_circle(front + Vector2(t * 14.0, -t * 6.0), rr, Color(1.0, 0.9, 0.2, aa * 0.45))
			draw_arc(front, rr + 4.0, 0.0, TAU, 22, Color(1.0, 0.65, 0.0, aa), 2.6)
		var spikes := 5
		for i in range(spikes):
			var ang := float(i) / float(spikes) * TAU + t * 2.0
			var p1 := front + Vector2(cos(ang), sin(ang)) * (r0 * 0.8)
			var p2 := front + Vector2(cos(ang), sin(ang)) * (r0 + 10.0 + t * 22.0)
			draw_line(p1, p2, Color(1.0, 0.85, 0.1, alpha), 2.4)
	else:
		for i in range(2):
			var rr := r0 + float(i) * 3.5
			var aa := (alpha - float(i) * 0.25)
			if aa <= 0.0:
				continue
			draw_circle(front, rr, Color(0.75, 1.0, 0.75, aa * 0.5))
			draw_arc(front, rr + 2.0, 0.0, TAU, 18, Color(0.5, 0.95, 0.55, aa), 2.0)

func _draw_axe(hand_pos: Vector2, slash_t: float) -> void:
	var base_angle := -0.35
	var slash_angle_range := 2.6
	var angle := base_angle
	if slash_t >= 0.0:
		angle = base_angle + (-slash_angle_range / 2.0 + slash_t * slash_angle_range)
	draw_set_transform(hand_pos, angle, Vector2.ONE)
	draw_rect(Rect2(0, -2.2, 30, 4.4), COLOR_AXE_HANDLE, true)
	draw_rect(Rect2(0, -2.2, 30, 4.4), COLOR_HAT_DARK, false, 0.9)
	draw_rect(Rect2(-4, -1.8, 4.4, 3.6), COLOR_HAT_DARK, true)
	var head_pts: PackedVector2Array = PackedVector2Array([
		Vector2(26, -16), Vector2(44, -10), Vector2(48, 0),
		Vector2(44, 10), Vector2(26, 16), Vector2(22, 0)])
	draw_colored_polygon(head_pts, COLOR_AXE_HEAD)
	draw_polyline(PackedVector2Array([
		Vector2(26, -16), Vector2(44, -10), Vector2(48, 0),
		Vector2(44, 10), Vector2(26, 16), Vector2(22, 0), Vector2(26, -16)]),
		COLOR_AXE_EDGE, 1.4)
	var blade_pts: PackedVector2Array = PackedVector2Array([
		Vector2(44, -10), Vector2(48, 0), Vector2(44, 10), Vector2(46, 0)])
	draw_colored_polygon(blade_pts, COLOR_AXE_SHINE)
	draw_line(Vector2(28, -14), Vector2(32, -6), COLOR_AXE_SHINE, 1.0)
	if slash_t >= 0.0:
		var arc_cx := 38.0
		var arc_cy := 0.0
		for r in [42.0, 32.0]:
			var arc: PackedVector2Array = PackedVector2Array([])
			for i in range(14):
				var ang: float = (-1.1 + float(i) * 0.18)
				arc.append(Vector2(arc_cx + cos(ang) * r, arc_cy + sin(ang) * r * 0.9))
			draw_polyline(arc, Color(0.55, 0.9, 0.6, 0.7), 3.0)
	if _hit_flash_t >= 0.0:
		var hf_alpha := 1.0 - _hit_flash_t
		var crit_hit := _hit_flash_crit
		var blade_c := Vector2(44, 0)
		if crit_hit:
			for gi in range(3):
				var gr := 7.0 + _hit_flash_t * 14.0 + float(gi) * 3.0
				var ga := (hf_alpha - float(gi) * 0.2)
				if ga <= 0.0:
					continue
				draw_circle(blade_c, gr, Color(1.0, 0.88, 0.2, ga * 0.5))
			draw_arc(blade_c, 16.0 + _hit_flash_t * 18.0, 0.0, TAU, 20, Color(1.0, 0.6, 0.0, hf_alpha), 2.6)
			var shine_pts: PackedVector2Array = PackedVector2Array([
				Vector2(40, -18), Vector2(58, -4), Vector2(58, 4), Vector2(40, 18)])
			draw_colored_polygon(shine_pts, Color(1.0, 0.95, 0.4, hf_alpha * 0.55))
		else:
			for gi in range(2):
				var gr := 5.0 + _hit_flash_t * 11.0 + float(gi) * 2.5
				var ga := (hf_alpha - float(gi) * 0.25)
				if ga <= 0.0:
					continue
				draw_circle(blade_c, gr, Color(0.7, 1.0, 0.7, ga * 0.55))
			draw_arc(blade_c, 13.0 + _hit_flash_t * 13.0, 0.0, TAU, 16, Color(0.55, 1.0, 0.6, hf_alpha), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

extends Node2D
class_name HaloRing
## V0.3g 通用光环：脚底黄色光圈，表示当前编队active角色
## 用法：halo = HaloRing.new() ; parent.add_child(halo) ; halo.global_position = char.pos

var halo_color: Color = Color(1.0, 0.92, 0.3, 0.85)
var radius: float = 38.0
var ring_width: float = 5.0
var pulse_speed: float = 2.6
var _t: float = 0.0

func set_color(c: Color) -> void:
	halo_color = c
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * pulse_speed)
	var r_outer := radius + 4.0 * pulse
	var r_inner := max(2.0, r_outer - ring_width)
	var col_outer: Color = halo_color
	var col_inner: Color = Color(halo_color.r, halo_color.g, halo_color.b, 0.0)
	var segs := 30
	for i in range(segs):
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU
		var p0o := Vector2(cos(a0) * r_outer, sin(a0) * r_outer * 0.42)
		var p1o := Vector2(cos(a1) * r_outer, sin(a1) * r_outer * 0.42)
		var p0i := Vector2(cos(a0) * r_inner, sin(a0) * r_inner * 0.42)
		var p1i := Vector2(cos(a1) * r_inner, sin(a1) * r_inner * 0.42)
		var quad: PackedVector2Array = PackedVector2Array([p0o, p1o, p1i, p0i])
		var mix: Color = col_outer
		draw_colored_polygon(quad, mix)
	var c2 := Color(halo_color.r, halo_color.g, halo_color.b, halo_color.a * 0.25)
	var in_pts: PackedVector2Array = PackedVector2Array([])
	for i in range(segs + 1):
		var a := float(i) / float(segs) * TAU
		in_pts.append(Vector2(cos(a) * r_inner, sin(a) * r_inner * 0.42))
	draw_circle(Vector2(0, 0), r_inner * 0.6, c2)

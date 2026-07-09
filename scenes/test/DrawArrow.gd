extends Node2D
class_name DrawArrow
## 箭矢绘制：细长箭杆 + 锐利三角箭头 + 尾部羽毛

const COLOR_SHAFT := Color(0.45, 0.32, 0.18, 1.0)
const COLOR_SHAFT_DARK := Color(0.28, 0.18, 0.08, 1.0)
const COLOR_HEAD := Color(0.90, 0.92, 0.96, 1.0)
const COLOR_HEAD_EDGE := Color(0.35, 0.38, 0.44, 1.0)
const COLOR_FEATHER_A := Color(0.95, 0.45, 0.30, 1.0)
const COLOR_FEATHER_B := Color(0.98, 0.82, 0.38, 1.0)

var _spin_t: float = 0.0

func _process(delta: float) -> void:
	_spin_t += delta
	queue_redraw()

func _draw() -> void:
	var shaft_len: float = 34.0
	var shaft_w: float = 2.2
	var head_len: float = 10.0
	var head_w: float = 6.0
	var feather_len: float = 10.0
	var feather_w: float = 6.0
	draw_rect(Rect2(-shaft_len, -shaft_w * 0.5, shaft_len, shaft_w), COLOR_SHAFT, true)
	draw_line(Vector2(-shaft_len, -shaft_w * 0.5), Vector2(0.0, -shaft_w * 0.5), COLOR_SHAFT_DARK, 1.0)
	var tip := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(head_len, -head_w * 0.5),
		Vector2(head_len + 4.0, 0.0),
		Vector2(head_len, head_w * 0.5),
	])
	draw_colored_polygon(tip, COLOR_HEAD)
	draw_polyline(PackedVector2Array([tip[0], tip[1], tip[2], tip[3], tip[0]]), COLOR_HEAD_EDGE, 1.1)
	var f1 := PackedVector2Array([
		Vector2(-shaft_len, 0.0),
		Vector2(-shaft_len - feather_len, -feather_w),
		Vector2(-shaft_len + 3.0, -feather_w * 0.35),
	])
	draw_colored_polygon(f1, COLOR_FEATHER_A)
	var f2 := PackedVector2Array([
		Vector2(-shaft_len, 0.0),
		Vector2(-shaft_len - feather_len, feather_w),
		Vector2(-shaft_len + 3.0, feather_w * 0.35),
	])
	draw_colored_polygon(f2, COLOR_FEATHER_B)
	draw_line(Vector2(-shaft_len - feather_len * 0.4, -feather_w * 0.6), Vector2(-shaft_len + 1.0, -shaft_w * 0.65), COLOR_FEATHER_B * Color(0.8, 0.8, 0.8, 1.0), 1.0)

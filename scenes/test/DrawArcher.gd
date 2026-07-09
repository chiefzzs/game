extends DrawEnemyRect
class_name DrawArcher
## 弓箭手绘制：**外貌与普通敌人一致（灰色矩形），但去掉长剑，另一只手持弓**
## 保留普通敌人的：警戒感叹号、受伤闪红、命中环等全部特效

const COLOR_BOW := Color(0.58, 0.38, 0.18, 1.0)
const COLOR_BOW_DARK := Color(0.32, 0.20, 0.08, 1.0)
const COLOR_STRING := Color(0.88, 0.85, 0.82, 1.0)
const COLOR_ARROW_SHAFT := Color(0.46, 0.30, 0.16, 1.0)
const COLOR_ARROW_HEAD := Color(0.90, 0.92, 0.96, 1.0)
const COLOR_ARROW_FEATHER := Color(0.96, 0.44, 0.28, 1.0)

var _drawing_bow: bool = false
var _draw_progress: float = 0.0
var _draw_total: float = 1.0
var _release_anim_t: float = 0.0

func _draw_sword(_origin: Vector2, _slash_t: float) -> void:
	pass

func start_draw_bow(dur: float) -> void:
	_drawing_bow = true
	_draw_total = max(0.05, dur)
	_draw_progress = 0.0
	queue_redraw()

func release_arrow() -> void:
	_drawing_bow = false
	_release_anim_t = 0.18
	_draw_progress = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	super._process(delta)
	if _drawing_bow and _draw_total > 0.0001:
		_draw_progress = min(1.0, _draw_progress + delta / _draw_total)
	else:
		_draw_progress = max(0.0, _draw_progress - delta * 2.5)
	if _release_anim_t > 0.0:
		_release_anim_t = max(0.0, _release_anim_t - delta)
	queue_redraw()

func _draw() -> void:
	super._draw()
	var bow_hand_x: float = -12.0
	var bow_top_y: float = -18.0
	var bow_bot_y: float = 14.0
	var bow_len: float = bow_bot_y - bow_top_y
	var bow_curve_x: float = bow_hand_x - 10.0
	var string_rest_x: float = bow_hand_x - 2.5
	var draw_amount: float = _draw_progress
	var string_pull: float = draw_amount * 14.0
	var string_cur_x: float = string_rest_x + string_pull
	var bow_pts := PackedVector2Array([
		Vector2(bow_hand_x, bow_top_y),
		Vector2(bow_curve_x, bow_top_y + bow_len * 0.18),
		Vector2(bow_curve_x - 3.0, bow_top_y + bow_len * 0.5),
		Vector2(bow_curve_x, bow_top_y + bow_len * 0.82),
		Vector2(bow_hand_x, bow_bot_y),
	])
	draw_polyline(bow_pts, COLOR_BOW, 3.0)
	draw_polyline(bow_pts, COLOR_BOW_DARK, 1.0)
	var string_top := Vector2(bow_hand_x, bow_top_y + 1.5)
	var string_mid := Vector2(string_cur_x, bow_top_y + bow_len * 0.5)
	var string_bot := Vector2(bow_hand_x, bow_bot_y - 1.5)
	draw_line(string_top, string_mid, COLOR_STRING, 0.9)
	draw_line(string_mid, string_bot, COLOR_STRING, 0.9)
	if draw_amount > 0.08:
		var shaft_len: float = 24.0
		var shaft_cx: float = string_cur_x
		var shaft_cy: float = bow_top_y + bow_len * 0.5
		draw_rect(Rect2(shaft_cx - 4.0, shaft_cy - 1.0, shaft_len + 4.0, 2.0), COLOR_ARROW_SHAFT, true)
		var head_p := PackedVector2Array([
			Vector2(shaft_cx + shaft_len, shaft_cy),
			Vector2(shaft_cx + shaft_len - 6.0, shaft_cy - 3.0),
			Vector2(shaft_cx + shaft_len - 6.0, shaft_cy + 3.0),
		])
		draw_colored_polygon(head_p, COLOR_ARROW_HEAD)
		var f1_p := PackedVector2Array([
			Vector2(shaft_cx - 4.0 + 1.0, shaft_cy),
			Vector2(shaft_cx - 4.0 - 5.0, shaft_cy - 4.0),
			Vector2(shaft_cx - 4.0 + 3.0, shaft_cy - 1.5),
		])
		draw_colored_polygon(f1_p, COLOR_ARROW_FEATHER)
		var f2_p := PackedVector2Array([
			Vector2(shaft_cx - 4.0 + 1.0, shaft_cy),
			Vector2(shaft_cx - 4.0 - 5.0, shaft_cy + 4.0),
			Vector2(shaft_cx - 4.0 + 3.0, shaft_cy + 1.5),
		])
		draw_colored_polygon(f2_p, COLOR_ARROW_FEATHER)
	if _release_anim_t > 0.0:
		var a: float = _release_anim_t / 0.18
		var cx: float = bow_curve_x - 18.0 * (1.0 - a)
		var cy: float = bow_top_y + bow_len * 0.5
		for i in range(3):
			var ang: float = (i * 1.3) + 2.0
			var rr: float = 5.0 + (1.0 - a) * 9.0
			draw_circle(Vector2(cx + cos(ang) * rr, cy + sin(ang) * rr), 1.3 * a, COLOR_STRING * Color(1.0, 1.0, 1.0, a))

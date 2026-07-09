extends Node2D
class_name HitFlyer

const _SELF_FLYER_SCRIPT := preload("res://scripts/combat/HitFlyer.gd")

var text: String = "-18"
var color: Color = Color.WHITE
var life: float = 0.9
var age: float = 0.0
var offset: Vector2 = Vector2(0, 0)
var rise_speed: float = 55.0
var sway_amp: float = 14.0
var sway_freq: float = 5.0
var font_size: int = 22

func _process(delta: float) -> void:
	age += delta
	if age >= life:
		if is_inside_tree():
			queue_free()
		return
	offset.y -= rise_speed * delta
	offset.x = sin(age * sway_freq) * sway_amp
	queue_redraw()

func _draw() -> void:
	var alpha: float = clamp(1.0 - age / max(0.001, life), 0.0, 1.0)
	var col := Color(color.r, color.g, color.b, alpha)
	var shadow := Color(0, 0, 0, alpha * 0.85)
	var f := ThemeDB.fallback_font
	var base := Vector2(offset.x, offset.y)
	var hs := 2
	draw_string(f, base + Vector2(hs, hs), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow)
	draw_string(f, base + Vector2(hs, -hs), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow)
	draw_string(f, base + Vector2(-hs, hs), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow)
	draw_string(f, base + Vector2(-hs, -hs), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow)
	draw_string(f, base, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, col)

static func spawn(parent: Node2D, pos: Vector2, dmg: int, crit: bool, backstab: bool) -> HitFlyer:
	var hf: HitFlyer = _SELF_FLYER_SCRIPT.new()
	if backstab:
		hf.text = "背刺%d" % dmg
		hf.color = Color(1.0, 0.25, 0.35)
		hf.font_size = 24
	elif crit:
		hf.text = "-暴击%d" % dmg
		hf.color = Color(1.0, 0.92, 0.3)
		hf.font_size = 24
	else:
		hf.text = "-%d" % dmg
		hf.color = Color.WHITE
	hf.global_position = pos
	if parent != null and is_instance_valid(parent):
		parent.add_child(hf)
	return hf

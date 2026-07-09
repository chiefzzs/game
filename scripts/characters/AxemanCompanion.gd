extends "res://scripts/characters/CompanionBase.gd"
class_name AxemanCompanion
## V0.3e AxemanCompanion.gd — 樵夫同伴（默认近战高伤·双手斧）
## 职责：数值初始化 + 几何图形绘制（无 sprite 资源依赖）
## 继承 CompanionBase→CharacterBase，4 AI 态不破坏

func _ready() -> void:
	super._ready()
	var cfg_mgr: Node = _autoload("ConfigManager")
	var has_cfg: bool = cfg_mgr != null and cfg_mgr.has_method("cfg_get")
	var cfg: Dictionary = {}
	if has_cfg:
		cfg = cfg_mgr.cfg_get("companions.axeman", {})
	if cfg.is_empty():
		cfg = {
			"id": "axeman", "display_name": "樵夫·伯克",
			"max_hp": 120, "base_atk": 12, "base_def": 4,
			"move_speed": 220, "jump_force": -460,
			"weapon": { "id": "axe_2h", "name": "双手斧", "atk_mult": 1.2, "range": 58, "cd_sec": 1.2, "knockback": 240, "break_shield": true },
			"ai": { "follow_distance": 90, "alert_radius": 260, "attack_range": 55, "retreat_radius": 340 }
		}
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(30, 56)
	cs.shape = rs
	cs.position = Vector2(0, -28)
	add_child(cs)
	set_meta("companion_class", "AxemanCompanion")

func _draw() -> void:
	var body_color := Color(0.38, 0.25, 0.18)
	var hat_color := Color(0.86, 0.55, 0.25)
	var skin := Color(1.0, 0.85, 0.72)
	var axe_wood := Color(0.50, 0.30, 0.12)
	var axe_blade := Color(0.72, 0.74, 0.78)
	draw_rect(Rect2(-17, -2, 34, 30), body_color, true)
	draw_rect(Rect2(-17, -2, 34, 30), Color(0,0,0,0.25), false, 1.0)
	draw_circle(Vector2(0, -24), 15.0, skin)
	var hat := PackedVector2Array([
		Vector2(-24, -30), Vector2(24, -30), Vector2(16, -46), Vector2(-16, -46)])
	draw_colored_polygon(hat, hat_color)
	draw_circle(Vector2(-5 + 3.0 * facing, -26), 2.0, Color.BLACK)
	draw_circle(Vector2(5 + 3.0 * facing, -26), 2.0, Color.BLACK)
	var handle_x := 16.0 * facing
	draw_line(Vector2(handle_x, -30), Vector2(handle_x + 14 * facing, 0), axe_wood, 3.0)
	var blade := PackedVector2Array([
		Vector2(handle_x + 8 * facing, -30), Vector2(handle_x + 32 * facing, -38),
		Vector2(handle_x + 36 * facing, -8), Vector2(handle_x + 10 * facing, -2)])
	draw_colored_polygon(blade, axe_blade)
	if state == FSMState.ATTACK1:
		var arc := PackedVector2Array([])
		for i in range(10):
			var ang := (-1.2 + float(i) * 0.28) * facing
			arc.append(Vector2(cos(ang) * 60.0, sin(ang) * 60.0 - 10.0))
		draw_polyline(arc, Color(1, 0.9, 0.3, 0.7), 4.0)
	if is_invincible and int(Time.get_ticks_msec() / 80) % 2 == 0:
		draw_rect(Rect2(-20, -62, 40, 66), Color(1,1,1,0.18), true)

func _process(_delta: float) -> void:
	queue_redraw()

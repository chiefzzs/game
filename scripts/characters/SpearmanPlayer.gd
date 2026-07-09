extends "res://scripts/characters/PlayerBase.gd"
class_name SpearmanPlayer
## V0.3g 枪兵 Spearman 三号位
## 特点：血薄90、远程直线刺10；形象：红袍+8字长枪头，攻击长条突刺

func _ready() -> void:
	super._ready()
	character_id = "player_spear"
	var cfg_mgr: Node = _autoload("ConfigManager")
	var has_cfg: bool = cfg_mgr != null and cfg_mgr.has_method("cfg_get")
	display_name = str(cfg_mgr.cfg_get("player.spear.display_name", "疾风枪兵 Lance")) if has_cfg else "疾风枪兵 Lance"
	max_hp = int(cfg_mgr.cfg_get("player.spear.max_hp", 90)) if has_cfg else 90
	hp = max_hp
	max_stamina = int(cfg_mgr.cfg_get("player.spear.max_stamina", 110)) if has_cfg else 110
	stamina = max_stamina
	atk = int(cfg_mgr.cfg_get("player.spear.base_atk", 10)) if has_cfg else 10
	defense = int(cfg_mgr.cfg_get("player.spear.base_def", 1)) if has_cfg else 1
	move_speed = float(cfg_mgr.cfg_get("player.spear.move_speed", 290)) if has_cfg else 290.0
	jump_force = float(cfg_mgr.cfg_get("player.spear.jump_force", -560)) if has_cfg else -560.0
	gravity = float(cfg_mgr.cfg_get("physics.gravity", 1800)) if has_cfg else 1800.0
	current_weapon_id = "spear"
	weapon_defs = {
		"fist":  {"atk_mult": 0.8, "range": 30.0, "break_shield": false},
		"spear": {"atk_mult": 1.15, "range": 78.0, "break_shield": false}
	}
	weapon = weapon_defs["spear"]
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(24, 50)
	cs.shape = rs
	cs.position = Vector2(0, -25)
	add_child(cs)
	queue_redraw()

func _draw() -> void:
	var robe := Color(0.78, 0.18, 0.2)
	var robe_dark := Color(0.48, 0.1, 0.12)
	var hair := Color(0.22, 0.16, 0.1)
	var skin := Color(1.0, 0.86, 0.7)
	var spear_pole := Color(0.5, 0.32, 0.15)
	var spear_head := Color(0.88, 0.88, 0.95)

	var robe_shape: PackedVector2Array = PackedVector2Array([
		Vector2(-15, 32), Vector2(15, 32),
		Vector2(12, -8), Vector2(8, -14), Vector2(-8, -14), Vector2(-12, -8)])
	draw_colored_polygon(robe_shape, robe)
	draw_line(Vector2(-15, 32), Vector2(15, 32), robe_dark, 2.0)
	draw_line(Vector2(0, -14), Vector2(0, 32), robe_dark, 1.2)
	draw_circle(Vector2(0, -22), 12.0, skin)
	var hair_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-13, -22), Vector2(13, -22), Vector2(11, -30),
		Vector2(4, -34), Vector2(-4, -34), Vector2(-11, -30)])
	draw_colored_polygon(hair_pts, hair)
	draw_circle(Vector2(-4 + 2.5 * facing, -23), 1.4, Color(0.05,0.05,0.08))
	draw_circle(Vector2(4 + 2.5 * facing, -23), 1.4, Color(0.05,0.05,0.08))
	var pole_x1: float = 14.0 * facing
	var pole_x2: float = 58.0 * facing
	var pole_y: float = -4.0
	draw_line(Vector2(pole_x1, pole_y), Vector2(pole_x2, pole_y), spear_pole, 3.5)
	var hx1: float = pole_x2
	var tip_x: float = (pole_x2 + 16.0 * facing)
	var hy_up: float = pole_y - 5.0
	var hy_dn: float = pole_y + 5.0
	var head_pts: PackedVector2Array = PackedVector2Array([
		Vector2(hx1, hy_up), Vector2(tip_x, pole_y), Vector2(hx1, hy_dn)])
	draw_colored_polygon(head_pts, spear_head)
	draw_line(Vector2(hx1, hy_up - 1.5), Vector2(hx1 - 6.0 * facing, pole_y), Color(0.7,0.7,0.8), 1.5)
	draw_line(Vector2(hx1, hy_dn + 1.5), Vector2(hx1 - 6.0 * facing, pole_y), Color(0.7,0.7,0.8), 1.5)
	if state == FSMState.ATTACK1 or state == FSMState.ATTACK2:
		var thrust_off: float = 28.0 * facing
		var stab_x1: float = pole_x2 + thrust_off
		var stab_x2: float = stab_x1 + 18.0 * facing
		draw_line(Vector2(pole_x1, pole_y), Vector2(stab_x1, pole_y), spear_pole, 3.5)
		var stab_head: PackedVector2Array = PackedVector2Array([
			Vector2(stab_x1, hy_up), Vector2(stab_x2, pole_y), Vector2(stab_x1, hy_dn)])
		draw_colored_polygon(stab_head, spear_head)
		var glow_pts: PackedVector2Array = PackedVector2Array([
			Vector2(pole_x1 + 12.0 * facing, pole_y - 7.0),
			Vector2(stab_x2 + 4.0 * facing, pole_y),
			Vector2(pole_x1 + 12.0 * facing, pole_y + 7.0)])
		draw_colored_polygon(glow_pts, Color(1.0, 0.75, 0.75, 0.35))
	if state == FSMState.BLOCK:
		var p := PackedVector2Array([
			Vector2(16 * facing, -20), Vector2(24 * facing, -22),
			Vector2(24 * facing, 6), Vector2(16 * facing, 2)])
		draw_colored_polygon(p, Color(0.9, 0.4, 0.4, 0.9))
	if is_invincible and int(Time.get_ticks_msec() / 80) % 2 == 0:
		draw_rect(Rect2(-17, -36, 34, 70), Color(1,1,1,0.15), true)

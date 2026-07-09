extends "res://scripts/characters/PlayerBase.gd"
class_name MaceFighterPlayer
## V0.3g 锤兵 MaceFighter 二号位
## 特点：血厚140、攻高14；形象：灰铁盔甲+蓝紫钉锤，攻击为圆形砸击范围

func _ready() -> void:
	super._ready()
	character_id = "player_mace"
	var cfg_mgr: Node = _autoload("ConfigManager")
	var has_cfg: bool = cfg_mgr != null and cfg_mgr.has_method("cfg_get")
	display_name = str(cfg_mgr.cfg_get("player.mace.display_name", "铁壁锤兵 Gregor")) if has_cfg else "铁壁锤兵 Gregor"
	max_hp = int(cfg_mgr.cfg_get("player.mace.max_hp", 140)) if has_cfg else 140
	hp = max_hp
	max_stamina = int(cfg_mgr.cfg_get("player.mace.max_stamina", 120)) if has_cfg else 120
	stamina = max_stamina
	atk = int(cfg_mgr.cfg_get("player.mace.base_atk", 14)) if has_cfg else 14
	defense = int(cfg_mgr.cfg_get("player.mace.base_def", 5)) if has_cfg else 5
	move_speed = float(cfg_mgr.cfg_get("player.mace.move_speed", 235)) if has_cfg else 235.0
	jump_force = float(cfg_mgr.cfg_get("player.mace.jump_force", -500)) if has_cfg else -500.0
	gravity = float(cfg_mgr.cfg_get("physics.gravity", 1800)) if has_cfg else 1800.0
	current_weapon_id = "mace"
	weapon_defs = {
		"fist": {"atk_mult": 0.8, "range": 32.0, "break_shield": false},
		"mace": {"atk_mult": 1.5, "range": 52.0, "break_shield": true}
	}
	weapon = weapon_defs["mace"]
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(32, 56)
	cs.shape = rs
	cs.position = Vector2(0, -28)
	add_child(cs)
	var cam := Camera2D.new()
	cam.current = true
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 10.0
	cam.zoom = Vector2(1.0, 1.0)
	cam.limit_left = -1000000
	cam.limit_right = 1000000
	cam.limit_top = -1000000
	cam.limit_bottom = 1000000
	add_child(cam)
	queue_redraw()

func _draw() -> void:
	var body_armor := Color(0.55, 0.58, 0.65)
	var body_dark := Color(0.38, 0.4, 0.46)
	var helmet := Color(0.72, 0.75, 0.82)
	var skin := Color(0.98, 0.8, 0.6)
	var mace_handle := Color(0.3, 0.2, 0.1)
	var mace_head := Color(0.3, 0.2, 0.85)
	var mace_spikes := Color(0.6, 0.5, 0.9)

	draw_rect(Rect2(-18, 0, 36, 32), body_armor, true)
	draw_rect(Rect2(-18, 0, 36, 32), body_dark, false, 1.5)
	draw_rect(Rect2(-15, 10, 30, 14), Color(0.35,0.38,0.46), true)
	var face_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-13, -18), Vector2(13, -18), Vector2(15, -6),
		Vector2(-15, -6)])
	draw_colored_polygon(face_pts, helmet)
	draw_rect(Rect2(-7, -14, 14, 6), skin, true)
	draw_circle(Vector2(-3 + 3.0 * facing, -12), 1.5, Color.BLACK)
	draw_circle(Vector2(4 + 3.0 * facing, -12), 1.5, Color.BLACK)
	if is_on_floor():
		draw_line(Vector2(-12, 31), Vector2(-4, 31), Color(0.2,0.2,0.25), 3.0)
		draw_line(Vector2(4, 31), Vector2(12, 31), Color(0.2,0.2,0.25), 3.0)
	else:
		draw_line(Vector2(-10, 30), Vector2(-2, 34), Color(0.2,0.2,0.25), 3.0)
		draw_line(Vector2(2, 34), Vector2(10, 30), Color(0.2,0.2,0.25), 3.0)
	match current_weapon_id:
		"mace":
			var handle_x1 := 16 * facing
			var handle_x2 := 36 * facing
			draw_line(Vector2(handle_x1, -8), Vector2(handle_x2, -16), mace_handle, 5.0)
			draw_circle(Vector2(handle_x2, -16), 10.0, mace_head)
			for i in range(6):
				var ang := float(i) * 1.047
				var sx := handle_x2 + int(cos(ang) * 13.0)
				var sy := -16 + int(sin(ang) * 13.0)
				draw_line(Vector2(handle_x2, -16), Vector2(sx, sy), mace_spikes, 2.0)
		_:
			draw_line(Vector2(14 * facing, -2), Vector2(24 * facing, 2), Color(0.6,0.6,0.6), 2.5)
	if state == FSMState.ATTACK1 or state == FSMState.ATTACK2:
		var cx := 40.0 * facing
		var cy := 6.0
		for r in [38.0, 28.0]:
			var arc: PackedVector2Array = PackedVector2Array([])
			for i in range(14):
				var ang: float = (-0.9 + float(i) * 0.16) * facing
				arc.append(Vector2(cx + cos(ang) * r, cy + sin(ang) * r * 0.9))
			draw_polyline(arc, Color(0.5, 0.35, 1.0, 0.75), 3.0)
	if state == FSMState.BLOCK:
		var p := PackedVector2Array([
			Vector2(20 * facing, -28), Vector2(32 * facing, -34),
			Vector2(32 * facing, 10), Vector2(20 * facing, 4)])
		draw_colored_polygon(p, Color(0.45, 0.55, 0.9, 0.9))
	if is_invincible and int(Time.get_ticks_msec() / 80) % 2 == 0:
		draw_rect(Rect2(-20, -32, 40, 66), Color(1,1,1,0.15), true)

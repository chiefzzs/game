extends "res://scripts/characters/PlayerBase.gd"
class_name FarmerPlayer
## V0.3 FarmerPlayer.gd — 默认玩家布衣农夫 John
## 职责：数值初始化 + 简单几何图形绘制（无sprite资源依赖）

func _ready() -> void:
	super._ready()
	character_id = "player_farmer"
	var cfg_mgr: Node = _autoload("ConfigManager")
	var has_cfg: bool = cfg_mgr != null and cfg_mgr.has_method("cfg_get")
	display_name = str(cfg_mgr.cfg_get("player.farmer.display_name", "布衣农夫 John")) if has_cfg else "布衣农夫 John"
	max_hp = int(cfg_mgr.cfg_get("player.farmer.max_hp", 100)) if has_cfg else 100
	hp = max_hp
	max_stamina = int(cfg_mgr.cfg_get("player.farmer.max_stamina", 100)) if has_cfg else 100
	stamina = max_stamina
	atk = int(cfg_mgr.cfg_get("player.farmer.base_atk", 8)) if has_cfg else 8
	defense = int(cfg_mgr.cfg_get("player.farmer.base_def", 2)) if has_cfg else 2
	move_speed = float(cfg_mgr.cfg_get("player.farmer.move_speed", 260)) if has_cfg else 260.0
	jump_force = float(cfg_mgr.cfg_get("player.farmer.jump_force", -520)) if has_cfg else -520.0
	gravity = float(cfg_mgr.cfg_get("physics.gravity", 1800)) if has_cfg else 1800.0
	weapon_defs = cfg_mgr.cfg_get("player.farmer.weapons", {}) if has_cfg else {}
	if weapon_defs.is_empty():
		weapon_defs = {
			"fist": {"atk_mult": 1.0, "range": 36.0, "break_shield": false},
			"axe":  {"atk_mult": 1.3, "range": 46.0, "break_shield": true},
			"bow":  {"atk_mult": 0.9, "range": 160.0, "break_shield": false}
		}
	attack_chain_cfg = cfg_mgr.cfg_get("player.farmer.attack_chain", []) if has_cfg else []
	var def_wep: String = str(cfg_mgr.cfg_get("player.farmer.default_weapon", "axe")) if has_cfg else "axe"
	if weapon_defs.has(def_wep):
		current_weapon_id = def_wep
		weapon = weapon_defs[def_wep]
	else:
		current_weapon_id = "fist"
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(28, 52)
	cs.shape = rs
	cs.position = Vector2(0, -26)
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
	set_meta("player_farmer_init", true)
	queue_redraw()

func _draw() -> void:
	var body_color := Color(0.85, 0.72, 0.45) # 土黄布衣
	var hat_color := Color(0.45, 0.30, 0.12) # 棕草帽
	var skin := Color(1.0, 0.87, 0.68)
	# 阴影
	draw_rect(Rect2(-16, -2, 32, 28), body_color, true)
	draw_rect(Rect2(-16, -2, 32, 28), Color(0,0,0,0.3), false, 1.0)
	# 头
	draw_circle(Vector2(0, -20), 14.0, skin)
	# 草帽
	var pts := PackedVector2Array([Vector2(-22, -22), Vector2(22, -22), Vector2(12, -36), Vector2(-12, -36)])
	draw_colored_polygon(pts, hat_color)
	# 眼睛
	draw_circle(Vector2(-5 + 3.0 * facing, -22), 1.8, Color.BLACK)
	draw_circle(Vector2(5 + 3.0 * facing, -22), 1.8, Color.BLACK)
	# 武器方向
	match current_weapon_id:
		"axe":
			var ax := PackedVector2Array([
				Vector2(14 * facing, -18), Vector2(30 * facing, -22),
				Vector2(34 * facing, -6), Vector2(18 * facing, -2)])
			draw_colored_polygon(ax, Color(0.55, 0.33, 0.15))
		"bow":
			draw_arc(Vector2(18 * facing, -6), 16.0, -1.0, 1.0, 10, Color(0.45, 0.7, 0.35), 2.0)
		_:
			draw_line(Vector2(12 * facing, -4), Vector2(22 * facing, 0), Color(0.6,0.6,0.6), 2.5)
	# BLOCK姿态: 前盾
	if state == FSMState.BLOCK:
		var p := PackedVector2Array([
			Vector2(18 * facing, -22), Vector2(28 * facing, -26),
			Vector2(28 * facing, 6), Vector2(18 * facing, 2)])
		draw_colored_polygon(p, Color(0.55, 0.75, 0.95, 0.9))
	# 无敌闪烁
	if is_invincible and int(Time.get_ticks_msec() / 80) % 2 == 0:
		draw_rect(Rect2(-18, -58, 36, 62), Color(1,1,1,0.15), true)

func _process(_delta: float) -> void:
	queue_redraw()

extends CompanionBase
## V0.3 ShepherdCompanion.gd — 牧人：近战+全队周期回血+替主角挡50%

func _ready() -> void:
	super._ready()
	id_key = "shepherd"
	var cfg := ConfigManager.cfg_get("companions.shepherd", {}) if ConfigManager else {}
	display_name = str(cfg.get("display_name", "牧人"))
	max_hp = int(cfg.get("max_hp", 80)) ; hp = max_hp
	base_atk = int(cfg.get("base_atk", 6))
	base_def = int(cfg.get("base_def", 3))
	move_speed = float(cfg.get("move_speed", 235))
	jump_force = float(cfg.get("jump_force", -480))
	weapon = cfg.get("weapon", {"id":"staff","name":"牧羊杖","atk_mult":0.8,"range":48,"cd_sec":0.9,"knockback":90,"break_shield":false})
	ai_cfg = cfg.get("ai", {"follow_distance":60,"alert_radius":200,"attack_range":45,"retreat_radius":280,"heal_per_sec":2,"heal_cycle_sec":5.0,"heal_pct_per_cycle":0.02,"shield_ally_pct":0.5})
	preferred_distance = float(ai_cfg.get("follow_distance", 60))
	robe = Color(0.92, 0.88, 0.60)
	hat_c = Color(0.96, 0.96, 0.96)
	queue_redraw()

var robe: Color = Color(0.92, 0.88, 0.60)
var hat_c: Color = Color(0.96, 0.96, 0.96)

func _process(_d: float) -> void: queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-13, -2, 26, 26), robe, true)
	draw_circle(Vector2(0, -17), 11.5, Color(1,0.87,0.68))
	draw_circle(Vector2(0, -26), 9.0, hat_c)
	draw_rect(Rect2(-4, -40, 8, 16), hat_c, true)
	draw_circle(Vector2(-3 + facing*3, -17), 1.5, Color.BLACK)
	draw_circle(Vector2(3 + facing*3, -17), 1.5, Color.BLACK)
	draw_line(Vector2(12*facing, -8), Vector2(32*facing, 8), Color(0.55,0.38,0.20), 3.0)
	draw_circle(Vector2(32*facing, 10), 3.0, Color(0.85,0.7,0.4))
	# 治愈光环
	if heal_cycle_left < 0.3:
		draw_arc(Vector2(0,-8), 22.0, 0.0, TAU, 24, Color(0.5,1.0,0.5,0.6), 1.5)

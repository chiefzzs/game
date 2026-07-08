extends CompanionBase
## V0.3 HunterCompanion.gd — 猎户：短弓远程，射速快

func _ready() -> void:
	super._ready()
	id_key = "hunter"
	var cfg := ConfigManager.cfg_get("companions.hunter", {}) if ConfigManager else {}
	display_name = str(cfg.get("display_name", "猎户"))
	max_hp = int(cfg.get("max_hp", 70)) ; hp = max_hp
	base_atk = int(cfg.get("base_atk", 9))
	base_def = int(cfg.get("base_def", 1))
	move_speed = float(cfg.get("move_speed", 250))
	jump_force = float(cfg.get("jump_force", -500))
	weapon = cfg.get("weapon", {"id":"shortbow","name":"猎户短弓","atk_mult":1.0,"range":500,"cd_sec":0.9,"knockback":40,"break_shield":false,"projectile":true,"proj_speed":620})
	ai_cfg = cfg.get("ai", {"follow_distance":140,"alert_radius":320,"attack_range":380,"retreat_radius":420,"preferred_range":300})
	preferred_distance = float(ai_cfg.get("follow_distance", 140))
	tunic = Color(0.25, 0.55, 0.25)
	hood  = Color(0.4, 0.3, 0.2)
	queue_redraw()

var tunic: Color = Color(0.25, 0.55, 0.25)
var hood: Color = Color(0.4, 0.3, 0.2)

func _process(_d: float) -> void: queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-12, -2, 24, 24), tunic, true)
	draw_circle(Vector2(0, -16), 11.0, Color(1,0.87,0.68))
	var hd := PackedVector2Array([Vector2(-14,-18),Vector2(14,-18),Vector2(8,-30),Vector2(-8,-30),Vector2(-6,-18)])
	draw_colored_polygon(hd, hood)
	draw_circle(Vector2(-3 + facing*3, -18), 1.5, Color.BLACK)
	draw_circle(Vector2(3 + facing*3, -18), 1.5, Color.BLACK)
	draw_arc(Vector2(14*facing,-4), 14.0, -1.1, 1.1, 12, Color(0.75,0.55,0.35), 2.0)

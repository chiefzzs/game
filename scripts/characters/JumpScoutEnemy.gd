extends "res://scripts/characters/EnemyBase.gd"
## V0.3 JumpScoutEnemy.gd — 跳跃斥候：高机动双匕

func _ready() -> void:
	super._ready()
	id_key = "jump_scout"
	var cfg: Dictionary = ConfigManager.cfg_get("enemies.jump_scout", {}) if ConfigManager else {}
	display_name = str(cfg.get("display_name", "跳跃斥候"))
	max_hp = int(cfg.get("max_hp", 40)) ; hp = max_hp
	base_atk = int(cfg.get("base_atk", 6))
	base_def = int(cfg.get("base_def", 0))
	move_speed = float(cfg.get("move_speed", 190))
	jump_force = float(cfg.get("jump_force", -520))
	weapon = cfg.get("weapon", {"id":"dagger","name":"双匕","atk_mult":0.9,"range":38,"cd_sec":0.8,"knockback":80,"break_shield":false})
	ai_cfg = cfg.get("ai", {"patrol_radius":150,"aggro_radius":300,"attack_range":38,"give_up_radius":500,"auto_jump_chance":0.5,"drop_gold":[4,10],"drop_potion_chance":0.15})
	training_dummy = bool(ai_cfg.get("training_dummy", false))
	tunic = Color(0.25, 0.25, 0.35)
	hood = Color(0.15, 0.15, 0.22)
	queue_redraw()

var tunic: Color = Color(0.25, 0.25, 0.35)
var hood: Color = Color(0.15, 0.15, 0.22)

func _process(_d: float) -> void: queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-11, -2, 22, 22), tunic, true)
	draw_circle(Vector2(0, -15), 10.5, Color(1,0.87,0.68))
	var arr := PackedVector2Array([Vector2(-13,-16),Vector2(13,-16),Vector2(8,-28),Vector2(-8,-28),Vector2(-6,-16)])
	draw_colored_polygon(arr, hood)
	draw_circle(Vector2(-3 + facing*3, -16), 1.4, Color(1, 0.25, 0.25))
	draw_circle(Vector2(3 + facing*3, -16), 1.4, Color(1, 0.25, 0.25))
	draw_line(Vector2(11*facing,-2), Vector2(26*facing,-4), Color(0.75, 0.75, 0.8), 2.0)
	draw_line(Vector2(11*facing,4), Vector2(26*facing,6), Color(0.75, 0.75, 0.8), 2.0)

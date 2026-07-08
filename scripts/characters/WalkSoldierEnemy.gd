extends "res://scripts/characters/EnemyBase.gd"
## V0.3 WalkSoldierEnemy.gd — 巡逻兵：短剑巡逻，稳定追击

func _ready() -> void:
	super._ready()
	id_key = "walk_soldier"
	var cfg: Dictionary = ConfigManager.cfg_get("enemies.walk_soldier", {}) if ConfigManager else {}
	display_name = str(cfg.get("display_name", "巡逻兵"))
	max_hp = int(cfg.get("max_hp", 60)) ; hp = max_hp
	base_atk = int(cfg.get("base_atk", 7))
	base_def = int(cfg.get("base_def", 1))
	move_speed = float(cfg.get("move_speed", 130))
	jump_force = float(cfg.get("jump_force", 0))
	weapon = cfg.get("weapon", {"id":"short_sword","name":"短剑","atk_mult":1.0,"range":48,"cd_sec":1.1,"knockback":110,"break_shield":false})
	ai_cfg = cfg.get("ai", {"patrol_radius":120,"aggro_radius":240,"attack_range":48,"give_up_radius":420,"drop_gold":[3,8],"drop_potion_chance":0.1})
	training_dummy = bool(ai_cfg.get("training_dummy", false))
	tunic = Color(0.45, 0.45, 0.55)
	helmet = Color(0.7, 0.7, 0.75)
	queue_redraw()

var tunic: Color = Color(0.45, 0.45, 0.55)
var helmet: Color = Color(0.7, 0.7, 0.75)

func _process(_d: float) -> void: queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-13, -2, 26, 26), tunic, true)
	draw_circle(Vector2(0, -17), 11.5, Color(1,0.87,0.68))
	draw_rect(Rect2(-12, -30, 24, 14), helmet, true)
	draw_rect(Rect2(-5, -17, 10, 4), Color.BLACK, true)
	draw_line(Vector2(12*facing,0),Vector2(30*facing,-8),Color(0.8,0.8,0.85), 2.5)

extends "res://scripts/characters/EnemyBase.gd"
## V0.3 DummyEnemy.gd — 训练木桩：不移动，HP恢复，不死亡（仅用于验收HUD）

func _ready() -> void:
	super._ready()
	id_key = "dummy"
	var cfg: Dictionary = ConfigManager.cfg_get("enemies.dummy", {}) if ConfigManager else {}
	display_name = str(cfg.get("display_name", "训练木桩"))
	max_hp = int(cfg.get("max_hp", 200)) ; hp = max_hp
	base_atk = int(cfg.get("base_atk", 0))
	base_def = int(cfg.get("base_def", 0))
	move_speed = 0.0
	jump_force = 0.0
	weapon = cfg.get("weapon", {"id":"none","name":"无","atk_mult":0.0,"range":0,"cd_sec":99.0,"knockback":0,"break_shield":false})
	ai_cfg = cfg.get("ai", {"patrol_radius":0,"aggro_radius":0,"attack_range":0,"give_up_radius":0,"training_dummy":true,"drop_gold":[0,0],"drop_potion_chance":0})
	training_dummy = true
	wood_color = Color(0.55, 0.4, 0.22)
	ring_color = Color(0.9, 0.75, 0.4)
	queue_redraw()

var wood_color: Color = Color(0.55, 0.4, 0.22)
var ring_color: Color = Color(0.9, 0.75, 0.4)

func _process(_d: float) -> void:
	if hp < max_hp:
		hp = min(max_hp, hp + 2)
		if GameEvents:
			GameEvents.emit_signal("character_stats_changed", self)
	queue_redraw()

func _on_death(_killer: Node) -> void:
	hp = max_hp ; alive = true
	is_invincible = true
	invincible_timer = 2.0
	change_state(_CE.BaseState.IDLE)

func _draw() -> void:
	draw_rect(Rect2(-14, -30, 28, 54), wood_color, true)
	draw_rect(Rect2(-14, -30, 28, 54), Color(0,0,0,0.25), false, 1.0)
	for i in range(3):
		draw_rect(Rect2(-14, -26 + i*16, 28, 4), ring_color, true)
	draw_rect(Rect2(-6, 22, 12, 10), Color(0.4,0.3,0.18), true)

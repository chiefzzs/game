extends CompanionBase
## V0.3 AxemanCompanion.gd — 樵夫：双手斧，慢速重砍，破盾

func _ready() -> void:
	super._ready()
	id_key = "axeman"
	var cfg := ConfigManager.cfg_get("companions.axeman", {}) if ConfigManager else {}
	display_name = str(cfg.get("display_name", "樵夫"))
	max_hp = int(cfg.get("max_hp", 120)) ; hp = max_hp
	base_atk = int(cfg.get("base_atk", 12))
	base_def = int(cfg.get("base_def", 4))
	move_speed = float(cfg.get("move_speed", 220))
	jump_force = float(cfg.get("jump_force", -460))
	weapon = cfg.get("weapon", {"id":"axe_2h","name":"双手斧","atk_mult":1.2,"range":58,"cd_sec":1.2,"knockback":240,"break_shield":true})
	ai_cfg = cfg.get("ai", {"follow_distance":90,"alert_radius":260,"attack_range":55,"retreat_radius":340})
	preferred_distance = float(ai_cfg.get("follow_distance", 90))
	body_color = Color(0.5, 0.3, 0.15)
	hat_color = Color(0.28, 0.16, 0.08)
	weapon_color = Color(0.55, 0.33, 0.15)
	queue_redraw()

var body_color: Color = Color(0.5, 0.3, 0.15)
var hat_color: Color = Color(0.28, 0.16, 0.08)
var weapon_color: Color = Color(0.55, 0.33, 0.15)

func _process(_d: float) -> void: queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-14, -2, 28, 26), body_color, true)
	draw_rect(Rect2(-14, -2, 28, 26), Color(0,0,0,0.25), false, 1.0)
	draw_circle(Vector2(0, -18), 12.0, Color(1,0.87,0.68))
	var tri := PackedVector2Array([Vector2(-18,-20),Vector2(18,-20),Vector2(10,-32),Vector2(-10,-32)])
	draw_colored_polygon(tri, hat_color)
	draw_circle(Vector2(-4 + facing*3, -20), 1.6, Color.BLACK)
	draw_circle(Vector2(4 + facing*3, -20), 1.6, Color.BLACK)
	var hx := PackedVector2Array([
		Vector2(12*facing,-20),Vector2(34*facing,-26),
		Vector2(40*facing,-2),Vector2(16*facing,2)])
	draw_colored_polygon(hx, weapon_color)
	if state == BaseState.BLOCK:
		var p := PackedVector2Array([
			Vector2(16*facing,-22),Vector2(26*facing,-26),
			Vector2(26*facing,6),Vector2(16*facing,2)])
		draw_colored_polygon(p, Color(0.55,0.75,0.95,0.9))

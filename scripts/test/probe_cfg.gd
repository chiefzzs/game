extends SceneTree
var _t: int = 0
const _CDC := preload("res://scripts/combat/CombatDamageCalculator.gd")

func _process(_d: float) -> bool:
	_t += 1
	if _t == 1:
		var cfg: Node = null
		if Engine.has_singleton("ConfigManager"):
			cfg = Engine.get_singleton("ConfigManager")
		print("PROBE2: has_cfg=", cfg != null)
		if cfg != null:
			var F: Dictionary = _CDC.get_default_formula()
			print("PROBE2: F_orig.crit.default_rate=", F.crit.default_rate)
			F.crit.default_rate = 1.01
			cfg.call("override", "formula", F)
			var got = cfg.call("cfg_get", "formula", null)
			print("PROBE2: cfg_get formula is dict=", typeof(got)==TYPE_DICTIONARY, "  crit.rate=", got.crit.default_rate if (typeof(got)==TYPE_DICTIONARY and got.has("crit")) else "NO_CRIT")
			var a := {"base_atk":20,"facing":1.0,"hp":100,"max_hp":100,"weapon":{"break_shield":false,"knockback":60},"kind":0,"state":0}
			var b := {"base_def":0,"facing":1.0,"hp":100,"max_hp":100,"kind":2,"state":0,"stamina":100.0,"block_damage_reduction":0.8}
			var r: Dictionary = _CDC.calculate(a, b, 20, "physical", Vector2.RIGHT, false, 1.0)
			print("PROBE2: final_damage=", r.final_damage, " is_crit=", r.is_crit, " steps=", r.steps)
			cfg.call("override", "formula", null)
			var exit_c: int = 0 if (r.is_crit and int(r.final_damage) == 35) else 1
			call_deferred("_q", exit_c)
		else:
			call_deferred("_q", 99)
	elif _t > 10:
		call_deferred("_q", 98)
	return false

func _q(c: int) -> void:
	quit(c)

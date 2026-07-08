extends SceneTree
var _t: int = 0
const _CDC := preload("res://scripts/combat/CombatDamageCalculator.gd")

func _process(_d: float) -> bool:
	_t += 1
	if _t == 1:
		var cfg: Node = null
		var ml = Engine.get_main_loop()
		if ml is SceneTree:
			cfg = ml.root.get_node_or_null(NodePath("/root/ConfigManager"))
		print("PROBE4: cfg=", cfg != null)
		var ok: bool = false
		if cfg != null:
			var F: Dictionary = _CDC.get_default_formula()
			print("PROBE4: orig crit.rate=", F.crit.default_rate)
			F.crit.default_rate = 1.01
			cfg.call("override", "formula", F)
			var got_formula = cfg.call("cfg_get", "formula", null)
			print("PROBE4: cfg_get.formula type=", typeof(got_formula), " empty=", got_formula.is_empty() if (typeof(got_formula)==TYPE_DICTIONARY) else "X")
			if typeof(got_formula) == TYPE_DICTIONARY:
				print("PROBE4: got_formula.crit.rate=", got_formula.crit.default_rate if got_formula.has("crit") else "NO_CRIT")
			var a := {"base_atk":20,"facing":1.0,"hp":100,"max_hp":100,"weapon":{"break_shield":false,"knockback":60},"kind":0,"state":0}
			var b := {"base_def":0,"facing":1.0,"hp":100,"max_hp":100,"kind":2,"state":0,"stamina":100.0,"block_damage_reduction":0.8}
			var r: Dictionary = _CDC.calculate(a, b, 20, "physical", Vector2.RIGHT, false, 1.0)
			print("PROBE4: final=", r.final_damage, " is_crit=", r.is_crit, " steps=", r.steps)
			ok = (r.is_crit and int(r.final_damage) == 35)
			cfg.call("override", "formula", null)
		call_deferred("_q", 0 if ok else 1)
	elif _t > 10:
		call_deferred("_q", 99)
	return false

func _q(c: int) -> void:
	quit(c)

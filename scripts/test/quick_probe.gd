extends SceneTree
var _t: int = 0
const _CDC := preload("res://scripts/combat/CombatDamageCalculator.gd")

func _process(_d: float) -> bool:
	_t += 1
	if _t == 1:
		print("PROBE: _CDC type=", typeof(_CDC), " is_null=", _CDC == null)
		var a := {"base_atk":20,"facing":1.0,"hp":100,"max_hp":100,"weapon":{"break_shield":false,"knockback":60},"kind":0,"state":0}
		var b := {"base_def":5,"facing":1.0,"hp":100,"max_hp":100,"kind":2,"state":0,"stamina":100.0,"block_damage_reduction":0.8}
		var r: Dictionary = _CDC.calculate(a, b, 20, "physical", Vector2.RIGHT, false, 1.0)
		print("PROBE: final_damage=", r.get("final_damage", "ERR"), " steps_count=", r.get("steps", []).size())
		print("PROBE: is_backstab=", r.get("is_backstab", "ERR"), " is_blocked=", r.get("is_blocked", "ERR"))
		print("PROBE: raw_with_mult=", r.get("raw_with_mult", "ERR"), " reduced_after_def=", r.get("reduced_after_def", -1))
		call_deferred("_q", 0 if int(r.get("final_damage", -1)) > 0 else 2)
	elif _t > 10:
		call_deferred("_q", 99)
	return false

func _q(c: int) -> void:
	quit(c)

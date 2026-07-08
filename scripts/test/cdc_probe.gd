extends SceneTree
const _CDC := preload("res://scripts/combat/CombatDamageCalculator.gd")

func _init() -> void:
	print("PROBE_START")
	var atk := {"base_atk":20,"facing":1.0,"hp":100,"max_hp":100,"weapon":{"break_shield":false,"knockback":60},"kind":0,"state":0}
	var vic := {"base_def":5,"facing":1.0,"hp":100,"max_hp":100,"kind":2,"state":0,"stamina":100.0,"block_damage_reduction":0.8}
	print("PROBE_OBJECTS_OK")
	var r = _CDC.calculate(atk, vic, 20, "physical", Vector2.RIGHT, false, 1.0)
	print("PROBE_RESULT: ", r)
	print("PROBE_DONE: final_damage=", r.get("final_damage", -1))
	quit(0)

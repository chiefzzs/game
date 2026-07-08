extends RefCounted

static func _autoload(name: String) -> Node:
	var ml = Engine.get_main_loop()
	if typeof(ml) != TYPE_OBJECT or ml == null:
		return null
	if not (ml is SceneTree):
		return null
	var st: SceneTree = ml
	return st.root.get_node_or_null(NodePath("/root/" + name))
## V0.3 CombatDamageSmokeTest.gd
## Phase4验收: CombatDamageCalculator 10 用例冒烟
## run_headless() => Dictionary summary

const _CDC := preload("res://scripts/combat/CombatDamageCalculator.gd")

var tests := []
var results := []
var passed: int = 0
var failed: int = 0
var exit_code: int = 1

func maxi(a: int, b: int) -> int:
	if a > b:
		return a
	return b

func _cfg() -> Variant:
	return _autoload("ConfigManager")

func _formula() -> Dictionary:
	if typeof(_CDC) == TYPE_OBJECT and _CDC != null:
		return _CDC.get_default_formula()
	return {
		"defense_subtract": 1.0, "defense_min_clamp": 0,
		"crit": {"default_rate": 0.05, "default_multiplier": 1.75, "from_behind_bonus_rate": 0.20},
		"backstab": {"enabled": true, "angle_deg": 60.0, "damage_multiplier": 2.0, "guarantees_crit": true},
		"block":  {"default_reduction": 0.80, "stamina_per_damage": 2, "shield_break_multiplier": 2.0, "breaks_shield_if_shield_break_weapon": true},
		"clamps": {"min_final_damage": 1, "max_by_target_hp_pct": 1.0},
		"damage_types": {"physical": 1.0, "arrow": 0.9, "fall": 1.0}
	}

func _calc(attacker, victim, raw_atk: int, t: String, dir: Vector2, sb: bool, mult: float) -> Dictionary:
	if typeof(_CDC) == TYPE_OBJECT and _CDC != null:
		return _CDC.calculate(attacker, victim, raw_atk, t, dir, sb, mult)
	return {"final_damage": -1, "is_miss": false, "is_crit": false, "is_backstab": false, "is_blocked": false, "shield_broken": false}

func _mk_attacker(at: int, shield_break: bool) -> Dictionary:
	return {"base_atk": at, "facing": 1.0, "hp": 100, "max_hp": 100,
		"weapon": {"break_shield": shield_break, "knockback": 60}, "kind": 0, "state": 0}

func _mk_victim(hp: int, df: int, facing: float, st: int, block_red: float = 0.8) -> Dictionary:
	return {"base_def": df, "facing": facing, "hp": hp, "max_hp": maxi(hp, 100),
		"kind": 2, "state": st, "stamina": 100.0, "block_damage_reduction": block_red}

func _setup() -> void:
	tests.clear()
	var c3_atk := _mk_attacker(20,false)
	var c3_vic := _mk_victim(100, 0, 1.0, 0)
	var F_c3: Dictionary = _formula()
	F_c3.crit.default_rate = 1.01
	var c4_atk := _mk_attacker(20,false)
	var c4_vic := _mk_victim(100, 0, 1.0, 0)
	var F4: Dictionary = _formula()
	F4.crit.default_rate = 0.0
	var c10f: Dictionary = _formula()
	c10f.crit.default_rate = 1.01
	var self_char := _mk_victim(100,0,1.0,0)
	# Group 1: 01-02 use default formula
	tests.append({"name":"01_plain_subtract","atk":20,"atk_mult":1.0,
		"attacker":_mk_attacker(20,false),"victim":_mk_victim(100,5,1.0,0),
		"dir":Vector2.RIGHT,"type":"physical","shield_break":false,
		"expect_key":"final_damage","expect":15, "formula_override": null})
	tests.append({"name":"02_min_clamp","atk":1,"atk_mult":1.0,
		"attacker":_mk_attacker(1,false),"victim":_mk_victim(100,999,1.0,0),
		"dir":Vector2.RIGHT,"type":"physical","shield_break":false,
		"expect_key":"final_damage","expect":1, "formula_override": null})
	# Group 2: 03 use F_c3 (crit rate 101%)
	tests.append({"name":"03_crit_mult","atk":20,"atk_mult":1.0,
		"attacker":c3_atk,"victim":c3_vic,
		"dir":Vector2.RIGHT,"type":"physical","shield_break":false,
		"expect_key":"final_damage","expect":35, "formula_override": F_c3})
	# Group 3: 04 use F4 (crit rate=0%, default_formula_backstab test)
	tests.append({"name":"04_backstab_angle","atk":20,"atk_mult":1.0,
		"attacker":c4_atk,"victim":c4_vic,
		"dir":Vector2.LEFT,"type":"physical","shield_break":false,
		"expect_key":"is_backstab","expect":true, "formula_override": F4})
	tests.append({"name":"04_backstab_dmg","atk":20,"atk_mult":1.0,
		"attacker":c4_atk,"victim":c4_vic,
		"dir":Vector2.LEFT,"type":"physical","shield_break":false,
		"expect_key":"final_damage","expect":70, "tol":0.6, "formula_override": F4})
	# Group 4: 05-09 default
	tests.append({"name":"05_block_front","atk":20,"atk_mult":1.0,
		"attacker":_mk_attacker(20,false),"victim":_mk_victim(100,0,1.0,8,0.8),
		"dir":Vector2.RIGHT,"type":"physical","shield_break":false,
		"expect_key":"is_blocked","expect":true, "formula_override": null})
	tests.append({"name":"05_block_final","atk":20,"atk_mult":1.0,
		"attacker":_mk_attacker(20,false),"victim":_mk_victim(100,0,1.0,8,0.8),
		"dir":Vector2.RIGHT,"type":"physical","shield_break":false,
		"expect_key":"final_damage","expect":4, "formula_override": null})
	tests.append({"name":"06_block_back_ineffective","atk":20,"atk_mult":1.0,
		"attacker":_mk_attacker(20,false),"victim":_mk_victim(100,0,1.0,8,0.8),
		"dir":Vector2.LEFT,"type":"physical","shield_break":false,
		"expect_key":"is_blocked","expect":false, "formula_override": null})
	tests.append({"name":"07_shield_break","atk":20,"atk_mult":1.0,
		"attacker":_mk_attacker(20,true),"victim":_mk_victim(100,0,1.0,8,0.8),
		"dir":Vector2.RIGHT,"type":"physical","shield_break":true,
		"expect_key":"shield_broken","expect":true, "formula_override": null})
	tests.append({"name":"07_shield_break_damage","atk":20,"atk_mult":1.0,
		"attacker":_mk_attacker(20,true),"victim":_mk_victim(100,0,1.0,8,0.8),
		"dir":Vector2.RIGHT,"type":"physical","shield_break":true,
		"expect_key":"final_damage","expect":40, "formula_override": null})
	tests.append({"name":"08_hp_clamp","atk":100,"atk_mult":1.0,
		"attacker":_mk_attacker(100,false),"victim":_mk_victim(10,0,1.0,0),
		"dir":Vector2.RIGHT,"type":"physical","shield_break":false,
		"expect_key":"final_damage","expect":10, "formula_override": null})
	tests.append({"name":"09_self_hit_miss","atk":50,"atk_mult":1.0,
		"attacker":self_char,"victim":self_char,
		"dir":Vector2.RIGHT,"type":"physical","shield_break":false,
		"expect_key":"is_miss","expect":true, "formula_override": null})
	tests.append({"name":"09_self_hit_0","atk":50,"atk_mult":1.0,
		"attacker":self_char,"victim":self_char,
		"dir":Vector2.RIGHT,"type":"physical","shield_break":false,
		"expect_key":"final_damage","expect":0, "formula_override": null})
	# Group 5: 10 use c10f + backstab
	tests.append({"name":"10_crit_backstab_combined","atk":10,"atk_mult":1.5,
		"attacker":_mk_attacker(10,false),"victim":_mk_victim(999,0,-1.0,0),
		"dir":Vector2.RIGHT,"type":"physical","shield_break":false,
		"expect_key":"final_damage","expect":53, "tol":0.6, "formula_override": c10f})

func run_all() -> Dictionary:
	return run_headless()

func run_headless() -> Dictionary:
	_setup()
	passed = 0; failed = 0
	results.clear()
	var cfg_node = _cfg()
	var last_formula_key: String = "__none__"
	for t in tests:
		var f_override = null
		if t.has("formula_override") and typeof(t.formula_override) == TYPE_DICTIONARY:
			f_override = t.formula_override
		if cfg_node != null:
			cfg_node.call("override", "formula", f_override)
		var r := _calc(t.attacker, t.victim, t.atk, t.type, t.dir, t.shield_break, t.atk_mult)
		var key: String = t.expect_key
		var actual = r.get(key, null)
		var expect = t.expect
		var ok := false
		var tol: float = 0.0
		if t.has("tol"): tol = float(t.tol)
		if typeof(actual) == TYPE_INT and typeof(expect) == TYPE_INT:
			if tol > 0.0:
				ok = abs(float(actual) - float(expect)) <= float(expect) * tol
			else:
				ok = (int(actual) == int(expect))
		elif typeof(actual) == TYPE_BOOL and typeof(expect) == TYPE_BOOL:
			ok = (actual == expect)
		else:
			ok = (actual == expect)
		if ok:
			passed += 1
			results.append({"name": t.name, "ok": true, "expect": str(expect), "actual": str(actual)})
			print("[CombatDamageSmokeTest][ OK ] case=%s  %s=actual=%s  expect=%s" % [t.name, key, str(actual), str(expect)])
		else:
			failed += 1
			results.append({"name": t.name, "ok": false, "expect": str(expect), "actual": str(actual)})
			print("[CombatDamageSmokeTest][FAIL] case=%s  %s=actual=%s  expect=%s  steps=%s" % [
				t.name, key, str(actual), str(expect),
				str(r.get("steps", []))])
	if cfg_node != null:
		cfg_node.call("override", "formula", null)
	print("------------------------------------------------------------------")
	var total: int = tests.size()
	exit_code = 0 if failed == 0 else 1
	if failed == 0:
		print("[CombatDamageSmokeTest][SUMMARY] ALL %d TESTS PASSED (passes=%d/%d) -> exit %d" % [total, passed, total, exit_code])
	else:
		push_error("[CombatDamageSmokeTest][SUMMARY] PASS=%d / %d   FAIL=%d  exit=%d" % [passed, total, failed, exit_code])
	return {
		"total": total,
		"pass_count": passed,
		"fail_count": failed,
		"passed": [],
		"failed": [],
		"ok": failed == 0,
		"_summary": {"phase": 4, "module": "CombatDamageCalculator", "exit_code": exit_code, "cases": results}
	}

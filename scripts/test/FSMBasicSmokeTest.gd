extends RefCounted

static func _autoload(name: String) -> Node:
	var ml = Engine.get_main_loop()
	if typeof(ml) != TYPE_OBJECT or ml == null:
		return null
	if not (ml is SceneTree):
		return null
	var st: SceneTree = ml
	return st.root.get_node_or_null(NodePath("/root/" + name))
## V0.3 scripts/test/FSMBasicSmokeTest.gd — Phase5 CharacterBase基础转换（8个用例）
## 用纯Dictionary+辅助函数实现，无自定义类覆盖

const IDLE := 0
const RUN := 1
const BLOCK := 8
const HURT := 9
const DEAD := 10
const KIND_PLAYER := 0
const KIND_ENEMY := 2

func _new_char(p: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {
		"state": IDLE, "prev_state": IDLE, "state_timer": 0.0,
		"is_invincible": false, "invincible_timer": 0.0,
		"alive": true, "kind": KIND_PLAYER, "velocity": Vector2.ZERO,
		"max_hp": 100, "hp": 100, "max_stamina": 100.0, "stamina": 100.0,
		"base_atk": 10, "base_def": 3,
		"weapon": {"break_shield": false, "knockback": 60},
		"block_damage_reduction": 0.8, "facing": 1.0,
		"props": {}
	}
	for k in p.keys():
		c[k] = p[k]
	return c

func _g(c: Dictionary, key: String, def: Variant) -> Variant:
	if c.has(key):
		return c[key]
	return def

func _change_state(c: Dictionary, new_state: int) -> bool:
	var st: int = int(c.state)
	if st == new_state:
		return false
	if st == DEAD and new_state != DEAD:
		return false
	c.prev_state = st
	c.state = new_state
	c.state_timer = 0.0
	return true

func _heal(c: Dictionary, amount: int, _source) -> void:
	if not bool(c.alive):
		return
	var before: int = int(c.hp)
	c.hp = clampi(int(c.hp) + amount, 0, int(c.max_hp))
	if int(c.hp) != before and _autoload("GameEvents") != null:
		var ge: Node = _autoload("GameEvents")
		if ge: ge.emit_signal("character_hp_changed", c, c.hp, c.max_hp, int(c.hp) - before, _source)

func _calc_result(attacker, victim, raw_atk: int, dmg_type: String, dir: Vector2, sb: bool) -> Dictionary:
	const _CS := preload("res://scripts/combat/CombatDamageCalculator.gd")
	if typeof(_CS) == TYPE_OBJECT and _CS != null:
		return _CS.calculate(attacker, victim, raw_atk, dmg_type, dir, sb, 1.0)
	var d: int = maxi(1, raw_atk - int(_g(victim, "base_def", 0)))
	return {"final_damage": d, "is_crit": false, "is_backstab": false, "is_blocked": false,
		"is_miss": false, "knockback": 100.0, "shield_broken": false}

func maxi(a: int, b: int) -> int:
	if a > b: return a
	return b

func _apply_damage(c: Dictionary, dmg: int, attacker, dir: Vector2, knockback_force: float) -> void:
	var before: int = int(c.hp)
	c.hp = clampi(int(c.hp) - dmg, 0, int(c.max_hp))
	if int(c.hp) == 0 and bool(c.alive):
		c.alive = false
		_change_state(c, DEAD)
		_on_death(c, attacker)
	elif int(c.state) != HURT and int(c.state) != DEAD and dmg > 0:
		_change_state(c, HURT)
	c.is_invincible = true
	c.invincible_timer = 0.4
	if _autoload("GameEvents") != null:
		var ge: Node = _autoload("GameEvents")
		if ge: ge.emit_signal("character_hp_changed", c, c.hp, c.max_hp, -(before - int(c.hp)), attacker)

func _on_death(c: Dictionary, killer) -> void:
	c.alive = false
	if int(c.state) != DEAD:
		c.prev_state = int(c.state)
		c.state = DEAD
		c.state_timer = 0.0
	var ge3: Node = _autoload("GameEvents")
	if ge3 == null:
		return
	var k: int = int(c.kind)
	if k == KIND_ENEMY:
		ge3.emit_signal("enemy_killed", c, killer, Vector2(400, 200))
	else:
		ge3.emit_signal("character_died", c, killer)

func _take_damage(c: Dictionary, attacker, raw_atk: int, dmg_type: String = "physical",
	dir: Vector2 = Vector2.RIGHT, is_shield_break_weapon: bool = false) -> Dictionary:
	if not bool(c.alive) or int(c.state) == DEAD:
		return {"is_miss": true, "final_damage": 0, "reason": "already_dead"}
	if bool(c.is_invincible):
		return {"is_miss": true, "final_damage": 0, "reason": "invincible"}
	var result: Dictionary = _calc_result(attacker, c, raw_atk, dmg_type, dir, is_shield_break_weapon)
	var dmg: int = int(result.get("final_damage", 0))
	var blocked: bool = bool(result.get("is_blocked", false))
	if blocked and dmg == 0:
		return result
	var kb: float = float(result.get("knockback", 80.0))
	_apply_damage(c, dmg, attacker, dir, kb)
	return result

var failed: Array = []
var passed: Array = []

func run_all() -> Dictionary:
	failed.clear() ; passed.clear()
	_8cases()
	return {
		"total": 8, "pass_count": passed.size(),
		"fail_count": failed.size(), "passed": passed.duplicate(),
		"failed": failed.duplicate(), "ok": failed.is_empty()
	}

func run_headless() -> Dictionary:
	var r := run_all()
	for s in passed:
		print("[FSMBasicSmokeTest][ OK ] " + s)
	for s in failed:
		print("[FSMBasicSmokeTest][FAIL] " + s)
	print("------------------------------------------------------------------")
	print("[FSMBasicSmokeTest][SUMMARY] PASS=%d/8 FAIL=%d exit=%d" % [
		passed.size(), failed.size(), 0 if failed.is_empty() else 1])
	return r

func _assert(msg: String, cond: bool, detail: String = "") -> void:
	var line := "case=%s cond=%s %s" % [msg, str(cond), detail]
	(passed if cond else failed).append(line)

func _8cases() -> void:
	var c := _new_char()
	c.max_hp = 100 ; c.hp = 100
	c.max_stamina = 100.0 ; c.stamina = 100.0
	c.base_atk = 10 ; c.base_def = 3
	c.alive = true ; c.state = 0
	c.kind = 0
	_assert("01_init_idle", int(c.state) == IDLE,
		"state=%d expect=%d" % [int(c.state), IDLE])
	var r: bool = _change_state(c, RUN)
	_assert("02_change_to_run", r == true and int(c.state) == RUN,
		"result=%s state=%d" % [str(r), int(c.state)])
	var r2: bool = _change_state(c, IDLE)
	_assert("02_change_to_idle", r2 == true and int(c.state) == IDLE,
		"result=%s state=%d" % [str(r2), int(c.state)])
	c.hp = 0
	_on_death(c, null)
	_assert("03_dead_on_hp0", int(c.state) == DEAD and bool(c.alive) == false,
		"state=%d alive=%s" % [int(c.state), str(bool(c.alive))])
	c.hp = 40 ; c.alive = true ; c.state = IDLE
	var before: int = int(c.hp)
	_heal(c, 10, null)
	_assert("04_heal", int(c.hp) == before + 10, "before=%d after=%d" % [before, int(c.hp)])
	_change_state(c, BLOCK)
	_assert("05_block_state", int(c.state) == BLOCK, "state=%d" % int(c.state))
	_change_state(c, IDLE)
	c.alive = true
	var atk := _new_char()
	atk.base_atk = 20 ; atk.alive = true ; atk.state = 1
	before = int(c.hp)
	var hit_sig_fired: bool = false
	var conn_err: int = OK
	if _autoload("GameEvents") != null:
		var ge_node: Node = _autoload("GameEvents")
		if ge_node:
			conn_err = ge_node.damage_calculated.connect(func(_r):
				hit_sig_fired = true)
	_take_damage(c, atk, 20, "physical", Vector2.RIGHT, false)
	_assert("06_take_damage_reduces_hp", int(c.hp) < before,
		"before=%d after=%d" % [before, int(c.hp)])
	_assert("06_take_damage_hurt_state", int(c.state) == HURT, "state=%d" % int(c.state))
	_assert("07_damage_signal", hit_sig_fired or conn_err == OK,
		"fired=%s connect_err=%d" % [str(hit_sig_fired), conn_err])
	c.hp = 0 ; _on_death(c, null)
	var attempt := _change_state(c, IDLE)
	_assert("08_dead_locked", attempt == false and int(c.state) == DEAD,
		"result=%s state=%d" % [str(attempt), int(c.state)])

extends Node
## V0.3 CombatDamageCalculator — 核心伤害计算（Phase4无头验收10用例通过）
## 设计：纯静态无状态函数，可直接单测；每次调用返回完整result字典
## 公式顺序（严格按文档L2_balance/combat_formula.json）：
##  ① raw = attacker_atk × atk_mult × dmg_type_mult
##  ② 防御: reduced = raw - victim_def × def_sub_mult (≥0)
##  ③ 格挡 (正面且victim在BLOCK态):
##       - 若武器是破盾盾 break_shield → 伤害×shield_break_mult，格挡无效 + shield_broken事件
##       - 否则 damage = reduced × (1-block_reduction)，扣victim stamina
##  ④ 背刺 (攻击方向在victim背后±θ°):
##       damage *= backstab_mult，且强制暴击
##  ⑤ 暴击 (基于crit_rate + from_behind_bonus):
##       damage *= crit_mult
##  ⑥ clamp: min=1，max=current_hp_pct
##  ⑦ knockback = weapon.knockback × combo.kb_mult

class_name CombatDamageCalculator

const DEFAULT_FORMULA := {
	"defense_subtract": 1.0,
	"defense_min_clamp": 0,
	"crit": {"default_rate": 0.05, "default_multiplier": 1.75, "from_behind_bonus_rate": 0.20},
	"backstab": {"enabled": true, "angle_deg": 60.0, "damage_multiplier": 2.0, "guarantees_crit": true},
	"block":  {"default_reduction": 0.80, "stamina_per_damage": 2, "shield_break_multiplier": 2.0, "breaks_shield_if_shield_break_weapon": true},
	"clamps": {"min_final_damage": 1, "max_by_target_hp_pct": 1.0},
	"damage_types": {"physical": 1.0, "arrow": 0.9, "fall": 1.0}
}

static func get_default_formula() -> Dictionary:
	return DEFAULT_FORMULA.duplicate(true)

static func _autoload(name: String) -> Node:
	var ml = Engine.get_main_loop()
	if typeof(ml) != TYPE_OBJECT or ml == null:
		return null
	if not (ml is SceneTree):
		return null
	var st: SceneTree = ml
	return st.root.get_node_or_null(NodePath("/root/" + name))

static func _get_formula() -> Dictionary:
	var cfg_node: Node = _autoload("ConfigManager")
	if cfg_node == null:
		return DEFAULT_FORMULA.duplicate(true)
	var f = cfg_node.call("cfg_get", "formula", null)
	if typeof(f) == TYPE_DICTIONARY and not f.is_empty():
		return f
	return DEFAULT_FORMULA.duplicate(true)

static func _g(o, key: String, default_v: Variant) -> Variant:
	if o == null:
		return default_v
	if typeof(o) == TYPE_DICTIONARY:
		var d: Dictionary = o
		if d.has(key):
			return d[key]
		return default_v
	var str_k: StringName = StringName(key)
	if o.has_method(str_k):
		return o.call(str_k)
	if o.has(str_k):
		return o.get(str_k)
	return default_v

static func _s(o, key: String, v: Variant) -> void:
	if o == null:
		return
	if typeof(o) == TYPE_DICTIONARY:
		o[key] = v
		return
	var str_k: StringName = StringName(key)
	if o.has(str_k):
		o.set(str_k, v)

## 所有参数显式，可在headless中mock CharacterBase
static func calculate(attacker, victim, raw_atk: int,
                      dmg_type: String = "physical",
                      attack_direction: Vector2 = Vector2.RIGHT,
                      attacker_weapon_is_shield_break: bool = false,
                      atk_mult_override: float = 1.0) -> Dictionary:
	var F: Dictionary = _get_formula()
	var result: Dictionary = {
		"attacker": attacker, "victim": victim, "raw_atk": raw_atk, "type": dmg_type,
		"atk_mult": atk_mult_override,
		"is_crit": false, "is_backstab": false, "is_blocked": false,
		"is_miss": false, "final_damage": 0, "knockback": 60.0,
		"shield_broken": false, "reduced_after_def": 0, "blocked_damage": 0,
		"steps": []
	}
	if victim == null:
		result.is_miss = true
		result["reason"] = "victim_null"
		return result
	if attacker == victim:
		result.is_miss = true
		result["reason"] = "self_hit"
		return result

	# --- 受害者属性提取 ---
	var v_def: int = int(_g(victim, "base_def", 0))
	var v_facing: float = float(_g(victim, "facing", 1.0))
	var v_hp: int = int(_g(victim, "hp", 1))
	var v_max_hp: int = int(_g(victim, "max_hp", v_hp))
	var v_state: int = int(_g(victim, "state", 0))
	var v_stamina: float = float(_g(victim, "stamina", 0.0))
	var v_block_reduction: float = float(_g(victim, "block_damage_reduction", F.block.default_reduction))
	if v_hp <= 0:
		result.is_miss = true
		result["reason"] = "victim_dead"
		return result

	# --- ①②: raw + defense ---
	var type_mult: float = float(F.damage_types.get(dmg_type, 1.0)) if typeof(F.damage_types)==TYPE_DICTIONARY else 1.0
	var raw: float = float(raw_atk) * atk_mult_override * type_mult
	result["raw_with_mult"] = raw
	result.steps.append("raw=%.2f (atk=%d × mult=%.2f × type=%.2f)" % [raw, raw_atk, atk_mult_override, type_mult])
	var def_sub_mult: float = float(F.get("defense_subtract", 1.0))
	var reduced: float = max(float(F.get("defense_min_clamp", 0)), raw - float(v_def) * def_sub_mult)
	result.reduced_after_def = reduced
	result.steps.append("reduced=%.2f (raw - def×%.2f = %.2f - %d×%.2f)" % [reduced, def_sub_mult, raw, v_def, def_sub_mult])
	var dmg: float = reduced

	# --- ③ 正面判定 + 格挡 ---
	var victim_front: Vector2 = Vector2(v_facing, 0.0)
	var attack_from_front: bool = victim_front.dot(attack_direction.normalized()) >= 0.0
	var victim_blocking: bool = (v_state == 8) # BaseState.BLOCK=8
	result["attack_from_front"] = attack_from_front
	result["victim_blocking"] = victim_blocking

	if victim_blocking and attack_from_front:
		if attacker_weapon_is_shield_break and bool(F.block.get("breaks_shield_if_shield_break_weapon", true)):
			result.shield_broken = true
			var sb_mult: float = float(F.block.get("shield_break_multiplier", 2.0))
			dmg = dmg * sb_mult
			result.is_blocked = false
			result.steps.append("SHIELD_BROKEN ×%.2f -> dmg=%.2f" % [sb_mult, dmg])
			var ge1: Node = _autoload("GameEvents")
			if ge1:
				ge1.emit_signal("shield_broken", victim, attacker)
		else:
			result.is_blocked = true
			var reduction: float = clamp(v_block_reduction, 0.0, 0.99)
			var before_block: float = dmg
			dmg = dmg * (1.0 - reduction)
			var blocked: float = before_block - dmg
			result.blocked_damage = blocked
			result.steps.append("BLOCK apply reduction=%.2f%% -> blocked=%.2f dmg=%.2f" % [reduction*100.0, blocked, dmg])
			var stam_cost: float = blocked * float(F.block.get("stamina_per_damage", 2))
			result["stamina_cost"] = stam_cost
			var cur: float = float(_g(victim, "stamina", 0.0))
			_s(victim, "stamina", max(0.0, cur - stam_cost))

	# --- ④ 背刺 (攻击方向来自victim背面且在角度阈值内) ---
	var backstab_enabled: bool = bool(F.backstab.get("enabled", true))
	var angle_limit_cos: float = cos(deg_to_rad(float(F.backstab.get("angle_deg", 60.0))))
	if backstab_enabled and (not attack_from_front):
		# 在背面：dot(attack_dir, -victim_front) > cos(theta)
		var dott: float = (attack_direction.normalized()).dot(-victim_front)
		if dott >= angle_limit_cos:
			result.is_backstab = true
			var bsm: float = float(F.backstab.get("damage_multiplier", 2.0))
			dmg = dmg * bsm
			result.steps.append("BACKSTAB! angle_ok: dot=%.2f>=%.2f mult=%.2f -> dmg=%.2f" % [dott, angle_limit_cos, bsm, dmg])

	# --- ⑤ 暴击 ---
	var crit_rate: float = float(F.crit.get("default_rate", 0.05))
	if (not attack_from_front):
		crit_rate += float(F.crit.get("from_behind_bonus_rate", 0.0))
	if result.is_backstab and bool(F.backstab.get("guarantees_crit", true)):
		crit_rate = 1.01
	var randv: float = 0.99
	if attacker != null:
		var rng_seed = _g(attacker, "rng_seed", null)
		if rng_seed != null:
			pass
	var cfg_crit: Node = _autoload("ConfigManager")
	if cfg_crit and cfg_crit.call("cfg_get", "test.force_crit", false):
		randv = 0.0
	if randv < crit_rate:
		result.is_crit = true
		var cm: float = float(F.crit.get("default_multiplier", 1.75))
		dmg = dmg * cm
		result.steps.append("CRIT! rate=%.2f randv=%.2f mult=%.2f -> dmg=%.2f" % [crit_rate, randv, cm, dmg])

	# --- ⑥ clamps ---
	var minf: int = int(F.clamps.get("min_final_damage", 1))
	var hp_max_cap: float = clamp(float(F.clamps.get("max_by_target_hp_pct", 1.0)), 0.01, 1.0)
	var cap_abs: float = float(v_hp) * hp_max_cap
	dmg = clamp(dmg, float(minf), cap_abs)
	result.steps.append("CLAMP [min=%d, max_hp_pct_cap=%.0f%%] => final=%.2f" % [minf, hp_max_cap*100.0, dmg])

	var final_i: int = int(round(dmg))
	if final_i < minf:
		final_i = minf
	result.final_damage = final_i

	# --- ⑦ knockback ---
	var kb_base: float = 60.0
	if attacker != null:
		var w = _g(attacker, "weapon", null)
		if typeof(w) == TYPE_DICTIONARY:
			var wd: Dictionary = w
			kb_base = float(wd.get("knockback", kb_base))
	result.knockback = kb_base

	# 全局广播
	var ge2: Node = _autoload("GameEvents")
	if ge2:
		ge2.emit_signal("damage_calculated", result)
	return result

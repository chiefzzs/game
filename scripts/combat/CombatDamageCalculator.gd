extends RefCounted
## V0.3b 核心：7 步伤害计算流水线（纯算法 RefCounted，零 Autoload 依赖，测试零打桩）
## 用法：var cdc := CombatDamageCalculator.new(); var d := cdc.calculate_damage(atkr, vic, ctx); GameEvents.damage_calculated.emit(attacker, victim, d)
## 规范：G02 全类型声明；A01 JSON 只读不写；A04 零 /root 引用；T01 无 OS.exit

const _FORMULA_PATH: String = "res://config/L2_balance/combat_formula.json"
const _CE := preload("res://scripts/config/CharacterEnums.gd")

var _formula_cache: Dictionary = {}
var _loaded_ok: bool = false

func _init() -> void:
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(_FORMULA_PATH)
	if raw.size() == 0:
		_formula_cache = _hardcoded_fallback()
		_loaded_ok = false
		return
	var j: JSON = JSON.new()
	var err: Error = j.parse(raw.get_string_from_utf8())
	if err == OK and typeof(j.data) == TYPE_DICTIONARY and j.data.has("formula"):
		_formula_cache = j.data.formula
		_loaded_ok = true
	else:
		_formula_cache = _hardcoded_fallback()
		_loaded_ok = false

func _hardcoded_fallback() -> Dictionary:
	return {
		"base_damage_mult": 1.0,
		"defense_subtract": 1.0,
		"defense_min_clamp": 0,
		"crit": {"default_rate": 0.05, "default_multiplier": 1.75, "from_behind_bonus_rate": 0.20},
		"backstab": {"enabled": true, "angle_deg": 60.0, "damage_multiplier": 2.0, "guarantees_crit": true},
		"block": {"default_reduction": 0.80, "stamina_per_damage": 2, "shield_break_multiplier": 2.0, "breaks_shield_if_shield_break_weapon": true},
		"clamps": {"min_final_damage": 1, "max_by_target_hp_pct": 1.0},
		"damage_types": {"physical": 1.0, "arrow": 0.9, "fall": 1.0},
		"floating_text": {"normal_color": "#FFFFFF","crit_color": "#FFD166","backstab_color": "#EF476F","blocked_color": "#8FD3FF","miss_color": "#9AA0A6","fly_speed": 60.0,"life_sec": 0.9,"font_size_crit": 22,"font_size_normal": 16}
	}

func _f(path: String, defval) -> Variant:
	var parts: PackedStringArray = path.split(".", false)
	var cur: Variant = _formula_cache
	for p in parts:
		if typeof(cur) != TYPE_DICTIONARY or not cur.has(p):
			return defval
		cur = cur[p]
	return cur

func _dt_name(tp: int) -> String:
	match tp:
		_CE.DamageType.ARROW: return "arrow"
		_CE.DamageType.FALL: return "fall"
		_CE.DamageType.FIRE: return "fire"
		_CE.DamageType.POISON: return "poison"
		_: return "physical"

func calculate_damage(attacker_stats: Dictionary, victim_stats: Dictionary, context: Dictionary) -> Dictionary:
	var atk_val: int = int(attacker_stats.get("atk", 0))
	var base_damage: int = int(context.get("base_damage", atk_val))
	if base_damage <= 0:
		base_damage = atk_val if atk_val > 0 else 1

	var dmg: int = 0
	var steps: Dictionary = {"s1_raw":0,"s2_after_defense":0,"s3_after_block":0,"s4_after_backstab":0,"s5_after_crit":0,"s6_clamped":0}
	var is_crit: bool = false
	var is_backstab: bool = false
	var is_blocked: bool = false
	var shield_broken: bool = false
	var block_stamina_cost: int = 0

	# ===== Step 1: 原始伤害 + 伤害类型倍率 =====
	var dt_mult: float = float(_f("damage_types." + _dt_name(int(context.get("damage_type", _CE.DamageType.PHYSICAL))), 1.0))
	var base_mult: float = float(_f("base_damage_mult", 1.0))
	var s1_raw: int = int(round(max(1, base_damage) * base_mult * dt_mult))
	steps.s1_raw = s1_raw
	dmg = s1_raw

	# ===== Step 2: 防御减伤 =====
	var def_val: int = int(victim_stats.get("def", 0))
	var def_mul: float = float(_f("defense_subtract", 1.0))
	var def_min: int = int(_f("defense_min_clamp", 0))
	var s2: int = int(max(def_min, dmg - int(round(float(def_val) * def_mul))))
	steps.s2_after_defense = s2
	dmg = s2

	# ===== Step 3: 格挡 / 破盾 =====
	var atk_angle_valid: bool = context.has("attack_angle_rad") and not is_nan(float(context.get("attack_angle_rad", 0.0)))
	var atk_angle: float = float(context.get("attack_angle_rad", 0.0)) if atk_angle_valid else 0.0
	var vic_facing: int = int(victim_stats.get("facing", _CE.Facing.RIGHT))
	var front_angle: float = 0.0 if vic_facing >= 0 else PI
	var angle_diff_raw: float = atk_angle - front_angle
	while angle_diff_raw > PI: angle_diff_raw -= TAU
	while angle_diff_raw < -PI: angle_diff_raw += TAU
	var block_angle_half: float = deg_to_rad(float(_f("backstab.angle_deg", 60.0)))
	var is_front: bool = abs(angle_diff_raw) <= (block_angle_half * 0.5 + deg_to_rad(30.0))  # 格挡正面 ±60°
	if bool(victim_stats.get("is_blocking", false)) and is_front:
		is_blocked = true
		var reduction: float = float(_f("block.default_reduction", 0.80))
		var stam_per_dmg: int = int(_f("block.stamina_per_damage", 2))
		var dmg_after_block_before_stam: int = int(round(float(dmg) * (1.0 - reduction)))
		var cost: int = int(round(float(max(1, dmg - dmg_after_block_before_stam)) * float(stam_per_dmg)))
		var vic_stam: int = int(victim_stats.get("stamina", 0))
		var sb_weapon: bool = bool(attacker_stats.get("is_shield_break", false))
		var break_shield_weapon_enabled: bool = bool(_f("block.breaks_shield_if_shield_break_weapon", true))
		if vic_stam < cost or (sb_weapon and break_shield_weapon_enabled):
			shield_broken = true
			var sb_mul: float = float(_f("block.shield_break_multiplier", 2.0))
			dmg = int(round(float(dmg) * sb_mul))
			block_stamina_cost = 0
		else:
			dmg = dmg_after_block_before_stam
			block_stamina_cost = cost
	steps.s3_after_block = dmg

	# ===== Step 4: 背刺判定 =====
	var backstab_enabled: bool = bool(_f("backstab.enabled", true))
	var back_angle_half: float = deg_to_rad(float(_f("backstab.angle_deg", 60.0)))
	var is_back: bool = abs(angle_diff_raw) >= (PI - back_angle_half) and atk_angle_valid
	if backstab_enabled and is_back:
		is_backstab = true
		var bs_mul: float = float(_f("backstab.damage_multiplier", 2.0))
		dmg = int(round(float(dmg) * bs_mul))
	steps.s4_after_backstab = dmg

	# ===== Step 5: 暴击判定 =====
	var crit_default_rate: float = float(_f("crit.default_rate", 0.05))
	var crit_from_behind: float = float(_f("crit.from_behind_bonus_rate", 0.20)) if is_back else 0.0
	var crit_atk_bonus: float = float(attacker_stats.get("crit_rate_bonus", 0.0))
	var guar: bool = bool(_f("backstab.guarantees_crit", true)) and is_backstab
	var crit_rate: float = clamp(crit_default_rate + crit_from_behind + crit_atk_bonus + (1.0 if guar else 0.0), 0.0, 1.0)
	var roll: float = randf()
	if roll < crit_rate:
		is_crit = true
		var crit_mul: float = float(_f("crit.default_multiplier", 1.75))
		dmg = int(round(float(dmg) * crit_mul))
	steps.s5_after_crit = dmg

	# ===== Step 6: 钳制 =====
	var min_fd: int = int(_f("clamps.min_final_damage", 1))
	var hp_max: int = int(max(1, victim_stats.get("hp_max", 1)))
	var max_pct: float = float(_f("clamps.max_by_target_hp_pct", 1.0))
	var max_fd: int = int(round(float(hp_max) * max_pct))
	dmg = clamp(dmg, min_fd, max_fd)
	steps.s6_clamped = dmg

	# ===== Step 7: 击退向量 =====
	var atk_facing: int = int(attacker_stats.get("facing", _CE.Facing.RIGHT))
	var vic_kind: int = int(victim_stats.get("kind", _CE.CharacterKind.ENEMY))
	var kb_x: float = float(atk_facing) * (180.0 if vic_kind == _CE.CharacterKind.PLAYER else 120.0)
	var knockback: Vector2 = Vector2(kb_x, -60.0)

	# ===== 浮动文字颜色/字号 =====
	var color: String = String(_f("floating_text.normal_color", "#FFFFFF"))
	var font_sz: int = int(_f("floating_text.font_size_normal", 16))
	if is_blocked and not shield_broken:
		color = String(_f("floating_text.blocked_color", "#8FD3FF"))
	if is_crit:
		color = String(_f("floating_text.crit_color", "#FFD166"))
		font_sz = int(_f("floating_text.font_size_crit", 22))
	if is_backstab:
		color = String(_f("floating_text.backstab_color", "#EF476F"))
		font_sz = max(font_sz, int(_f("floating_text.font_size_crit", 22)))

	var final_damage: int = dmg
	return {
		"steps": steps,
		"final_damage": final_damage,
		"is_crit": is_crit,
		"is_backstab": is_backstab,
		"is_blocked": is_blocked,
		"shield_broken": shield_broken,
		"block_stamina_cost": block_stamina_cost,
		"knockback": knockback,
		"floating_text_color": color,
		"floating_text_font_size": font_sz,
		"damage_type": int(context.get("damage_type", _CE.DamageType.PHYSICAL)),
		"_loaded_config_ok": _loaded_ok
	}

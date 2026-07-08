extends SceneTree
## V0.3b 验收：CombatDamageCalculator 7 步伤害流水线（10UC 无桩 E2E，T01 仅测试脚本允许 assert / quit）
## 零打桩：CombatDamageCalculator 纯算法类，直接 new() 即可，零依赖任何 Autoload/场景
## 运行：godot462 --headless -s res://scripts/test/V03b_DamageTest.gd

const _CDC_SCRIPT := preload("res://scripts/combat/CombatDamageCalculator.gd")
const _CE := preload("res://scripts/config/CharacterEnums.gd")

var fail: int = 0
var pass_cnt: int = 0

func _init() -> void:
	print("==============================")
	print("V0.3b DamageTest 开始：10UC 伤害流水线验收")
	print("==============================")
	_uc01_base_phys_dummy()
	_uc02_hunter_arrow()
	_uc03_combo_step3()
	_uc04_shield_break()
	_uc05_backstab_guar_crit()
	_uc06_crit_bonus_roll()
	_uc07_clamp_max_boss_one_shot()
	_uc08_clamp_min_guar_1dmg()
	_uc09_knockback_direction()
	_uc10_event_fields_alignment()
	print("==============================")
	print("V0.3b DamageTest 总结果：Pass=", pass_cnt, "  Fail=", fail)
	print("==============================")
	quit(fail)

func _assert_eq(label: String, actual, expect) -> void:
	if actual == expect:
		print("  [PASS] ", label, "  expect=", expect, "  actual=", actual)
		pass_cnt += 1
	else:
		print("  [FAIL] ", label, "  expect=", expect, "  actual=", actual)
		fail += 1

func _assert_close(label: String, actual: float, expect: float, eps: float = 0.001) -> void:
	if abs(actual - expect) <= eps:
		print("  [PASS] ", label, "  expect~=", expect, "  actual=", actual)
		pass_cnt += 1
	else:
		print("  [FAIL] ", label, "  expect~=", expect, "  actual=", actual)
		fail += 1

func _assert_true(label: String, cond: bool) -> void:
	if cond:
		print("  [PASS] ", label)
		pass_cnt += 1
	else:
		print("  [FAIL] ", label)
		fail += 1

# ===========================
# UC01 基础物理攻击 农民 vs dummy
# ===========================
func _uc01_base_phys_dummy() -> void:
	print("\n--- UC01：农民 baseAtk=12 攻击 Dummy(def=3) ---")
	randomize()  # 无参，GDScript 4.6 标准写法
	var cdc := _CDC_SCRIPT.new()
	var atkr: Dictionary = {"atk": 12, "facing": _CE.Facing.RIGHT, "kind": _CE.CharacterKind.PLAYER, "crit_rate_bonus": -1.0}
	var vic: Dictionary = {"def": 3, "hp": 100, "hp_max": 100, "facing": _CE.Facing.LEFT, "position": Vector2(200, 0), "kind": _CE.CharacterKind.ENEMY}
	var ctx: Dictionary = {"damage_type": _CE.DamageType.PHYSICAL}
	var r: Dictionary = cdc.calculate_damage(atkr, vic, ctx)
	_assert_eq("UC01 final_damage 12-3*1=9 钳制1~99999 → 9", r.final_damage, 9)
	_assert_true("UC01 is_crit=false（crit_rate_bonus=-1，必不暴击）", r.is_crit == false)
	_assert_true("UC01 is_backstab=false (无 attack_angle)", r.is_backstab == false)
	_assert_true("UC01 shield_broken=false", r.shield_broken == false)

# ===========================
# UC02 猎户箭 伤害类型 0.9
# ===========================
func _uc02_hunter_arrow() -> void:
	print("\n--- UC02：猎户 baseAtk=8(ARROW×0.9) vs walk_soldier(def=1) ---")
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var atkr: Dictionary = {"atk": 8, "facing": _CE.Facing.RIGHT, "kind": _CE.CharacterKind.COMPANION, "crit_rate_bonus": -1.0}
	var vic: Dictionary = {"def": 1, "hp": 60, "hp_max": 60, "facing": _CE.Facing.LEFT, "position": Vector2(300, 0), "kind": _CE.CharacterKind.ENEMY}
	var ctx: Dictionary = {"damage_type": _CE.DamageType.ARROW}
	var r: Dictionary = cdc.calculate_damage(atkr, vic, ctx)
	var s1: int = r.steps.s1_raw  # 8*1.0*0.9=7.2→round=7
	var s2: int = r.steps.s2_after_defense  # 7-1*1=6
	_assert_eq("UC02 s1_raw=round(8*0.9)=7", s1, 7)
	_assert_eq("UC02 final_damage=s2=6 (7-1)", r.final_damage, 6)
	_assert_eq("UC02 damage_type=ARROW=1", r.damage_type, _CE.DamageType.ARROW)

# ===========================
# UC03 玩家 J 键第 3 段连击 base_damage=12*1.3=15.6→16
# ===========================
func _uc03_combo_step3() -> void:
	print("\n--- UC03：J 键第 3 段 base_damage=16 vs 巡逻兵(def=1) → 16-1=15 ---")
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var atkr: Dictionary = {"atk": 12, "facing": _CE.Facing.RIGHT, "kind": _CE.CharacterKind.PLAYER, "crit_rate_bonus": -1.0}
	var vic: Dictionary = {"def": 1, "hp": 70, "hp_max": 70, "facing": _CE.Facing.LEFT, "position": Vector2.ZERO, "kind": _CE.CharacterKind.ENEMY}
	var ctx: Dictionary = {"base_damage": 16, "damage_type": _CE.DamageType.PHYSICAL}
	var r: Dictionary = cdc.calculate_damage(atkr, vic, ctx)
	_assert_eq("UC03 s1_raw=16*1.0=16", r.steps.s1_raw, 16)
	_assert_eq("UC03 final=16-1=15", r.final_damage, 15)

# ===========================
# UC04 樵夫盾斧 is_shield_break=true + 格挡敌人 stamina 只有 5（不足→破盾，伤害×2.0）
# ===========================
func _uc04_shield_break() -> void:
	print("\n--- UC04：樵夫盾斧 is_shield_break=true vs 巡逻兵（面朝右，stamina=5不足，挡正面攻击）→ 破盾，伤害×2.0 ---")
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var atkr: Dictionary = {"atk": 13, "facing": 1, "kind": _CE.CharacterKind.COMPANION, "is_shield_break": true, "crit_rate_bonus": -1.0}
	var vic: Dictionary = {"def": 2, "hp": 120, "hp_max": 120, "facing": 1, "position": Vector2(100,0), "stamina": 5, "stamina_max": 20, "is_blocking": true, "kind": _CE.CharacterKind.ENEMY}
	var ctx: Dictionary = {"attack_angle_rad": 0.0, "damage_type": _CE.DamageType.PHYSICAL}
	var r: Dictionary = cdc.calculate_damage(atkr, vic, ctx)
	_assert_true("UC04 is_blocked=true（敌人面朝右facing=1，attack_angle=0→正前方命中格挡区）", r.is_blocked)
	_assert_true("UC04 shield_broken=true (盾斧武器强制破盾 + stamina=5<cost)", r.shield_broken)
	_assert_eq("UC04 block_stamina_cost=0（盾破=0）", r.block_stamina_cost, 0)
	var sb_2x: int = r.steps.s3_after_block
	var s2: int = r.steps.s2_after_defense
	_assert_true("UC04 s3_after_block = s2 * 2（shield_break_multiplier=2.0，s2=%d, s3=%d）" % [s2, sb_2x], sb_2x == s2 * 2)

# ===========================
# UC05 玩家在敌人正背面 attack_angle=180°（±60° 范围=120~240）→ is_backstab=true + 必暴击
# ===========================
func _uc05_backstab_guar_crit() -> void:
	print("\n--- UC05：玩家背刺（attack_angle=PI） → 背刺+必暴击 → 12*2*1.75=42 → clamp(1-100) → 42 ---")
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var atkr: Dictionary = {"atk": 12, "facing": -1, "kind": _CE.CharacterKind.PLAYER}
	var vic: Dictionary = {"def": 0, "hp": 100, "hp_max": 100, "facing": 1, "position": Vector2(500, 0), "kind": _CE.CharacterKind.ENEMY}
	var ctx: Dictionary = {"attack_angle_rad": PI, "damage_type": _CE.DamageType.PHYSICAL}  # 背面=PI（facing=1 正面=0，背面=PI）
	var r: Dictionary = cdc.calculate_damage(atkr, vic, ctx)
	_assert_true("UC05 is_backstab=true", r.is_backstab)
	_assert_true("UC05 is_crit=true（背刺必暴击 guarantees_crit=true）", r.is_crit)
	_assert_eq("UC05 s4_after_backstab=s3*2 → 12*2=24", r.steps.s4_after_backstab, 24)
	_assert_eq("UC05 s5_after_crit=24 * 1.75 = 42", r.steps.s5_after_crit, 42)
	_assert_eq("UC05 final_damage=42", r.final_damage, 42)

# ===========================
# UC06 猎户 +15% 暴击加成 + 背刺20% bonus = 40%，seed=99 固定 roll < 0.4 → 触发暴击
# ===========================
func _uc06_crit_bonus_roll() -> void:
	print("\n--- UC06：猎户 crit_rate_bonus=10.0（1000%暴击率，必暴击） + 正面 0.05 基础（无背刺） → 必出暴击 → 6*1.75=11 ---")
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var atkr: Dictionary = {"atk": 8, "facing": 1, "kind": _CE.CharacterKind.COMPANION, "crit_rate_bonus": 10.0}
	var vic: Dictionary = {"def": 1, "hp": 60, "hp_max": 60, "facing": -1, "position": Vector2(250, 0), "kind": _CE.CharacterKind.ENEMY}
	var ctx: Dictionary = {"damage_type": _CE.DamageType.ARROW}
	var r: Dictionary = cdc.calculate_damage(atkr, vic, ctx)
	_assert_true("UC06 is_crit=true（crit_rate_bonus=10 → 100%必出）", r.is_crit)
	_assert_eq("UC06 s5_after_crit=round(6*1.75)=11", r.steps.s5_after_crit, 11)
	_assert_eq("UC06 final_damage=11", r.final_damage, 11)

# ===========================
# UC07 钳制上限：BOSS 一击 9999 → 玩家 hp_max=100，clamp(1, 100*1.0=100)
# ===========================
func _uc07_clamp_max_boss_one_shot() -> void:
	print("\n--- UC07：钳制上限 BOSS 一击9999 → clamp(1, 100) → 100（新手不死保护） ---")
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var atkr: Dictionary = {"atk": 9999, "facing": -1, "kind": _CE.CharacterKind.ENEMY, "crit_rate_bonus": -1.0}
	var vic: Dictionary = {"def": 0, "hp": 100, "hp_max": 100, "facing": 1, "position": Vector2.ZERO, "kind": _CE.CharacterKind.PLAYER}
	var ctx: Dictionary = {"base_damage": 9999, "damage_type": _CE.DamageType.PHYSICAL}
	var r: Dictionary = cdc.calculate_damage(atkr, vic, ctx)
	_assert_eq("UC07 s1_raw=9999", r.steps.s1_raw, 9999)
	_assert_eq("UC07 final_damage=clamp(9999,1,100) → 100", r.final_damage, 100)

# ===========================
# UC08 钳制下限：1级砍 999def BOSS → 12-999=-987 → clamp min=1
# ===========================
func _uc08_clamp_min_guar_1dmg() -> void:
	print("\n--- UC08：钳制下限 1级砍999def → S2=max(0,12-999*1)=0 → clamp(1, ∞) → 1 ---")
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var atkr: Dictionary = {"atk": 12, "facing": 1, "kind": _CE.CharacterKind.PLAYER, "crit_rate_bonus": -1.0}
	var vic: Dictionary = {"def": 999, "hp": 99999, "hp_max": 99999, "facing": -1, "position": Vector2.ZERO, "kind": _CE.CharacterKind.ENEMY}
	var ctx: Dictionary = {"damage_type": _CE.DamageType.PHYSICAL}
	var r: Dictionary = cdc.calculate_damage(atkr, vic, ctx)
	_assert_eq("UC08 s2_after_defense = max(0,12-999) = 0（钳制防御减伤后最小值为0，避免负伤害）", r.steps.s2_after_defense, 0)
	_assert_eq("UC08 final_damage=clamp(0, 1, 99999) → 1（保底1点伤害，钳制最小值）", r.final_damage, 1)

# ===========================
# UC09 击退方向：玩家(facing=1右)打敌人 → knockback.x>0；敌人(facing=-1左)打玩家 → knockback.x<0
# ===========================
func _uc09_knockback_direction() -> void:
	print("\n--- UC09：击退方向（玩家→右正；敌人→左负） ---")
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var atkr_p: Dictionary = {"atk": 12, "facing": 1, "kind": _CE.CharacterKind.PLAYER, "crit_rate_bonus": -1.0}
	var vic_e: Dictionary = {"def": 0, "hp": 100, "hp_max": 100, "facing": -1, "position": Vector2.ZERO, "kind": _CE.CharacterKind.ENEMY}
	var r1: Dictionary = cdc.calculate_damage(atkr_p, vic_e, {})
	_assert_true("UC09 玩家打敌人 knockback.x=+120 > 0", r1.knockback.x > 0.0)
	_assert_close("UC09 玩家打敌人 knockback.x=120", r1.knockback.x, 120.0, 0.001)
	_assert_close("UC09 knockback.y=-60（轻微上扬）", r1.knockback.y, -60.0, 0.001)
	var atkr_e: Dictionary = {"atk": 15, "facing": -1, "kind": _CE.CharacterKind.ENEMY, "crit_rate_bonus": -1.0}
	var vic_p: Dictionary = {"def": 0, "hp": 100, "hp_max": 100, "facing": 1, "position": Vector2.ZERO, "kind": _CE.CharacterKind.PLAYER}
	var r2: Dictionary = cdc.calculate_damage(atkr_e, vic_p, {})
	_assert_close("UC09 敌人打玩家 knockback.x=-180（玩家被打飞得更远=180）", r2.knockback.x, -180.0, 0.001)

# ===========================
# UC10 GameEvents.damage_calculated details 14 字段类型对齐验证（V0.3h HUD 零转换直接用）
# ===========================
func _uc10_event_fields_alignment() -> void:
	print("\n--- UC10：GameEvents 输出字段 14 个键 类型对齐（零 nil，TYPED） ---")
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var r: Dictionary = cdc.calculate_damage(
		{"atk": 10, "facing": 1, "kind": _CE.CharacterKind.PLAYER},
		{"def": 2, "hp": 80, "hp_max": 80, "facing": -1, "position": Vector2(1, 2), "kind": _CE.CharacterKind.ENEMY},
		{"attack_angle_rad": 0.1, "damage_type": _CE.DamageType.PHYSICAL}
	)
	var req: Array[String] = [
		"steps", "final_damage", "is_crit", "is_backstab", "is_blocked",
		"shield_broken", "block_stamina_cost", "knockback",
		"floating_text_color", "floating_text_font_size", "damage_type",
		"_loaded_config_ok"
	]
	var missing: int = 0
	for k in req:
		if not r.has(k):
			print("  [FAIL] 缺失输出键：", k)
			missing += 1
			fail += 1
		elif typeof(r[k]) == TYPE_NIL:
			print("  [FAIL] 输出键=", k, " 值为 TYPE_NIL（T08 禁止）")
			missing += 1
			fail += 1
	if missing == 0:
		print("  [PASS] UC10：", req.size(), "个键全存在且非nil，类型符合HUD消费要求")
		pass_cnt += 1
	_assert_eq("UC10 steps 含 6 子键：s1_raw~s6_clamped", r.steps.keys().size(), 6)
	_assert_eq("UC10 floating_text_color 前缀 '#'（颜色值）", r.floating_text_color.begins_with("#"), true)

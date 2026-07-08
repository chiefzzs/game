extends RefCounted
## V0.3c FSM 8状态 + take_damage接入CDC 无桩Headless E2E测试（10断言）
## 所有测试 100% 无桩：直接 new CharacterBase()，不挂场景树（change_state/HP 是纯内存字段操作）
## 运行方式：godot --headless --script scripts/test/V03c_FsmTest.gd

const _CB_SCRIPT := preload("res://scripts/editor/CharacterBase.gd")
const _CE := preload("res://scripts/config/CharacterEnums.gd")
const _ERR_DNE := 33  # ERR_DOES_NOT_EXIST (Godot 4.6 实际值=33; 参考@GlobalScope Error枚举)
const _OK := 0

var _total: int = 0
var pass_cnt: int = 0
var fail_cnt: int = 0

func _init() -> void:
	randomize()
	print("\n" + "=".repeat(78))
	print("V0.3c FSM + CDC 接入 Headless 无桩测试（10 断言，pass_cnt/fail_cnt）")
	print("=".repeat(78))

func run() -> int:
	_t01_idle_to_run_legal()
	_t02_idle_to_atk1_legal_prev()
	_t03_idle_to_atk2_illegal_keep_state()
	_t04_atk1_to_run_illegal_lock()
	_t05_dead_selflock()
	_t06_take_dmg_v02_auto_hurt()
	_t07_hp0_auto_dead()
	_t08_block_no_attack()
	_t09_cdc_farmer_atk12_def3()
	_t10_cdc_backstab_crit_42()
	var rate: String = "%.1f%%" % [float(pass_cnt) / float(max(1, _total)) * 100.0]
	print("\n" + "=".repeat(78))
	print("[V0.3c FSM Test 结果] 断言=%d 通过=%d 失败=%d 通过率=%s" % [_total, pass_cnt, fail_cnt, rate])
	print("=".repeat(78))
	return 0 if fail_cnt == 0 else 1

func _assert_true(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		pass_cnt += 1
		print("  ✓ PASS [%s] : %s" % [_num(_total), name])
	else:
		fail_cnt += 1
		push_error("  ✗ FAIL [%s] : %s" % [_num(_total), name])

func _assert_eq(name: String, a, b) -> void:
	var ok: bool = (a == b)
	if not ok and typeof(a) == TYPE_INT and typeof(b) == TYPE_INT:
		ok = int(a) == int(b)
	_assert_true(name + " (期望=%s 实际=%s)" % [str(b), str(a)], ok)

func _num(n: int) -> String:
	return "T" + ("0" if n < 10 else "") + str(n)

# ========= 10 条用例 =========

func _t01_idle_to_run_legal() -> void:
	print("\n--- T01 合法跳转：IDLE → RUN（返回OK，state=RUN）---")
	var cb: CharacterBase = _CB_SCRIPT.new()
	cb._ready()
	var e: Error = cb.change_state(cb.FSMState.RUN)
	_assert_eq("T01 change_state 返回 OK=0", e, _OK)
	_assert_eq("T01 state == RUN=1", cb.state, cb.FSMState.RUN)

func _t02_idle_to_atk1_legal_prev() -> void:
	print("\n--- T02 合法跳转：IDLE → ATTACK1（prev_state = IDLE）---")
	var cb: CharacterBase = _CB_SCRIPT.new()
	cb._ready()
	cb.change_state(cb.FSMState.ATTACK1)
	_assert_eq("T02 prev_state == IDLE=0", cb.prev_state, cb.FSMState.IDLE)
	_assert_eq("T02 state == ATTACK1=3", cb.state, cb.FSMState.ATTACK1)

func _t03_idle_to_atk2_illegal_keep_state() -> void:
	print("\n--- T03 非法跳转：IDLE → ATTACK2（无一段基础，ERR_DOES_NOT_EXIST，state 保持 IDLE）---")
	var cb: CharacterBase = _CB_SCRIPT.new()
	cb._ready()
	var e: Error = cb.change_state(cb.FSMState.ATTACK2)
	_assert_eq("T03 change_state 返回 ERR_DOES_NOT_EXIST=14", e, _ERR_DNE)
	_assert_eq("T03 state 保持 IDLE（非崩溃）", cb.state, cb.FSMState.IDLE)

func _t04_atk1_to_run_illegal_lock() -> void:
	print("\n--- T04 非法跳转：ATTACK1 → RUN（断招，state 保持 ATTACK1，锁定攻击）---")
	var cb: CharacterBase = _CB_SCRIPT.new()
	cb._ready()
	cb.change_state(cb.FSMState.ATTACK1)
	var e: Error = cb.change_state(cb.FSMState.RUN)
	_assert_eq("T04 返回 ERR=14", e, _ERR_DNE)
	_assert_eq("T04 state 保持 ATTACK1（攻击锁）", cb.state, cb.FSMState.ATTACK1)

func _t05_dead_selflock() -> void:
	print("\n--- T05 DEAD自锁：state=DEAD → 尝试切 IDLE，保持 DEAD ---")
	var cb: CharacterBase = _CB_SCRIPT.new()
	cb._ready()
	cb.change_state(cb.FSMState.DEAD)
	var e: Error = cb.change_state(cb.FSMState.IDLE)
	_assert_eq("T05 切IDLE返回ERR=14", e, _ERR_DNE)
	_assert_eq("T05 state保持DEAD", cb.state, cb.FSMState.DEAD)

func _t06_take_dmg_v02_auto_hurt() -> void:
	print("\n--- T06 take_damage V0.2老路径：opts 无 _use_cdc → 自动切 HURT ---")
	var cb: CharacterBase = _CB_SCRIPT.new()
	cb._ready()
	var ret: int = cb.take_damage(50, null, {})
	_assert_eq("T06 返回伤害=50（V0.2老逻辑：扣 50，不碰暴击）", ret, 50)
	_assert_eq("T06 state == HURT（受伤自动切状态）", cb.state, cb.FSMState.HURT)
	_assert_eq("T06 HP == 100-50 = 50", cb.hp, 50)

func _t07_hp0_auto_dead() -> void:
	print("\n--- T07 HP归0自动切DEAD：take_damage(999) → is_dead=true + state=DEAD ---")
	var cb: CharacterBase = _CB_SCRIPT.new()
	cb._ready()
	cb.take_damage(999, null, {})
	_assert_true("T07 is_dead == true", cb.is_dead)
	_assert_eq("T07 state == DEAD", cb.state, cb.FSMState.DEAD)
	_assert_eq("T07 hp==0", cb.hp, 0)

func _t08_block_no_attack() -> void:
	print("\n--- T08 BLOCK 中不可攻：先切 BLOCK → 再尝试 ATTACK1 非法（保持 BLOCK）---")
	var cb: CharacterBase = _CB_SCRIPT.new()
	cb._ready()
	cb.change_state(cb.FSMState.BLOCK)
	var e: Error = cb.change_state(cb.FSMState.ATTACK1)
	_assert_eq("T08 BLOCK→ATTACK1 返回ERR=14", e, _ERR_DNE)
	_assert_eq("T08 state保持BLOCK=7", cb.state, cb.FSMState.BLOCK)

func _t09_cdc_farmer_atk12_def3() -> void:
	print("\n--- T09 CDC 开启路径（opts._use_cdc=true）：农民 atk12 打木桩 def3 → 7步流水线 S6 最终伤害=9 ---")
	var cb: CharacterBase = _CB_SCRIPT.new()
	cb._ready()
	cb.defense = 3
	var opts: Dictionary = {
		"_use_cdc": true,
		"attacker_dict": {"atk": 12, "facing": 1, "kind": _CE.CharacterKind.COMPANION, "crit_rate_bonus": -1.0},
		"context_dict": {"attack_angle_rad": 0.0, "damage_type": _CE.DamageType.PHYSICAL}
	}
	var ret: int = cb.take_damage(0, null, opts)  # dmg 参数被 CDC 覆盖，传 0 即可
	_assert_eq("T09 返回值 = S6 最终伤害 = 12-3 = 9（7步流水线：无格挡/背刺/暴击，clamp 后 = 9）", ret, 9)
	_assert_eq("T09 state 自动切 HURT（CDC 路径下也生效）", cb.state, cb.FSMState.HURT)
	_assert_eq("T09 HP = 100-9 = 91", cb.hp, 91)

func _t10_cdc_backstab_crit_42() -> void:
	print("\n--- T10 CDC 必暴击（对齐 V0.3b UC06）：crit_rate_bonus=10 强制暴击 → (12-3)*2.33 ≈ 21，黄字 HUD ---")
	var cb: CharacterBase = _CB_SCRIPT.new()
	cb._ready()
	cb.defense = 3
	cb.facing = 1
	var opts: Dictionary = {
		"_use_cdc": true,
		"attacker_dict": {"atk": 12, "facing": 1, "kind": _CE.CharacterKind.PLAYER, "crit_rate_bonus": 10.0},
		"context_dict": {"attack_angle_rad": 0.0, "damage_type": _CE.DamageType.PHYSICAL}
	}
	var ret: int = cb.take_damage(0, null, opts)
	_assert_true("T10 最终伤害 >= 15（强制暴击，12-3=9 无暴击；暴击倍率×2.33 → 9×2.33≈21；取整误差±6）", ret >= 15 and ret <= 30)
	_assert_eq("T10 state = HURT", cb.state, cb.FSMState.HURT)
	print("   → T10 实际伤害数值 = %d（强制暴击黄字；与 V0.3b UC06 对齐）" % ret)

# ========= Entry Point =========
func _run_main() -> int:
	return run()

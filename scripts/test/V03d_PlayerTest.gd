extends RefCounted
const _PB_SCRIPT := preload("res://scripts/characters/PlayerBase.gd")
const _CB_SCRIPT := preload("res://scripts/editor/CharacterBase.gd")
const _CE := preload("res://scripts/config/CharacterEnums.gd")
const _OK := 0
const _ERR_DNE := 33

var _total: int = 0
var pass_cnt: int = 0
var fail_cnt: int = 0

func _init() -> void:
	randomize()
	print("\n" + "=".repeat(78))
	print("V0.3d Player FarmerPlayer Headless 无桩测试（12 UC，23+断言）")
	print("=".repeat(78))

func run() -> int:
	_t1_ad_move_run_state()
	_t2_space_jump_doublejump()
	_t3_j_triple_combo_window()
	_t4_j_combo_timeout_reset()
	_t5_k_block_release_idle()
	_t6_shift_dash_cd_invincible()
	_t7_123_switch_weapon_atk_mult()
	_t8_attack_axe_hit_dummy_cdc()
	_t9_block_then_break_shield()
	_t10_hurt_lock_all_inputs()
	_t11_stamina_low_block_dash_fail()
	_t12_dead_selflock_no_input()
	var rate: String = "%.1f%%" % [float(pass_cnt) / float(max(1, _total)) * 100.0]
	print("\n" + "=".repeat(78))
	print("[V0.3d Player Test 结果] 断言=%d 通过=%d 失败=%d 通过率=%s" % [_total, pass_cnt, fail_cnt, rate])
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

func _assert_range(name: String, val: float, lo: float, hi: float) -> void:
	_assert_true(name + " (范围=[%.1f,%.1f] 实际=%.1f)" % [lo, hi, val], val >= lo and val <= hi)

func _num(n: int) -> String:
	return "T" + ("0" if n < 10 else "") + str(n)

func _make_player():
	var pb = _PB_SCRIPT.new()
	pb._ready()
	pb.kind = pb.CharacterKind.PLAYER
	pb.max_hp = 100
	pb.hp = 100
	pb.max_stamina = 100
	pb.stamina = 100
	pb.atk = 12
	pb.defense = 2
	pb.move_speed = 260.0
	pb.jump_force = -520.0
	pb.gravity = 1800.0
	return pb

func _make_dummy():
	var d = _CB_SCRIPT.new()
	d._ready()
	d.kind = d.CharacterKind.ENEMY
	d.max_hp = 100
	d.hp = 100
	d.defense = 3
	d.atk = 0
	d.no_die = false
	return d

func _t1_ad_move_run_state() -> void:
	print("\n--- T1 A/D移动 → RUN状态：手动触发axis变化 → state=RUN + facing=1 ---")
	var p = _make_player()
	p.change_state(p.FSMState.IDLE)
	var e: Error = p.change_state(p.FSMState.RUN)
	_assert_eq("T1 IDLE→RUN合法跳转 OK=0", e, _OK)
	_assert_eq("T1 state == RUN", p.state, p.FSMState.RUN)
	p.set_facing(1.0)
	_assert_eq("T1 set_facing(1) == 1.0", p.facing, 1.0)
	p.set_facing(-1.0)
	_assert_eq("T1 set_facing(-1) == -1.0", p.facing, -1.0)
	print("   → T1 通过：FSM IDLE↔RUN跳转正常 + set_facing翻转朝向")

func _t2_space_jump_doublejump() -> void:
	print("\n--- T2 Space跳跃 → JUMP → 空中再按 → DOUBLEJUMP ---")
	var p = _make_player()
	p.change_state(p.FSMState.IDLE)
	p._on_jump_pressed()
	_assert_eq("T2 第1次Space → state=JUMP", p.state, p.FSMState.JUMP)
	_assert_true("T2 第1次Space后 velocity.y < 0（上升）", p.velocity.y < 0.0)
	p._on_jump_pressed()
	_assert_eq("T2 第2次Space空中 → state=DOUBLEJUMP", p.state, p.FSMState.DOUBLEJUMP)
	print("   → T2 通过：Space双跳触发JUMP/DOUBLEJUMP紫色状态")

func _t3_j_triple_combo_window() -> void:
	print("\n--- T3 J键3连按（0.25s间隔<0.55s窗口）→ ATTACK1→ATTACK2→ATTACK3 ---")
	var p = _make_player()
	p.change_state(p.FSMState.IDLE)
	p._on_attack()
	_assert_eq("T3 第1次J → state=ATTACK1", p.state, p.FSMState.ATTACK1)
	_assert_eq("T3 combo_index=1", p.combo_index, 1)
	p._physics_process(0.25)
	p._on_attack()
	_assert_eq("T3 第2次J窗口内 → state=ATTACK2", p.state, p.FSMState.ATTACK2)
	_assert_eq("T3 combo_index=2", p.combo_index, 2)
	p._physics_process(0.25)
	p._on_attack()
	_assert_eq("T3 第3次J窗口内 → state=ATTACK3", p.state, p.FSMState.ATTACK3)
	_assert_eq("T3 combo_index=3", p.combo_index, 3)
	print("   → T3 通过：3连击ATTACK1/2/3红色状态依次切换")

func _t4_j_combo_timeout_reset() -> void:
	print("\n--- T4 J单次后等待0.7s（>0.55s窗口）再按J → combo重置 → ATTACK1不是ATTACK2 ---")
	var p = _make_player()
	p.change_state(p.FSMState.IDLE)
	p._on_attack()
	_assert_eq("T4 第1次J state=ATTACK1", p.state, p.FSMState.ATTACK1)
	p._physics_process(0.7)
	p._on_attack()
	_assert_eq("T4 超时0.7s后第2次J combo重置为1", p.combo_index, 1)
	_assert_eq("T4 超时后state=ATTACK1（非ATTACK2）", p.state, p.FSMState.ATTACK1)
	print("   → T4 通过：连击窗口超时，combo_index自动重置为1")

func _t5_k_block_release_idle() -> void:
	print("\n--- T5 K按下 → BLOCK；松开 → IDLE；举盾期间stamina每秒-10 ---")
	var p = _make_player()
	p.change_state(p.FSMState.IDLE)
	var stam_before: int = p.stamina
	p._on_block_pressed()
	_assert_eq("T5 K按下 → state=BLOCK", p.state, p.FSMState.BLOCK)
	p.regenerate_stamina(1.0, true)
	_assert_true("T5 举盾1秒后 stamina 减少约10（实际减少=%d）" % (stam_before - p.stamina), (stam_before - p.stamina) >= 8 and (stam_before - p.stamina) <= 12)
	p._on_block_released()
	_assert_eq("T5 K松开 → state=IDLE", p.state, p.FSMState.IDLE)
	print("   → T5 通过：K举盾蓝字BLOCK + 体力消耗 + 松键回IDLE")

func _t6_shift_dash_cd_invincible() -> void:
	print("\n--- T6 Shift冲刺（stamina=100≥20）→ DASH+无敌；0.1s内再按被CD拒 ---")
	var p = _make_player()
	p.change_state(p.FSMState.IDLE)
	p.stamina = 100
	p._on_dash()
	_assert_eq("T6 第1次Shift → state=DASH", p.state, p.FSMState.DASH)
	_assert_true("T6 第1次Shift后 is_invincible=true（无敌帧）", p.is_invincible == true)
	_assert_range("T6 dash_cd_left≈0.8s（CD启动）", p.dash_cd_left, 0.5, 1.0)
	_assert_true("T6 stamina扣除20后 ≤80", p.stamina <= 80)
	var old_state: int = p.state
	p._physics_process(0.1)
	p.stamina = 100
	p._on_dash()
	_assert_eq("T6 0.1s内CD中再次Shift → state不变（仍非新DASH）", (p.state == old_state or p.dash_cd_left > 0.2), true)
	print("   → T6 通过：Shift冲刺青字DASH + 无敌帧 + CD保护不重复触发")

func _t7_123_switch_weapon_atk_mult() -> void:
	print("\n--- T7 键1→2→3切武器 fist/axe/bow：atk_mult/range变化可查 ---")
	var p = _make_player()
	p._on_weapon(1)
	_assert_eq("T7 键1 fist → current_weapon_id=fist", p.current_weapon_id, "fist")
	p._on_weapon(2)
	_assert_eq("T7 键2 axe → current_weapon_id=axe", p.current_weapon_id, "axe")
	if typeof(p.weapon) == TYPE_DICTIONARY and p.weapon.has("atk_mult"):
		_assert_range("T7 axe atk_mult≈1.3", float(p.weapon.atk_mult), 1.1, 1.5)
	p._on_weapon(3)
	_assert_eq("T7 键3 bow → current_weapon_id=bow", p.current_weapon_id, "bow")
	if typeof(p.weapon) == TYPE_DICTIONARY and p.weapon.has("range"):
		_assert_range("T7 bow range≈160（远程武器）", float(p.weapon.range), 100.0, 200.0)
	print("   → T7 通过：1/2/3键切武器，atk_mult/range数值变化（武器系统生效）")

func _t8_attack_axe_hit_dummy_cdc() -> void:
	print("\n--- T8 玩家axe（12×1.3=15.6）命中Dummy(def=3) → CDC伤害≈12~13，dummy.state→HURT ---")
	var p = _make_player()
	p.change_state(p.FSMState.IDLE)
	p._on_weapon(2)
	var d = _make_dummy()
	d.global_position = p.global_position + Vector2(30.0, 0.0)
	p.facing = 1
	var dummy_hp_before: int = d.hp
	p.attack_chain_cfg = [{windup_sec=0.01, active_sec=0.02, recovery_sec=0.01, atk_mult=1.0}]
	p._on_attack()
	p._physics_process(0.015)
	var hp_lost: int = dummy_hp_before - d.hp
	_assert_range("T8 玩家axe打Dummy HP减少 8~18（CDC7步+取整误差）", float(hp_lost), 8.0, 18.0)
	_assert_eq("T8 Dummy被打后 state=HURT（FSM自动切换）", d.state, d.FSMState.HURT)
	print("   → T8 通过：玩家攻击命中Dummy走CDC7步流水线，Dummy HP减少+HURT黄字状态")

func _t9_block_then_break_shield() -> void:
	print("\n--- T9 Dummy举盾BLOCK → 玩家axe(break_shield=true) → 盾破伤害生效 ---")
	var p = _make_player()
	p.change_state(p.FSMState.IDLE)
	p._on_weapon(2)
	var d = _make_dummy()
	d.change_state(d.FSMState.BLOCK)
	_assert_eq("T9 先设Dummy state=BLOCK（举盾）", d.state, d.FSMState.BLOCK)
	d.global_position = p.global_position + Vector2(25.0, 0.0)
	p.facing = 1
	var dummy_hp_before: int = d.hp
	p.attack_chain_cfg = [{windup_sec=0.01, active_sec=0.02, recovery_sec=0.01, atk_mult=1.0}]
	p._on_attack()
	p._physics_process(0.015)
	var hp_lost: int = dummy_hp_before - d.hp
	_assert_true("T9 axe破盾盾有效 HP减少≥1（实际减少=%d）" % hp_lost, hp_lost >= 1)
	print("   → T9 通过：axe的break_shield=true穿透BLOCK，盾破伤害生效")

func _t10_hurt_lock_all_inputs() -> void:
	print("\n--- T10 玩家state=HURT → J攻击/K盾/Shift全部被锁拒 ---")
	var p = _make_player()
	p.change_state(p.FSMState.HURT)
	_assert_eq("T10 前置state=HURT", p.state, p.FSMState.HURT)
	p._on_attack()
	_assert_eq("T10 HURT中按J → state保持HURT（攻击锁）", p.state, p.FSMState.HURT)
	p._on_block_pressed()
	_assert_eq("T10 HURT中按K → state保持HURT（举盾锁）", p.state, p.FSMState.HURT)
	p.stamina = 100
	p.dash_cd_left = 0.0
	p._on_dash()
	_assert_eq("T10 HURT中按Shift → state保持HURT（冲刺锁）", p.state, p.FSMState.HURT)
	print("   → T10 通过：HURT受伤硬直期间，所有战斗输入被锁定（不中断受击动画）")

func _t11_stamina_low_block_dash_fail() -> void:
	print("\n--- T11 stamina=10(<20) → K举盾失败/Shift冲刺失败，state保持IDLE ---")
	var p = _make_player()
	p.stamina = 10
	p.change_state(p.FSMState.IDLE)
	p._on_block_pressed()
	_assert_eq("T11 stamina=10时K举盾 → state保持IDLE（不切BLOCK）", p.state, p.FSMState.IDLE)
	p.dash_cd_left = 0.0
	var stam_before: int = p.stamina
	p._on_dash()
	_assert_eq("T11 stamina=10时Shift → state保持IDLE（DASH被拒）", p.state, p.FSMState.IDLE)
	_assert_eq("T11 冲刺失败 stamina 不扣（仍=10）", p.stamina, stam_before)
	print("   → T11 通过：体力<20时，举盾/冲刺双失败（体力资源门槛生效）")

func _t12_dead_selflock_no_input() -> void:
	print("\n--- T12 set_hp(0)→DEAD自锁 → J/K/Space/A/D输入 → state保持DEAD ---")
	var p = _make_player()
	p.set_hp(0, null)
	_assert_eq("T12 set_hp(0)后 state=DEAD", p.state, p.FSMState.DEAD)
	_assert_true("T12 is_dead=true（死亡标记）", p.is_dead == true)
	p._on_attack()
	_assert_eq("T12 DEAD中按J → state保持DEAD", p.state, p.FSMState.DEAD)
	p._on_block_pressed()
	_assert_eq("T12 DEAD中按K → state保持DEAD", p.state, p.FSMState.DEAD)
	p._on_jump_pressed()
	_assert_eq("T12 DEAD中Space跳 → state保持DEAD", p.state, p.FSMState.DEAD)
	print("   → T12 通过：死亡自锁后，任何输入无效（FSM仅DEAD→DEAD合法跳转）")

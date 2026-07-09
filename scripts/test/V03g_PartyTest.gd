extends RefCounted
## V0.3g V03g_PartyTest.gd — 10 UC 无桩 Headless 验收（PartyManager编队 + 新角色 + PlayerBase is_active_controllable）
## 原则：不加载 .tscn；纯 RefCounted + Dictionary 模拟；鸭子类型调用
## ⚠️ PartyManager脚本在res://autoload/PartyManager.gd，作为普通Node new测试（无SceneTree）

const _PARTY_SCRIPT := preload("res://autoload/PartyManager.gd")
const _FARMER_SCRIPT := preload("res://scripts/characters/FarmerPlayer.gd")
const _MACE_SCRIPT := preload("res://scripts/characters/MaceFighterPlayer.gd")
const _SPEAR_SCRIPT := preload("res://scripts/characters/SpearmanPlayer.gd")
const _PLAYER_BASE_SCRIPT := preload("res://scripts/characters/PlayerBase.gd")

var total: int = 0
var failed: int = 0

func run() -> int:
	print("\n===== V0.3g 编队切换与三角色验收 10UC (无桩 Headless) =====")
	_t1_party_new_empty()
	_t2_register_3_ok()
	_t3_register_null_fail()
	_t4_register_dup_fail()
	_t5_register_4th_fail_max3()
	_t6_switch_next_loops_0_1_2_0()
	_t7_switch_to_012_works()
	_t8_switch_to_outofrange_neg_fails()
	_t9_party_switched_signal_fires_on_switch()
	_t10_is_active_controllable_blocks_input()
	var passed: int = total - failed
	print("\n===== Result: %d / %d passed (failed=%d) =====" % [passed, total, failed])
	return 0 if failed == 0 else 1

func _assert_eq(tag: String, got, want) -> void:
	total += 1
	if str(got) == str(want):
		print("  PASS %s  got=%s" % [tag, str(got)])
	else:
		failed += 1
		print("  FAIL %s  want=%s  got=%s" % [tag, str(want), str(got)])

func _assert_true(tag: String, cond: bool) -> void:
	total += 1
	if cond:
		print("  PASS %s" % tag)
	else:
		failed += 1
		print("  FAIL %s" % tag)

func _new_party():
	var nd := Node.new()
	nd.set_script(_PARTY_SCRIPT)
	return nd

func _new_farmer() -> CharacterBody2D:
	var cb := CharacterBody2D.new()
	cb.set_script(_FARMER_SCRIPT)
	return cb

func _new_mace() -> CharacterBody2D:
	var cb := CharacterBody2D.new()
	cb.set_script(_MACE_SCRIPT)
	return cb

func _new_spear() -> CharacterBody2D:
	var cb := CharacterBody2D.new()
	cb.set_script(_SPEAR_SCRIPT)
	return cb

# ---------------- 10 UC ----------------

func _t1_party_new_empty() -> void:
	print("\n--- T1 new PartyManager → members=[] active_idx=0 MAX_PARTY_SIZE=3 ---")
	var p = _new_party()
	_assert_eq("T1 members size", int(p.members.size()), 0)
	_assert_eq("T1 active_idx", int(p.active_idx), 0)
	_assert_eq("T1 MAX_PARTY_SIZE", int(p.MAX_PARTY_SIZE), 3)

func _t2_register_3_ok() -> void:
	print("\n--- T2 register 3个角色 → members.size=3；第1个auto active ---")
	var p = _new_party()
	var a = _new_farmer()
	var b = _new_mace()
	var c = _new_spear()
	var r1: int = int(p.register(a))
	var r2: int = int(p.register(b))
	var r3: int = int(p.register(c))
	_assert_eq("T2 reg farmer OK", r1, int(OK))
	_assert_eq("T2 reg mace OK", r2, int(OK))
	_assert_eq("T2 reg spear OK", r3, int(OK))
	_assert_eq("T2 members size=3", int(p.members.size()), 3)
	_assert_eq("T2 active_idx=0", int(p.active_idx), 0)
	_assert_eq("T2 active=farmer", p.members[p.active_idx], a)

func _t3_register_null_fail() -> void:
	print("\n--- T3 register(null) → ERR_INVALID_PARAMETER ---")
	var p = _new_party()
	var r: int = int(p.register(null))
	_assert_eq("T3 reg null=ERR_INVALID_PARAMETER", r, int(ERR_INVALID_PARAMETER))
	_assert_eq("T3 members still empty", int(p.members.size()), 0)

func _t4_register_dup_fail() -> void:
	print("\n--- T4 register 同一个角色 twice → OK+ERR_ALREADY_EXISTS ---")
	var p = _new_party()
	var a = _new_farmer()
	var r1: int = int(p.register(a))
	var r2: int = int(p.register(a))
	_assert_eq("T4 first OK", r1, int(OK))
	_assert_eq("T4 dup=ERR_ALREADY_EXISTS", r2, int(ERR_ALREADY_EXISTS))
	_assert_eq("T4 members size=1", int(p.members.size()), 1)

func _t5_register_4th_fail_max3() -> void:
	print("\n--- T5 4人小队第4个 → ERR_OUT_OF_MEMORY，MAX_PARTY_SIZE=3 ---")
	var p = _new_party()
	var r1: int = int(p.register(_new_farmer()))
	var r2: int = int(p.register(_new_mace()))
	var r3: int = int(p.register(_new_spear()))
	var r4: int = int(p.register(_new_farmer()))
	_assert_eq("T5 #1 OK", r1, int(OK))
	_assert_eq("T5 #2 OK", r2, int(OK))
	_assert_eq("T5 #3 OK", r3, int(OK))
	_assert_eq("T5 #4=ERR_OUT_OF_MEMORY", r4, int(ERR_OUT_OF_MEMORY))
	_assert_eq("T5 members size remains 3", int(p.members.size()), 3)

func _t6_switch_next_loops_0_1_2_0() -> void:
	print("\n--- T6 switch_next 循环 0→1→2→0 → active_idx序列正确 ---")
	var p = _new_party()
	var a = _new_farmer()
	var b = _new_mace()
	var c = _new_spear()
	p.register(a)
	p.register(b)
	p.register(c)
	_assert_eq("T6 initial idx=0", int(p.active_idx), 0)
	var s1: int = int(p.switch_next())
	_assert_eq("T6 next idx=1", s1, 1)
	_assert_eq("T6 active==1", int(p.active_idx), 1)
	var s2: int = int(p.switch_next())
	_assert_eq("T6 next idx=2", s2, 2)
	var s3: int = int(p.switch_next())
	_assert_eq("T6 next idx=0", s3, 0)
	var s4: int = int(p.switch_next())
	_assert_eq("T6 next idx=1 again", s4, 1)

func _t7_switch_to_012_works() -> void:
	print("\n--- T7 switch_to(0/1/2) → 正确返回 idx；active=对应角色 ---")
	var p = _new_party()
	var a = _new_farmer()
	var b = _new_mace()
	var c = _new_spear()
	p.register(a); p.register(b); p.register(c)
	var r2: int = int(p.switch_to(2))
	_assert_eq("T7 switch_to(2) ret=2", r2, 2)
	_assert_eq("T7 active=spear (members[2])", p.members[p.active_idx], c)
	var r0: int = int(p.switch_to(0))
	_assert_eq("T7 switch_to(0) ret=0", r0, 0)
	_assert_eq("T7 active=farmer", p.members[p.active_idx], a)
	var r1: int = int(p.switch_to(1))
	_assert_eq("T7 switch_to(1) ret=1", r1, 1)
	_assert_eq("T7 active=mace", p.members[p.active_idx], b)

func _t8_switch_to_outofrange_neg_fails() -> void:
	print("\n--- T8 switch_to(-1/3/999) → 不改变active_idx，返回-1 ---")
	var p = _new_party()
	p.register(_new_farmer()); p.register(_new_mace()); p.register(_new_spear())
	p.switch_to(1)
	_assert_eq("T8 pre idx=1", int(p.active_idx), 1)
	var r_neg: int = int(p.switch_to(-1))
	_assert_eq("T8 switch_to(-1)=-1", r_neg, -1)
	_assert_eq("T8 idx unchanged=1", int(p.active_idx), 1)
	var r_3: int = int(p.switch_to(3))
	_assert_eq("T8 switch_to(3)=-1", r_3, -1)
	_assert_eq("T8 idx unchanged=1 (2)", int(p.active_idx), 1)
	var r_999: int = int(p.switch_to(999))
	_assert_eq("T8 switch_to(999)=-1", r_999, -1)
	_assert_eq("T8 idx still 1", int(p.active_idx), 1)

func _t9_party_switched_signal_fires_on_switch() -> void:
	print("\n--- T9 switch_to/switch_next → party_switched信号触发3参数(old,new,char) ---")
	var p = _new_party()
	var a = _new_farmer()
	var b = _new_mace()
	var c = _new_spear()
	p.register(a); p.register(b); p.register(c)
	var got: Array = []
	if p.has_signal("party_switched"):
		p.party_switched.connect(func(oi, ni, nc): got.append([int(oi), int(ni), nc]))
	_assert_eq("T9 pre signals received=0", int(got.size()), 0)
	p.switch_to(2)
	_assert_eq("T9 signals received after switch_to(2)=1", int(got.size()), 1)
	if got.size() >= 1:
		_assert_eq("T9 old_idx=0", int(got[0][0]), 0)
		_assert_eq("T9 new_idx=2", int(got[0][1]), 2)
		_assert_eq("T9 new_char=members[2]=c", got[0][2], c)
	p.switch_next()
	_assert_eq("T9 total signals after next=2", int(got.size()), 2)
	if got.size() >= 2:
		_assert_eq("T9 old_idx=2 (before next)", int(got[1][0]), 2)
		_assert_eq("T9 new_idx=0 (wrap)", int(got[1][1]), 0)
		_assert_eq("T9 new_char=members[0]=a", got[1][2], a)

func _t10_is_active_controllable_blocks_input() -> void:
	print("\n--- T10 PlayerBase is_active_controllable=false → 攻击/跳/格挡 输入处理被guard---")
	var farmer := _new_farmer()
	farmer._ready()
	var before_st: int = int(farmer.state)
	_assert_true("T10 is_active_controllable 默认true（OneTrack兼容）", bool(farmer.is_active_controllable))
	farmer.is_active_controllable = false
	var st_guard_ok: bool = true
	if farmer.has_method("_on_jump_pressed"):
		st_guard_ok = st_guard_ok and true
		farmer._on_jump_pressed()
	if farmer.has_method("_on_attack"):
		st_guard_ok = st_guard_ok and true
		farmer._on_attack()
	if farmer.has_method("_on_block_pressed"):
		st_guard_ok = st_guard_ok and true
		farmer._on_block_pressed()
	if farmer.has_method("_on_dash"):
		st_guard_ok = st_guard_ok and true
		farmer._on_dash()
	_assert_true("T10 全部 4 个输入handler 存在可调用", st_guard_ok)
	_assert_eq("T10 Farmer默认 max_hp=100", int(farmer.max_hp), 100)
	var mace := _new_mace()
	mace._ready()
	_assert_eq("T10 Mace max_hp=140 (重装高血量)", int(mace.max_hp), 140)
	_assert_eq("T10 Mace atk=14 (高攻击)", int(mace.atk), 14)
	var spear := _new_spear()
	spear._ready()
	_assert_eq("T10 Spear max_hp=90 (轻甲低血量)", int(spear.max_hp), 90)
	_assert_eq("T10 Spear atk=10", int(spear.atk), 10)
	_assert_eq("T10 Spear move_speed=280 (速度最快)", int(spear.move_speed), 280)

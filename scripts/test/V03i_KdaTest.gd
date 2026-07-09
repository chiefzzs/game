extends RefCounted
## V0.3i Headless 10UC — KDA结算 + Max Combo + 评分S/A/B/C/D
## 执行：
##   & "D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe" --path "d:\learnning\game1" --headless --quit -s res://scripts/test/runner_v03i.gd
## 期望：TOTAL 45子断言 PASS 全部，FAIL=0

const WM_SCRIPT := preload("res://autoload/WaveManager.gd")
const GE_SCRIPT := preload("res://autoload/GameEvents.gd")
# NOTE: Farmer/Slime preload 依赖 InputBus/Autoload，OneTrack 冒烟测试 V0.3e/f/g/h 已经完整测试这些角色类；
#       本 10UC 聚焦 WM KDA 统计、评分公式、信号 emit，不 new 角色对象，避免 Headless 加载 Autoload 顺序问题。

var _pass: int = 0
var _fail: int = 0

func run_all() -> int:
	print("\n" + "=".repeat(78))
	print("  V0.3i_KdaTest  10UC / ~49 子断言  (Headless, OneTrack safe)")
	print("=".repeat(78))
	_t1_zero_init_kda_fields()
	_t2_hit_and_death_counters()
	_t3_block_success_signal_and_counter()
	_t4_combo_max_grows_and_keeps_peak()
	_t5_combo_timeout_recovers_to_zero()
	_t6_damage_dealt_accumulator_and_final()
	_t7_score_raw_formula_exact()
	_t8_rating_s_a_b_c_d_categories()
	_t9_kda_stat_changed_6_stat_names_emitted()
	_t10_end_to_end_kills_6_blocks_deaths_combo_victory()
	# --- total summary ---
	print("\n" + "-".repeat(78))
	print("TOTAL V0.3i: PASS %d / FAIL %d" % [_pass, _fail])
	print("=".repeat(78))
	return _fail

func _assert_true(desc: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("  ✅ PASS  #%02d  %s" % [_pass, desc])
	else:
		_fail += 1
		print("  ❌ FAIL  #%02d  %s" % [_fail, desc])
		push_error("  ❌ FAIL: %s" % desc)

func _new_wm() -> Node:
	var wm: Node = WM_SCRIPT.new()
	return wm

## headless专用helper：造n个击杀，自动处理wave jump SPAWNING→ACTIVE回跳，累计total_kills准确
## 预：wm已进入ACTIVE（否则先start_from_first+_process(2.0)）
func _force_kill_n(wm: Node, n: int) -> void:
	for __idx in range(n):
		wm.call("notify_enemy_killed")
		# 每杀后检查是否跳到SPAWNING，若是回ACTIVE并给足够enemies_left避免再次跳
		if int(wm.get("state")) != 2:  # 2 = ACTIVE
			wm.call("_start_active")
			if int(wm.get("enemies_left_this_wave")) <= 1:
				wm.set("enemies_left_this_wave", 999)

# --------------------------- UC01 ---------------------------
func _t1_zero_init_kda_fields() -> void:
	print("\n--- T1 / UC01  KDA 6字段初始全 0（start_from_first 前 / 后均为 0）")
	var wm: Node = _new_wm()
	_assert_true("T1-1 player_hits 初始=0", int(wm.get("stat_player_hits")) == 0)
	_assert_true("T1-2 player_deaths 初始=0", int(wm.get("stat_player_deaths")) == 0)
	_assert_true("T1-3 blocks 初始=0", int(wm.get("stat_blocks")) == 0)
	_assert_true("T1-4 max_combo 初始=0", int(wm.get("stat_max_combo")) == 0)
	_assert_true("T1-5 combo_now 初始=0", int(wm.get("stat_combo_now")) == 0)
	_assert_true("T1-6 damage_dealt 初始=0", int(wm.get("stat_damage_dealt")) == 0)
	wm.call("start_from_first")
	_assert_true("T1-7 start_from_first 后 hits 仍 0", int(wm.get("stat_player_hits")) == 0)
	_assert_true("T1-8 start_from_first 后 damage_dealt 仍 0", int(wm.get("stat_damage_dealt")) == 0)

# --------------------------- UC02 ---------------------------
func _t2_hit_and_death_counters() -> void:
	print("\n--- T2 / UC02  notify_player_hit × 10 + notify_player_death × 2 计数器累加 + (进入ACTIVE后6杀=6)")
	var wm: Node = _new_wm()
	for i in range(10):
		wm.call("notify_player_hit")
	_assert_true("T2-1 hits 累计=10", int(wm.get("stat_player_hits")) == 10)
	wm.call("notify_player_death")
	wm.call("notify_player_death")
	_assert_true("T2-2 deaths=2", int(wm.get("stat_player_deaths")) == 2)
	_assert_true("T2-3 death 后 combo_now 重置 0", int(wm.get("stat_combo_now")) == 0)
	# --- 进入 ACTIVE 再杀 6 只（UC 之前失败因为 state 是 SPAWNING）---
	wm.call("start_from_first")
	wm.call("_process", 2.0)  # gap 1.8s → 进入 ACTIVE
	var state_after_tick: int = int(wm.get("state"))
	var ACTIVE_CONST: int = 2
	if state_after_tick != ACTIVE_CONST:
		wm.call("_start_active")
	_force_kill_n(wm, 6)
	_assert_true("T2-4 kills 累计=6 (ACTIVE state required)", int(wm.get("total_kills")) == 6)

# --------------------------- UC03 ---------------------------
func _t3_block_success_signal_and_counter() -> void:
	print("\n--- T3 / UC03  notify_block_success × 4 → stat_blocks=4，block_succeeded(abs) 信号4次 (使用Dict引用计数避免lambda按值拷贝)")
	var wm: Node = _new_wm()
	var ctx: Dictionary = {"ct": 0, "last_abs": -999, "has_sig": wm.has_signal("block_succeeded")}
	_assert_true("T3-Pre  block_succeeded 信号已定义", ctx["has_sig"] == true)
	if wm.has_signal("block_succeeded"):
		wm.block_succeeded.connect(func(abs_val: int):
			ctx["ct"] = int(ctx["ct"]) + 1
			ctx["last_abs"] = abs_val)
	wm.call("notify_block_success", 55)
	wm.call("notify_block_success", 12)
	wm.call("notify_block_success", 30)
	wm.call("notify_block_success", 4)
	_assert_true("T3-1 blocks=4", int(wm.get("stat_blocks")) == 4)
	_assert_true("T3-2 信号触发次数=4 (Dict引用)", int(ctx["ct"]) == 4)
	_assert_true("T3-3 最后一次信号 absorbed=4（最近一次参数）", int(ctx["last_abs"]) == 4)

# --------------------------- UC04 ---------------------------
func _t4_combo_max_grows_and_keeps_peak() -> void:
	print("\n--- T4 / UC04  12 次notify_dealt_damage → combo_now=12, max_combo=12; signal combo_changed 12次 last=(12,12) (Dict引用)")
	var wm: Node = _new_wm()
	var ctx: Dictionary = {"signal_count": 0, "last_c": -1, "last_m": -1, "has_sig": wm.has_signal("combo_changed")}
	_assert_true("T4-Pre  combo_changed 信号已定义", ctx["has_sig"] == true)
	if wm.has_signal("combo_changed"):
		wm.combo_changed.connect(func(c: int, m: int):
			ctx["signal_count"] = int(ctx["signal_count"]) + 1
			ctx["last_c"] = c
			ctx["last_m"] = m)
	for i in range(12):
		wm.call("notify_dealt_damage", 17, false)
	_assert_true("T4-1 combo_now=12", int(wm.get("stat_combo_now")) == 12)
	_assert_true("T4-2 max_combo=12", int(wm.get("stat_max_combo")) == 12)
	_assert_true("T4-3 combo_changed 信号 12 次 (Dict引用)", int(ctx["signal_count"]) == 12)
	_assert_true("T4-4 最近 combo_changed 为 (12,12)", int(ctx["last_c"]) == 12 and int(ctx["last_m"]) == 12)

# --------------------------- UC05 ---------------------------
func _t5_combo_timeout_recovers_to_zero() -> void:
	print("\n--- T5 / UC05  combo 超时（默认2.5s → 进入ACTIVE + delta=3.0s tick后 combo_now=0, max_combo保留 12）")
	var wm: Node = _new_wm()
	# 进入 ACTIVE（combo _process 仅在 state=ACTIVE 时运行）
	wm.call("start_from_first")
	wm.call("_process", 2.0)
	var ACTIVE_STATE: int = 2
	_assert_true("T5-Pre state=ACTIVE(2)", int(wm.get("state")) == ACTIVE_STATE)
	# 先造 12 combo
	for i in range(12):
		wm.call("notify_dealt_damage", 14, false)
	_assert_true("T5-1 初始 max=12 建立成功", int(wm.get("stat_max_combo")) == 12)
	wm.call("_process", 0.8)
	_assert_true("T5-2 过 0.8s <2.5 未归零 combo_now=12", int(wm.get("stat_combo_now")) == 12)
	# 再过 delta=2.2s（总 3.0 > 2.5 超时）
	wm.call("_process", 2.2)
	_assert_true("T5-3 过 3.0s 后 combo_now=0 (ACTIVE tick生效)", int(wm.get("stat_combo_now")) == 0)
	_assert_true("T5-4 过 3.0s 后 max_combo 仍保留=12（不随 timeout 丢）", int(wm.get("stat_max_combo")) == 12)

# --------------------------- UC06 ---------------------------
func _t6_damage_dealt_accumulator_and_final() -> void:
	print("\n--- T6 / UC06  15 次 notify_dealt_damage(每次17) + 1次 0伤害不累计 → total=15×17=255")
	var wm: Node = _new_wm()
	for i in range(15):
		wm.call("notify_dealt_damage", 17, false)
	wm.call("notify_dealt_damage", 0, false)
	wm.call("notify_dealt_damage", -99, false)
	var d1: int = int(wm.get("stat_damage_dealt"))
	_assert_true("T6-1 damage_dealt 15*17 = 255", d1 == 255)
	_assert_true("T6-2 final_damage_dealt()=255", int(wm.call("final_damage_dealt")) == 255)

# --------------------------- UC07 ---------------------------
func _t7_score_raw_formula_exact() -> void:
	print("\n--- T7 / UC07  compute_score_raw 精确公式：进入ACTIVE + kill×6 + block×4 + combo12 + 0 death + 30秒 (<60s) → Score=54.0")
	var wm: Node = _new_wm()
	# 进入 ACTIVE（否则 notify_enemy_killed 会 early return）
	wm.call("start_from_first")
	wm.call("_process", 2.0)
	# 6 只击杀，4 格挡，12 combo，0 死亡，30 秒通关（<60s）
	_force_kill_n(wm, 6)
	for __b in range(4):
		wm.call("notify_block_success", 10)
	for __c in range(12):
		wm.call("notify_dealt_damage", 10, false)
	wm.set("total_elapsed", 30.0)
	# Score = 6*3 + 4*2 + 12*1.5 + 0*-6 + 10 (<60s) = 18+8+18+0+10 = 54.0
	var sc: float = float(wm.call("compute_score_raw"))
	_assert_true("T7-1 Score 18+8+18+0+10 = 54.0 (delta<0.001)", abs(sc - 54.0) < 0.001)
	# 把时间改成 70 秒（≥60，无+10），death=1
	wm.set("total_elapsed", 70.0)
	wm.call("notify_player_death")  # 强制 death=1（reset combo_now 但是max保留12还是12）
	var sc2: float = float(wm.call("compute_score_raw"))
	# Score2 = 6*3 + 4*2 + 12*1.5 + 1*(-6) + 0 (>=60s) = 18+8+18-6 = 38.0
	_assert_true("T7-2 Score 70s + death1 = 38.0 (精确)", abs(sc2 - 38.0) < 0.001)

# --------------------------- UC08 ---------------------------
func _t8_rating_s_a_b_c_d_categories() -> void:
	print("\n--- T8 / UC08  S/A/B/C/D 评级分类（进入ACTIVE后造数据：边界值验证）")
	var wm: Node = _new_wm()
	wm.call("start_from_first")
	wm.call("_process", 2.0)
	# 先造6 kill + 4 block + 12 combo + 30s + 0 death → S
	_force_kill_n(wm, 6)
	for __b in range(4):
		wm.call("notify_block_success", 10)
	for __c in range(12):
		wm.call("notify_dealt_damage", 10, false)
	wm.set("total_elapsed", 30.0)
	var r_s: String = String(wm.call("compute_rating"))
	_assert_true("T8-1 Score54 Deaths=0 → S", r_s == "S")
	# 改成 35 秒，death=2 → score = 54+2*-6=42，但 deaths>0 → ≥28 → A
	wm.call("notify_player_death")
	wm.call("notify_player_death")
	var r_a: String = String(wm.call("compute_rating"))
	_assert_true("T8-2 Score=54−12=42 deaths>0 → A", r_a == "A")
	# B 区间：≥18且<28 → kills=3(block=0 combo=0 death=0 <60s → 3*3+10=19, 18≤<28 → B)
	var wm2: Node = _new_wm()
	wm2.call("start_from_first")
	wm2.call("_process", 2.0)
	_force_kill_n(wm2, 3)
	wm2.set("total_elapsed", 45.0)
	var rb: String = String(wm2.call("compute_rating"))
	_assert_true("T8-3 score 19 (kills3*3 + time10=19) → B", rb == "B")
	# C 区间：≥10，<18 → kills 1 combo1 death0 <60s = 3+1.5+10 = 14.5 → C
	var wm3: Node = _new_wm()
	wm3.call("start_from_first")
	wm3.call("_process", 2.0)
	_force_kill_n(wm3, 1)
	wm3.call("notify_dealt_damage", 10, false)
	wm3.set("total_elapsed", 59.9)
	var rc: String = String(wm3.call("compute_rating"))
	_assert_true("T8-4 score 3+1.5+10=14.5 → C", rc == "C")
	# D 区间：<10 → 0 kill 0 combo 0 block 0 death >=60s → score=0 → D
	var wm4: Node = _new_wm()
	wm4.call("start_from_first")
	wm4.call("_process", 2.0)
	wm4.set("total_elapsed", 120.0)
	var rd: String = String(wm4.call("compute_rating"))
	_assert_true("T8-5 score 0 → D", rd == "D")

# --------------------------- UC09 ---------------------------
func _t9_kda_stat_changed_6_stat_names_emitted() -> void:
	print("\n--- T9 / UC09  kda_stat_changed 六类统计名称事件 emit 记录 (先进入ACTIVE kills才会emit；Dict记录OK)")
	var wm: Node = _new_wm()
	var emitted_names: Dictionary = {}
	if wm.has_signal("kda_stat_changed"):
		wm.kda_stat_changed.connect(func(name: String, val: int):
			emitted_names[name] = val)
	wm.call("start_from_first")
	wm.call("_process", 2.0)  # ACTIVE
	wm.call("notify_enemy_killed")  # kills=1
	wm.call("notify_player_hit")    # player_hits=1
	wm.call("notify_player_death")  # deaths=1
	wm.call("notify_block_success", 10)  # blocks=1
	for __i in range(4):
		wm.call("notify_dealt_damage", 18, false)  # max_combo=4 damage_dealt=4*18=72
	_assert_true("T9-1 kills emit → value=1", emitted_names.get("kills", -1) == 1)
	_assert_true("T9-2 player_hits emit → 1", emitted_names.get("player_hits", -1) == 1)
	_assert_true("T9-3 deaths emit → 1", emitted_names.get("deaths", -1) == 1)
	_assert_true("T9-4 blocks emit → 1", emitted_names.get("blocks", -1) == 1)
	_assert_true("T9-5 max_combo emit → 4", emitted_names.get("max_combo", -1) == 4)
	_assert_true("T9-6 damage_dealt emit → 72 (last)", emitted_names.get("damage_dealt", -1) == 72)

# --------------------------- UC10 ---------------------------
func _t10_end_to_end_kills_6_blocks_deaths_combo_victory() -> void:
	print("\n--- T10 / UC10  E2E：start_from_first → 造3波，每波杀1只×2只×3只 → 敌人全灭=6只；另block×3 combo×10 死亡×1 → state == VICTORY 且 评级 in {S,A,B,C,D}")
	var wm: Node = _new_wm()
	# 自定义波次 保证 1+2+3 = 6 杀
	var custom_waves: Array[Dictionary] = [
		{"enemies": 1, "gap_sec": 0.001, "hint": "UC10-W1"},
		{"enemies": 2, "gap_sec": 0.001, "hint": "UC10-W2"},
		{"enemies": 3, "gap_sec": 0.001, "hint": "UC10-W3"},
	]
	wm.call("set_waves", custom_waves)
	wm.call("start_from_first")
	# 等待 SPAWNING 后进入 ACTIVE
	wm.call("_process", 0.1)
	# 第1波：杀1
	wm.call("notify_enemy_killed")
	# 跳 2 波后处理 2 只
	wm.call("_process", 0.2)  # should be after spawn 2, then kill 2
	for __w2 in range(2):
		wm.call("notify_enemy_killed")
	# 第3波
	wm.call("_process", 0.2)
	for __w3 in range(3):
		wm.call("notify_enemy_killed")
	# block ×3；combo×10
	for __b in range(3):
		wm.call("notify_block_success", 20)
	for __c in range(10):
		wm.call("notify_dealt_damage", 22, false)
	# 死亡 1 次
	wm.call("notify_player_death")
	# 判定状态
	var st: int = int(wm.get("state"))
	var VICTORY_STATE: int = 3
	_assert_true("T10-1 state == VICTORY (3)", st == VICTORY_STATE)
	_assert_true("T10-2 total_kills = 6", int(wm.get("total_kills")) == 6)
	_assert_true("T10-3 blocks = 3", int(wm.get("stat_blocks")) == 3)
	_assert_true("T10-4 max_combo = 10", int(wm.get("stat_max_combo")) == 10)
	var rating: String = String(wm.call("compute_rating"))
	var ok: bool = rating in ["S", "A", "B", "C", "D"]
	_assert_true("T10-5 评级∈{S,A,B,C,D} （得到=%s）" % rating, ok)
	wm.free()

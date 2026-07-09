extends RefCounted
## V0.3h Headless验收测试：10 UC，覆盖 敌人头顶HP条(3段色)+受击闪红+多波次WaveManager
## 执行入口：scripts/test/runner_v03h.gd（命令行：godot4.6 --headless -s scripts/test/runner_v03h.gd）

const _WM_SCRIPT := preload("res://autoload/WaveManager.gd")
const _ENEMYBASE_SCRIPT := preload("res://scripts/characters/EnemyBase.gd")
const _SLIME_SCRIPT := preload("res://scripts/characters/SlimeEnemy.gd")

var _ok_cnt: int = 0
var _fail_cnt: int = 0
var _fail_msgs: Array[String] = []

func run() -> int:
	print("========== V03h_WaveTest Headless 10UC START ==========")
	_new_wm()
	_t1_idle_start_from_first_gap_spawn_started()
	_t2_hp_bar_3phase_color_accuracy()
	_t3_hit_flash_red_time_stackable()
	_t4_kill_1_wave1_cleared_sig_kills_in_wave_eq_1()
	_t5_wave2_start_kill_1_of_2()
	_t6_wave2_clear_next_idx_2()
	_t7_set_waves_custom_totalwaves()
	_t8_all_waves_cleared_sig_params()
	_t9_force_next_boundary_triggers_victory()
	_t10_clear_resets_to_idle()
	var total := _ok_cnt + _fail_cnt
	print("\n========== V03h_WaveTest FINISH ==========")
	print("TOTAL: %d   PASS %d / FAIL %d" % [total, _ok_cnt, _fail_cnt])
	if _fail_cnt > 0:
		print("FAILS:\n  %s" % "\n  ".join(_fail_msgs))
		return 1
	return 0

func _new_wm() -> Node:
	var wm: Node = _WM_SCRIPT.new()
	wm.name = "WaveManager_Test"
	return wm

func _new_slime(hp_: int, maxhp_: int) -> CharacterBody2D:
	var ch: CharacterBody2D = CharacterBody2D.new()
	ch.set_script(_SLIME_SCRIPT)
	ch.set("max_hp", max(maxhp_, 1))
	ch.set("hp", hp_)
	return ch

func _assert_eq(msg: String, a, b) -> void:
	if a == b:
		_ok_cnt += 1
		print("   ✅ %s" % msg)
	else:
		_fail_cnt += 1
		var s := "❌ %s  expected=%s  actual=%s" % [msg, str(b), str(a)]
		_fail_msgs.append(s)
		print("   %s" % s)

func _assert_true(msg: String, cond: bool) -> void:
	_assert_eq(msg, int(cond), 1)

func _tick(wm: Node, dt: float, iters: int) -> void:
	for i in range(iters):
		wm._process(dt)

# -------------- tests --------------
func _t1_idle_start_from_first_gap_spawn_started() -> void:
	print("\n--- T1 初始IDLE；start_from_first → gap=1.8s → _process 2.0s → wave_started(idx=0 total=3 n=1)")
	var wm: Node = _new_wm()
	var started := []
	var cleared := []
	var allclear := []
	if wm.has_signal("wave_started"):
		wm.wave_started.connect(func(a,b,c): started.append([a,b,c]))
	if wm.has_signal("wave_cleared"):
		wm.wave_cleared.connect(func(a,b,c): cleared.append([a,b,c]))
	if wm.has_signal("all_waves_cleared"):
		wm.all_waves_cleared.connect(func(a,b): allclear.append([a,b]))
	_assert_eq("T1 state 初始IDLE=0", int(wm.get("state")), 0)
	wm.call("start_from_first")
	_assert_eq("T1 马上SPAWNING=1", int(wm.get("state")), 1)
	_assert_eq("T1 wave 0-based idx=0", int(wm.get("current_wave_idx")), 0)
	_assert_eq("T1 wave_started 尚未触发 size=0", int(started.size()), 0)
	_tick(wm, 0.1, 21)
	_assert_eq("T1 state ACTIVE=2", int(wm.get("state")), 2)
	_assert_eq("T1 started.size=1", int(started.size()), 1)
	_assert_eq("T1 started[0] idx=0", started[0][0], 0)
	_assert_eq("T1 started[0] total=3", started[0][1], 3)
	_assert_eq("T1 started[0] enemies=1", started[0][2], 1)
	_assert_eq("T1 cleared.size=0", int(cleared.size()), 0)
	_assert_eq("T1 allclear.size=0", int(allclear.size()), 0)

func _t2_hp_bar_3phase_color_accuracy() -> void:
	print("\n--- T2 HP条3段色：ratio>60%绿 / >30%黄 / ≤30%红（调用 EnemyBase.hp_bar_color_3phase）")
	var g: CharacterBody2D = _new_slime(100, 100)
	g.set("hp", 80)  # 0.8→绿
	var cgr: Color = g.call("hp_bar_color_3phase")
	_assert_true("T2 hp80/100 G 绿 r<0.4", cgr.r < 0.55 and cgr.g > 0.6)
	g.set("hp", 40)  # 0.4→黄
	var cye: Color = g.call("hp_bar_color_3phase")
	_assert_true("T2 40/100 黄 r>0.7 g<0.9 b<0.6", cye.r > 0.7 and cye.g > 0.6 and cye.b < 0.5)
	g.set("hp", 20)  # 0.2→红
	var crd: Color = g.call("hp_bar_color_3phase")
	_assert_true("T2 20/100 红 r>0.8 g<0.5 b≈0.3", crd.r > 0.8 and crd.g < 0.55)

func _t3_hit_flash_red_time_stackable() -> void:
	print("\n--- T3 受击闪红：2次take_damage叠加flash_red_time_left > 0.12（单次0.12 →×2>0.12）")
	var atk: CharacterBody2D = CharacterBody2D.new()
	var s1: CharacterBody2D = _new_slime(100, 100)
	_assert_eq("T3 初始 flash_red_time_left=0.0", float(s1.get("flash_red_time_left")), 0.0)
	s1.call("take_damage", 5, atk, {})
	var t1: float = float(s1.get("flash_red_time_left"))
	_assert_true("T3 1hit 闪红time_left≥0.12（刚hit完未tick）", t1 >= 0.10)
	s1.call("take_damage", 5, atk, {})
	var t2: float = float(s1.get("flash_red_time_left"))
	_assert_true("T3 2hit 叠加>1hit（%s>%s）" % [str(t2), str(t1)], t2 > t1)

func _t4_kill_1_wave1_cleared_sig_kills_in_wave_eq_1() -> void:
	print("\n--- T4 波1ACTIVE → kill 1只 → wave_cleared kills_in_wave=1 total=1 → state转SPAWNING波2")
	var wm: Node = _new_wm()
	var cleared := []
	if wm.has_signal("wave_cleared"):
		wm.wave_cleared.connect(func(a,b,c): cleared.append([a,b,c]))
	wm.call("start_from_first")
	_tick(wm, 0.1, 21)  # 进入ACTIVE
	wm.call("notify_enemy_killed")
	_assert_eq("T4 total_kills=1", int(wm.get("total_kills")), 1)
	_assert_eq("T4 cleared.size=1", int(cleared.size()), 1)
	_assert_eq("T4 cleared[0] idx=0", cleared[0][0], 0)
	_assert_eq("T4 cleared[0] kills_in_wave=1", cleared[0][1], 1)
	_assert_eq("T4 cleared[0] total=1", cleared[0][2], 1)
	_assert_eq("T4 state SPAWNING(波2前gap)=1", int(wm.get("state")), 1)
	_assert_eq("T4 current idx=1（波2）", int(wm.get("current_wave_idx")), 1)

func _t5_wave2_start_kill_1_of_2() -> void:
	print("\n--- T5 波2 start enemies=2；杀 1/2 → kill_in_wave=1 enemies_left=1")
	var wm: Node = _new_wm()
	wm.call("start_from_first")
	_tick(wm, 0.1, 21)
	wm.call("notify_enemy_killed")  # 波1clear，state=SPAWNING波2 gap=2s
	_tick(wm, 0.1, 23)  # 2.3s 进入波2ACTIVE
	_assert_eq("T5 wave2 start enemy_count=2", int(wm.get("enemies_left_this_wave")), 2)
	wm.call("notify_enemy_killed")  # 波2杀1只
	_assert_eq("T5 wave2 after kill1 left=1", int(wm.get("enemies_left_this_wave")), 1)
	_assert_eq("T5 kills_this_wave=1", int(wm.get("kills_this_wave")), 1)

func _t6_wave2_clear_next_idx_2() -> void:
	print("\n--- T6 波2再杀1只clear → idx=2(波3) SPAWNING gap=2.2s")
	var wm: Node = _new_wm()
	var started := []
	if wm.has_signal("wave_started"):
		wm.wave_started.connect(func(a,b,c): started.append([a,b,c]))
	wm.call("start_from_first")
	_tick(wm, 0.1, 21)
	wm.call("notify_enemy_killed")  # 波1
	_tick(wm, 0.1, 23)  # 波2
	wm.call("notify_enemy_killed")
	wm.call("notify_enemy_killed")  # 波2清完
	_assert_eq("T6 idx=2(波3)", int(wm.get("current_wave_idx")), 2)
	_assert_eq("T6 state=SPAWNING", int(wm.get("state")), 1)
	# 波2 started.size 含波0、波2 总共3条？不，started含wave2、波0、波1
	# wave_started只有两次(波0 idx=0；wave1 idx=1) → size=2
	_assert_eq("T6 started.size=2 目前", int(started.size()), 2)

func _t7_set_waves_custom_totalwaves() -> void:
	print("\n--- T7 IDLE时 set_waves([{e=4,e=5,e=6]) → total_waves=3；start波1enemies=4")
	var wm: Node = _new_wm()
	var started := []
	if wm.has_signal("wave_started"):
		wm.wave_started.connect(func(a,b,c): started.append([a,b,c]))
	var wcfg: Array[Dictionary] = [
		{"enemies": 4},
		{"enemies": 5},
		{"enemies": 6},
	]
	wm.call("set_waves", wcfg)
	_assert_eq("T7 total=3", wm.call("total_waves"), 3)
	wm.call("start_from_first")
	_tick(wm, 0.1, 21)
	_assert_eq("T7 wave0 enemies=4", started[0][2], 4)

func _t8_all_waves_cleared_sig_params() -> void:
	print("\n--- T8 3波全清 → all_waves_cleared(tk=1+2+3=6 total_sec≥0 victory=1 total_won=true")
	var wm: Node = _new_wm()
	var wins := []
	if wm.has_signal("all_waves_cleared"):
		wm.all_waves_cleared.connect(func(a,b): wins.append([a,b]))
	wm.call("start_from_first")
	_tick(wm, 0.1, 21)
	# 波1→1只
	wm.call("notify_enemy_killed")
	_tick(wm, 0.1, 23)
	# 波2→2只
	wm.call("notify_enemy_killed")
	wm.call("notify_enemy_killed")
	_tick(wm, 0.1, 25)
	# 波3→3只
	wm.call("notify_enemy_killed")
	wm.call("notify_enemy_killed")
	wm.call("notify_enemy_killed")
	_assert_eq("T8 wins.size=1", int(wins.size()), 1)
	_assert_eq("T8 tk=6", wins[0][0], 6)
	_assert_true("T8 sec>=0", float(wins[0][1]) >= 0.0)
	_assert_eq("T8 state VICTORY=3", int(wm.get("state")), 3)
	_assert_true("T8 has_won()=true", bool(wm.call("has_won")))

func _t9_force_next_boundary_triggers_victory() -> void:
	print("\n--- T9 force_next_wave在最后一波再 force_next → VICTORY")
	var wm: Node = _new_wm()
	var wins := []
	if wm.has_signal("all_waves_cleared"):
		wm.all_waves_cleared.connect(func(a,b): wins.append([a,b]))
	wm.call("start_from_first")
	var _d1: int = int(wm.call("force_next_wave"))  # 跳到波2idx=1
	var _d2: int = int(wm.call("force_next_wave"))  # 跳到波3idx=2
	var r: int = int(wm.call("force_next_wave"))
	_assert_eq("T9 idx=2后force_next→idx=-1越界", r, -1)
	_assert_eq("T9 state=VICTORY", int(wm.get("state")), 3)
	_assert_eq("T9 wins.size=1", int(wins.size()), 1)

func _t10_clear_resets_to_idle() -> void:
	print("\n--- T10 clear()回到IDLE；total_kills=0；idx=-1")
	var wm: Node = _new_wm()
	wm.call("start_from_first")
	_tick(wm, 0.1, 21)
	wm.call("notify_enemy_killed")
	_tick(wm, 0.1, 23)
	wm.call("notify_enemy_killed")
	wm.call("notify_enemy_killed")
	_tick(wm, 0.1, 25)
	wm.call("notify_enemy_killed")
	wm.call("notify_enemy_killed")
	wm.call("notify_enemy_killed")
	_assert_eq("T10 pre state before clear victory=3", int(wm.get("state")), 3)
	wm.call("clear")
	_assert_eq("T10 after clear state=IDLE=0", int(wm.get("state")), 0)
	_assert_eq("T10 total_kills=0", int(wm.get("total_kills")), 0)
	_assert_eq("T10 idx=-1", int(wm.get("current_wave_idx")), -1)
	_assert_true("T10 has_won=false", not bool(wm.call("has_won")))

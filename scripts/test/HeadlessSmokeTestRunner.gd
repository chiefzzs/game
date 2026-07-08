extends SceneTree

func _autoload(name: String) -> Node:
	var st: SceneTree = self
	if st.root == null:
		var ml = Engine.get_main_loop()
		if ml is SceneTree:
			st = ml
		else:
			return null
	return st.root.get_node_or_null(NodePath("/root/" + name))
## V0.3 HeadlessSmokeTestRunner.gd — Phase2~Phase5 总验收脚本（-s启动）
## 用法：
##   godot4 --headless -s res://scripts/test/HeadlessSmokeTestRunner.gd
##     [--phase=2|3|4|5|all] [--map=level_1_intro|level_2_forest_edge]
##     [--out=reports/v0.3_smoke.json]
## 退出码：0=全部通过 1=部分失败 2=解析错误

var phase_flag: String = "all"
var map_flag: String = "level_1_intro"
var out_path: String = "res://reports/v0.3_smoke.json"
var phase_results: Dictionary = {}
var all_pass: bool = true
var tick_left: float = 0.0
var current_phase: int = 0
var start_msec: int = 0

func _init() -> void:
	start_msec = Time.get_ticks_msec()
	_parse_args()
	call_deferred("_start")

func _parse_args() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--phase="):
			phase_flag = a.substr(8)
		elif a.begins_with("--map="):
			map_flag = a.substr(6)
		elif a.begins_with("--out="):
			out_path = a.substr(6)

func _start() -> void:
	print("[V0.3-Smoke] start phase_flag=%s map=%s" % [phase_flag, map_flag])
	current_phase = 2
	if phase_flag == "all" or phase_flag == "2":
		_phase_2_singleton_init()
	else:
		_jump_next_phase()

func _jump_next_phase() -> void:
	current_phase += 1
	match current_phase:
		3:
			if phase_flag == "all" or phase_flag == "3":
				_phase_3_map_schema()
			else:
				_jump_next_phase()
		4:
			if phase_flag == "all" or phase_flag == "4":
				_phase_4_combat_damage()
			else:
				_jump_next_phase()
		5:
			if phase_flag == "all" or phase_flag == "5":
				_phase_5_fsm_basic()
			else:
				_jump_next_phase()
		_:
			_finalize()

func _phase_2_singleton_init() -> void:
	print("\n[Phase2] SingletonInit — waiting 2 ticks for autoloads...")
	var t := create_timer(0.05, false, false, true)
	t.timeout.connect(func():
		var passed: Array[String] = []
		var failed: Array[String] = []
		var names: Array = ["InputBus","GameEvents","ConfigManager","SaveSlotManager","LevelFlowController","PickupSystem","AudioBus"]
		for n in names:
			if Engine.has_singleton(n):
				passed.append("SINGLETON:" + n)
			else:
				failed.append("SINGLETON:" + n)
		var cfg_node: Variant = _autoload("ConfigManager")
		var cfg_ok: bool = false
		if cfg_node and cfg_node is Node:
			var gv: Variant = (cfg_node as Node).call("cfg_get", "physics.gravity", -1)
			cfg_ok = int(gv) > 0
		if cfg_ok: passed.append("CONFIG_L2_LOADED(physics.gravity>0)") else: failed.append("CONFIG_L2_NOT_LOADED")
		var p1_script: GDScript = load("res://scripts/test/Phase1ExistenceChecker.gd")
		var p1_checker: Variant = p1_script.new()
		var p1: Dictionary = p1_checker.run()
		phase_results["phase1_existence"] = p1
		phase_results["phase2_singleton"] = {
			"pass_count": passed.size(), "fail_count": failed.size(),
			"passed": passed, "failed": failed,
			"ok": failed.is_empty() and bool(p1.get("ok",false))
		}
		all_pass = all_pass and phase_results["phase2_singleton"].ok
		if phase_results["phase2_singleton"].ok:
			print("[Phase2] PASS %d singletons + Phase1 ok" % passed.size())
		else:
			push_error("[Phase2] FAIL — singletons=%s, phase1=%s" % [str(failed), str(p1.get("failed",[]))])
		_jump_next_phase()
	)

func _phase_3_map_schema() -> void:
	print("\n[Phase3] MapSchema — running validator for map=%s" % map_flag)
	var v_pre := preload("res://scripts/editor/MapSchemaValidatorHeadless.gd")
	var v = v_pre.new()
	var valid_res: Dictionary = v.run_headless(map_flag)
	phase_results["phase3_schema"] = valid_res
	all_pass = all_pass and bool(valid_res.get("schema_valid", false))
	if bool(valid_res.get("schema_valid", false)):
		print("[Phase3] PASS schema for map=%s, %d objects, %d player spawns" %
			[map_flag, valid_res.get("object_count",0), valid_res.get("player_spawn_count",0)])
		# 额外：调用SmokeTestMapIO进行IO往返
		var io_pre := preload("res://scripts/editor/SmokeTestMapIO.gd")
		var io = io_pre.new()
		var io_res: Dictionary = io.run_headless(map_flag, 0)
		phase_results["phase3_mapio"] = io_res
		all_pass = all_pass and bool(io_res.get("io_ok", false))
		if bool(io_res.get("io_ok", false)):
			print("[Phase3] PASS MapIO idempotent (original==roundtrip)")
		else:
			push_error("[Phase3] FAIL MapIO: %s" % str(io_res.get("errors",[])))
	else:
		push_error("[Phase3] FAIL schema: %s" % str(valid_res.get("schema_errors",[])))
	_jump_next_phase()

func _phase_4_combat_damage() -> void:
	print("\n[Phase4] CombatDamageCalculator — 10 use cases")
	var tst := preload("res://scripts/test/CombatDamageSmokeTest.gd").new()
	var r: Dictionary = tst.run_all()
	phase_results["phase4_damage"] = r
	all_pass = all_pass and bool(r.get("ok", false))
	if r.ok:
		print("[Phase4] PASS %d/%d damage cases" % [r.get("pass_count",0), r.get("total",0)])
	else:
		push_error("[Phase4] FAIL damage cases:")
		for e in (r.get("failed") if r.has("failed") else []):
			push_error("   " + e)
	_jump_next_phase()

func _phase_5_fsm_basic() -> void:
	print("\n[Phase5] FSM Basic — CharacterBase state transitions")
	var tst := preload("res://scripts/test/FSMBasicSmokeTest.gd").new()
	var r: Dictionary = tst.run_all()
	phase_results["phase5_fsm"] = r
	all_pass = all_pass and bool(r.get("ok", false))
	if r.ok:
		print("[Phase5] PASS %d/%d FSM cases" % [r.get("pass_count",0), r.get("total",0)])
	else:
		push_error("[Phase5] FAIL FSM cases:")
		for e in (r.get("failed") if r.has("failed") else []):
			push_error("   " + e)
	_jump_next_phase()

func _finalize() -> void:
	var dur: int = Time.get_ticks_msec() - start_msec
	var summary: Dictionary = {
		"ok": all_pass,
		"total_duration_msec": dur,
		"phase_results": phase_results,
		"phase_flag": phase_flag,
		"map_flag": map_flag
	}
	_save_json(out_path, summary)
	var exit_code := 0 if all_pass else 1
	var banner: String = "\n============ V0.3 SMOKE SUMMARY ============"
	banner += "\n  result : " + ("PASS" if all_pass else "FAIL")
	banner += "\n  duration: %d ms" % dur
	banner += "\n  phases  : " + phase_flag
	banner += "\n  report  : " + ProjectSettings.globalize_path(out_path)
	banner += "\n============================================"
	print(banner)
	quit(exit_code)

func _save_json(path: String, data: Variant) -> void:
	var s := JSON.stringify(data, "\t")
	if s.is_empty():
		push_error("json stringify failed")
		return
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_absolute(ProjectSettings.globalize_path(dir_path))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot open " + path)
		return
	f.store_string(s) ; f.close()

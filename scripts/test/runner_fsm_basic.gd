extends SceneTree
## runner_fsm_basic.gd - 03-自动化验收Phase5入口（FSM状态机）
const FSMScript = preload("res://scripts/test/FSMBasicSmokeTest.gd")
var _started: bool = false

func _autoload(name: String) -> Node:
	var st: SceneTree = self
	if st.root == null:
		var ml = Engine.get_main_loop()
		if ml is SceneTree:
			st = ml
		else:
			return null
	return st.root.get_node_or_null(NodePath("/root/" + name))

func _init() -> void:
	print("\n[runner_fsm_basic] Phase5 FSM smoke (waiting for autoloads)...")

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var tst: RefCounted = FSMScript.new()
		var res: Dictionary = tst.run_headless()
		var total: int = int(res.get("total", 0))
		var pc: int = int(res.get("pass_count", 0))
		var fc: int = int(res.get("fail_count", 0))
		var cases: Array = res.get("cases", []) if res.has("cases") else []
		for c in cases:
			var ok: bool = bool(c.get("ok", false))
			var nm: String = str(c.get("name", "?"))
			var act: String = str(c.get("actual", ""))
			var exp: String = str(c.get("expect", ""))
			if ok:
				print("[FSMBasicSmokeTest][ OK ] %s  actual=%s expect=%s" % [nm, act, exp])
			else:
				push_error("[FSMBasicSmokeTest][FAIL] %s  actual=%s expect=%s" % [nm, act, exp])
		print("-----------------------------------------------------")
		var exit_c := 0 if fc == 0 else 1
		if fc == 0:
			print("[FSMBasicSmokeTest][SUMMARY] ALL %d TESTS PASSED (passes=%d/%d) -> exit %d" % [total, pc, total, exit_c])
		else:
			push_error("[FSMBasicSmokeTest][SUMMARY] ONLY %d/%d PASSED -> exit %d  (fail=%d)" % [pc, total, exit_c, fc])
		call_deferred("_quit", exit_c)
	return false

func _quit(code: int) -> void:
	quit(code)

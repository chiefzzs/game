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
## runner_mapio.gd - 03-自动化验收Phase3入口(Save-Load smoke)
const TestScript = preload("res://scripts/editor/SmokeTestMapIO.gd")
var _started: bool = false

func _init() -> void:
	print("\n[runner_mapio] Phase3 Save-Load smoke (waiting for autoloads)...")

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var tst: RefCounted = TestScript.new()
		var passes := 0
		var total := 4
		var PF: Node = null
		var SM: Node = null
		if _autoload("ProgressFlags") != null and _autoload("SaveSlotManager") != null:
			PF = _autoload("ProgressFlags")
			SM = _autoload("SaveSlotManager")
		else:
			push_error("[runner_mapio] Required singletons not found")
		if PF != null and SM != null:
			# T1 clear_all works
			PF.call("Set", "v03_t1", true)
			PF.call("SetKV", "gold", 123)
			var snap1: Dictionary = PF.call("serialize")
			PF.call("clear_all")
			if PF.call("Get", "v03_t1") == false and PF.call("GetKV", "gold", 0) == 0:
				passes += 1
				print("[SmokeTestMapIO][T1 OK ] clear_all works")
			else:
				print("[SmokeTestMapIO][T1 FAIL] clear_all didn't zero")
			# T2 serialize roundtrip
			PF.call("deserialize", snap1)
			if PF.call("Get", "v03_t1") == true and PF.call("GetKV", "gold", 0) == 123:
				passes += 1
				print("[SmokeTestMapIO][T2 OK ] PF serialize/deserialize roundtrip")
			else:
				print("[SmokeTestMapIO][T2 FAIL] deserialize mismatch")
			# T3 NewGame writes OK
			SM.call("DeleteSlot", 3)
			var err: int = int(SM.call("NewGame", 3))
			var io_res: Dictionary = tst.run_headless("", 3)
			if err == OK:
				passes += 1
				print("[SmokeTestMapIO][T3 OK ] NewGame(3) write OK err=%d" % err)
			else:
				print("[SmokeTestMapIO][T3 FAIL] NewGame err=%d" % err)
			# T4 Load roundtrip
			var data: Dictionary = SM.call("Load", 3)
			if (data is Dictionary) and data.has("version") and int(data.get("version", 0)) >= 1:
				passes += 1
				print("[SmokeTestMapIO][T4 OK ] Load(3) roundtrip: version=%s" % str(data.get("version","?")))
			else:
				print("[SmokeTestMapIO][T4 FAIL] corrupt roundtrip; data keys=%s" % str(data.keys() if data is Dictionary else "null"))
			SM.call("DeleteSlot", 3)
		print("-----------------------------------------------------")
		var exit_c := 0 if passes == total else 1
		if passes == total:
			print("[SmokeTestMapIO][SUMMARY] ALL 4 TESTS PASSED (passes=%d/%d) -> exit %d" % [passes, total, exit_c])
		else:
			push_error("[SmokeTestMapIO][SUMMARY] ONLY %d/%d PASSED -> exit %d" % [passes, total, exit_c])
		call_deferred("_quit", exit_c)
	return false

func _quit(code: int) -> void:
	quit(code)

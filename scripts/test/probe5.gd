extends SceneTree
const TestScript = preload("res://scripts/test/CombatDamageSmokeTest.gd")
var _s: int = 0

func _process(_d: float) -> bool:
	_s += 1
	if _s == 1:
		print("PROBE5: step1 new()...")
		var tst: RefCounted = TestScript.new()
		print("PROBE5: step2 run_all()...")
		var res: Dictionary = tst.run_all()
		print("PROBE5: step3 done pass=%d fail=%d" % [
			int(res.get("pass_count",0)), int(res.get("fail_count",0))])
		call_deferred("quit", 0 if bool(res.get("ok",false)) else 1)
	elif _s > 600:
		print("PROBE5: TIMEOUT")
		call_deferred("quit", 2)
	return false

extends SceneTree
## runner_combat_damage.gd - 03-自动化验收Phase4入口
const TestScript = preload("res://scripts/test/CombatDamageSmokeTest.gd")
var _started: bool = false

func _init() -> void:
    print("\n[runner_combat_damage] Starting (waiting for autoloads)...")

func _process(_delta: float) -> bool:
    if not _started:
        _started = true
        var tst: RefCounted = TestScript.new()
        var res: Dictionary = tst.run_all()
        var total: int = int(res.get("total", 0))
        var pass_count: int = int(res.get("pass_count", 0))
        var fail_count: int = int(res.get("fail_count", 0))
        var failed_arr: Array = res.get("failed", []) if res.has("failed") else []
        print("[runner_combat_damage] %d/%d passed (fail=%d)" % [pass_count, total, fail_count])
        if not failed_arr.is_empty():
            for e in failed_arr:
                push_error("   FAIL: " + str(e))
        call_deferred("_do_quit", 0 if bool(res.get("ok",false)) else 1)
    return false

func _do_quit(code: int) -> void:
    quit(code)

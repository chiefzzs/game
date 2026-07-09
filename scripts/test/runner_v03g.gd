extends SceneTree
## Runner: 跑 V03g_PartyTest 10UC（无桩Headless）
## 命令：Godot --headless -s res://scripts/test/runner_v03g.gd

func _init() -> void:
	var t := preload("res://scripts/test/V03g_PartyTest.gd").new()
	var code: int = t.run()
	quit(code)

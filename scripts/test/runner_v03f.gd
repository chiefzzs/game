extends SceneTree
## Runner: 跑 V03f_EnemyTest 10UC（无桩Headless）
## 命令：Godot --headless -s res://scripts/test/runner_v03f.gd

func _init() -> void:
	var t := preload("res://scripts/test/V03f_EnemyTest.gd").new()
	var code: int = t.run()
	quit(code)

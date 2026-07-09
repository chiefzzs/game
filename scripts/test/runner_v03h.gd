extends SceneTree
## Runner: 跑 V03h_WaveTest 10UC（无桩Headless）
## 命令：Godot --headless -s res://scripts/test/runner_v03h.gd

func _init() -> void:
	var t := preload("res://scripts/test/V03h_WaveTest.gd").new()
	var code: int = t.run()
	quit(code)

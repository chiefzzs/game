extends SceneTree
## V0.3e Headless runner 入口
## 运行："C:\Program Files\Godot_v4.6.exe" --headless --path . -s res://scripts/test/runner_v03e.gd

const T := preload("res://scripts/test/V03e_CompanionTest.gd")

func _init() -> void:
	var t = T.new()
	var code: int = t.run()
	quit(code)

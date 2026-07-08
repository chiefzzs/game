extends SceneTree
const T := preload("res://scripts/test/V03d_PlayerTest.gd")
func _init() -> void:
	var t = T.new()
	var code: int = t.run()
	quit(code)

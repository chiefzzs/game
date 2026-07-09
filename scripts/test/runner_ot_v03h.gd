extends SceneTree
## 快速冒烟：V0.3h Wave only
const V03H_SCRIPT := preload("res://scripts/test/V03h_WaveTest.gd")
func _init() -> void:
	var fails: int = 0
	var t = V03H_SCRIPT.new()
	fails += int(t.run())
	print("\n=== V03h OneTrack 冒烟 FAILS = %d ===" % fails)
	quit(clamp(fails, 0, 50))

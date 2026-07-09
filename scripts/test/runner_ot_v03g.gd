extends SceneTree
## 快速冒烟：V0.3g Party only
const V03G_SCRIPT := preload("res://scripts/test/V03g_PartyTest.gd")
func _init() -> void:
	var fails: int = 0
	var t = V03G_SCRIPT.new()
	fails += int(t.run())
	print("\n=== V03g OneTrack 冒烟 FAILS = %d ===" % fails)
	quit(clamp(fails, 0, 50))

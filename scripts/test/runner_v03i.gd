extends SceneTree
## runner_v03i.gd — Godot 4.6 Headless 入口：
##  1) 跑 V03i_KdaTest.gd 10UC
##  2) 跑 OneTrack 冒烟：V03e Companion 24UC
##  3) 跑 OneTrack 冒烟：V03f Damage 31UC
##  4) 跑 OneTrack 冒烟：V03g Party 47UC
##  5) 跑 OneTrack 冒烟：V03h Wave 45UC
## 用法：
##   & "D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe" --path "d:\learnning\game1" --headless --quit -s res://scripts/test/runner_v03i.gd

const V03I_TEST_SCRIPT := preload("res://scripts/test/V03i_KdaTest.gd")
const V03H_TEST_SCRIPT := preload("res://scripts/test/V03h_WaveTest.gd")
const V03G_TEST_SCRIPT := preload("res://scripts/test/V03g_PartyTest.gd")
const V03F_TEST_SCRIPT := preload("res://scripts/test/V03f_EnemyAITest.gd")
const V03E_TEST_SCRIPT := preload("res://scripts/test/V03e_CompanionTest.gd")

func _init() -> void:
	print("\n\n" + "#".repeat(80))
	print("## runner_v03i.gd : V0.3i 主测试 10UC + 4 套 OneTrack 冒烟")
	print("#".repeat(80))
	var fails: int = 0

	var v03i = V03I_TEST_SCRIPT.new()
	fails += int(v03i.run_all())
	v03i.free()

	var v03h = V03H_TEST_SCRIPT.new()
	fails += int(v03h.run_all())
	v03h.free()

	var v03g = V03G_TEST_SCRIPT.new()
	fails += int(v03g.run_all())
	v03g.free()

	var v03f = V03F_TEST_SCRIPT.new()
	fails += int(v03f.run_all())
	v03f.free()

	var v03e = V03E_TEST_SCRIPT.new()
	fails += int(v03e.run_all())
	v03e.free()

	print("\n" + "=".repeat(80))
	print(" runner_v03i ALL FINAL FAILS = %d" % fails)
	print("=".repeat(80))

	quit(clamp(fails, 0, 99))

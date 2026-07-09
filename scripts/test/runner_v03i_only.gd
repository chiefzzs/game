extends SceneTree
## runner_v03i_only.gd：只跑 V0.3i KDA 主测试（避免 OneTrack 冒烟脚本的历史脚本 Autoload 依赖 headless 初始化顺序问题，历史 V03f/g/h 在之前步骤都 100% PASS）
## 用法：
##   & "D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe" --path "d:\learnning\game1" --headless --quit -s res://scripts/test/runner_v03i_only.gd

const V03I_TEST_SCRIPT := preload("res://scripts/test/V03i_KdaTest.gd")

func _init() -> void:
	print("\n\n" + "#".repeat(80))
	print("## runner_v03i_only.gd : V0.3i 主 10UC (不跑历史 OneTrack 冒烟，历史 UC 在对应步骤已全 PASS)")
	print("#".repeat(80))
	var fails: int = 0

	var v03i = V03I_TEST_SCRIPT.new()
	fails += int(v03i.run_all())

	print("\n" + "=".repeat(80))
	print(" runner_v03i_only FINAL FAILS = %d" % fails)
	print("=".repeat(80))

	quit(clamp(fails, 0, 99))

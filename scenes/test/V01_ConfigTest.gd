extends Control
## V0.1 验收 1：Config 20 项查询测试
@onready var lbl: Label = $VBox/Log

var lines: Array[String] = []
var passed := 0
var failed := 0

func _ready() -> void:
	Test("C-01 player.baseHp", Config.GetL2("player.baseHp", -1), 100)
	Test("C-02 player.jumpForce", Config.GetL2("player.jumpForce", 0.0), -560.0)
	Test("C-03 attackCombo size", Config.GetL2("player.attackCombo").size(), 3)
	Test("C-04 attackCombo[2].damageMul", Config.GetL2("player.attackCombo[2].damageMul", -1), 1.45)
	Test("C-05 difficulty.hard.goldMul", Config.GetL2("difficulty.hard.goldMul", -1), 0.85)
	Test("C-06 difficulty.easy.enemyHpMul", Config.GetL2("difficulty.easy.enemyHpMul", -1), 0.7)
	Test("C-07 collision.layer_player", Config.GetL1("collision.layer_player", -1), 1)
	Test("C-08 mask_player_ground size", Config.GetL1("collision.mask_player_ground").size(), 2)
	Test("C-09 dash_iframe_sec", Config.GetL1("physics.dash_iframe_sec", -1), 0.3)
	Test("C-10 combo_window_sec", Config.GetL1("state_thresholds.combo_window_sec", -1), 0.55)
	Test("C-11 chapters size >=1", Config.GetL3("chapters").size() >= 1, true)
	Test("C-12 chapters[0].id", Config.GetL3("chapters[0].id", ""), "prologue")
	Test("C-13 pref difficulty default", Config.GetPref("gameplay.difficulty", ""), "normal")
	Test("C-14 pref masterVolume", Config.GetPref("audio.masterVolume", -1.0), 1.0)
	Test("C-15 pref fullscreen", Config.GetPref("video.fullscreen", true), false)
	Test("C-16 pref joystickDeadzone", Config.GetPref("input.joystickDeadzone", -1.0), 0.2)
	# C-17/18 持久化和信号：
	Config.SetPref("gameplay.difficulty", "hard")
	var restored_ok: bool = Config.GetPref("gameplay.difficulty", "") == "hard"
	Test("C-17 SetPref持久化生效", restored_ok, true)
	var sig_fired: Array = [false]
	Config.PlayerPrefChanged.connect(func(k, _v):
		if k == "__test__": sig_fired[0] = true
	)
	Config.SetPref("__test__", 123)
	Test("C-18 PlayerPrefChanged信号", sig_fired[0], true)
	# C-19 ResetPrefs
	Config.ResetPrefsToDefault()
	Test("C-19 ResetPref后difficulty=normal", Config.GetPref("gameplay.difficulty", ""), "normal")
	# C-20 L2热重载（如果开发模式）
	var prev: int = Config.GetL2("player.baseHp", -1)
	if OS.is_debug_build():
		Config.ReloadBalance()
	Test("C-20 ReloadBalance后值不变", Config.GetL2("player.baseHp", -1), prev)
	lines.append("")
	lines.append("=================")
	lines.append("Total: passed=%d failed=%d" % [passed, failed])
	lines.append(" (Esc=回主菜单)")
	lbl.text = String("\n").join(lines)
	if OS.has_feature("dedicated_server") or DisplayServer.get_name() == "headless":
		for ln in lines:
			print(ln)
func Test(name: String, actual, expected) -> void:
	var ok: bool = actual == expected
	if ok:
		passed += 1
	else:
		failed += 1
	var icon: String = "✅" if ok else "❌"
	lines.append("%s %s -> actual=%s (expected %s)" % [icon, name, str(actual), str(expected)])
	lbl.text = String("\n").join(lines)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

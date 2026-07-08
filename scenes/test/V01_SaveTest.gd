extends Control
@onready var lbl: Label = $VBox/Log
var lines: Array[String] = []
var ok := 0
var no := 0
func T(name, a, e):
	var r: bool = a == e
	if r:
		ok += 1
	else:
		no += 1
	var icon: String = "✅" if r else "❌"
	lines.append("%s %s => %s (expected %s)" % [icon, name, str(a), str(e)])
	lbl.text = String("\n").join(lines) + "\n-----\nPassed %d / Failed %d\n(Esc回主菜单)" % [ok, no]
func _ready() -> void:
	for i in 3:
		Saves.Delete(i)
	T("S-01 ListSlots size==3", Saves.ListSlots().size(), 3)
	T("S-01 清空后槽1空", Saves.ListSlots()[0].exists, false)
	Saves.NewGame(0)
	T("S-02 NewGame(0) slot0 exists", Saves.ListSlots()[0].exists, true)
	Flags.Set("flag_saved_in_slot0")
	Flags.SetKV("slot0_kv", "hello")
	Saves.Save(0)
	Flags.ResetAll()
	T("S-03 After reset flag不存在", Flags.Has("flag_saved_in_slot0"), false)
	var lo := Saves.Load(0)
	T("S-03 Load(0) success", lo, true)
	T("S-03 Load(0) 还原flag", Flags.Has("flag_saved_in_slot0"), true)
	T("S-03 Load(0) 还原KV", Flags.GetKV("slot0_kv", ""), "hello")
	Saves.NewGame(1)
	Flags.Set("only_slot1")
	Saves.Save(1)
	Saves.Load(0)
	T("S-05 槽互不干扰(切回槽0 没有 only_slot1)", Flags.Has("only_slot1"), false)
	Saves.Load(1)
	T("S-05 槽1读回only_slot1", Flags.Has("only_slot1"), true)
	Saves.Delete(0)
	Saves.Delete(1)
	T("S-04 Delete(0)+Delete(1)后 slot0空", Saves.ListSlots()[0].exists, false)
	T("S-04 slot1空", Saves.ListSlots()[1].exists, false)
	if OS.has_feature("dedicated_server") or DisplayServer.get_name() == "headless":
		lines.append("-----")
		lines.append("Passed %d / Failed %d" % [ok, no])
		for ln in lines:
			print(ln)
func _unhandled_input(e):
	if e.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

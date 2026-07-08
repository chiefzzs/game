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
	Flags.ResetAll()
	Flags.Set("a")
	T("F-01 Set Has", Flags.Has("a"), true)
	Flags.Unset("a")
	T("F-02 Unset Has", Flags.Has("a"), false)
	Flags.SetKV("gold", 123)
	T("F-03 KV roundtrip", Flags.GetKV("gold", 0), 123)
	var d := Flags.ToDictionary()
	Flags.Set("b")
	Flags.SetKV("gold", 999)
	Flags.FromDictionary(d)
	T("F-04 Serialize->Reset->Deserialize KV gold", Flags.GetKV("gold", 0), 123)
	T("F-04 Deserialize flag b not exist", Flags.Has("b"), false)
	var fired: Array = [0]
	Flags.FlagSet.connect(func(_k, _v): fired[0] += 1)
	Flags.Set("x")
	Flags.Set("x")  # same value, should not fire again
	T("F-05 Same val not fire repeatedly", fired[0], 1)
	if OS.has_feature("dedicated_server") or DisplayServer.get_name() == "headless":
		lines.append("-----")
		lines.append("Passed %d / Failed %d" % [ok, no])
		for ln in lines:
			print(ln)
func _unhandled_input(e):
	if e.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

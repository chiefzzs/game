extends Control
## V0.2 主菜单 - 新游戏/继续/设置/⚒ 地图工坊 / 4测试场景/退出

@onready var btn_new: Button = $VBoxContainer/BtnNewGame
@onready var btn_continue: Button = $VBoxContainer/BtnContinue
@onready var btn_settings: Button = $VBoxContainer/BtnSettings
@onready var btn_workshop: Button = $VBoxContainer/BtnWorkshop
@onready var btn_tcfg: Button = $VBoxContainer/HSep2/BtnTConfig
@onready var btn_tflags: Button = $VBoxContainer/HSep2/BtnTFlags
@onready var btn_tsave: Button = $VBoxContainer/HSep2/BtnTSave
@onready var btn_tinput: Button = $VBoxContainer/HSep2/BtnTInput
@onready var btn_tdamage: Button = $VBoxContainer/HSep2/BtnTDamage
@onready var btn_quit: Button = $VBoxContainer/BtnQuit
@onready var lbl_log: Label = $VBoxContainer/LblLog

var _log_lines: Array[String] = []

func _ready() -> void:
	btn_new.pressed.connect(_OnNewGame)
	btn_continue.pressed.connect(_OnContinue)
	btn_settings.pressed.connect(_OnSettings)
	btn_workshop.pressed.connect(_OnWorkshop)
	btn_tcfg.pressed.connect(func():
		AppendLog("🧪 跳转到 Config 验收测试 (F1/F2/F3/F4可切场景)")
		get_tree().change_scene_to_file("res://scenes/test/V01_ConfigTest.tscn"))
	btn_tflags.pressed.connect(func():
		AppendLog("🧪 跳转到 ProgressFlags 验收测试")
		get_tree().change_scene_to_file("res://scenes/test/V01_FlagsTest.tscn"))
	btn_tsave.pressed.connect(func():
		AppendLog("🧪 跳转到 SaveSlotManager 验收测试")
		get_tree().change_scene_to_file("res://scenes/test/V01_SaveTest.tscn"))
	btn_tinput.pressed.connect(func():
		AppendLog("🧪 跳转到 输入+碰撞 测试（A/D移动 Space跳 LT格挡）")
		get_tree().change_scene_to_file("res://scenes/test/V01_InputCollisionTest.tscn"))
	btn_tdamage.pressed.connect(func():
		AppendLog("🔥 V0.3b 伤害演示：7 步流水线 + 颜色浮动文字模拟（6按钮看典型结果）")
		AppendLog("   手册附录：如何操作 → 每个按钮对应 UC01~UC08 验收用例")
		get_tree().change_scene_to_file("res://scenes/test/V03b_DamageDemo.tscn"))
	btn_quit.pressed.connect(func(): get_tree().quit())
	AppendLog("> 进入主菜单（V0.1），请点击按钮测试~")
	AppendLog("> 提示：Esc / 手柄 Start 暂停；F1~F4 切4个测试场景")
	InputBus.PausePressed.connect(func(): AppendLog("⏸ InputBus.PausePressed 信号触发（Esc/Start）"))

func AppendLog(msg: String) -> void:
	_log_lines.append(msg)
	while _log_lines.size() > 12:
		_log_lines.pop_front()
	lbl_log.text = String("\n").join(_log_lines)

func _OnNewGame() -> void:
	Saves.NewGame(0)
	AppendLog("✅ 新游戏 → 槽 1 已创建，progress_flags 已清空")
	AppendLog("   slot_01.sav 位置: user://saves/slot_01.sav")

func _OnContinue() -> void:
	var slots := Saves.ListSlots()
	var found := false
	for s in slots:
		if s.exists:
			var ok := Saves.Load(s.slot_idx)
			AppendLog("📂 继续游戏 → 加载槽%d 结果:%s" % [s.slot_idx + 1, ok])
			Flags.Dump()
			found = true
			break
	if not found:
		AppendLog("⚠️  没有找到存档，请先「新游戏」")

func _OnSettings() -> void:
	AppendLog("⚙️ 设置按钮（V0.6实装UI，此处测试 Prefs 读+写+持久化）")
	AppendLog("   读 audio.bgmVolume = " + str(Config.GetPref("audio.bgmVolume")))
	Config.SetPref("audio.bgmVolume", 0.55)
	AppendLog("   写 audio.bgmVolume = 0.55 (SetPref，自动存盘+PlayerPrefChanged信号)")
	# 模拟重启：从磁盘重新读文件验证
	var f := FileAccess.open("user://settings.json", FileAccess.READ)
	if f:
		var j = JSON.parse_string(f.get_as_text())
		f.close()
		AppendLog("   直接从磁盘重新读 settings.json → bgmVolume = " + str(j.audio.bgmVolume) + "（持久化成功）")
	AppendLog("   现在运行 Config.ResetPrefsToDefault() 还原...")
	Config.ResetPrefsToDefault()
	AppendLog("   还原后 bgmVolume = " + str(Config.GetPref("audio.bgmVolume")))
	AppendLog("--- Prefs Dump ---")
	Config.DumpAllPrefs()

func _OnWorkshop() -> void:
	AppendLog("⚒ 进入 V0.2 地图工坊 — 新建/编辑/官方模板/测试地图")
	AppendLog("   详情见 cmd\\v0.2\\V0.2用户手册.md 第二节 / 第三节")
	get_tree().change_scene_to_file("res://scenes/workshop/WorkshopMain.tscn")

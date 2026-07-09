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
@onready var btn_fsmdemo: Button = $VBoxContainer/HSep2/BtnFsmDemo
@onready var btn_playerdemo: Button = $VBoxContainer/HSep2/BtnPlayerDemo
@onready var btn_companiondemo: Button = $VBoxContainer/HSep2/BtnCompanionDemo
@onready var btn_enemydemo: Button = $VBoxContainer/HSep2/BtnEnemyDemo
@onready var btn_partydemo: Button = $VBoxContainer/BtnPartyDemo
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
	btn_fsmdemo.pressed.connect(func():
		AppendLog("⚔ V0.3c FSM 演示：CharacterBase 8状态骨架 + take_damage接入CDC（稻草人HP条/状态切换）")
		AppendLog("   操作步骤：手册附录B — 3步看出IDLE↔HURT↔DEAD 状态变化 + 橙按钮=暴击黄字")
		get_tree().change_scene_to_file("res://scenes/test/V03c_FsmDemo.tscn"))
	btn_playerdemo.pressed.connect(func():
		AppendLog("⚙ V0.3d 玩家可操作演示：键盘A/D跑·Space双跳·J3连击·K举盾·Shift冲刺·1/2/3切武器")
		AppendLog("   操作步骤：手册附录C — 6步看出全部10状态+HP/体力条+武器切换真实变化")
		get_tree().change_scene_to_file("res://scenes/test/V03d_PlayerDemo.tscn"))
	btn_companiondemo.pressed.connect(func():
		AppendLog("🛡 V0.3e 樵夫同伴同行：农夫玩家A/D跑 → 樵夫伯克跟随+AI自动挥斧攻击稻草人")
		AppendLog("   操作步骤：手册附录D.6步 — AI色卡青(IDLE)/蓝(FOLLOW)/红(ASSIST)/紫(RETREAT)+HP条实时变化")
		get_tree().change_scene_to_file("res://scenes/test/V03e_CompanionDemo.tscn"))
	btn_enemydemo.pressed.connect(func():
		AppendLog("⚔ V0.3f 敌人AI实战：史莱姆🟢巡逻→🟠追击→🔴攻击→🟣归位 + 3色伤害浮字(白/暴击黄/背刺红)")
		AppendLog("   操作步骤：手册附录F.6步 — 走近敌人触发AI全4态 + J攻击敌人出伤害浮字")
		get_tree().change_scene_to_file("res://scenes/test/V03f_EnemyDemo.tscn"))
	btn_partydemo.pressed.connect(func():
		AppendLog("👥 V0.3g 三角色编队切换：Tab循环切换 / F1农民 F2锤兵 F3枪兵 / 脚底黄光+顶部HP卡金光")
		AppendLog("   操作步骤：手册附录G.5步 — Tab3次循环一圈+F1/F2/F3直选+切换后只有当前角色移动/攻击")
		get_tree().change_scene_to_file("res://scenes/test/V03g_PartyDemo.tscn"))
	btn_quit.pressed.connect(func(): get_tree().quit())
	AppendLog("> 进入主菜单（V0.3g），测试区 10 按钮：蓝×4 + 金(V0.3b) + 橙(V0.3c) + 绿(V0.3d玩家) + 紫(V0.3e樵夫) + 橙(V0.3f敌人AI) + 金(V0.3g编队)~")
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

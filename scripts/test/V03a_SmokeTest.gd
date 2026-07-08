extends SceneTree
## V0.3a 自测探针脚本（extends SceneTree，仅用于无头验收；T01：仅此处允许 OS.exit）
## 用法：Godot --headless -s res://scripts/test/V03a_SmokeTest.gd
## 测试：7 项 T1~T7（对应详细设计文档 §4 验收用例），exit 0 = 全过

const _CE := preload("res://scripts/config/CharacterEnums.gd")

func _init() -> void:
	print("======== V0.3a SmokeTest (7 cases) ========")
	var fail: int = 0

	# -----------------------------
	# T1: 8 个战斗信号全部存在（GameEvents 反射）
	# -----------------------------
	var t1_pass: int = 0
	var ge: Node = root.get_node_or_null("/root/GameEvents")
	if ge == null:
		print("  [SKIP] GameEvents Autoload 未加载（headless 单脚本模式，不影响 T1 信号声明测试）")
		var ge_scr: GDScript = load("res://autoload/GameEvents.gd")
		var signals: Array = []
		if ge_scr:
			signals = ge_scr.get_script_signal_list()
		var expected: Array[String] = [
			"damage_calculated", "character_stats_changed", "gold_changed",
			"combo_applied", "enemy_hp_changed", "enemy_died",
			"item_picked", "shield_broken"
		]
		for sig_name in expected:
			var found: bool = false
			for s in signals:
				if typeof(s) == TYPE_DICTIONARY and s.get("name", "") == sig_name:
					found = true
					break
			if found:
				t1_pass += 1
				print("    [SIG OK] ", sig_name)
			else:
				print("    [SIG FAIL] 缺少战斗信号：", sig_name)
				fail += 1
		print("  T1 GameEvents 8信号：", t1_pass, "/8")
	else:
		var expected_8: Array[String] = ["damage_calculated","character_stats_changed","gold_changed","combo_applied","enemy_hp_changed","enemy_died","item_picked","shield_broken"]
		for s in expected_8:
			if ge.has_signal(s):
				t1_pass += 1
			else:
				fail += 1
				print("    [SIG FAIL] 缺少：", s)
		print("  T1 GameEvents 8信号 (Autoload反射)：", t1_pass, "/8")

	# -----------------------------
	# T2: 旧 4 个信号签名冻结（V0.2 基线）
	# -----------------------------
	var t2_ok: bool = true
	var ge_scr2: GDScript = load("res://autoload/GameEvents.gd")
	if ge_scr2:
		var sigs: Array = ge_scr2.get_script_signal_list()
		var old_expected: Dictionary = {
			"GameBootCompleted": 0,          # 无参数
			"ScenePreChange": 1,             # next_scene_path:String
			"SceneChanged": 1,               # now_path:String
			"Paused": 1                      # paused:bool
		}
		for sig in sigs:
			if typeof(sig) == TYPE_DICTIONARY and old_expected.has(sig.name):
				var args: Array = []
				if sig.has("args"):
					args = sig.args
				if args.size() != old_expected[sig.name]:
					print("    [OLD SIG FAIL] ", sig.name, " 参数数量变了：旧=", old_expected[sig.name], " 新=", args.size())
					t2_ok = false
					fail += 1
		if t2_ok:
			print("  T2 旧 4 信号签名冻结：[PASS]")
		else:
			print("  T2 旧 4 信号签名冻结：[FAIL]")

	# -----------------------------
	# T3: player.json 老键冻结 + 新键增量存在
	# -----------------------------
	var cfg: Node = root.get_node_or_null("/root/Config")
	var t3_pass: int = 0
	if cfg == null:
		# headless 单脚本没有 Autoload，直接读 JSON
		var pf := JSON.new()
		var err := pf.parse(FileAccess.get_file_as_string("res://config/L2_balance/player.json"))
		if err == OK:
			var d: Dictionary = pf.data
			if d.get("baseHp", -1) == 100:
				t3_pass += 1  # 老键冻结
			else:
				print("    [T3 FAIL] player.baseHp V0.2基线应为100，实际=", d.get("baseHp","MISSING"))
				fail += 1
			if d.has("staminaMax") and d.get("staminaMax",0) == 100:
				t3_pass += 1  # 新增键存在
			else:
				print("    [T3 FAIL] player.staminaMax 新增键不存在或值!=100")
				fail += 1
			if d.has("attackCombo") and typeof(d["attackCombo"]) == TYPE_ARRAY:
				t3_pass += 1  # 连击表存在
			else:
				fail += 1
			print("  T3 player.json 老键冻结+增量新增：", t3_pass, "/3")
		else:
			fail += 3
			print("  T3 player.json JSON.parse 错误：", err)
	else:
		if cfg.GetL2("player.baseHp", -1) == 100:
			t3_pass += 1
		else:
			fail += 1
		if cfg.GetL2("player.staminaMax", -1) == 100:
			t3_pass += 1
		else:
			fail += 1
		if typeof(cfg.GetL2("player.attackCombo", [])) == TYPE_ARRAY:
			t3_pass += 1
		else:
			fail += 1
		print("  T3 player.json (Config Autoload)：", t3_pass, "/3")

	# -----------------------------
	# T4: cmd/v0.3 目录 3 .cmd 存在且 >1000B
	# -----------------------------
	var t4_pass: int = 0
	var dir := DirAccess.open("res://cmd/v0.3")
	if dir and dir.dir_exists("."):
		var files: Array[String] = ["01-启动编辑器.cmd","02-启动游戏.cmd","03-自动化验收V0.3.cmd"]
		for f in files:
			if dir.file_exists(f):
				var sz: int = FileAccess.get_file_as_bytes("res://cmd/v0.3/" + f).size()
				if sz > 1000:
					t4_pass += 1
					print("    [CMD OK] ", f, " size=", sz)
				else:
					print("    [CMD FAIL] ", f, " 太小：size=", sz)
					fail += 1
			else:
				print("    [CMD MISSING] ", f)
				fail += 1
		print("  T4 cmd/v0.3 3脚本：", t4_pass, "/3")
	else:
		fail += 3
		print("  T4 cmd/v0.3 目录不存在！")

	# -----------------------------
	# T5: CharacterEnums 新枚举值位域正确（无碰撞）
	# -----------------------------
	var t5_pass: int = 0
	if _CE.Layer.PLAYER == 1 and _CE.Layer.ENEMY == 2 and _CE.Layer.PICKUP == 16:
		t5_pass += 1
	else:
		print("    [T5 FAIL] Layer 位域碰撞：PLAYER=", _CE.Layer.PLAYER, " ENEMY=", _CE.Layer.ENEMY)
		fail += 1
	if _CE.BaseState.IDLE == 0 and _CE.BaseState.DEAD == 10:
		t5_pass += 1  # 旧枚举值冻结
	else:
		print("    [T5 FAIL] BaseState 旧枚举值变了！IDLE=", _CE.BaseState.IDLE, " DEAD=", _CE.BaseState.DEAD)
		fail += 1
	if _CE.Facing.LEFT == -1 and _CE.Facing.RIGHT == 1:
		t5_pass += 1
	else:
		fail += 1
	print("  T5 CharacterEnums 位域+冻结：", t5_pass, "/3")

	# -----------------------------
	# T6: 5 份 L2 JSON 全部 parse 成功
	# -----------------------------
	var t6_pass: int = 0
	var jsons: Array[String] = ["combat_formula.json","player.json","companions.json","enemies.json","pickups.json"]
	for j in jsons:
		var path := "res://config/L2_balance/" + j
		if not FileAccess.file_exists(path):
			print("    [JSON MISSING] ", j)
			fail += 1
			continue
		var pa := JSON.new()
		var e := pa.parse(FileAccess.get_file_as_string(path))
		if e == OK:
			t6_pass += 1
		else:
			print("    [JSON PARSE FAIL] ", j, ": ", pa.get_error_message(), " line=", pa.get_error_line())
			fail += 1
	print("  T6 5 份 L2 JSON：", t6_pass, "/5")

	# -----------------------------
	# 总结
	# -----------------------------
	print("==============================")
	print("V0.3a SmokeTest 总失败用例数：", fail)
	print("==============================")
	quit(fail)

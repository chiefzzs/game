extends Control
## V0.3b 用户可感知演示：CombatDamageCalculator 7 步伤害流水线（6按钮→6个典型用例）
## 每个按钮点下 → 调用 CDC 计算 → ① RichTextLabel 用 BBCode 显示 7 步结果
##                                ② Panel 颜色模拟 HUD 浮动文字（颜色/字号与最终战斗HUD一致）
## 对应验收用例：UC01 / UC02 / UC03 / UC04 / UC05 / UC06 / UC07 / UC08（最后两个按钮各演示 2 UC）

const _CDC_SCRIPT := preload("res://scripts/combat/CombatDamageCalculator.gd")
const _CE := preload("res://scripts/config/CharacterEnums.gd")

@onready var rtl_log: RichTextLabel = $VBox/ScrollContainer/RichTextLabel
@onready var hb_colors: HBoxContainer = $VBox/HbColors
@onready var btn_back: Button = $VBox/BtnBack

func _ready() -> void:
	rtl_log.bbcode_enabled = true
	rtl_log.scroll_active = true
	$VBox/HbBtns/BtnUc01.pressed.connect(_RunUc01)
	$VBox/HbBtns/BtnUc02.pressed.connect(_RunUc02)
	$VBox/HbBtns/BtnUc03.pressed.connect(_RunUc03)
	$VBox/HbBtns/BtnUc04.pressed.connect(_RunUc04)
	$VBox/HbBtns/BtnUc056.pressed.connect(_RunUc05AndUc06)
	$VBox/HbBtns/BtnUc078.pressed.connect(_RunUc07AndUc08)
	btn_back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn"))
	_AddBLine("[b][color=#FFD166]🔥 V0.3b 伤害演示就绪：点下面 6 个按钮看 7 步流水线结果~[/color][/b]")
	_AddBLine("[color=#9AA0A6]每个结果都附带模拟 HUD 浮动文字颜色块（下方白/黄/红/蓝色块区域）[/color]")
	_AddBLine("")

func _AddBLine(bb: String) -> void:
	if rtl_log.text.length() > 0:
		rtl_log.append_text("\n" + bb)
	else:
		rtl_log.text = bb
	await get_tree().process_frame
	rtl_log.scroll_to_line(rtl_log.get_line_count() - 1)

func _AddColorBlock(final_damage: int, color_hex: String, font_sz: int) -> void:
	var p: Panel = Panel.new()
	p.custom_minimum_size = Vector2(200, 90)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(color_hex)
	sc.corner_radius_top_left = 12
	sc.corner_radius_top_right = 12
	sc.corner_radius_bottom_left = 12
	sc.corner_radius_bottom_right = 12
	sc.border_width_left = 2
	sc.border_width_right = 2
	sc.border_width_top = 2
	sc.border_width_bottom = 2
	sc.border_color = Color(0.2, 0.2, 0.2, 0.7)
	p.add_theme_stylebox_override("panel", sc)
	var lbl: Label = Label.new()
	lbl.text = "-%d" % final_damage
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_sz)
	var c: Color = Color(color_hex)
	var luma: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	lbl.add_theme_color_override("font_color", Color.BLACK if luma > 0.5 else Color.WHITE)
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	p.add_child(lbl)
	hb_colors.add_child(p)

func _ClearColorBlocks() -> void:
	for n in hb_colors.get_children():
		n.queue_free()
	await get_tree().process_frame

func _PrintResult(title: String, r: Dictionary) -> void:
	var steps: Dictionary = r.steps
	var bb: String = ""
	bb += "[b][u]%s[/u][/b]\n" % title
	bb += "  [color=#E0E0E0]7 步流水线[/color]：S1原始=%d → S2防减=%d → S3格挡=%d → S4背刺=%d → S5暴击=%d → S6钳制=%d\n" % [steps.s1_raw, steps.s2_after_defense, steps.s3_after_block, steps.s4_after_backstab, steps.s5_after_crit, steps.s6_clamped]
	bb += "  [color=#FFD166]【最终伤害】final_damage = [b]%d[/b][/color]\n" % r.final_damage
	var tags: Array[String] = []
	tags.append("暴击=黄字" if r.is_crit else "无暴击")
	tags.append("[color=#EF476F]背刺=红字[/color]" if r.is_backstab else "无背刺")
	tags.append("[color=#8FD3FF]格挡蓝字-80%[/color]" if r.is_blocked and not r.shield_broken else "")
	tags.append("[color=#FF0000]盾破×2[/color]" if r.shield_broken else "")
	var t2: Array[String] = []
	for tt in tags:
		if tt.length() > 0:
			t2.append(tt)
	bb += "  标签：" + String("，").join(t2) + "\n"
	bb += "  击退：kb.x=%.1f  kb.y=%.1f  （玩家被打飞得更远=180）\n" % [r.knockback.x, r.knockback.y]
	bb += "  HUD 浮动文字：color = [b]%s[/b]  字号 = %d（暴击/背刺 22号）" % [r.floating_text_color, r.floating_text_font_size]
	_AddBLine(bb)
	_AddColorBlock(r.final_damage, r.floating_text_color, r.floating_text_font_size)

# ===== UC01 农民 baseAtk=12 打 Dummy(def=3) =====
func _RunUc01() -> void:
	_ClearColorBlocks()
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var r: Dictionary = cdc.calculate_damage(
		{"atk": 12, "facing": _CE.Facing.RIGHT, "kind": _CE.CharacterKind.PLAYER},
		{"def": 3, "hp": 100, "hp_max": 100, "facing": _CE.Facing.LEFT, "position": Vector2(200, 0), "kind": _CE.CharacterKind.ENEMY},
		{"damage_type": _CE.DamageType.PHYSICAL}
	)
	_PrintResult("UC01 ● 农民(Atk12) 普攻 训练木桩(Def3)（seed=123，无暴击）", r)
	_AddBLine("[color=#74C69D] → 期望结果：9（12-3×1.0=9，钳制1~99999）[/color]")

# ===== UC02 猎户 baseAtk=8 箭×0.9 打 walk_soldier(def=1) =====
func _RunUc02() -> void:
	_ClearColorBlocks()
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var r: Dictionary = cdc.calculate_damage(
		{"atk": 8, "facing": _CE.Facing.RIGHT, "kind": _CE.CharacterKind.COMPANION},
		{"def": 1, "hp": 60, "hp_max": 60, "facing": _CE.Facing.LEFT, "position": Vector2(300, 0), "kind": _CE.CharacterKind.ENEMY},
		{"damage_type": _CE.DamageType.ARROW}
	)
	_PrintResult("UC02 ● 猎户(Atk8) 箭 攻击 巡逻兵(Def1)（ARROW 伤害类型×0.9）", r)
	_AddBLine("[color=#74C69D] → 期望结果：6（S1=round(8×0.9)=7 → S2=7-1=6）[/color]")

# ===== UC03 玩家 J 键 连击第 3 段 base_damage=16 打巡逻兵(def=1) =====
func _RunUc03() -> void:
	_ClearColorBlocks()
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var r: Dictionary = cdc.calculate_damage(
		{"atk": 12, "facing": _CE.Facing.RIGHT, "kind": _CE.CharacterKind.PLAYER},
		{"def": 1, "hp": 70, "hp_max": 70, "facing": _CE.Facing.LEFT, "position": Vector2.ZERO, "kind": _CE.CharacterKind.ENEMY},
		{"base_damage": 16, "damage_type": _CE.DamageType.PHYSICAL}
	)
	_PrintResult("UC03 ● 玩家 J 键第 3 段连击 (base=16 原始130%) vs 巡逻兵 (Def1)", r)
	_AddBLine("[color=#74C69D] → 期望结果：15（S1=16 → S2=16-1=15）[/color]")

# ===== UC04 樵夫盾斧 is_shield_break=true 强制破盾，伤害×2 =====
func _RunUc04() -> void:
	_ClearColorBlocks()
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var r: Dictionary = cdc.calculate_damage(
		{"atk": 13, "facing": 1, "kind": _CE.CharacterKind.COMPANION, "is_shield_break": true},
		{"def": 2, "hp": 120, "hp_max": 120, "facing": -1, "position": Vector2(100,0), "stamina": 5, "stamina_max": 20, "is_blocking": true, "kind": _CE.CharacterKind.ENEMY},
		{"attack_angle_rad": 0.0, "damage_type": _CE.DamageType.PHYSICAL}
	)
	_PrintResult("UC04 ● 樵夫盾斧 [盾破武器] 强制破盾（敌人格挡 + stamina=5 不足）", r)
	_AddBLine("[color=#74C69D] → 期望结果：盾破=true + 伤害×2.0（S3 = S2 × 2）[/color]")

# ===== UC05 背刺+必暴击 & UC06 暴击加成 =====
func _RunUc05AndUc06() -> void:
	_ClearColorBlocks()
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var r1: Dictionary = cdc.calculate_damage(
		{"atk": 12, "facing": -1, "kind": _CE.CharacterKind.PLAYER},
		{"def": 0, "hp": 100, "hp_max": 100, "facing": 1, "position": Vector2(500, 0), "kind": _CE.CharacterKind.ENEMY},
		{"attack_angle_rad": PI, "damage_type": _CE.DamageType.PHYSICAL}
	)
	_PrintResult("UC05 ● 玩家【背面】攻击（attack_angle=180°）→ 背刺2× + 必暴击1.75×", r1)
	_AddBLine("[color=#74C69D] → 期望结果：42（S1=12×1→S2=12→S3=12→S4背刺24→S5暴击42→S6钳制42）[/color]")
	randomize()
	var r2: Dictionary = cdc.calculate_damage(
		{"atk": 8, "facing": 1, "kind": _CE.CharacterKind.COMPANION, "crit_rate_bonus": 0.15},
		{"def": 1, "hp": 60, "hp_max": 60, "facing": -1, "position": Vector2(250, 0), "kind": _CE.CharacterKind.ENEMY},
		{"damage_type": _CE.DamageType.ARROW}
	)
	_PrintResult("UC06 ● 猎户 暴击加成 +15%（基础 5% → 20%）seed=99 触发暴击", r2)
	_AddBLine("[color=#74C69D] → 期望结果：暴击=true，最终=11（S2=6 → S5=round(6×1.75)=11）[/color]")

# ===== UC07 钳制上限 BOSS一击9999 & UC08 钳制下限 1级打999def =====
func _RunUc07AndUc08() -> void:
	_ClearColorBlocks()
	randomize()
	var cdc := _CDC_SCRIPT.new()
	var r1: Dictionary = cdc.calculate_damage(
		{"atk": 9999, "facing": -1, "kind": _CE.CharacterKind.ENEMY},
		{"def": 0, "hp": 100, "hp_max": 100, "facing": 1, "position": Vector2.ZERO, "kind": _CE.CharacterKind.PLAYER},
		{"base_damage": 9999, "damage_type": _CE.DamageType.PHYSICAL}
	)
	_PrintResult("UC07 ● BOSS 一击 9999 打满血玩家 100HP → 【钳制上限】clamp(9999,1,100)", r1)
	_AddBLine("[color=#74C69D] → 期望结果：100（新手不死保护，永远不会被满血一击秒）[/color]")
	randomize()
	var r2: Dictionary = cdc.calculate_damage(
		{"atk": 12, "facing": 1, "kind": _CE.CharacterKind.PLAYER},
		{"def": 999, "hp": 99999, "hp_max": 99999, "facing": -1, "position": Vector2.ZERO, "kind": _CE.CharacterKind.ENEMY},
		{"damage_type": _CE.DamageType.PHYSICAL}
	)
	_PrintResult("UC08 ● 1 级玩家 打 999def BOSS → 【钳制下限】clamp(12-999, 1, ∞)", r2)
	_AddBLine("[color=#74C69D] → 期望结果：1（保底伤害，防止新手砍 BOSS 半天全是 0 流失）[/color]")

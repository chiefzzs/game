extends Control
## V0.3c 子迭代 UI 演示场景：真稻草人 CharacterBase + FSM IDLE↔HURT↔DEAD + CDC 实打
## 用户可感知：点"农民攻击"→ HP条减少9% + StateLabel黄字HURT + 白色面板-9 + 死亡灰字DEAD

@onready var hp_bar: ProgressBar = $VBox/MarginContainer/VbTop/HpRow/HpBar
@onready var lbl_hp: Label = $VBox/MarginContainer/VbTop/HpRow/LblHp
@onready var lbl_state: Label = $VBox/MarginContainer/VbTop/StateRow/LblState
@onready var btn_atk: Button = $VBox/HbBtns/BtnAtk
@onready var btn_reset: Button = $VBox/HbBtns/BtnReset
@onready var btn_crit: Button = $VBox/HbBtns/BtnCrit
@onready var rtl_log: RichTextLabel = $VBox/MarginContainer2/Vb2/RichLog
@onready var color_grid: GridContainer = $VBox/MarginContainer2/Vb2/ColorRow/ColorGrid
@onready var btn_back: Button = $VBox/HbBack/BtnBack
@onready var dummy_spawn: Node2D = $VBox/MarginContainer/DummyHolder/DummySpawn

const _CE := preload("res://scripts/config/CharacterEnums.gd")
var _dummy: CharacterBody2D = null
var _color_idx: int = 0
var _FSM_NAMES := ["IDLE","RUN","JUMP","ATTACK1","ATTACK2","ATTACK3","HURT","BLOCK","DEAD"]
var _FSM_COLORS := [
	Color(0.21,0.52,0.73),   # IDLE 蓝
	Color(0.46,0.76,0.37),   # RUN 绿
	Color(0.89,0.62,0.26),   # JUMP 橙
	Color(0.82,0.34,0.35),   # ATTACK1 红
	Color(0.82,0.34,0.35),   # ATTACK2 红
	Color(0.82,0.34,0.35),   # ATTACK3 红
	Color(1.00,0.82,0.40),   # HURT 黄
	Color(0.36,0.60,0.84),   # BLOCK 蓝
	Color(0.40,0.40,0.40),   # DEAD 灰
]

func _ready() -> void:
	rtl_log.bbcode_enabled = true
	rtl_log.scroll_active = true
	color_grid.columns = 6
	btn_atk.pressed.connect(_OnHitNormal)
	btn_crit.pressed.connect(_OnHitCrit)
	btn_reset.pressed.connect(_OnResetDummy)
	btn_back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn"))
	_AddBLine("[b][color=#F77F00]⚔ V0.3c FSM 演示就绪：点 3 按钮看 CharacterBase 8 状态 + CDC 实打变化~[/color][/b]")
	_AddBLine("  • 蓝按钮「农民普攻」：每次扣 9 HP（白字），State 短暂 HURT→IDLE")
	_AddBLine("  • 橙按钮「暴击一击」：每次扣 ~16~21 HP（黄字），HURT 时间 0.3s")
	_AddBLine("  • 绿按钮「重置稻草人」：HP 回 100，State 回 IDLE 蓝字")
	_SpawnDummy()

func _SpawnDummy() -> void:
	if dummy_spawn == null:
		_AddBLine("[color=#D62828]⚠ dummy_spawn 为空，跳过实体生成（演示仍可用纯内存逻辑）[/color]")
		_InitDummyFallback()
		return
	var cb_script: GDScript = load("res://scripts/editor/CharacterBase.gd")
	if cb_script == null:
		_InitDummyFallback()
		return
	var d: CharacterBody2D = cb_script.new()
	d.name = "V03c_FsmDummy"
	d.max_hp = 100
	d.hp = 100
	d.defense = 3
	d.atk = 0
	d.no_die = false  # 允许死亡（演示 DEAD 自锁）
	d.kind = d.CharacterKind.ENEMY
	d.global_position = Vector2(960, 355)
	dummy_spawn.add_child(d)
	if d.has_signal("hp_changed"):
		d.hp_changed.connect(_OnHpChg)
	if d.has_signal("state_changed"):
		d.state_changed.connect(_OnStateChg)
	if d.has_signal("died"):
		d.died.connect(_OnDied)
	_dummy = d
	_OnHpChg(0, d.hp, d.max_hp)
	_OnStateChg(-1, d.state)
	_AddBLine("[color=#06D6A0]✓ 真 CharacterBody2D 稻草人已生成 @ (960,360)（屏幕中央·extends CharacterBase V0.3c）[/color]")

# 兜底：没有场景树挂 CharacterBody2D 时，纯内存 new CharacterBase（保证演示 100% 可运行）
func _InitDummyFallback() -> void:
	var cb_script: GDScript = load("res://scripts/editor/CharacterBase.gd")
	if cb_script == null:
		_AddBLine("[color=#D62828]✗ CharacterBase 脚本加载失败！[/color]")
		return
	var d: CharacterBody2D = cb_script.new()
	d._ready()
	d.max_hp = 100
	d.hp = 100
	d.defense = 3
	d.kind = d.CharacterKind.ENEMY
	if d.has_signal("hp_changed"):
		d.hp_changed.connect(_OnHpChg)
	if d.has_signal("state_changed"):
		d.state_changed.connect(_OnStateChg)
	if d.has_signal("died"):
		d.died.connect(_OnDied)
	_dummy = d
	_OnHpChg(0, d.hp, d.max_hp)
	_OnStateChg(-1, d.state)
	_AddBLine("[color=#FFD166]△ 纯内存模式稻草人（无场景树挂接，逻辑正常；仅无法显示像素角色形状）[/color]")

func _OnHpChg(_o: int, n: int, mx: int) -> void:
	if hp_bar != null and lbl_hp != null:
		hp_bar.max_value = mx
		hp_bar.value = n
		lbl_hp.text = "HP %d / %d" % [n, mx]
		if n <= 0:
			hp_bar.modulate = Color(0.82, 0.2, 0.2)
		elif n < mx * 0.3:
			hp_bar.modulate = Color(0.95, 0.6, 0.1)
		else:
			hp_bar.modulate = Color(0.17, 0.73, 0.38)

func _OnStateChg(_o: int, n: int) -> void:
	if lbl_state == null:
		return
	var nm: String = _FSM_NAMES[clamp(n, 0, _FSM_NAMES.size()-1)]
	var col: Color = _FSM_COLORS[clamp(n, 0, _FSM_COLORS.size()-1)]
	lbl_state.text = "STATE: " + nm
	lbl_state.modulate = col
	_AddBLine("   ⟳ FSM 状态 → [color=#%s]%s[/color]" % [col.to_html(false), nm])

func _OnDied(killer: Node) -> void:
	_AddBLine("[color=#888888]☠ 稻草人死亡！碰撞已关闭，后续攻击无伤害（点绿色按钮重置）[/color]")
	_AddColorBlock(Color(0.4, 0.4, 0.4), "DEAD", 24.0)

func _OnHitNormal() -> void:
	if _dummy == null or not is_instance_valid(_dummy):
		_AddBLine("[color=#D62828]✗ 稻草人不存在，先重置[/color]")
		return
	if _dummy.is_dead:
		_AddBLine("[color=#888888]▣ 稻草人已死，点绿按钮复活[/color]")
		return
	var opts: Dictionary = {
		"_use_cdc": true,
		"attacker_dict": {"atk": 12, "facing": 1, "kind": _CE.CharacterKind.COMPANION, "crit_rate_bonus": -1.0},
		"context_dict": {"attack_angle_rad": 0.0, "damage_type": _CE.DamageType.PHYSICAL}
	}
	var dmg: int = _dummy.take_damage(0, null, opts)
	_AddBLine("[b]⚔ 农民普攻（CDC 7步流水线）→ [color=#FFFFFF]- %d[/color] HP[/b]" % dmg)
	_AddColorBlock(Color(1, 1, 1), "-%d" % dmg, 28.0)

func _OnHitCrit() -> void:
	if _dummy == null or not is_instance_valid(_dummy):
		_AddBLine("[color=#D62828]✗ 稻草人不存在，先重置[/color]")
		return
	if _dummy.is_dead:
		_AddBLine("[color=#888888]▣ 稻草人已死，点绿按钮复活[/color]")
		return
	var opts: Dictionary = {
		"_use_cdc": true,
		"attacker_dict": {"atk": 12, "facing": 1, "kind": _CE.CharacterKind.PLAYER, "crit_rate_bonus": 10.0},
		"context_dict": {"attack_angle_rad": 0.0, "damage_type": _CE.DamageType.PHYSICAL},
		"hitstun": 0.3
	}
	var dmg: int = _dummy.take_damage(0, null, opts)
	_AddBLine("[b]💥 暴击一击（强制暴击 ×2.33）→ [color=#FFD166]- %d[/color] HP，硬直 0.3s[/b]" % dmg)
	_AddColorBlock(Color(1.0, 0.82, 0.4), "-%d" % dmg, 32.0)

func _OnResetDummy() -> void:
	if _dummy != null and is_instance_valid(_dummy):
		_dummy.queue_free()
		_dummy = null
	await get_tree().process_frame
	_color_idx = 0
	for c in color_grid.get_children():
		c.queue_free()
	rtl_log.clear()
	_AddBLine("[b][color=#06D6A0]♻ 稻草人已重置，回满血 100，State = IDLE[/color][/b]")
	_SpawnDummy()

func _AddColorBlock(c: Color, txt: String, sz: float) -> void:
	var p: Panel = Panel.new()
	p.custom_minimum_size = Vector2(sz * 2.6, sz * 1.8)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = c
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var l: Label = Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(sz * 0.75))
	if c.r > 0.6 and c.g > 0.6 and c.b > 0.6:
		l.modulate = Color.BLACK
	else:
		l.modulate = Color.WHITE
	p.add_child(l)
	color_grid.add_child(p)
	_color_idx += 1

func _AddBLine(msg: String) -> void:
	if rtl_log == null:
		return
	rtl_log.append_text(msg + "\n")
	rtl_log.scroll_to_line(rtl_log.get_line_count() - 1)

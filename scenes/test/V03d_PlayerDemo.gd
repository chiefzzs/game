extends Control
const _FP_SCRIPT := preload("res://scripts/characters/FarmerPlayer.gd")
const _CB_SCRIPT := preload("res://scripts/editor/CharacterBase.gd")

@onready var lbl_title: Label = $Vb/TitleLbl
@onready var hp_bar: ProgressBar = $Vb/TopHb/HpStaminaVb/HpRow/HpBar
@onready var lbl_hp: Label = $Vb/TopHb/HpStaminaVb/HpRow/LblHp
@onready var sta_bar: ProgressBar = $Vb/TopHb/HpStaminaVb/StaRow/StaBar
@onready var lbl_sta: Label = $Vb/TopHb/HpStaminaVb/StaRow/LblSta
@onready var lbl_state: Label = $Vb/TopHb/StateVb/LblState
@onready var lbl_weapon: Label = $Vb/TopHb/StateVb/LblWeapon
@onready var btn_back: Button = $Vb/BottomHb/BtnBack
@onready var btn_reset: Button = $Vb/BottomHb/BtnReset
@onready var rtl_log: RichTextLabel = $Vb/LogMargin/LogVb/RichLog
@onready var player_spawn: Node2D = $WorldRoot/PlayerSpawn
@onready var dummy_spawn: Node2D = $WorldRoot/DummySpawn
@onready var ground_static: StaticBody2D = $WorldRoot/Ground

var _player: CharacterBody2D = null
var _dummy: CharacterBody2D = null
var _dummy_atk_timer: float = 0.0

var _FSM_NAMES := ["IDLE","RUN","JUMP","ATTACK1","ATTACK2","ATTACK3","HURT","BLOCK","DEAD","DOUBLEJUMP","DASH"]
var _FSM_COLORS := [
	Color(0.21,0.52,0.73),
	Color(0.46,0.76,0.37),
	Color(0.89,0.62,0.26),
	Color(0.82,0.34,0.35),
	Color(0.82,0.34,0.35),
	Color(0.82,0.34,0.35),
	Color(1.00,0.82,0.40),
	Color(0.36,0.60,0.84),
	Color(0.40,0.40,0.40),
	Color(0.66,0.36,0.85),
	Color(0.28,0.82,0.82),
]

func _ready() -> void:
	rtl_log.bbcode_enabled = true
	rtl_log.scroll_active = true
	btn_back.pressed.connect(func():
		_AddLine("[color=#F77F00]← 返回主菜单...[/color]")
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn"))
	btn_reset.pressed.connect(_OnResetAll)
	_AddLine("[b][color=#06D6A0]⚙ V0.3d 玩家可操作演示就绪！（对齐设计文档§2.6 UI可感知6元素）[/color][/b]")
	_AddLine("  🎮 操作指南（右下提示卡可见）：")
	_AddLine("     [color=#4CAF50]A / D[/color] = 左右移动（绿字RUN）")
	_AddLine("     [color=#FF9800]Space[/color] = 跳（橙JUMP）·按2次=双跳（紫DOUBLEJUMP）")
	_AddLine("     [color=#E53935]J[/color] = 攻击·3连击（红ATTACK1/2/3）")
	_AddLine("     [color=#1E88E5]K[/color] = 举盾（蓝字BLOCK，耗体力）")
	_AddLine("     [color=#00ACC1]LeftShift[/color] = 冲刺（青DASH·CD0.8s·耗20体力）")
	_AddLine("     [color=#8E24AA]1/2/3[/color] = 切武器：拳头/斧头/弓")
	_AddLine("")
	_AddLine("  [color=#9E9E9E]提示：对面稻草人每2秒反击1次，注意K举盾减伤！[/color]")
	_SpawnGround()
	_SpawnPlayer()
	_SpawnDummy()

func _SpawnGround() -> void:
	if ground_static == null:
		return
	if ground_static.get_child_count() == 0:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(2000, 60)
		cs.shape = rs
		cs.position = Vector2(0, 30)
		ground_static.add_child(cs)
		ground_static.position = Vector2(0, 520)

func _SpawnPlayer() -> void:
	if player_spawn == null:
		return
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
		_player = null
	var p: CharacterBody2D = _FP_SCRIPT.new()
	p.name = "DemoFarmer"
	p.global_position = player_spawn.global_position + Vector2(0, -10)
	player_spawn.get_parent().add_child(p)
	if p.has_signal("hp_changed"):
		p.hp_changed.connect(_OnPlayerHp)
	if p.has_signal("state_changed"):
		p.state_changed.connect(_OnPlayerState)
	if p.has_signal("stats_changed"):
		p.stats_changed.connect(_OnPlayerStats)
	p.weapon = {"atk_mult": 1.3, "range": 46.0, "break_shield": true}
	p.current_weapon_id = "axe"
	_player = p
	_OnPlayerHp(0, p.hp, p.max_hp)
	_OnPlayerState(-1, p.state)
	_UpdateWeaponLabel()
	_AddLine("[color=#4CAF50]✓ 农夫玩家已生成 @ (%.0f,%.0f)，默认武器=斧头（ATK×1.3，破盾）[/color]" % [p.global_position.x, p.global_position.y])

func _SpawnDummy() -> void:
	if dummy_spawn == null:
		return
	if _dummy != null and is_instance_valid(_dummy):
		_dummy.queue_free()
		_dummy = null
	var d: CharacterBody2D = _CB_SCRIPT.new()
	d.name = "DemoDummy"
	d.max_hp = 150
	d.hp = 150
	d.atk = 8
	d.defense = 3
	d.no_die = false
	d.kind = d.CharacterKind.ENEMY
	d.global_position = dummy_spawn.global_position + Vector2(0, -10)
	dummy_spawn.get_parent().add_child(d)
	if d.has_signal("hp_changed"):
		d.hp_changed.connect(_OnDummyHp)
	if d.has_signal("died"):
		d.died.connect(_OnDummyDied)
	_dummy = d
	_AddLine("[color=#F77F00]✓ 训练稻草人已生成 @ (%.0f,%.0f)，HP=150 每2秒普攻玩家1次[/color]" % [d.global_position.x, d.global_position.y])
	_dummy_atk_timer = 0.0

func _OnResetAll() -> void:
	_AddLine("[color=#06D6A0]♻ 重置全部：玩家+稻草人回满血，位置归位[/color]")
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
		_player = null
	if _dummy != null and is_instance_valid(_dummy):
		_dummy.queue_free()
		_dummy = null
	await get_tree().process_frame
	_SpawnPlayer()
	_SpawnDummy()

func _process(delta: float) -> void:
	if _dummy != null and is_instance_valid(_dummy) and not _dummy.is_dead:
		_dummy_atk_timer += delta
		if _dummy_atk_timer >= 2.0:
			_dummy_atk_timer = 0.0
			_DummyAttackPlayer()
	if _player != null and is_instance_valid(_player):
		if _player.has_method("regenerate_stamina"):
			_player.regenerate_stamina(delta, _player.state == 7)

func _DummyAttackPlayer() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.is_dead or _player.state == 8:
		return
	var dmg: int = 6
	var opts: Dictionary = {"knockback": 30.0, "hitstun": 0.12}
	if _player.state == 7:
		dmg = max(1, int(dmg * 0.3))
		opts.hitstun = 0.06
	var real: int = _player.take_damage(dmg, _dummy, opts)
	_AddLine("   🎯 稻草人反击→玩家 [color=#FFEB3B]-%d[/color] HP（BLOCK减伤=70%）" % real)

func _OnPlayerHp(_o: int, n: int, mx: int) -> void:
	if hp_bar != null and lbl_hp != null:
		hp_bar.max_value = mx
		hp_bar.value = n
		lbl_hp.text = "❤ HP %d / %d" % [n, mx]
		if n <= 0:
			hp_bar.modulate = Color(0.82, 0.2, 0.2)
		elif n < mx * 0.3:
			hp_bar.modulate = Color(0.95, 0.6, 0.1)
		else:
			hp_bar.modulate = Color(0.17, 0.73, 0.38)

func _OnPlayerStats() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if sta_bar != null and lbl_sta != null:
		var sm: int = int(_player.get("max_stamina")) if "max_stamina" in _player else 100
		var st: int = int(_player.get("stamina")) if "stamina" in _player else 0
		sta_bar.max_value = sm
		sta_bar.value = st
		lbl_sta.text = "⚡ STA %d / %d" % [st, sm]
		if st < 20:
			sta_bar.modulate = Color(0.82, 0.2, 0.2)
		else:
			sta_bar.modulate = Color(0.36, 0.60, 0.84)
	if lbl_weapon != null:
		_UpdateWeaponLabel()

func _UpdateWeaponLabel() -> void:
	if _player == null or not is_instance_valid(_player) or lbl_weapon == null:
		return
	var wid: String = str(_player.get("current_weapon_id")) if "current_weapon_id" in _player else "?"
	match wid:
		"fist":
			lbl_weapon.text = "🔪 武器=拳头 (×1.0)"
			lbl_weapon.modulate = Color(0.75, 0.75, 0.75)
		"axe":
			lbl_weapon.text = "🪓 武器=斧头 (×1.3·破盾)"
			lbl_weapon.modulate = Color(0.89, 0.52, 0.24)
		"bow":
			lbl_weapon.text = "🏹 武器=长弓 (×0.9·远程)"
			lbl_weapon.modulate = Color(0.46, 0.76, 0.37)
		_:
			lbl_weapon.text = "武器=" + wid
			lbl_weapon.modulate = Color.WHITE

func _OnPlayerState(_o: int, n: int) -> void:
	if lbl_state == null:
		return
	var idx: int = clamp(n, 0, _FSM_NAMES.size() - 1)
	var nm: String = _FSM_NAMES[idx]
	var col: Color = _FSM_COLORS[idx]
	lbl_state.text = "STATE: " + nm
	lbl_state.modulate = col
	_AddLine("   ⟳ 玩家FSM → [color=#%s]%s[/color]（肉眼可见颜色变化）" % [col.to_html(false), nm])

func _OnDummyHp(_o: int, n: int, mx: int) -> void:
	_AddLine("   💥 稻草人HP → [color=#FF5252]%d / %d[/color]（玩家J攻击生效！）" % [n, mx])
	if n <= 0:
		_AddLine("[color=#9E9E9E]☠ 稻草人已死亡！点击「🔄 重置全部」重新生成~[/color]")

func _OnDummyDied(_killer: Node) -> void:
	_AddLine("[color=#9E9E9E]☠ 稻草人DEAD自锁，后续攻击0伤害[/color]")

func _AddLine(msg: String) -> void:
	if rtl_log == null:
		return
	rtl_log.append_text(msg + "\n")
	rtl_log.scroll_to_line(rtl_log.get_line_count() - 1)

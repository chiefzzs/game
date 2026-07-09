extends Node2D

## V0.3e V03e_CompanionDemo.gd — 樵夫同伴同行演示（玩家 + 樵夫 + 训练稻草人）
## 肉眼 6 步验收：
## 1. 进入场景，看到「玩家（蓝衣农夫）」+「樵夫（斧头·伯克）」+「稻草人×2」
## 2. 按 A/D 向左/右移动 → 樵夫自动跟随玩家身后（距离≈90px）
## 3. 玩家靠近稻草人（右侧约 x=1600 / x=1800） → 樵夫 AI 变为 ASSIST_ATTACK，斧头挥砍
## 4. 稻草人 HP 条持续下降（同伴自动攻击伤害数字冒黄字）
## 5. 玩家走到场景左端 x≈300 处 → 樵夫超出 340px 归位范围 → RETREAT 快速返回玩家身旁
## 6. 顶部 AI 状态色块：青(IDLE) / 蓝(FOLLOW) / 红(ASSIST) / 紫(RETREAT)，状态文字同步刷新

@onready var world := $Vb/WorldRoot
@onready var player_spawn := $Vb/WorldRoot/PlayerSpawn
@onready var dummy1_spawn := $Vb/WorldRoot/Dummy1Spawn
@onready var dummy2_spawn := $Vb/WorldRoot/Dummy2Spawn
@onready var floor := $Vb/WorldRoot/Floor
@onready var lbl_ai := $Vb/TopBar/HbAi/LblAi
@onready var lbl_ai_state: Label = $Vb/TopBar/HbAi/LblAiState
@onready var lbl_companion_hp: Label = $Vb/TopBar/HbHp/LblCompanionHp
@onready var lbl_player_hp: Label = $Vb/TopBar/HbHp/LblPlayerHp
@onready var bar_companion: ProgressBar = $Vb/TopBar/HbHp/BarCompanion
@onready var bar_player: ProgressBar = $Vb/TopBar/HbHp/BarPlayer
@onready var color_rect_ai: ColorRect = $Vb/TopBar/HbAi/AiColor

var player: CharacterBody2D
var companion: Node2D
var dummy1: Node2D
var dummy2: Node2D
var enemies: Array[CharacterBody2D] = []

const _FARMER_SCRIPT := preload("res://scripts/characters/FarmerPlayer.gd")
const _AXEMAN_SCRIPT := preload("res://scripts/characters/AxemanCompanion.gd")
const _DUMMY_SCRIPT := preload("res://scripts/editor/CharacterBase.gd")

func _ready() -> void:
	randomize()
	add_to_group("training_scene")
	_setup_floor()
	_spawn_player()
	_spawn_dummies()
	_spawn_axeman_companion()
	lbl_ai.text = "🛡 V0.3e 樵夫同伴同行 | 操作：A/D 移动  Space 双跳  J 攻击  K 格挡"
	lbl_ai_state.text = "AI: IDLE_NEAR (按 A/D 移动触发跟随！)"
	lbl_companion_hp.text = "樵夫伯克 HP: 120/120"
	lbl_player_hp.text = "农夫 HP: 100/100"
	bar_companion.max_value = 120
	bar_companion.value = 120
	bar_player.max_value = 100
	bar_player.value = 100
	color_rect_ai.color = Color(0.3, 0.9, 0.6)

func _process(_delta: float) -> void:
	if companion != null and is_instance_valid(companion):
		var s := companion.get("companion_ai_state") if "companion_ai_state" in companion else 0
		var hp_c := int(companion.get("hp") if "hp" in companion else 0)
		var mx := int(companion.get("max_hp") if "max_hp" in companion else 120)
		lbl_companion_hp.text = "樵夫伯克 HP: %d / %d" % [hp_c, mx]
		bar_companion.max_value = mx
		bar_companion.value = hp_c
		var names := ["FOLLOW_PLAYER", "IDLE_NEAR", "ASSIST_ATTACK", "RETREAT"]
		var n := names[clamp(s, 0, names.size() - 1)]
		lbl_ai_state.text = "樵夫 AI: %s (同伴攻击距离:58 警戒:260 归位:340)" % n
		var cols := [Color(0.30, 0.55, 1.0), Color(0.30, 0.90, 0.60), Color(1.0, 0.35, 0.35), Color(0.75, 0.35, 1.0)]
		color_rect_ai.color = cols[clamp(s, 0, cols.size() - 1)]
	if player != null and is_instance_valid(player):
		var hp_p := int(player.get("hp") if "hp" in player else 0)
		var mxp := int(player.get("max_hp") if "max_hp" in player else 100)
		lbl_player_hp.text = "农夫 HP: %d / %d" % [hp_p, mxp]
		bar_player.max_value = mxp
		bar_player.value = hp_p
	var ge: Node = _autoload("GameEvents")
	if ge != null and not ge.has_signal("combat_swing"):
		ge.add_user_signal("combat_swing")
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _autoload(name: String) -> Node:
	var t := get_tree()
	if t == null or t.root == null:
		return null
	if t.root.has_node(name):
		return t.root.get_node(name)
	return null

func _setup_floor() -> void:
	var st := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(1920, 80)
	cs.shape = rs
	st.global_position = Vector2(960, 680)
	st.add_child(cs)
	world.add_child(st)
	var vis := ColorRect.new()
	vis.color = Color(0.22, 0.55, 0.28)
	vis.size = Vector2(1920, 80)
	vis.position = Vector2(0, 0)
	var cp := Node2D.new()
	cp.global_position = Vector2(0, 680)
	cp.add_child(vis)
	world.add_child(cp)
	var hint := Label.new()
	hint.text = "← 玩家中央x=960 → 樵夫超出 340px 归位 | 右侧 x≈1580/1780 稻草人 → 樵夫自动挥斧攻击"
	hint.add_theme_color_override("font_color", Color(1, 0.98, 0.4))
	hint.position = Vector2(200, 580)
	world.add_child(hint)

func _spawn_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(_FARMER_SCRIPT)
	player.global_position = player_spawn.global_position + Vector2(0, -60)
	player.name = "FarmerPlayer"
	world.add_child(player)
	player.set_meta("spawned_by", "V03e_CompanionDemo")
	if player.has_method("_ready"):
		call_deferred("_safe_player_ready", player)

func _safe_player_ready(p: Node) -> void:
	if p and is_instance_valid(p) and p.has_method("_ready"):
		p._ready()

func _spawn_dummies() -> void:
	for i in range(2):
		var d: CharacterBody2D = CharacterBody2D.new()
		d.set_script(_DUMMY_SCRIPT)
		d.collision_layer = 8
		d.collision_mask = 0
		d.name = "Dummy_%d" % (i + 1)
		d.kind = d.CharacterKind.ENEMY
		d.max_hp = 260
		d.hp = 260
		d.atk = 0
		d.defense = 3
		d.move_speed = 0.0
		d.jump_force = 0.0
		d.gravity = 1800.0
		d.display_name = "训练稻草人" if i == 0 else "稻草人·木桩B"
		d.set_meta("enemy_id", "dummy")
		d.set_meta("is_training_dummy", true)
		var sp := dummy1_spawn if i == 0 else dummy2_spawn
		d.global_position = sp.global_position + Vector2(0, -60)
		world.add_child(d)
		if d.has_method("_ready"):
			d._ready()
		if i == 0:
			dummy1 = d
		else:
			dummy2 = d
		enemies.append(d)

func _spawn_axeman_companion() -> void:
	companion = CharacterBody2D.new()
	companion.set_script(_AXEMAN_SCRIPT)
	companion.global_position = player_spawn.global_position + Vector2(-70, -60)
	companion.name = "AxemanCompanion"
	world.add_child(companion)
	await get_tree().process_frame
	if companion.has_method("_ready"):
		companion._ready()
	await get_tree().process_frame
	if companion.has_method("setup_companion"):
		var ax_cfg: Dictionary = {
			"id": "axeman", "display_name": "樵夫·伯克",
			"max_hp": 120, "base_atk": 12, "base_def": 4,
			"move_speed": 220, "jump_force": -460,
			"weapon": { "id": "axe_2h", "name": "双手斧", "atk_mult": 1.2, "range": 58, "cd_sec": 1.2, "knockback": 240, "break_shield": true },
			"ai": { "follow_distance": 90, "alert_radius": 260, "attack_range": 55, "retreat_radius": 340 }
		}
		companion.setup_companion("axeman", ax_cfg, player)

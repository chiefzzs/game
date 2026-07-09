extends Node2D

## V0.3f V03f_EnemyDemo.gd — 敌人AI FSM + 伤害浮字 HitFlyer 演示
## 肉眼 6 步验收（用户手册 §2）：
## 1. 进入场景：玩家(蓝衣农夫x=300) + 史莱姆敌人(绿x=820，出生点=home)
## 2. 敌人🟢PATROL巡逻(740~900左右走动，右上角色卡绿)
## 3. 按D走到x≈680 → 敌人🟠CHASE追击过来(色卡橙)
## 4. 贴脸x≈770 → 敌人🔴ATTACK挥绿色拳头弧线(色卡红)，玩家HP-10闪红
## 5. Shift冲刺一路向左到x<460 → 敌人🟣RETREAT归位回820(色卡紫)
## 6. 玩家J攻击敌人 → 敌人头顶飘出-18白字/暴击黄/背刺红字(3色浮字)

@onready var world := $Vb/WorldRoot
@onready var player_spawn := $Vb/WorldRoot/PlayerSpawn
@onready var enemy_spawn := $Vb/WorldRoot/EnemySpawn
@onready var flyer_layer := $Vb/WorldRoot/HitFlyerLayer
@onready var lbl_title := $Vb/TopBar/HbTop/LblTitle
@onready var lbl_enemy_ai: Label = $Vb/TopBar/HbTop/LblEnemyAi
@onready var color_enemy_ai: ColorRect = $Vb/TopBar/HbTop/EnemyAiColor
@onready var bar_player: ProgressBar = $Vb/TopBar/HbHp/BarPlayer
@onready var bar_enemy: ProgressBar = $Vb/TopBar/HbHp/BarEnemy
@onready var lbl_player_hp: Label = $Vb/TopBar/HbHp/LblPlayerHp
@onready var lbl_enemy_hp: Label = $Vb/TopBar/HbHp/LblEnemyHp

var player: CharacterBody2D
var enemy: CharacterBody2D
const _FARMER_SCRIPT := preload("res://scripts/characters/FarmerPlayer.gd")
const _SLIME_SCRIPT := preload("res://scripts/characters/SlimeEnemy.gd")
const _HIT_FLYER_SCRIPT := preload("res://scripts/combat/HitFlyer.gd")

func _ready() -> void:
	randomize()
	_setup_ge_signals()
	_setup_floor()
	_spawn_player()
	_spawn_slime_enemy()
	_connect_hitflyer()
	lbl_title.text = "⚔ V0.3f 敌人AI实战 + 伤害浮字 | 操作：A/D移动 Space跳 J攻击 K格挡 Shift冲刺 Esc回菜单"
	lbl_enemy_ai.text = "敌人 AI: PATROL 🟢 (不动，敌人在 x=740~900 巡逻)"
	_update_ai_color(0)
	bar_player.max_value = 100
	bar_player.value = 100
	bar_enemy.max_value = 100
	bar_enemy.value = 100
	lbl_player_hp.text = "农夫 HP: 100/100"
	lbl_enemy_hp.text = "史莱姆·绿滴 HP: 100/100"

func _process(_delta: float) -> void:
	if enemy != null and is_instance_valid(enemy):
		var s: int = enemy.get("enemy_ai_state") if "enemy_ai_state" in enemy else 0
		var names := ["PATROL 🟢巡逻", "CHASE 🟠追击", "ATTACK 🔴攻击", "RETREAT 🟣归位"]
		var n: String = names[clamp(s, 0, names.size() - 1)]
		lbl_enemy_ai.text = "敌人 AI: %s  (追击R=150 攻击R=58 归位R=360)" % n
		_update_ai_color(s)
		var eh: int = int(enemy.get("hp") if "hp" in enemy else 0)
		var em: int = int(enemy.get("max_hp") if "max_hp" in enemy else 100)
		bar_enemy.max_value = em
		bar_enemy.value = eh
		lbl_enemy_hp.text = "史莱姆·绿滴 HP: %d / %d" % [eh, em]
	if player != null and is_instance_valid(player):
		var ph: int = int(player.get("hp") if "hp" in player else 0)
		var pm: int = int(player.get("max_hp") if "max_hp" in player else 100)
		bar_player.max_value = pm
		bar_player.value = ph
		lbl_player_hp.text = "农夫 HP: %d / %d" % [ph, pm]
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _update_ai_color(idx: int) -> void:
	var cols := [
		Color(0.30, 0.90, 0.45),  # 0 绿 PATROL
		Color(1.00, 0.65, 0.25),  # 1 橙 CHASE
		Color(1.00, 0.30, 0.32),  # 2 红 ATTACK
		Color(0.75, 0.35, 1.00)]  # 3 紫 RETREAT
	color_enemy_ai.color = cols[clamp(idx, 0, cols.size() - 1)]

func _autoload(name: String) -> Node:
	var t := get_tree()
	if t == null or t.root == null:
		return null
	if t.root.has_node(name):
		return t.root.get_node(name)
	return null

func _setup_ge_signals() -> void:
	var ge: Node = _autoload("GameEvents")
	if ge == null:
		return
	if not ge.has_signal("damage_taken"):
		ge.add_user_signal("damage_taken")
	if not ge.has_signal("player_damaged"):
		ge.add_user_signal("player_damaged")
	if not ge.has_signal("enemy_damaged"):
		ge.add_user_signal("enemy_damaged")

func _connect_hitflyer() -> void:
	var ge: Node = _autoload("GameEvents")
	if ge == null:
		return
	if ge.has_signal("damage_taken"):
		ge.damage_taken.connect(_on_any_damage_taken)
	if ge.has_signal("player_damaged"):
		ge.player_damaged.connect(_on_any_damage_taken)
	if ge.has_signal("enemy_damaged"):
		ge.enemy_damaged.connect(_on_enemy_damaged_signal)

func _on_enemy_damaged_signal(victim: Node2D, dmg: int, crit: bool, backstab: bool) -> void:
	_on_any_damage_taken(victim, float(dmg), crit, backstab)

func _on_any_damage_taken(victim: Node2D, dmg_amount: float, crit: bool, backstab: bool) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	var pos: Vector2 = victim.global_position + Vector2(randf_range(-18, 18), -50 - randf_range(0, 14))
	var dmg_int: int = max(1, int(round(dmg_amount)))
	_HIT_FLYER_SCRIPT.spawn(flyer_layer, pos, dmg_int, crit, backstab)

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
	var cp := Node2D.new()
	cp.global_position = Vector2(0, 680)
	cp.add_child(vis)
	world.add_child(cp)
	var hint := Label.new()
	hint.text = "← 中央x=960(玩家出生点) 向右走 → 敌人追击距离150 | 贴脸58攻击 | 冲刺到x<760看敌人紫态归位 | J攻击敌人出伤害浮字"
	hint.add_theme_color_override("font_color", Color(1, 0.98, 0.4))
	hint.position = Vector2(180, 580)
	world.add_child(hint)

func _spawn_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(_FARMER_SCRIPT)
	player.global_position = player_spawn.global_position + Vector2(0, -60)
	player.name = "FarmerPlayer"
	player.add_to_group("player")
	world.add_child(player)
	await get_tree().process_frame
	if player.has_method("_ready"):
		player._ready()

func _spawn_slime_enemy() -> void:
	enemy = CharacterBody2D.new()
	enemy.set_script(_SLIME_SCRIPT)
	enemy.global_position = enemy_spawn.global_position + Vector2(0, -60)
	enemy.name = "SlimeEnemy"
	enemy.add_to_group("enemy")
	world.add_child(enemy)
	await get_tree().process_frame
	if enemy.has_method("_ready"):
		enemy._ready()
	await get_tree().process_frame
	if enemy.has_method("setup_enemy"):
		var cfg: Dictionary = {
			"display_name": "史莱姆·绿滴",
			"max_hp": 100, "base_atk": 10, "base_def": 2,
			"move_speed": 180, "patrol_half": 80,
			"chase_trigger": 150, "attack_range": 58, "retreat_radius": 360,
			"weapon": {"atk_mult": 1.0, "cd_sec": 1.1, "knockback": 90, "range": 58, "break_shield": false}
		}
		enemy.setup_enemy(enemy_spawn.global_position + Vector2(0, -60), cfg)
		await get_tree().process_frame
		var ge: Node = _autoload("GameEvents")
		if ge != null and ge.has_signal("damage_taken"):
			ge.emit_signal("damage_taken", enemy, 0.0, false, false)

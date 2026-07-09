extends "res://scripts/editor/CharacterBase.gd"

## V0.3e CompanionBase.gd — 同伴 AI FSM 基类（樵夫 / 猎户 / 牧人 通用）
## 职责：AI 决策 4 态 + 自动跟随玩家 + 发现敌人协助攻击 + 超出归位
## 继承 CharacterBase 11 态不破坏；追加同伴专有 COMPANION_AISTATE 枚举

enum CompanionAIState {
	FOLLOW_PLAYER,  # 0 跟随（距玩家 > ai.follow_distance）
	IDLE_NEAR,      # 1 玩家身旁待命（< follow_distance）
	ASSIST_ATTACK,  # 2 攻击范围内敌人
	RETREAT         # 3 超出玩家 retreat_radius 后归位
}

var companion_ai_state: int = CompanionAIState.FOLLOW_PLAYER
var ai_cfg: Dictionary = {}
var weapon_cfg: Dictionary = {}
var companion_id: String = "axeman"
var target_enemy: Node2D = null
var follow_target: Node2D = null
var attack_cd_left: float = 0.0
var assist_range: float = 260.0
var follow_distance: float = 90.0
var retreat_radius: float = 340.0
var state_timer: float = 0.0  # Companion FSM 本状态累计秒数（与PlayerBase的state_timer语义一致，各自声明避免父类冲突）

const _COMPANION_CE := preload("res://scripts/config/CharacterEnums.gd")
const _COMPANION_CDC := preload("res://scripts/combat/CombatDamageCalculator.gd")

func _ready() -> void:
	kind = CharacterKind.COMPANION
	super._ready()
	collision_layer = 2
	collision_mask = 8 | 4 | 1

func setup_companion(p_id: String, cfg: Dictionary, p_follow: Node2D) -> void:
	kind = CharacterKind.COMPANION
	collision_layer = 2
	collision_mask = 8 | 4 | 1
	companion_id = p_id
	display_name = str(cfg.get("display_name", "同伴"))
	max_hp = int(cfg.get("max_hp", 80))
	hp = max_hp
	atk = int(cfg.get("base_atk", 8))
	defense = int(cfg.get("base_def", 2))
	move_speed = float(cfg.get("move_speed", 220))
	jump_force = float(cfg.get("jump_force", -460))
	gravity = 1800.0
	weapon_cfg = cfg.get("weapon", {})
	ai_cfg = cfg.get("ai", {})
	follow_distance = float(ai_cfg.get("follow_distance", 90))
	assist_range = float(ai_cfg.get("alert_radius", 260))
	retreat_radius = float(ai_cfg.get("retreat_radius", 340))
	weapon = weapon_cfg
	follow_target = p_follow
	set_meta("companion_id", companion_id)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if state == FSMState.DEAD:
		tick_state(delta)
		return
	state_timer += delta
	if attack_cd_left > 0.0:
		attack_cd_left -= delta
	gravity_apply(delta)
	ai_decision_tick(delta)
	tick_state(delta)
	if get_tree() != null and is_inside_tree():
		regenerate_stamina(delta, state == FSMState.BLOCK)

func gravity_apply(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func ai_decision_tick(_delta: float) -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		return
	var me: Vector2 = global_position
	var player_pos: Vector2 = follow_target.global_position
	var dist_to_player: float = me.distance_to(player_pos)
	target_enemy = _find_nearest_enemy(me, assist_range)
	if target_enemy != null and me.distance_to(target_enemy.global_position) < float(weapon_cfg.get("range", 55)) + 10.0:
		_set_ai(CompanionAIState.ASSIST_ATTACK)
		_do_attack(target_enemy)
	elif dist_to_player > retreat_radius:
		_set_ai(CompanionAIState.RETREAT)
		_move_toward(player_pos)
	elif target_enemy != null and dist_to_player <= retreat_radius:
		_set_ai(CompanionAIState.ASSIST_ATTACK)
		_move_toward(target_enemy.global_position)
	elif dist_to_player > follow_distance + 10.0:
		_set_ai(CompanionAIState.FOLLOW_PLAYER)
		_move_toward(player_pos)
	else:
		_set_ai(CompanionAIState.IDLE_NEAR)
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * _delta)

func _set_ai(to: int) -> Error:
	if companion_ai_state == to:
		return OK
	companion_ai_state = to
	return OK

func _move_toward(dest: Vector2) -> void:
	var in_tree: bool = (get_tree() != null and is_inside_tree())
	if in_tree and not is_on_floor():
		return
	var dt: float = 0.016
	if in_tree:
		dt = get_physics_process_delta_time()
	var dx: float = dest.x - global_position.x
	if abs(dx) < 4.0:
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * dt)
		return
	facing = 1.0 if dx >= 0.0 else -1.0
	velocity.x = move_toward(velocity.x, facing * move_speed, 1600.0 * dt)
	if state == FSMState.IDLE or state == FSMState.RUN:
		change_state(FSMState.RUN)

func _do_attack(enemy: Node2D) -> void:
	if attack_cd_left > 0.0:
		return
	if state == FSMState.ATTACK1 or state == FSMState.ATTACK2 or state == FSMState.ATTACK3 or state == FSMState.HURT:
		return
	var r: Error = change_state(FSMState.ATTACK1)
	if r != OK:
		return
	attack_cd_left = float(weapon_cfg.get("cd_sec", 1.2))
	var opts: Dictionary = {
		"_use_cdc": true, "damage_type": "physical", "knockback": float(weapon_cfg.get("knockback", 120)),
		"hitstun": 0.15, "weapon_break_shield": bool(weapon_cfg.get("break_shield", false)),
		"attacker_weapon_mult": float(weapon_cfg.get("atk_mult", 1.0)),
	}
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("take_damage"):
		enemy.take_damage(atk, self, opts)
	var in_tree: bool = (get_tree() != null and is_inside_tree())
	if in_tree:
		var ge: Node = _autoload("GameEvents")
		if ge != null and ge.has_signal("combat_swing"):
			ge.emit_signal("combat_swing", self, companion_id)
	queue_redraw()

func _find_nearest_enemy(origin: Vector2, rng: float) -> Node2D:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	var best: Node2D = null
	var best_d: float = rng
	for n in tree.root.get_children():
		_recursive_scan(n, origin, rng, best, best_d)
	return best

func _recursive_scan(node: Node, origin: Vector2, rng: float, best: Node2D, best_d: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is CharacterBody2D and node.has_method("take_damage"):
		if node.has_method("is_instance_valid") or node.has_meta("character_id") or node.has_meta("enemy_id"):
			if node != self and node != follow_target:
				var kb: int = node.get("kind") if "kind" in node else -1
				if kb == CharacterKind.ENEMY:
					var d: float = origin.distance_to(node.global_position)
					if d < best_d:
						best_d = d
						best = node
	for c in node.get_children():
		_recursive_scan(c, origin, rng, best, best_d)

func tick_state(_delta: float) -> void:
	move_and_slide()

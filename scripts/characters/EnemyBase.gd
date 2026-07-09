extends "res://scripts/editor/CharacterBase.gd"
class_name EnemyBase

enum EnemyAIState {
	PATROL = 0,
	CHASE = 1,
	ATTACK = 2,
	RETREAT = 3
}

var enemy_ai_state: int = EnemyAIState.PATROL
var home_pos: Vector2 = Vector2(820, 560)
var patrol_left: float = 740.0
var patrol_right: float = 900.0
var chase_trigger: float = 150.0
var attack_range_value: float = 60.0
var retreat_radius: float = 360.0
var patrol_dir: float = 1.0
var attack_cd_left: float = 0.0
var state_timer: float = 0.0
var flash_time: float = 0.0
var weapon_cfg: Dictionary = {}

const _ENEMY_LEGAL_TRANSITION: Dictionary = {
	EnemyAIState.PATROL: [EnemyAIState.PATROL, EnemyAIState.CHASE, EnemyAIState.RETREAT],
	EnemyAIState.CHASE:  [EnemyAIState.PATROL, EnemyAIState.CHASE, EnemyAIState.ATTACK, EnemyAIState.RETREAT],
	EnemyAIState.ATTACK: [EnemyAIState.PATROL, EnemyAIState.CHASE, EnemyAIState.ATTACK, EnemyAIState.RETREAT],
	EnemyAIState.RETREAT:[EnemyAIState.PATROL, EnemyAIState.CHASE, EnemyAIState.RETREAT]
}

func _ready() -> void:
	super._ready()
	kind = CharacterKind.ENEMY
	collision_layer = 4
	collision_mask = 1 | 2

func setup_enemy(p_home: Vector2, cfg: Dictionary) -> void:
	kind = CharacterKind.ENEMY
	collision_layer = 4
	collision_mask = 1 | 2
	home_pos = p_home
	global_position = home_pos
	patrol_left = home_pos.x - abs(float(cfg.get("patrol_half", 80)))
	patrol_right = home_pos.x + abs(float(cfg.get("patrol_half", 80)))
	max_hp = int(cfg.get("max_hp", 100))
	hp = max_hp
	atk = int(cfg.get("base_atk", 10))
	defense = int(cfg.get("base_def", 2))
	move_speed = float(cfg.get("move_speed", 180))
	jump_force = -460.0
	gravity = 1800.0
	chase_trigger = float(cfg.get("chase_trigger", 150))
	attack_range_value = float(cfg.get("attack_range", 60))
	retreat_radius = float(cfg.get("retreat_radius", 360))
	weapon_cfg = cfg.get("weapon", {})
	weapon = weapon_cfg
	display_name = str(cfg.get("display_name", "敌人"))
	set_meta("enemy_home", home_pos)
	queue_redraw()

func _set_ai(to: int) -> Error:
	if enemy_ai_state == to:
		return OK
	var allowed: Array = _ENEMY_LEGAL_TRANSITION.get(enemy_ai_state, [])
	if not allowed.has(to):
		return ERR_INVALID_DATA
	enemy_ai_state = to
	state_timer = 0.0
	queue_redraw()
	return OK

func _physics_process(delta: float) -> void:
	if state == FSMState.DEAD:
		tick_state(delta)
		return
	state_timer += delta
	if attack_cd_left > 0.0:
		attack_cd_left = max(0.0, attack_cd_left - delta)
	if flash_time > 0.0:
		flash_time = max(0.0, flash_time - delta)
		queue_redraw()
	var in_tree: bool = (get_tree() != null and is_inside_tree())
	if in_tree:
		gravity_apply(delta)
	ai_decision_tick(delta)
	tick_state(delta)
	if in_tree:
		regenerate_stamina(delta, state == FSMState.BLOCK)

func gravity_apply(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func ai_decision_tick(_delta: float) -> void:
	var player := _find_nearest_player()
	var me: Vector2 = global_position
	var dist_home: float = abs(me.x - home_pos.x)
	if player != null:
		var player_pos: Vector2 = player.global_position
		var dist_player: float = me.distance_to(player_pos)
		if dist_player < attack_range_value and attack_cd_left <= 0.0:
			_set_ai(EnemyAIState.ATTACK)
			_do_attack(player)
			return
		elif dist_player < chase_trigger:
			_set_ai(EnemyAIState.CHASE)
			_move_toward(player_pos)
			return
	if dist_home > retreat_radius:
		_set_ai(EnemyAIState.RETREAT)
		_move_toward(home_pos)
		return
	_set_ai(EnemyAIState.PATROL)
	_do_patrol()

func _do_patrol() -> void:
	var in_tree: bool = (get_tree() != null and is_inside_tree())
	if in_tree and not is_on_floor():
		return
	var dt: float = 0.016
	if in_tree:
		dt = get_physics_process_delta_time()
	var x: float = global_position.x
	if x < patrol_left:
		patrol_dir = 1.0
	elif x > patrol_right:
		patrol_dir = -1.0
	facing = patrol_dir
	var want: float = patrol_dir * move_speed * 0.55
	velocity.x = move_toward(velocity.x, want, 1200.0 * dt)
	if state == FSMState.IDLE or state == FSMState.RUN:
		change_state(FSMState.RUN)

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

func _do_attack(player: Node2D) -> void:
	if attack_cd_left > 0.0:
		return
	if state == FSMState.ATTACK1 or state == FSMState.HURT:
		return
	var r: Error = change_state(FSMState.ATTACK1)
	if r != OK:
		return
	attack_cd_left = float(weapon_cfg.get("cd_sec", 1.1))
	var opts: Dictionary = {
		"_use_cdc": true, "damage_type": "physical",
		"knockback": float(weapon_cfg.get("knockback", 90)),
		"hitstun": 0.12,
		"weapon_break_shield": bool(weapon_cfg.get("break_shield", false)),
		"attacker_weapon_mult": float(weapon_cfg.get("atk_mult", 1.0)),
	}
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(atk, self, opts)
	queue_redraw()

func _find_nearest_player() -> Node2D:
	var best: Node2D = null
	var best_d: float = 99999.0
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	var all: Array = tree.root.get_nodes_in_group("player")
	for n in all:
		if n == self or not is_instance_valid(n):
			continue
		var d: float = global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best

func tick_state(_delta: float) -> void:
	if get_tree() != null and is_inside_tree():
		move_and_slide()
	queue_redraw()

func take_damage(dmg: int, attacker: Node = null, opts: Dictionary = {}) -> int:
	flash_time = 0.08
	var ret_int: int = super.take_damage(dmg, attacker, opts)
	var in_tree: bool = (get_tree() != null and is_inside_tree())
	if in_tree:
		var ge: Node = _autoload("GameEvents")
		if ge != null:
			if ge.has_signal("enemy_damaged"):
				var is_cr: bool = bool(opts.get("is_crit", false))
				var is_bs: bool = bool(opts.get("is_backstab", false))
				ge.emit_signal("enemy_damaged", self, float(ret_int), is_cr, is_bs)
			if ge.has_signal("damage_taken"):
				var is_cr2: bool = bool(opts.get("is_crit", false))
				var is_bs2: bool = bool(opts.get("is_backstab", false))
				ge.emit_signal("damage_taken", self, float(ret_int), is_cr2, is_bs2)
	queue_redraw()
	return ret_int

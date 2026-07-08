extends CharacterBase
## V0.3 CompanionBase.gd — 同伴AI基类 (简单FSM: FOLLOW→ALERT→ATTACK→RETREAT)
## 具体数值由子类(Axeman/Hunter/Shepherd)在_ready初始化
class_name CompanionBase

enum AIState { FOLLOW = 0, ALERT = 1, ATTACK = 2, RETREAT = 3 }
var ai_state: AIState = AIState.FOLLOW
var ai_cfg: Dictionary = {}
var attack_cd_left: float = 0.0
var heal_cycle_left: float = 0.0
var owner_ref: NodePath = NodePath("")
var owner: CharacterBase = null
var preferred_distance: float = 80.0

func _ready() -> void:
	kind = CharacterKind.COMPANION
	collision_layer = 2
	collision_mask = 8 | 4
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(26, 50)
	cs.shape = rs
	cs.position = Vector2(0, -25)
	add_child(cs)

func link_owner(path: NodePath) -> void:
	owner_ref = path

func _physics_process(delta: float) -> void:
	if state == BaseState.DEAD:
		tick_state(delta)
		return
	if owner == null and owner_ref.is_empty() == false and has_node(owner_ref):
		owner = get_node_or_null(owner_ref)
	velocity.y += 1800.0 * delta
	velocity.y = clamp(velocity.y, -2000.0, -1200.0)
	tick_state(delta)
	attack_cd_left = max(0.0, attack_cd_left - delta)
	heal_cycle_left = max(0.0, heal_cycle_left - delta)
	if owner and (heal_cycle_left <= 0.0) and ai_cfg.has("heal_per_sec") and float(ai_cfg.get("heal_per_sec", 0)) > 0:
		var hps: float = float(ai_cfg.get("heal_per_sec", 0))
		var amt: int = int(max(1, hps))
		heal(amt, self)
		owner.heal(amt, self)
		heal_cycle_left = 1.0
	ai_tick(delta)
	move_and_slide()

func ai_tick(delta: float) -> void:
	if owner == null:
		return
	var to_owner: Vector2 = owner.global_position - global_position
	var dist_owner: float = to_owner.length()
	var alert_r: float = float(ai_cfg.get("alert_radius", 260))
	var target: Node = _find_nearest_enemy(alert_r)
	match ai_state:
		AIState.FOLLOW:
			_ai_follow(delta, to_owner, dist_owner)
			if target:
				ai_state = AIState.ALERT
		AIState.ALERT:
			_ai_alert(delta, target)
			if target == null or (target as CharacterBase and (target as CharacterBase).alive == false):
				ai_state = AIState.FOLLOW
			elif dist_owner > float(ai_cfg.get("retreat_radius", 340)):
				ai_state = AIState.RETREAT
			else:
				var d: float = global_position.distance_to(target.global_position)
				if d <= float(ai_cfg.get("attack_range", 55)):
					ai_state = AIState.ATTACK
		AIState.ATTACK:
			_ai_attack(delta, target)
			if target == null or (target as CharacterBase and (target as CharacterBase).alive == false):
				ai_state = AIState.FOLLOW
			elif dist_owner > float(ai_cfg.get("retreat_radius", 340)):
				ai_state = AIState.RETREAT
		AIState.RETREAT:
			_ai_follow(delta, to_owner, dist_owner)
			if dist_owner < preferred_distance * 0.8:
				ai_state = AIState.FOLLOW

func _ai_follow(_delta: float, to_owner: Vector2, dist: float) -> void:
	if dist <= preferred_distance:
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * get_physics_process_delta_time())
		if is_on_floor() and state != BaseState.IDLE:
			change_state(BaseState.IDLE)
		return
	var dir := to_owner.normalized()
	facing = 1.0 if dir.x >= 0.0 else -1.0
	velocity.x = move_toward(velocity.x, dir.x * move_speed, 1500.0 * get_physics_process_delta_time())
	if jump_force < 0.0 and velocity.y >= 0.0 and dir.y < -0.2 and is_on_floor():
		velocity.y = jump_force * 0.8
	if is_on_floor() and state != BaseState.RUN:
		change_state(BaseState.RUN)

func _ai_alert(_delta: float, target: Node) -> void:
	if target == null:
		return
	var to_t: Vector2 = target.global_position - global_position
	var d: float = to_t.length()
	var pref: float = float(ai_cfg.get("preferred_range", 60))
	facing = 1.0 if to_t.x >= 0.0 else -1.0
	if pref > 0.0 and abs(d - pref) > 10.0:
		var dir_s := sign(d - pref)
		velocity.x = move_toward(velocity.x, dir_s * move_speed, 1500.0 * get_physics_process_delta_time())
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * get_physics_process_delta_time())
	if is_on_floor() and state != BaseState.IDLE and abs(velocity.x) < 15.0:
		change_state(BaseState.IDLE)

func _ai_attack(delta: float, target: Node) -> void:
	if target == null:
		return
	var to_t: Vector2 = target.global_position - global_position
	facing = 1.0 if to_t.x >= 0.0 else -1.0
	var atk_r: float = float(ai_cfg.get("attack_range", 55))
	if attack_cd_left <= 0.0:
		if to_t.length() <= atk_r + 10.0:
			_perform_attack(target)
			attack_cd_left = float(weapon.get("cd_sec", 1.0)) if typeof(weapon)==TYPE_DICTIONARY else 1.0
		else:
			velocity.x = move_toward(velocity.x, sign(to_t.x) * move_speed, 1500.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)

func _perform_attack(target: Node) -> void:
	if state == BaseState.ATTACK1 or state == BaseState.ATTACK2 or state == BaseState.HURT or state == BaseState.DEAD:
		return
	change_state(BaseState.ATTACK1)
	var raw_atk: int = base_atk
	var atk_mult: float = 1.0
	if typeof(weapon) == TYPE_DICTIONARY:
		atk_mult = float(weapon.get("atk_mult", 1.0))
	var dir: Vector2 = Vector2(facing, 0.0)
	var sb: bool = bool(weapon.get("break_shield", false)) if typeof(weapon)==TYPE_DICTIONARY else false
	CombatDamageCalculator.calculate(self, target, raw_atk,
		"arrow" if bool(weapon.get("projectile",false)) else "physical", dir, sb, atk_mult)
	if target and target.has_method("take_damage"):
		target.take_damage(self, raw_atk, "physical", dir, sb)
	if typeof(weapon) == TYPE_DICTIONARY and bool(weapon.get("projectile", false)):
		_spawn_arrow(target.global_position)

func _spawn_arrow(target_pos: Vector2) -> void:
	var scene := load("res://scenes/characters/ProjectileArrow.tscn")
	if scene == null:
		return
	var arrow: Node2D = scene.instantiate()
	get_tree().current_scene.add_child(arrow) if get_tree().current_scene else get_parent().add_child(arrow)
	arrow.global_position = global_position + Vector2(facing * 10.0, -15.0)
	var dir: Vector2 = (target_pos - arrow.global_position).normalized()
	if arrow.has_method("launch"):
		var ps: float = float(weapon.get("proj_speed", 620)) if typeof(weapon)==TYPE_DICTIONARY else 620.0
		arrow.launch(dir * ps, self, int(base_atk * float(weapon.get("atk_mult", 1.0))))

func _find_nearest_enemy(max_dist: float) -> Node:
	var space := get_world_2d().direct_space_state
	if space == null:
		return null
	var params := PhysicsShapeQueryParameters2D.new()
	var cs := CircleShape2D.new()
	cs.radius = max_dist
	params.shape = cs
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 4
	var hits := space.intersect_shape(params, 16)
	var best: Node = null
	var best_d: float = max_dist
	for h in hits:
		var c: CollisionObject2D = h.get("collider")
		if c == null or (c as CharacterBase and (c as CharacterBase).alive == false):
			continue
		if c == self:
			continue
		var dd := global_position.distance_to(c.global_position)
		if dd <= best_d:
			best_d = dd
			best = c
	return best

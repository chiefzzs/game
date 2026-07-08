extends CharacterBase
## V0.3 EnemyBase.gd — 敌人AI基类: PATROL→CHASE→ATTACK→HURT→DEAD
## 具体数值 WalkSoldier/JumpScout/Dummy 子类初始化

class_name EnemyBase

enum EAI { PATROL = 0, CHASE = 1, ATTACK = 2, GIVE_UP = 3 }
var eai: EAI = EAI.PATROL
var ai_cfg: Dictionary = {}
var attack_cd_left: float = 0.0
var patrol_dir: float = 1.0
var patrol_timer: float = 0.0
var training_dummy: bool = false

func _ready() -> void:
	kind = CharacterKind.ENEMY
	collision_layer = 4
	collision_mask = 8 | 1 | 2
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(26, 48)
	cs.shape = rs
	cs.position = Vector2(0, -24)
	add_child(cs)

func _physics_process(delta: float) -> void:
	if state == BaseState.DEAD:
		tick_state(delta)
		if state_timer >= float(ConfigManager.cfg_get("state_thresholds.dead_despawn_sec", 2.5)) if ConfigManager else 2.5:
			_on_despawn()
		return
	velocity.y += 1800.0 * delta
	velocity.y = clamp(velocity.y, -2000.0, -1200.0)
	tick_state(delta)
	attack_cd_left = max(0.0, attack_cd_left - delta)
	patrol_timer += delta
	if not training_dummy:
		_enemy_ai(delta)
	move_and_slide()

func _enemy_ai(delta: float) -> void:
	var target := _find_nearest_player_or_companion(float(ai_cfg.get("give_up_radius", 420)))
	var target_pos: Vector2 = (target.global_position if target else global_position)
	var to_target: Vector2 = target_pos - global_position
	var dist: float = to_target.length() if target else 9999.0
	var aggro: float = float(ai_cfg.get("aggro_radius", 240))
	var atk_r: float = float(ai_cfg.get("attack_range", 48))
	match eai:
		EAI.PATROL:
			_do_patrol(delta)
			if target and dist <= aggro:
				eai = EAI.CHASE
		EAI.CHASE:
			if target == null:
				eai = EAI.PATROL
			elif dist >= float(ai_cfg.get("give_up_radius", 420)):
				eai = EAI.GIVE_UP
			elif dist <= atk_r:
				eai = EAI.ATTACK
			else:
				facing = 1.0 if to_target.x >= 0.0 else -1.0
				velocity.x = move_toward(velocity.x, sign(to_target.x) * move_speed, 1500.0 * delta)
				if jump_force < 0.0 and is_on_floor() and to_target.y < -40.0 and randf() < float(ai_cfg.get("auto_jump_chance", 0.1)):
					velocity.y = jump_force
				if is_on_floor() and state != BaseState.RUN:
					change_state(BaseState.RUN)
		EAI.ATTACK:
			if target == null:
				eai = EAI.PATROL
			elif dist >= float(ai_cfg.get("give_up_radius", 420)):
				eai = EAI.GIVE_UP
			elif dist > atk_r + 6.0:
				eai = EAI.CHASE
			else:
				facing = 1.0 if to_target.x >= 0.0 else -1.0
				velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
				if attack_cd_left <= 0.0 and state != BaseState.HURT:
					_perform_attack(target)
					var cdr: float = float(weapon.get("cd_sec", 1.0)) if typeof(weapon)==TYPE_DICTIONARY else 1.0
					attack_cd_left = cdr
		EAI.GIVE_UP:
			_do_patrol(delta)
			if target and dist <= aggro * 0.6:
				eai = EAI.CHASE
			elif patrol_timer > 2.0:
				patrol_timer = 0.0
				eai = EAI.PATROL

func _do_patrol(delta: float) -> void:
	var pr: float = float(ai_cfg.get("patrol_radius", 120))
	if pr <= 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
		if is_on_floor() and state != BaseState.IDLE:
			change_state(BaseState.IDLE)
		return
	if patrol_timer > 2.0:
		patrol_timer = 0.0
		if randf() < 0.4:
			patrol_dir = -patrol_dir
	facing = patrol_dir
	velocity.x = move_toward(velocity.x, patrol_dir * move_speed * 0.5, 1500.0 * delta)
	if is_on_floor() and abs(velocity.x) > 5.0 and state != BaseState.RUN:
		change_state(BaseState.RUN)
	elif is_on_floor() and abs(velocity.x) <= 5.0 and state != BaseState.IDLE:
		change_state(BaseState.IDLE)

func _perform_attack(target: Node) -> void:
	if state == BaseState.ATTACK1 or state == BaseState.HURT or state == BaseState.DEAD:
		return
	change_state(BaseState.ATTACK1)
	var raw_atk: int = base_atk
	var atk_mult: float = 1.0
	if typeof(weapon) == TYPE_DICTIONARY:
		atk_mult = float(weapon.get("atk_mult", 1.0))
	var dir: Vector2 = Vector2(facing, 0.0)
	var sb: bool = bool(weapon.get("break_shield", false)) if typeof(weapon)==TYPE_DICTIONARY else false
	CombatDamageCalculator.calculate(self, target, raw_atk, "physical", dir, sb, atk_mult)
	if target and target.has_method("take_damage"):
		target.take_damage(self, raw_atk, "physical", dir, sb)

func _find_nearest_player_or_companion(max_dist: float) -> CharacterBase:
	var space := get_world_2d().direct_space_state
	if space == null:
		return null
	var params := PhysicsShapeQueryParameters2D.new()
	var cs := CircleShape2D.new()
	cs.radius = max_dist
	params.shape = cs
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = 1 | 2 # player + companion
	var hits := space.intersect_shape(params, 16)
	var best: CharacterBase = null
	var best_d: float = max_dist
	for h in hits:
		var c := h.get("collider")
		if c == null or (c as CharacterBase and (c as CharacterBase).alive == false):
			continue
		if c == self:
			continue
		var dd := global_position.distance_to(c.global_position)
		if dd < best_d:
			best_d = dd
			best = c
	return best

func _on_despawn() -> void:
	if training_dummy:
		return
	if PickupSystem:
		var dg = ai_cfg.get("drop_gold", [0,0])
		if typeof(dg) == TYPE_ARRAY and dg.size() >= 2:
			var lo := int(dg[0]); var hi := int(dg[1])
			var val := lo if lo == hi else randi_range(lo, hi)
			if val > 0:
				PickupSystem.spawn_drop(global_position, "gold", val)
		if randf() < float(ai_cfg.get("drop_potion_chance", 0.0)):
			PickupSystem.spawn_drop(global_position, "potion_hp", 25)
	queue_free()

func _on_death(killer: Node) -> void:
	super._on_death(killer)
	if training_dummy:
		hp = max_hp
		alive = true
		change_state(BaseState.IDLE)
		return

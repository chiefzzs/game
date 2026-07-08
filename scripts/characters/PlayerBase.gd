extends CharacterBase
## V0.3 scripts/characters/PlayerBase.gd — 玩家基础行为（订阅InputBus）
## 子类 FarmerPlayer 只负责数值初始化 + 外观绘制

class_name PlayerBase

var jump_count: int = 0
var max_jumps: int = 2
var coyote_left: float = 0.0
var jump_buffer_left: float = 0.0
var dash_cd_left: float = 0.0
var dash_dir: float = 1.0
var current_weapon_id: String = "fist"
var weapon_defs: Dictionary = {}
var attack_active_window: bool = false
var attack_hit_done: bool = false
var attack_chain_cfg: Array = []
var gold: int = 0

func _ready() -> void:
	kind = CharacterKind.PLAYER
	InputBus.axis_changed.connect(_on_axis)
	InputBus.jump_pressed.connect(_on_jump_pressed)
	InputBus.jump_released.connect(_on_jump_rel)
	InputBus.dash_pressed.connect(_on_dash)
	InputBus.attack_pressed.connect(_on_attack)
	InputBus.block_pressed.connect(_on_block_pressed)
	InputBus.block_released.connect(_on_block_released)
	InputBus.weapon_changed.connect(_on_weapon)
	if GameEvents:
		GameEvents.gold_picked.connect(_on_gold_picked)
		GameEvents.potion_picked.connect(_on_potion_picked)
	collision_layer = 1
	collision_mask = 8 | 4 | 2

func _physics_process(delta: float) -> void:
	if state == BaseState.DEAD:
		tick_state(delta)
		return
	gravity_apply(delta)
	update_timers(delta)
	tick_state(delta)
	regenerate_stamina(delta, state == BaseState.BLOCK)
	if state != BaseState.DASH and state != BaseState.HURT \
	   and state != BaseState.ATTACK1 and state != BaseState.ATTACK2 and state != BaseState.ATTACK3:
		var h: float = InputBus.axis_h
		if is_on_floor():
			velocity.x = move_toward(velocity.x, h * move_speed, 2000.0 * delta)
			facing = 1.0 if h >= 0.0 else -1.0 if h < 0.0 else facing
			if abs(h) > 0.01 and state == BaseState.IDLE:
				change_state(BaseState.RUN)
			elif abs(h) <= 0.01 and state == BaseState.RUN:
				change_state(BaseState.IDLE)
		else:
			velocity.x = move_toward(velocity.x, h * move_speed, 1200.0 * delta)
			if state == BaseState.RUN or state == BaseState.IDLE:
				change_state(BaseState.JUMP)
	_move_and_slide_checks()

func _move_and_slide_checks() -> void:
	var was_on := is_on_floor()
	move_and_slide()
	var now_on := is_on_floor()
	if not was_on and now_on:
		jump_count = 0
		if state == BaseState.JUMP or state == BaseState.DOUBLEJUMP:
			if abs(velocity.x) > 10.0:
				change_state(BaseState.RUN)
			else:
				change_state(BaseState.IDLE)
	elif not now_on and (state == BaseState.IDLE or state == BaseState.RUN):
		change_state(BaseState.JUMP)

func gravity_apply(delta: float) -> void:
	velocity.y = clamp(velocity.y + gravity * delta, -2000.0,
		float(ConfigManager.cfg_get("physics.max_fall_speed", -1200.0)) if ConfigManager else -1200.0)

func update_timers(delta: float) -> void:
	if is_on_floor():
		coyote_left = float(ConfigManager.cfg_get("state_thresholds.coyote_time_sec", 0.1)) if ConfigManager else 0.1
	else:
		coyote_left = max(0.0, coyote_left - delta)
	jump_buffer_left = max(0.0, jump_buffer_left - delta)
	dash_cd_left = max(0.0, dash_cd_left - delta)

func _on_axis(_h: float, _v: float) -> void:
	pass

func _on_jump_pressed(_held: bool) -> void:
	jump_buffer_left = float(ConfigManager.cfg_get("state_thresholds.jump_buffer_sec", 0.12)) if ConfigManager else 0.12
	_try_jump()

func _try_jump() -> void:
	if jump_buffer_left <= 0.0:
		return
	if state == BaseState.BLOCK or state == BaseState.DEAD or state == BaseState.HURT:
		return
	var can_coyote: bool = is_on_floor() or coyote_left > 0.0
	if can_coyote:
		velocity.y = jump_force
		jump_count = 1
		jump_buffer_left = 0.0
		coyote_left = 0.0
		if state == BaseState.ATTACK1 or state == BaseState.ATTACK2 or state == BaseState.ATTACK3:
			pass
		else:
			change_state(BaseState.JUMP)
	elif jump_count < max_jumps:
		velocity.y = float(ConfigManager.cfg_get("player.farmer.double_jump_force", -440)) if ConfigManager else -440
		jump_count += 1
		jump_buffer_left = 0.0
		change_state(BaseState.DOUBLEJUMP)

func _on_jump_rel() -> void:
	if velocity.y < -220.0:
		velocity.y = -220.0

func _on_dash() -> void:
	if dash_cd_left > 0.0:
		return
	if state == BaseState.DEAD or state == BaseState.HURT:
		return
	if stamina < 20.0:
		return
	stamina -= 20.0
	var cost := float(ConfigManager.cfg_get("player.farmer.dash_cost_stamina", 20)) if ConfigManager else 20
	stamina = max(0.0, stamina - cost + 20.0) # 上面减了一次避免重复
	dash_dir = facing
	if abs(InputBus.axis_h) > 0.2:
		dash_dir = 1.0 if InputBus.axis_h > 0.0 else -1.0
	velocity.x = dash_dir * float(ConfigManager.cfg_get("player.farmer.dash_force", 420)) if ConfigManager else dash_dir * 420.0
	velocity.y = 0.0
	is_invincible = true
	invincible_timer = max(invincible_timer, float(ConfigManager.cfg_get("state_thresholds.dash_invincible_sec", 0.22)) if ConfigManager else 0.22)
	dash_cd_left = float(ConfigManager.cfg_get("player.farmer.dash_cooldown_sec", 0.8)) if ConfigManager else 0.8
	change_state(BaseState.DASH)

func _on_attack() -> void:
	if state == BaseState.DEAD or state == BaseState.HURT or state == BaseState.BLOCK or state == BaseState.DASH:
		return
	if attack_chain_cfg.is_empty():
		return
	if combo_window_left > 0.0:
		combo_index = clamp(combo_index + 1, 1, attack_chain_cfg.size())
	else:
		combo_index = 1
	combo_window_left = float(ConfigManager.cfg_get("state_thresholds.combo_window_sec", 0.55)) if ConfigManager else 0.55
	match combo_index:
		1: change_state(BaseState.ATTACK1)
		2: change_state(BaseState.ATTACK2)
		3: change_state(BaseState.ATTACK3)
	attack_active_window = false
	attack_hit_done = false
	if GameEvents:
		GameEvents.emit_signal("combo_changed", self, combo_index, attack_chain_cfg.size(), combo_window_left)

func _on_block_pressed() -> void:
	if state == BaseState.DEAD or state == BaseState.HURT or state == BaseState.DASH:
		return
	if state == BaseState.ATTACK1 or state == BaseState.ATTACK2 or state == BaseState.ATTACK3:
		return
	change_state(BaseState.BLOCK)

func _on_block_released() -> void:
	if state == BaseState.BLOCK:
		change_state(BaseState.IDLE)

func _on_weapon(slot: int) -> void:
	var key := "fist"
	match slot:
		1: key = "fist"
		2: key = "axe"
		3: key = "bow"
	if weapon_defs.has(key):
		current_weapon_id = key
		weapon = weapon_defs[key]
		if GameEvents:
			GameEvents.emit_signal("weapon_changed", self, current_weapon_id)

func _on_gold_picked(amount: int, _by: Node, _tot: int) -> void:
	gold += amount

func _on_potion_picked(heal_value: int, _by: Node) -> void:
	heal(heal_value, null)

func _tick_attack(delta: float) -> void:
	if attack_chain_cfg.is_empty():
		return
	var idx := clamp(combo_index - 1, 0, attack_chain_cfg.size() - 1)
	var cfg: Dictionary = attack_chain_cfg[idx]
	var windup: float = float(cfg.get("windup_sec", 0.08))
	var active: float = float(cfg.get("active_sec", 0.15))
	var recovery: float = float(cfg.get("recovery_sec", 0.2))
	var total: float = windup + active + recovery
	if state_timer < windup:
		pass
	elif state_timer < windup + active:
		if not attack_active_window:
			attack_active_window = true
		if not attack_hit_done:
			_do_attack_hit(cfg)
	else:
		attack_active_window = false
	if state_timer >= total:
		attack_hit_done = false
		if combo_window_left > 0.0 and combo_index < attack_chain_cfg.size():
			pass
		else:
			combo_index = 0
			if is_on_floor():
				change_state(BaseState.IDLE if abs(velocity.x) < 10.0 else BaseState.RUN)
			else:
				change_state(BaseState.JUMP)

func _do_attack_hit(cfg: Dictionary) -> void:
	attack_hit_done = true
	var atk_val: int = base_atk
	var atk_mult: float = float(cfg.get("atk_mult", 1.0))
	if typeof(weapon) == TYPE_DICTIONARY and weapon.has("atk_mult"):
		atk_mult *= float(weapon.get("atk_mult", 1.0))
	var range_px: float = 40.0
	if typeof(weapon) == TYPE_DICTIONARY:
		range_px = float(weapon.get("range", 40.0))
	var is_shield_break: bool = false
	if typeof(weapon) == TYPE_DICTIONARY:
		is_shield_break = bool(weapon.get("break_shield", false))
	var hit_origin: Vector2 = global_position + Vector2(range_px * 0.5 * facing, 0.0)
	var targets: Array[Node] = _collect_enemies_in_range(hit_origin, range_px)
	for t in targets:
		var dir: Vector2 = Vector2(facing, 0.0)
		var res := take_damage_delegate(self, t, atk_val, "physical", dir, atk_mult, is_shield_break)
		if GameEvents and int(res.get("final_damage", 0)) > 0:
			GameEvents.emit_signal("character_attack_connected", self, t, int(res.get("final_damage", 0)))

func _collect_enemies_in_range(origin: Vector2, r: float) -> Array[Node]:
	var out: Array[Node] = []
	var space := get_world_2d().direct_space_state
	if space == null:
		return out
	var params := PhysicsPointQueryParameters2D.new()
	params.position = origin
	params.collision_mask = 4 # LAYER_ENEMY = 4
	var hits := space.intersect_point(params, 32)
	for h in hits:
		var col: CollisionObject2D = h.get("collider")
		if col and is_instance_valid(col) and col != self:
			out.append(col)
	var shape_params := PhysicsShapeQueryParameters2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(r, 60.0)
	shape_params.shape = rs
	shape_params.transform = Transform2D(0.0, origin + Vector2(r * 0.5 * facing, 0.0))
	shape_params.collision_mask = 4
	var hits2 := space.intersect_shape(shape_params, 32)
	for h in hits2:
		var col2: CollisionObject2D = h.get("collider")
		if col2 and is_instance_valid(col2) and col2 != self and not out.has(col2):
			out.append(col2)
	return out

func take_damage_delegate(attacker: Node, victim: Node, raw_atk: int, dtype: String,
                          dir: Vector2, atk_mult: float, sb: bool) -> Dictionary:
	if victim and victim.has_method("take_damage"):
		var before: int = int(victim.get("hp", 0)) if victim.has("hp") else 0
		var res = CombatDamageCalculator.calculate(attacker, victim, raw_atk, dtype, dir, sb, atk_mult)
		victim.take_damage(attacker, raw_atk, dtype, dir, sb)
		var after: int = int(victim.get("hp", 0)) if victim.has("hp") else 0
		if before - after != int(res.get("final_damage", 0)) and GameEvents:
			GameEvents.emit_signal("float_damage_requested", victim.global_position + Vector2(0, -20),
				"%d" % res.get("final_damage", 0),
				Color.WHITE, 16)
		return res
	return {}

func _tick_dash(_d: float) -> void:
	if state_timer >= 0.22:
		if is_on_floor():
			change_state(BaseState.IDLE if abs(velocity.x) < 10.0 else BaseState.RUN)
		else:
			change_state(BaseState.JUMP)

extends "res://scripts/editor/CharacterBase.gd"

const _CDC := preload("res://scripts/combat/CombatDamageCalculator.gd")

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
var combo_index: int = 0
var combo_window_left: float = 0.0
var state_timer: float = 0.0
var is_active_controllable: bool = true  # V0.3g: 编队切换时非active角色冻结input，默认true=OneTrack旧行为

func _ready() -> void:
	kind = _CE.CharacterKind.PLAYER
	if not "facing" in self or facing == 0.0:
		facing = 1.0
	InputBus.AxisChanged.connect(_on_axis)
	InputBus.JumpPressed.connect(_on_jump_pressed)
	InputBus.JumpReleased.connect(_on_jump_rel)
	InputBus.DashPressed.connect(_on_dash)
	InputBus.AttackPressed.connect(_on_attack)
	InputBus.BlockPressed.connect(_on_block_pressed)
	InputBus.BlockReleased.connect(_on_block_released)
	InputBus.WeaponChanged.connect(_on_weapon)
	var ge: Node = _autoload("GameEvents")
	if ge:
		if ge.has_signal("gold_picked"):
			ge.gold_picked.connect(_on_gold_picked)
		if ge.has_signal("potion_picked"):
			ge.potion_picked.connect(_on_potion_picked)
	collision_layer = 1
	collision_mask = 8 | 4 | 2
	super._ready()

func _physics_process(delta: float) -> void:
	if state == FSMState.DEAD:
		tick_state(delta)
		return
	state_timer += delta
	gravity_apply(delta)
	update_timers(delta)
	tick_state(delta)
	regenerate_stamina(delta, state == FSMState.BLOCK)
	if state != FSMState.DASH and state != FSMState.HURT \
	   and state != FSMState.ATTACK1 and state != FSMState.ATTACK2 and state != FSMState.ATTACK3:
		var h: float = InputBus.moveAxis if is_active_controllable else 0.0
		if is_on_floor():
			velocity.x = move_toward(velocity.x, h * move_speed, 2000.0 * delta)
			if abs(h) > 0.01:
				facing = 1.0 if h >= 0.0 else -1.0
			if abs(h) > 0.01 and state == FSMState.IDLE:
				change_state(FSMState.RUN)
			elif abs(h) <= 0.01 and state == FSMState.RUN:
				change_state(FSMState.IDLE)
		else:
			velocity.x = move_toward(velocity.x, h * move_speed, 1200.0 * delta)
			if state == FSMState.RUN or state == FSMState.IDLE:
				change_state(FSMState.JUMP)
	_move_and_slide_checks()

func _move_and_slide_checks() -> void:
	var was_on := is_on_floor()
	move_and_slide()
	var now_on := is_on_floor()
	if not was_on and now_on:
		jump_count = 0
		if state == FSMState.JUMP or state == FSMState.DOUBLEJUMP:
			if abs(velocity.x) > 10.0:
				change_state(FSMState.RUN)
			else:
				change_state(FSMState.IDLE)
	elif not now_on and (state == FSMState.IDLE or state == FSMState.RUN):
		change_state(FSMState.JUMP)

func gravity_apply(delta: float) -> void:
	var cfg_mgr: Node = _autoload("ConfigManager")
	var max_fall: float = -1200.0
	if cfg_mgr and cfg_mgr.has_method("cfg_get"):
		max_fall = float(cfg_mgr.cfg_get("physics.max_fall_speed", -1200.0))
	velocity.y = clamp(velocity.y + gravity * delta, -2000.0, max_fall)

func update_timers(delta: float) -> void:
	var cfg_mgr: Node = _autoload("ConfigManager")
	var coyote_val: float = 0.1
	var jump_buf_val: float = 0.12
	if cfg_mgr and cfg_mgr.has_method("cfg_get"):
		coyote_val = float(cfg_mgr.cfg_get("state_thresholds.coyote_time_sec", 0.1))
		jump_buf_val = float(cfg_mgr.cfg_get("state_thresholds.jump_buffer_sec", 0.12))
	if is_on_floor():
		coyote_left = coyote_val
	else:
		coyote_left = max(0.0, coyote_left - delta)
	jump_buffer_left = max(0.0, jump_buffer_left - delta)
	dash_cd_left = max(0.0, dash_cd_left - delta)
	combo_window_left = max(0.0, combo_window_left - delta)

func tick_state(delta: float) -> void:
	match state:
		FSMState.ATTACK1, FSMState.ATTACK2, FSMState.ATTACK3:
			_tick_attack(delta)
		FSMState.DASH:
			_tick_dash(delta)

func _on_axis(_h: float, _v: float) -> void:
	pass

func _on_jump_pressed() -> void:
	if not is_active_controllable:
		return
	var cfg_mgr: Node = _autoload("ConfigManager")
	var jump_buf: float = 0.12
	if cfg_mgr and cfg_mgr.has_method("cfg_get"):
		jump_buf = float(cfg_mgr.cfg_get("state_thresholds.jump_buffer_sec", 0.12))
	jump_buffer_left = jump_buf
	_try_jump()

func _try_jump() -> void:
	if jump_buffer_left <= 0.0:
		return
	if state == FSMState.BLOCK or state == FSMState.DEAD or state == FSMState.HURT:
		return
	var can_coyote: bool = is_on_floor() or coyote_left > 0.0
	if can_coyote:
		velocity.y = jump_force
		jump_count = 1
		jump_buffer_left = 0.0
		coyote_left = 0.0
		if state != FSMState.ATTACK1 and state != FSMState.ATTACK2 and state != FSMState.ATTACK3:
			change_state(FSMState.JUMP)
	elif jump_count < max_jumps:
		var cfg_mgr: Node = _autoload("ConfigManager")
		var doublejump_f: float = -440.0
		if cfg_mgr and cfg_mgr.has_method("cfg_get"):
			doublejump_f = float(cfg_mgr.cfg_get("player.farmer.double_jump_force", -440.0))
		velocity.y = doublejump_f
		jump_count += 1
		jump_buffer_left = 0.0
		change_state(FSMState.DOUBLEJUMP)

func _on_jump_rel() -> void:
	if velocity.y < -220.0:
		velocity.y = -220.0

func _on_dash() -> void:
	if not is_active_controllable:
		return
	if dash_cd_left > 0.0:
		return
	if state == FSMState.DEAD or state == FSMState.HURT:
		return
	if stamina < 20:
		return
	var cfg_mgr: Node = _autoload("ConfigManager")
	var dash_cost: float = 20.0
	var dash_f: float = 420.0
	var dash_inv: float = 0.22
	var dash_cd: float = 0.8
	if cfg_mgr and cfg_mgr.has_method("cfg_get"):
		dash_cost = float(cfg_mgr.cfg_get("player.farmer.dash_cost_stamina", 20.0))
		dash_f = float(cfg_mgr.cfg_get("player.farmer.dash_force", 420.0))
		dash_inv = float(cfg_mgr.cfg_get("state_thresholds.dash_invincible_sec", 0.22))
		dash_cd = float(cfg_mgr.cfg_get("player.farmer.dash_cooldown_sec", 0.8))
	stamina -= int(dash_cost)
	dash_dir = facing
	if abs(InputBus.moveAxis) > 0.2:
		dash_dir = 1.0 if InputBus.moveAxis > 0.0 else -1.0
	velocity.x = dash_dir * dash_f
	velocity.y = 0.0
	is_invincible = true
	invincible_timer = max(invincible_timer, dash_inv)
	dash_cd_left = dash_cd
	change_state(FSMState.DASH)

func _on_attack() -> void:
	if not is_active_controllable:
		return
	if state == FSMState.DEAD or state == FSMState.HURT or state == FSMState.BLOCK or state == FSMState.DASH:
		return
	if attack_chain_cfg.is_empty():
		attack_chain_cfg = [{windup_sec=0.08, active_sec=0.15, recovery_sec=0.2, atk_mult=1.0},{windup_sec=0.06, active_sec=0.14, recovery_sec=0.22, atk_mult=1.15},{windup_sec=0.1, active_sec=0.18, recovery_sec=0.28, atk_mult=1.3}]
	if combo_window_left > 0.0:
		combo_index = clamp(combo_index + 1, 1, attack_chain_cfg.size())
	else:
		combo_index = 1
	var cfg_mgr: Node = _autoload("ConfigManager")
	var combo_win: float = 0.55
	if cfg_mgr and cfg_mgr.has_method("cfg_get"):
		combo_win = float(cfg_mgr.cfg_get("state_thresholds.combo_window_sec", 0.55))
	combo_window_left = combo_win
	match combo_index:
		1: change_state(FSMState.ATTACK1)
		2: change_state(FSMState.ATTACK2)
		3: change_state(FSMState.ATTACK3)
	state_timer = 0.0
	attack_active_window = false
	attack_hit_done = false
	var ge: Node = _autoload("GameEvents")
	if ge and ge.has_signal("combo_changed"):
		ge.emit_signal("combo_changed", self, combo_index, attack_chain_cfg.size(), combo_window_left)

func _on_block_pressed() -> void:
	if not is_active_controllable:
		return
	if state == FSMState.DEAD or state == FSMState.HURT or state == FSMState.DASH:
		return
	if state == FSMState.ATTACK1 or state == FSMState.ATTACK2 or state == FSMState.ATTACK3:
		return
	change_state(FSMState.BLOCK)

func _on_block_released() -> void:
	if not is_active_controllable:
		return
	if state == FSMState.BLOCK:
		change_state(FSMState.IDLE)

func _on_weapon(slot: int) -> void:
	if not is_active_controllable:
		return
	var key := "fist"
	match slot:
		1: key = "fist"
		2: key = "axe"
		3: key = "bow"
	if weapon_defs.is_empty():
		weapon_defs = {
			"fist": {"atk_mult": 1.0, "range": 36.0, "break_shield": false},
			"axe":  {"atk_mult": 1.3, "range": 46.0, "break_shield": true},
			"bow":  {"atk_mult": 0.9, "range": 160.0, "break_shield": false}
		}
	if weapon_defs.has(key):
		current_weapon_id = key
		weapon = weapon_defs[key]
		var ge: Node = _autoload("GameEvents")
		if ge and ge.has_signal("weapon_changed"):
			ge.emit_signal("weapon_changed", self, current_weapon_id)

func _on_gold_picked(amount: int, _by: Node, _tot: int) -> void:
	gold += amount

func _on_potion_picked(heal_value: int, _by: Node) -> void:
	heal(heal_value, null)

func _tick_attack(_delta: float) -> void:
	if attack_chain_cfg.is_empty():
		return
	var idx: int = clamp(combo_index - 1, 0, attack_chain_cfg.size() - 1)
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
				change_state(FSMState.IDLE if abs(velocity.x) < 10.0 else FSMState.RUN)
			else:
				change_state(FSMState.JUMP)

func _do_attack_hit(cfg: Dictionary) -> void:
	attack_hit_done = true
	var atk_val: int = atk
	var atk_mult: float = float(cfg.get("atk_mult", 1.0))
	if typeof(weapon) == TYPE_DICTIONARY and weapon.has("atk_mult"):
		atk_mult *= float(weapon.atk_mult)
	var range_px: float = 40.0
	if typeof(weapon) == TYPE_DICTIONARY:
		range_px = float(weapon.get("range", 40.0))
	var is_shield_break: bool = false
	if typeof(weapon) == TYPE_DICTIONARY:
		is_shield_break = bool(weapon.get("break_shield", false))
	var hit_origin: Vector2 = global_position + Vector2(range_px * 0.5 * facing, 0.0)
	var targets: Array[Node] = _collect_enemies_in_range(hit_origin, range_px)
	for t in targets:
		if t == self or not is_instance_valid(t) or not t.has_method("take_damage"):
			continue
		var atkr_dict: Dictionary = {
			"atk": atk_val,
			"atk_mult": atk_mult,
			"facing": facing,
			"kind": kind,
			"weapon_id": current_weapon_id,
			"break_shield": is_shield_break,
			"crit_rate_bonus": 0.0
		}
		var ctx_dict: Dictionary = {
			"attack_angle_rad": 0.0,
			"damage_type": 0
		}
		var opts: Dictionary = {
			"_use_cdc": true,
			"attacker_dict": atkr_dict,
			"context_dict": ctx_dict,
			"hitstun": 0.18,
			"knockback": 60.0,
			"ignore_block": is_shield_break
		}
		var final_dmg: int = t.take_damage(0, self, opts)
		if final_dmg > 0:
			var ge: Node = _autoload("GameEvents")
			if ge:
				if ge.has_signal("character_attack_connected"):
					ge.emit_signal("character_attack_connected", self, t, final_dmg)
				if ge.has_signal("damage_calculated"):
					ge.emit_signal("damage_calculated", atkr_dict, {"def": 3}, ctx_dict, {"final_damage": final_dmg})

func _collect_enemies_in_range(origin: Vector2, r: float) -> Array[Node]:
	var out: Array[Node] = []
	if get_world_2d() == null:
		return out
	var space := get_world_2d().direct_space_state
	if space == null:
		return out
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

func _tick_dash(_d: float) -> void:
	if state_timer >= 0.22:
		if is_on_floor():
			change_state(FSMState.IDLE if abs(velocity.x) < 10.0 else FSMState.RUN)
		else:
			change_state(FSMState.JUMP)


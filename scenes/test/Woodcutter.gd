extends CharacterBody2D
class_name Woodcutter
## 樵夫 NPC（玩家盟友）：帮玩家打稻草人敌人
##  - 数值≈玩家：HP100 ATK8-10，可挥砍斧头，不会冲刺
##  - 视觉：DrawWoodcutter 同体型矩形+手持斧头+盟友光环
signal died()
signal hited_enemy(dmg: int)

const MAX_HP: int = 100
const BASE_ATK_MIN: int = 10
const BASE_ATK_MAX: int = 16
const CRIT_CHANCE: float = 0.18
const CRIT_MULTIPLIER: float = 1.5
const PATROL_SPD: float = 50.0
const CHASE_SPD: float = 145.0
const PATROL_RANGE: float = 90.0
const CHASE_DIST: float = 620.0
const ATTACK_DIST: float = 92.0
const ATTACK_CD: float = 0.74
const ATTACK_HITBOX_W: float = 108.0
const ATTACK_HITBOX_H: float = 76.0
const GROUP_ALLY := "allies_v02"
const GROUP_ENEMY := "enemies_v02"
const GROUP_PLAYER_CANDIDATE := "player"

var hp: int = MAX_HP
var max_hp: int = MAX_HP
var atk_min: int = BASE_ATK_MIN
var atk_max: int = BASE_ATK_MAX
var _attack_cd: float = 0.0
var _state: String = "patrol"
var _spawn_x: float = 0.0
var _patrol_dir: float = 1.0
var _enemy_node: CharacterBody2D = null
var _player_node: CharacterBody2D = null
var _scene_root: Node = null
var _drawer: Node2D = null
var _face_dir: float = 1.0
var _hurt_t: float = 0.0
var _initialized: bool = false
var _name_tag: String = "樵夫"
var _follow_player_dist: float = 220.0
var _attack_hitbox: Area2D = null
var _attack_hit_shape: CollisionShape2D = null
var _attack_window_left: float = 0.0
var _attack_hit_done: bool = false
var _next_patrol_turn_t: float = 0.0
var _follow_activate_dist: float = 280.0
var _follow_deactivate_dist: float = 170.0
var _attack_state_timer: float = 0.0
const MAX_ATTACK_STATE_TIME: float = 1.2
var _last_on_floor_t: float = 0.0
var _fallback_safety_t: float = 0.0
var _fallback_ground_y: float = 848.0

func _init() -> void:
	collision_layer = 8
	collision_mask = 4
	if not is_in_group(GROUP_ALLY):
		add_to_group(GROUP_ALLY)

func _ready() -> void:
	_initialized = true
	_spawn_x = global_position.x
	velocity = Vector2.ZERO
	collision_layer = 8
	collision_mask = 4
	_acquire_scene_root()
	_drawer = get_node_or_null("Drawer")
	if _drawer and _drawer.has_method("set_halo_on"):
		_drawer.call("set_halo_on", true, Color(0.4, 0.9, 0.6, 0.85))
	_setup_attack_hitbox()
	_refind_player(true)
	_refind_nearest_enemy(true)
	set_physics_process(true)
	set_process(true)
	_fallback_ground_y = 848.0
	if global_position.y > _fallback_ground_y - 30.0:
		_fallback_ground_y = global_position.y - 4.0
	call_deferred("_deferred_force_stuck_fix")

func _deferred_force_stuck_fix() -> void:
	if not is_instance_valid(self):
		return
	collision_layer = 8
	collision_mask = 4
	velocity = Vector2(0, -50)
	if is_inside_tree():
		move_and_slide()
	var t := get_tree().create_timer(0.3)
	t.timeout.connect(_forced_land_check)

func _acquire_scene_root() -> void:
	_scene_root = null
	if get_tree() and is_instance_valid(get_tree()):
		if get_tree().current_scene:
			_scene_root = get_tree().current_scene
	if _scene_root == null and owner:
		_scene_root = owner
	if _scene_root == null and get_parent() and get_parent().get_parent():
		_scene_root = get_parent().get_parent()
	if _scene_root == null and get_tree() and get_tree().root and get_tree().root.get_child_count() > 0:
		for i in range(get_tree().root.get_child_count()):
			var c := get_tree().root.get_child(i)
			if c and c.has_method("damage_player"):
				_scene_root = c
				break

func _setup_attack_hitbox() -> void:
	_attack_hitbox = Area2D.new()
	_attack_hitbox.name = "AxeHitbox"
	_attack_hitbox.monitoring = false
	_attack_hitbox.monitorable = false
	_attack_hitbox.collision_layer = 0
	_attack_hitbox.collision_mask = 2
	_attack_hit_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(ATTACK_HITBOX_W, ATTACK_HITBOX_H)
	_attack_hit_shape.shape = rs
	_attack_hit_shape.position = Vector2(ATTACK_HITBOX_W * 0.5 + 6.0, -4.0)
	_attack_hit_shape.disabled = true
	_attack_hitbox.add_child(_attack_hit_shape)
	add_child(_attack_hitbox)
	_attack_hitbox.body_entered.connect(_on_hitbox_body_entered)

func _on_hitbox_body_entered(body: Node) -> void:
	if _attack_hit_done or body == self or not _attack_window_left > 0.0:
		return
	if body is CharacterBody2D and body.is_in_group(GROUP_ENEMY):
		_attack_hit_done = true
		var base_dmg: int = randi_range(atk_min, atk_max)
		var is_crit: bool = randf() < CRIT_CHANCE
		if is_crit:
			base_dmg = int(float(base_dmg) * CRIT_MULTIPLIER)
		if _player_node and is_instance_valid(_player_node) and _player_node.has_method("get"):
			var pdef = _player_node.get("defense")
			var t_pdef: int = typeof(pdef)
			if t_pdef == TYPE_INT or t_pdef == TYPE_FLOAT:
				base_dmg += int(float(pdef) * 0.3)
		var damage_applied: bool = false
		if body.has_method("take_damage"):
			body.call("take_damage", base_dmg, global_position, is_crit, "woodcutter")
			damage_applied = true
		if not damage_applied and body.has_method("get") and body.has_method("set"):
			var cur_hp = body.get("hp")
			var t_hp: int = typeof(cur_hp)
			if t_hp == TYPE_INT or t_hp == TYPE_FLOAT:
				var new_hp: int = max(0, int(cur_hp) - base_dmg)
				body.set("hp", new_hp)
				damage_applied = true
		if _drawer and _drawer.has_method("on_hit_connect"):
			_drawer.call("on_hit_connect", is_crit)
		hited_enemy.emit(base_dmg)

func _refind_player(force: bool = false) -> void:
	if _player_node and is_instance_valid(_player_node):
		return
	if get_tree() == null:
		return
	var cands := get_tree().get_nodes_in_group(GROUP_PLAYER_CANDIDATE)
	for n in cands:
		if n and is_instance_valid(n) and n is CharacterBody2D and n != self:
			_player_node = n
			return
	if _scene_root and is_instance_valid(_scene_root):
		var pn := _scene_root.get_node_or_null("World/Player")
		if pn and pn is CharacterBody2D and pn != self:
			_player_node = pn

func _refind_nearest_enemy(force: bool = false) -> void:
	if not force and (_enemy_node and is_instance_valid(_enemy_node)):
		if _enemy_node.has_method("get") and _enemy_node.get("hp") and int(_enemy_node.get("hp")) > 0:
			return
	if get_tree() == null:
		return
	var best: CharacterBody2D = null
	var best_d := 1e9
	var cands := get_tree().get_nodes_in_group(GROUP_ENEMY)
	for n in cands:
		if n == null or not is_instance_valid(n) or not (n is CharacterBody2D) or n == self:
			continue
		if not n.has_method("take_damage"):
			continue
		var nd := global_position.distance_to(n.global_position)
		if nd < best_d and nd < CHASE_DIST + 200.0:
			best_d = nd
			best = n
	_enemy_node = best

func take_damage(dmg: int, attacker_pos: Vector2 = Vector2.ZERO, is_crit: bool = false) -> void:
	if hp <= 0 or not _initialized:
		return
	hp = max(0, hp - dmg)
	_hurt_t = 0.28
	if _drawer and _drawer.has_method("flash_red"):
		_drawer.call("flash_red", is_crit) if is_crit else _drawer.flash_red()
	elif _drawer:
		_drawer.modulate = Color(1.4, 0.2, 0.2, 1.0) if is_crit else Color(1.25, 0.4, 0.4, 1.0)
		await get_tree().create_timer(0.12).timeout
		if is_instance_valid(_drawer):
			_drawer.modulate = Color.WHITE
	var kb_power: float = 130.0 if not is_crit else 230.0
	var kb_dir: Vector2 = Vector2.RIGHT
	if attacker_pos != Vector2.ZERO:
		kb_dir = Vector2.RIGHT if global_position.x >= attacker_pos.x else Vector2.LEFT
	elif _enemy_node and is_instance_valid(_enemy_node):
		kb_dir = Vector2.RIGHT if global_position.x > _enemy_node.global_position.x else Vector2.LEFT
	velocity += kb_dir * kb_power
	_refind_nearest_enemy(true)
	if hp <= 0:
		hp = 0
		if _drawer and _drawer.has_method("set_halo_on"):
			_drawer.call("set_halo_on", false)
		died.emit()
		queue_free()

func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	if _hurt_t > 0.0:
		_hurt_t = max(0.0, _hurt_t - delta)
	if _attack_cd > 0.0:
		_attack_cd = max(0.0, _attack_cd - delta)
	if _attack_window_left > 0.0:
		_attack_window_left = max(0.0, _attack_window_left - delta)
		if _attack_window_left <= 0.0 and _attack_hit_shape:
			_attack_hit_shape.disabled = true
			_attack_hit_done = true
	if _attack_state_timer > 0.0:
		_attack_state_timer = max(0.0, _attack_state_timer - delta)
	if Time.get_ticks_msec() % 7 == 0:
		_refind_nearest_enemy(false)
		_refind_player(false)
	if is_on_floor():
		_last_on_floor_t = Time.get_ticks_msec() / 1000.0
	_fallback_safety_t += delta
	if _fallback_safety_t > 0.5:
		_fallback_safety_t = 0.0
		var now_t: float = Time.get_ticks_msec() / 1000.0
		if not is_on_floor() and (now_t - _last_on_floor_t) > 0.8:
			var p: Vector2 = global_position
			p.y = min(p.y, _fallback_ground_y)
			global_position = p
			velocity = Vector2(velocity.x, 0.0)
			if is_inside_tree():
				move_and_slide()
	var target_pos: Vector2 = global_position
	var dist_e: float = 9999.0
	var dist_p: float = 9999.0
	var enemy_alive: bool = (_enemy_node != null) and is_instance_valid(_enemy_node)
	var player_alive: bool = (_player_node != null) and is_instance_valid(_player_node)
	if enemy_alive:
		target_pos = _enemy_node.global_position
		dist_e = global_position.distance_to(target_pos)
	elif player_alive:
		target_pos = _player_node.global_position
		dist_p = global_position.distance_to(target_pos)
	var in_atk: bool = enemy_alive and dist_e < ATTACK_DIST and abs(target_pos.y - global_position.y) < 70.0
	var in_chase: bool = enemy_alive and dist_e < CHASE_DIST
	var should_follow: bool = false
	if player_alive:
		if _state == "follow":
			should_follow = dist_p > _follow_deactivate_dist
		else:
			should_follow = dist_p > _follow_activate_dist
	should_follow = (not in_chase) and should_follow
	var prev_state: String = _state
	if in_atk:
		_state = "attack"
	elif in_chase:
		_state = "chase"
	elif should_follow:
		_state = "follow"
	else:
		_state = "patrol"
	if _state == "attack" and _attack_state_timer <= 0.0:
		_attack_state_timer = MAX_ATTACK_STATE_TIME
	elif _state != "attack":
		_attack_state_timer = 0.0
	if _state == "attack" and _attack_state_timer <= 0.001:
		if in_chase:
			_state = "chase"
		elif should_follow:
			_state = "follow"
		else:
			_state = "patrol"
	var move_x: float = 0.0
	match _state:
		"attack":
			_face_dir = 1.0 if (target_pos.x - global_position.x) >= 0.0 else -1.0
			move_x = 0.0
			if _attack_cd <= 0.0:
				_do_axe_attack()
		"chase":
			var cd: float = 1.0 if target_pos.x >= global_position.x else -1.0
			move_x = cd * CHASE_SPD
			_face_dir = cd
		"follow":
			var fd: float = 1.0 if target_pos.x >= global_position.x else -1.0
			move_x = fd * (CHASE_SPD * 0.75)
			_face_dir = fd
		_:
			var cx := global_position.x
			if cx > _spawn_x + PATROL_RANGE:
				_patrol_dir = -1.0
			elif cx < _spawn_x - PATROL_RANGE:
				_patrol_dir = 1.0
			move_x = _patrol_dir * PATROL_SPD
			_face_dir = _patrol_dir
	velocity.x = move_x
	velocity.y += 1200.0 * delta
	if not is_on_floor():
		velocity.y += 600.0 * delta
	velocity.y = min(velocity.y, 1100.0)
	if _drawer:
		var s: float = sign(_face_dir)
		if abs(s) < 0.001:
			s = 1.0
		_drawer.scale.x = s
		if _attack_hit_shape:
			_attack_hit_shape.position.x = abs(ATTACK_HITBOX_W * 0.5 + 6.0) * s
	move_and_slide()
	velocity = velocity

func _forced_land_check() -> void:
	if not is_instance_valid(self):
		return
	if not is_on_floor():
		var p: Vector2 = global_position
		p.y = _fallback_ground_y
		global_position = p
		velocity = Vector2.ZERO
		if is_inside_tree():
			move_and_slide()

func _do_axe_attack() -> void:
	_attack_cd = ATTACK_CD
	_attack_window_left = 0.24
	_attack_hit_done = false
	if _attack_hitbox:
		_attack_hitbox.monitoring = true
		_attack_hitbox.monitorable = true
	if _attack_hit_shape:
		_attack_hit_shape.disabled = false
	if _drawer and _drawer.has_method("show_ax_slash"):
		_drawer.show_ax_slash(0.28)
	await get_tree().create_timer(0.30).timeout
	if is_instance_valid(self):
		if _attack_hitbox:
			_attack_hitbox.monitoring = false
			_attack_hitbox.monitorable = false
		if _attack_hit_shape:
			_attack_hit_shape.disabled = true
		_attack_hit_done = true

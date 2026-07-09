extends CharacterBody2D
class_name Scarecrow
## 敌人 AI（巡逻/警戒/追击/近战攻击）
##  - 视觉：DrawEnemyRect（浅灰矩形+持剑）；Drawer.show_exclamation() 触发头顶橙色感叹号
##  - 广播：首次发现玩家/盟友时通知 480px 内所有 Scarecrow 进入追击+感叹号
signal died()
signal hited_someone(dmg: int)

var MAX_HP: int = 30
var ATK: int = 10
var PATROL_SPD: float = 40.0
var CHASE_SPD: float = 105.0
var PATROL_RANGE: float = 40.0
var CHASE_DIST: float = 340.0
var ALERT_DIST: float = 560.0
var ATTACK_DIST: float = 60.0
var ATTACK_CD: float = 1.05
const GROUP_ENEMY := "enemies_v02"
const GROUP_PLAYER_CANDIDATE := "player"
const GROUP_ALLY := "allies_v02"
const PATH_PLAYER_FALLBACK := "World/Player"

var hp: int = MAX_HP
var last_killer_type: String = ""
var _attack_cd: float = 0.0
var _state: String = "patrol"  # patrol | alert | chase | attack
var _spawn_x: float = 0.0
var _patrol_dir: float = 1.0
var _target_node: CharacterBody2D = null
var _scene_root: Node = null
var _drawer: Node2D = null
var _face_dir: float = -1.0
var _hurt_t: float = 0.0
var _alerted_by_sight: bool = false
var _forced_chase_until: int = 0
var _refind_target_cooldown: float = 0.0
var _initialized: bool = false
var _atk_hitbox: Area2D = null
var _atk_shape: CollisionShape2D = null
var _atk_window_left: float = 0.0
var _atk_hit_done: bool = false
var _player_prev: CharacterBody2D = null

func _init() -> void:
	collision_layer = 2
	collision_mask = 4
	if not is_in_group(GROUP_ENEMY):
		add_to_group(GROUP_ENEMY)

func _ready() -> void:
	_initialized = true
	_spawn_x = global_position.x
	velocity = Vector2.ZERO
	_acquire_scene_root()
	_drawer = get_node_or_null("Drawer")
	if _drawer:
		_drawer.set_process(true)
	_setup_atk_hitbox()
	_try_refind_target(true)

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

func _setup_atk_hitbox() -> void:
	_atk_hitbox = Area2D.new()
	_atk_hitbox.name = "SwordHitbox"
	_atk_hitbox.monitoring = false
	_atk_hitbox.monitorable = false
	_atk_hitbox.collision_layer = 0
	_atk_hitbox.collision_mask = 1 | 8
	_atk_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(72.0, 54.0)
	_atk_shape.shape = rs
	_atk_shape.position = Vector2(40.0, -2.0)
	_atk_shape.disabled = true
	_atk_hitbox.add_child(_atk_shape)
	add_child(_atk_hitbox)
	_atk_hitbox.body_entered.connect(_on_atk_body_entered)

func _on_atk_body_entered(body: Node) -> void:
	if _atk_hit_done or body == self or _atk_window_left <= 0.0:
		return
	if body is CharacterBody2D:
		var is_opponent: bool = false
		var is_player_hit: bool = false
		var is_ally_hit: bool = false
		if body.is_in_group(GROUP_PLAYER_CANDIDATE):
			is_opponent = true
			is_player_hit = true
		elif body.is_in_group(GROUP_ALLY):
			is_opponent = true
			is_ally_hit = true
		if not is_opponent:
			return
		_atk_hit_done = true
		var damage_applied: bool = false
		if body.has_method("take_damage"):
			body.call("take_damage", ATK, global_position, false)
			damage_applied = true
		if is_player_hit and (not damage_applied) and _scene_root and _scene_root.has_method("damage_player"):
			_scene_root.call("damage_player", ATK)
			damage_applied = true
		if is_player_hit and not damage_applied:
			var alt_root := _find_alt_scene_root()
			if alt_root and alt_root.has_method("damage_player"):
				alt_root.call("damage_player", ATK)
				damage_applied = true
		hited_someone.emit(ATK)

func _find_alt_scene_root() -> Node:
	var candidates: Array[Node] = []
	if get_tree() and get_tree().current_scene:
		candidates.append(get_tree().current_scene)
	if owner:
		candidates.append(owner)
	if get_parent() and get_parent().get_parent():
		candidates.append(get_parent().get_parent())
	if get_tree() and get_tree().root:
		for i in range(get_tree().root.get_child_count()):
			candidates.append(get_tree().root.get_child(i))
	for n in candidates:
		if n and is_instance_valid(n) and n.has_method("damage_player"):
			return n
	return null

func _try_refind_target(force: bool = false) -> void:
	if _target_node and is_instance_valid(_target_node) and _target_node.has_method("get"):
		var still_alive: bool = true
		if _target_node.has_method("get") and _target_node.get("hp") != null:
			if int(_target_node.get("hp")) <= 0:
				still_alive = false
		if still_alive:
			return
	if not force and _refind_target_cooldown > 0.0:
		return
	_refind_target_cooldown = 0.55
	if get_tree() == null:
		return
	var best: CharacterBody2D = null
	var best_d := 1e9
	var cands: Array = []
	var gp := get_tree().get_nodes_in_group(GROUP_PLAYER_CANDIDATE)
	for n in gp:
		cands.append(n)
	var ga := get_tree().get_nodes_in_group(GROUP_ALLY)
	for n in ga:
		cands.append(n)
	for n in cands:
		if n == null or not is_instance_valid(n) or not (n is CharacterBody2D) or n == self:
			continue
		if n.has_method("get") and n.get("hp") != null:
			if int(n.get("hp")) <= 0:
				continue
		var nd := global_position.distance_to(n.global_position)
		if nd < best_d and nd < 900.0:
			best_d = nd
			best = n
	if not best and _scene_root and is_instance_valid(_scene_root):
		var pn := _scene_root.get_node_or_null(PATH_PLAYER_FALLBACK)
		if pn and pn is CharacterBody2D and pn != self:
			best = pn
	_target_node = best

func take_damage(dmg: int, attacker_pos: Vector2 = Vector2.ZERO, is_crit: bool = false, killer_type: String = "") -> void:
	if hp <= 0 or not _initialized:
		return
	if killer_type != "":
		last_killer_type = killer_type
	var was_alive: bool = hp > 0
	hp = max(0, hp - dmg)
	_hurt_t = 0.32
	if _drawer and _drawer.has_method("flash_red"):
		_drawer.call("flash_red", is_crit)
	if _drawer and _drawer.has_method("show_hit_ring"):
		_drawer.call("show_hit_ring", is_crit)
	elif _drawer:
		_drawer.modulate = Color(1.5, 0.15, 0.15, 1.0)
		await get_tree().create_timer(0.22).timeout
		if is_instance_valid(_drawer):
			_drawer.modulate = Color.WHITE
	_forced_chase_until = Time.get_ticks_msec() + 5500
	_try_refind_target(true)
	var knockback_power: float = 170.0
	if is_crit:
		knockback_power = 300.0
	var kb_dir: Vector2 = Vector2.RIGHT
	if attacker_pos != Vector2.ZERO:
		kb_dir = Vector2.RIGHT if global_position.x >= attacker_pos.x else Vector2.LEFT
	elif _target_node:
		kb_dir = Vector2.RIGHT if global_position.x > _target_node.global_position.x else Vector2.LEFT
	velocity += kb_dir * knockback_power
	if not is_on_floor():
		velocity.y = -180.0
	if _target_node:
		_call_ally_alerts(_target_node.global_position, true)
	if was_alive and hp <= 0:
		hp = 0
		died.emit()
		queue_free()

func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	if _hurt_t > 0.0:
		_hurt_t = max(0.0, _hurt_t - delta)
	if _attack_cd > 0.0:
		_attack_cd = max(0.0, _attack_cd - delta)
	if _refind_target_cooldown > 0.0:
		_refind_target_cooldown = max(0.0, _refind_target_cooldown - delta)
	if _atk_window_left > 0.0:
		_atk_window_left = max(0.0, _atk_window_left - delta)
		if _atk_window_left <= 0.0 and _atk_shape:
			_atk_shape.disabled = true
			_atk_hit_done = true
	if Time.get_ticks_msec() % 6 == 0:
		_try_refind_target(false)
	var target_pos: Vector2 = global_position
	var dist_x: float = 9999.0
	var dist: float = 9999.0
	var target_alive: bool = (_target_node != null) and is_instance_valid(_target_node)
	if target_alive:
		target_pos = _target_node.global_position
		dist_x = target_pos.x - global_position.x
		dist = global_position.distance_to(target_pos)
	var now_ms: int = Time.get_ticks_msec()
	var forced_chase: bool = now_ms < _forced_chase_until
	var in_attack_range: bool = target_alive and (dist < ATTACK_DIST) and (abs(target_pos.y - global_position.y) < 28.0)
	var in_chase_range: bool = (target_alive and (dist < CHASE_DIST)) or forced_chase
	var prev_state: String = _state
	if in_attack_range:
		_state = "attack"
	elif in_chase_range:
		if prev_state == "patrol" and target_alive:
			_trigger_sight_alert(target_pos)
		_state = "chase"
	else:
		if forced_chase:
			_state = "chase"
		else:
			_state = "patrol"
			_alerted_by_sight = false
	var move_x: float = 0.0
	match _state:
		"patrol":
			var cx: float = global_position.x
			if cx > _spawn_x + PATROL_RANGE:
				_patrol_dir = -1.0
			elif cx < _spawn_x - PATROL_RANGE:
				_patrol_dir = 1.0
			move_x = _patrol_dir * PATROL_SPD
			_face_dir = _patrol_dir
		"chase":
			var chase_dir: float = 1.0 if dist_x > 0.0 else -1.0
			if not target_alive:
				chase_dir = _patrol_dir
			move_x = chase_dir * CHASE_SPD
			_face_dir = chase_dir
		"attack":
			_face_dir = 1.0 if dist_x >= 0.0 else -1.0
			move_x = 0.0
			if _attack_cd <= 0.0:
				_do_attack()
	velocity.x = move_x
	velocity.y += 1200.0 * delta
	velocity.y = min(velocity.y, 950.0)
	if _drawer:
		var s: float = sign(_face_dir)
		if abs(s) < 0.001:
			s = 1.0
		_drawer.scale.x = s
		if _atk_shape:
			_atk_shape.position.x = abs(32.0) * s
	move_and_slide()
	if Engine.is_editor_hint():
		return
	if false:
		var tag := "SKR1" if global_position.x < 1300.0 else "SKR2"
		print_debug("[%s] x=%.1f y=%.1f st=%s onF=%s vx=%.1f vy=%.1f alive=%s dist=%.0f" % [
			tag, global_position.x, global_position.y, _state,
			str(is_on_floor()), velocity.x, velocity.y,
			str(target_alive), dist])

func _trigger_sight_alert(target_pos: Vector2) -> void:
	if not _alerted_by_sight:
		_alerted_by_sight = true
		if _drawer and _drawer.has_method("show_exclamation"):
			_drawer.show_exclamation(1.1)
		_call_ally_alerts(target_pos, false)
		if _target_node and is_instance_valid(_target_node):
			var kick_dir: float = 1.0 if _target_node.global_position.x >= global_position.x else -1.0
			velocity.x = kick_dir * 150.0

func _call_ally_alerts(player_pos: Vector2, urgent: bool) -> void:
	if not is_in_group(GROUP_ENEMY):
		return
	var src_pos: Vector2 = global_position
	var recipients := get_tree().get_nodes_in_group(GROUP_ENEMY)
	for n in recipients:
		if n == self or not is_instance_valid(n):
			continue
		if n.has_method("_receive_ally_alert"):
			n.call("_receive_ally_alert", src_pos, player_pos, urgent)

func _receive_ally_alert(source_pos: Vector2, player_pos: Vector2, urgent: bool) -> void:
	if not _initialized or not is_instance_valid(self):
		return
	var d := global_position.distance_to(source_pos)
	if d <= ALERT_DIST:
		var chase_ms := 4200 if urgent else 3200
		_forced_chase_until = Time.get_ticks_msec() + chase_ms
		if (_state == "patrol" or not _alerted_by_sight) and _drawer and _drawer.has_method("show_exclamation"):
			_alerted_by_sight = true
			_drawer.show_exclamation(0.95 if urgent else 0.85)
		if _target_node == null and player_pos.distance_to(global_position) < 1100.0:
			_try_refind_target(true)
		if _target_node == null:
			var dir_guess: float = 1.0 if player_pos.x >= global_position.x else -1.0
			_face_dir = dir_guess
			velocity.x = dir_guess * (CHASE_SPD * 1.1)
		else:
			var dir: float = 1.0 if _target_node.global_position.x >= global_position.x else -1.0
			velocity.x = dir * (CHASE_SPD * 1.25)

func _do_attack() -> void:
	_attack_cd = ATTACK_CD
	_atk_window_left = 0.22
	_atk_hit_done = false
	if _atk_hitbox:
		_atk_hitbox.monitoring = true
		_atk_hitbox.monitorable = true
	if _atk_shape:
		_atk_shape.disabled = false
	if _drawer and _drawer.has_method("set_sword_slash"):
		_drawer.set_sword_slash(0.22)
	if _drawer:
		_drawer.modulate = Color(1.1, 0.8, 0.2, 1.0)
	await get_tree().create_timer(0.28).timeout
	if is_instance_valid(self):
		if _atk_hitbox:
			_atk_hitbox.monitoring = false
			_atk_hitbox.monitorable = false
		if _atk_shape:
			_atk_shape.disabled = true
		if _drawer and is_instance_valid(_drawer) and hp > 0:
			_drawer.modulate = Color.WHITE

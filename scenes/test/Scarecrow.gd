extends CharacterBody2D
class_name Scarecrow
## 敌人 AI（巡逻/警戒/追击/近战攻击）
##  - 视觉：DrawEnemyRect（浅灰矩形+持剑）；Drawer.show_exclamation() 触发头顶感叹号
##  - 广播：首次发现玩家时通知 250px 内所有 Scarecrow 进入警戒
signal died()
signal hited_someone(dmg: int)

const MAX_HP: int = 30
const ATK: int = 10
const PATROL_SPD: float = 40.0
const CHASE_SPD: float = 80.0
const PATROL_RANGE: float = 40.0
const CHASE_DIST: float = 220.0
const ALERT_DIST: float = 300.0
const ATTACK_DIST: float = 40.0
const ATTACK_CD: float = 1.1
const GROUP_ENEMY := "enemies_v02"
const GROUP_PLAYER_CANDIDATE := "player"
const PATH_PLAYER_FALLBACK := "World/Player"

var hp: int = MAX_HP
var _attack_cd: float = 0.0
var _state: String = "patrol"  # patrol | alert | chase | attack
var _spawn_x: float = 0.0
var _patrol_dir: float = 1.0
var _player_node: CharacterBody2D = null
var _scene_root: Node = null
var _drawer: Node2D = null
var _face_dir: float = -1.0
var _hurt_t: float = 0.0
var _alerted_by_sight: bool = false
var _forced_chase_until: int = 0
var _refind_player_cooldown: float = 0.0
var _initialized: bool = false

func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 4

func _ready() -> void:
	_initialized = true
	_spawn_x = global_position.x
	velocity = Vector2.ZERO
	if not is_in_group(GROUP_ENEMY):
		add_to_group(GROUP_ENEMY)
	_scene_root = get_tree().current_scene
	_drawer = get_node_or_null("Drawer")
	if _drawer:
		_drawer.set_process(true)
	_try_refind_player(true)

func _try_refind_player(force: bool = false) -> void:
	if _player_node and is_instance_valid(_player_node):
		return
	if not force and _refind_player_cooldown > 0.0:
		return
	_refind_player_cooldown = 0.6
	if get_tree() == null:
		return
	var candidates := get_tree().get_nodes_in_group(GROUP_PLAYER_CANDIDATE)
	for n in candidates:
		if n and is_instance_valid(n) and n is CharacterBody2D and n != self:
			_player_node = n
			return
	if _scene_root and is_instance_valid(_scene_root):
		var pn := _scene_root.get_node_or_null(PATH_PLAYER_FALLBACK)
		if pn and pn is CharacterBody2D and pn != self:
			_player_node = pn
			return
		var found := _scene_root.find_child("Player", true, false)
		if found and found is CharacterBody2D and found != self:
			_player_node = found
			return

func take_damage(dmg: int) -> void:
	if hp <= 0 or not _initialized:
		return
	hp = max(0, hp - dmg)
	_hurt_t = 0.2
	if _drawer and _drawer.has_method("flash_red"):
		_drawer.flash_red()
	elif _drawer:
		_drawer.modulate = Color(1.3, 0.3, 0.3, 1.0)
		await get_tree().create_timer(0.18).timeout
		if is_instance_valid(_drawer):
			_drawer.modulate = Color.WHITE
	_forced_chase_until = Time.get_ticks_msec() + 3500
	_try_refind_player(true)
	if _player_node:
		var dir := Vector2.RIGHT if global_position.x > _player_node.global_position.x else Vector2.LEFT
		velocity += dir * 90.0
		_call_ally_alerts(_player_node.global_position)
	if hp <= 0:
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
	if _refind_player_cooldown > 0.0:
		_refind_player_cooldown = max(0.0, _refind_player_cooldown - delta)
	if _player_node == null or not is_instance_valid(_player_node):
		_try_refind_player()
	var target_pos: Vector2 = global_position
	var dist_x: float = 9999.0
	var dist: float = 9999.0
	var player_alive := _player_node and is_instance_valid(_player_node)
	if player_alive:
		target_pos = _player_node.global_position
		dist_x = target_pos.x - global_position.x
		dist = global_position.distance_to(target_pos)
	var now_ms: int = Time.get_ticks_msec()
	var forced_chase := now_ms < _forced_chase_until
	var in_attack_range := player_alive and dist < ATTACK_DIST and abs(target_pos.y - global_position.y) < 28.0
	var in_chase_range := (player_alive and dist < CHASE_DIST) or forced_chase
	var prev_state := _state
	if in_attack_range:
		_state = "attack"
	elif in_chase_range:
		if prev_state == "patrol" and player_alive:
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
			if not player_alive:
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
	if is_on_floor():
		velocity.x = move_toward(velocity.x, move_x, 800.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, move_x, 200.0 * delta)
	if _drawer:
		var s: float = sign(_face_dir)
		if abs(s) < 0.001:
			s = 1.0
		_drawer.scale.x = s
	move_and_slide()

func _trigger_sight_alert(target_pos: Vector2) -> void:
	if not _alerted_by_sight:
		_alerted_by_sight = true
		if _drawer and _drawer.has_method("show_exclamation"):
			_drawer.show_exclamation(0.9)
		_call_ally_alerts(target_pos)

func _call_ally_alerts(player_pos: Vector2) -> void:
	if not is_in_group(GROUP_ENEMY):
		return
	var src_pos: Vector2 = global_position
	var recipients := get_tree().get_nodes_in_group(GROUP_ENEMY)
	for n in recipients:
		if n == self or not is_instance_valid(n):
			continue
		if n.has_method("_receive_ally_alert"):
			n.call("_receive_ally_alert", src_pos, player_pos)

func _receive_ally_alert(source_pos: Vector2, player_pos: Vector2) -> void:
	if not _initialized or not is_instance_valid(self):
		return
	var d := global_position.distance_to(source_pos)
	if d <= ALERT_DIST:
		_forced_chase_until = Time.get_ticks_msec() + 2500
		if _drawer and _drawer.has_method("show_exclamation") and _state == "patrol":
			_drawer.show_exclamation(0.8)
		if _player_node == null and player_pos.distance_to(global_position) < 900.0:
			_try_refind_player(true)

func _do_attack() -> void:
	_attack_cd = ATTACK_CD
	if _drawer and _drawer.has_method("set_sword_slash"):
		_drawer.set_sword_slash(0.22)
	if _scene_root and _scene_root.has_method("damage_player"):
		_scene_root.call("damage_player", ATK)
	hited_someone.emit(ATK)
	if _drawer:
		_drawer.modulate = Color(1.1, 0.8, 0.2, 1.0)
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(_drawer) and hp > 0:
			_drawer.modulate = Color.WHITE

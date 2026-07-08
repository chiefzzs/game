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
const CHASE_DIST: float = 180.0
const ALERT_DIST: float = 260.0
const ATTACK_DIST: float = 34.0
const ATTACK_CD: float = 1.2
const GROUP_ENEMY := "enemies_v02"

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
var _forced_chase_until: float = 0.0

func _ready() -> void:
	_spawn_x = global_position.x
	if not is_in_group(GROUP_ENEMY):
		add_to_group(GROUP_ENEMY)
	if get_tree().current_scene:
		_scene_root = get_tree().current_scene
		var w: Node = _scene_root.get_node_or_null("World")
		if w and w.has_node("Player"):
			_player_node = w.get_node("Player")
	_drawer = get_node_or_null("Drawer")
	collision_layer = 2
	collision_mask = 1 | 4

func take_damage(dmg: int) -> void:
	if hp <= 0:
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
	if _player_node:
		var dir := Vector2.RIGHT if global_position.x > _player_node.global_position.x else Vector2.LEFT
		velocity += dir * 90.0
		_call_ally_alerts(_player_node.global_position)
	if hp <= 0:
		hp = 0
		died.emit()
		queue_free()

func _physics_process(delta: float) -> void:
	if _hurt_t > 0.0:
		_hurt_t = max(0.0, _hurt_t - delta)
	if _attack_cd > 0.0:
		_attack_cd = max(0.0, _attack_cd - delta)
	var target_pos: Vector2 = global_position
	var dist_x: float = 9999.0
	var dist: float = 9999.0
	var player_alive := _player_node and is_instance_valid(_player_node)
	if player_alive:
		target_pos = _player_node.global_position
		dist_x = target_pos.x - global_position.x
		dist = global_position.distance_to(target_pos)
	var forced_chase := Time.get_ticks_msec() < _forced_chase_until
	var in_attack_range := dist < ATTACK_DIST and abs(target_pos.y - global_position.y) < 22.0
	var in_chase_range := dist < CHASE_DIST or forced_chase
	var prev_state := _state
	if in_attack_range:
		_state = "attack"
	elif in_chase_range:
		if prev_state == "patrol":
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
			if global_position.x > _spawn_x + PATROL_RANGE:
				_patrol_dir = -1.0
			elif global_position.x < _spawn_x - PATROL_RANGE:
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
	velocity.y += 1100.0 * delta
	velocity.y = min(velocity.y, 900.0)
	if _drawer:
		_drawer.scale.x = 1.0 if _face_dir >= 0.0 else -1.0
	move_and_slide()
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)

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
	if not is_instance_valid(self):
		return
	var d := global_position.distance_to(source_pos)
	if d <= ALERT_DIST:
		_forced_chase_until = Time.get_ticks_msec() + 2500
		if _drawer and _drawer.has_method("show_exclamation") and _state == "patrol":
			_drawer.show_exclamation(0.7)

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

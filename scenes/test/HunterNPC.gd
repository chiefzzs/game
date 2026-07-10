extends CharacterBody2D
class_name HunterNPC
## 猎人 NPC（玩家盟友）：中速攻击高伤害低血量的远程弓箭友军
##  - 数值：HP65 攻击18-24，攻速0.9s，暴击18%
##  - 行为：**强制紧跟玩家不超过5格(≈160px)**，超出立刻全速跟上；15米内所有敌人都射箭
##  - 视觉：DrawHunter 墨绿色游猎斗篷+猎帽+手持弓箭+蓝色盟友光环

signal died()
signal hited_enemy(dmg: int)

const MAX_HP: int = 65
const BASE_ATK_MIN: int = 18
const BASE_ATK_MAX: int = 24
const CRIT_CHANCE: float = 0.18
const CRIT_MULTIPLIER: float = 1.6
const PATROL_SPD: float = 60.0
const CHASE_SPD: float = 160.0
const KITE_SPD: float = 180.0
const PATROL_RANGE: float = 80.0
const ATTACK_RADIUS: float = 1500.0
const MIN_SHOOT_DIST: float = 180.0
const KITE_DIST: float = 220.0
const ATTACK_CD: float = 0.9
const DRAW_BOW_DUR: float = 0.32
const GROUP_ALLY := "allies_v02"
const GROUP_ENEMY := "enemies_v02"
const GROUP_PLAYER_CANDIDATE := "player"
const PATH_ARROW_FALLBACK := "res://scenes/test/Arrow.tscn"
const FOLLOW_ACTIVATE_DIST: float = 170.0
const FOLLOW_DEACTIVATE_DIST: float = 130.0
const MAX_ALLOWED_DIST_FROM_PLAYER: float = 170.0

var hp: int = MAX_HP
var max_hp: int = MAX_HP
var atk_min: int = BASE_ATK_MIN
var atk_max: int = BASE_ATK_MAX
var _attack_cd: float = 0.0
var _draw_bow_t: float = 0.0
var _is_drawing: bool = false
var _current_target: CharacterBody2D = null
var _pending_fire_pos: Vector2 = Vector2.ZERO
var _state: String = "patrol"
var _spawn_x: float = 0.0
var _patrol_dir: float = 1.0
var _player_node: CharacterBody2D = null
var _scene_root: Node = null
var _drawer: Node2D = null
var _face_dir: float = 1.0
var _hurt_t: float = 0.0
var _initialized: bool = false
var _name_tag: String = "猎人"
var _last_on_floor_t: float = 0.0
var _fallback_safety_t: float = 0.0
var _fallback_ground_y: float = 848.0
var _next_patrol_turn_t: float = 0.0
var _refind_tick: int = 0

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
		_drawer.call("set_halo_on", true, Color(0.35, 0.6, 1.0, 0.85))
	_refind_player(true)
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

func _refind_player(force: bool = false) -> void:
	if _player_node and is_instance_valid(_player_node):
		if force:
			pass
		else:
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

func _find_best_attack_target() -> CharacterBody2D:
	if get_tree() == null:
		return null
	var best: CharacterBody2D = null
	var best_d: float = ATTACK_RADIUS + 1.0
	var cands := get_tree().get_nodes_in_group(GROUP_ENEMY)
	for n in cands:
		if n == null or not is_instance_valid(n) or not (n is CharacterBody2D):
			continue
		if not n.has_method("take_damage"):
			continue
		if n.has_method("get"):
			var nhp = n.get("hp")
			if typeof(nhp) == TYPE_INT or typeof(nhp) == TYPE_FLOAT:
				if int(nhp) <= 0:
					continue
		var nd: float = global_position.distance_to(n.global_position)
		var dy_ok: bool = abs(global_position.y - n.global_position.y) < 180.0
		if nd < best_d and nd <= ATTACK_RADIUS and nd >= MIN_SHOOT_DIST * 0.6 and dy_ok:
			best_d = nd
			best = n
	return best

func _collect_all_attackable_enemies() -> Array:
	var result: Array = []
	if get_tree() == null:
		return result
	var cands := get_tree().get_nodes_in_group(GROUP_ENEMY)
	for n in cands:
		if n == null or not is_instance_valid(n) or not (n is CharacterBody2D):
			continue
		if not n.has_method("take_damage"):
			continue
		if n.has_method("get"):
			var nhp = n.get("hp")
			if typeof(nhp) == TYPE_INT or typeof(nhp) == TYPE_FLOAT:
				if int(nhp) <= 0:
					continue
		var nd: float = global_position.distance_to(n.global_position)
		var dy_ok: bool = abs(global_position.y - n.global_position.y) < 180.0
		if nd <= ATTACK_RADIUS and nd >= MIN_SHOOT_DIST * 0.5 and dy_ok:
			result.append(n)
	return result

func take_damage(dmg: int, attacker_pos: Vector2 = Vector2.ZERO, is_crit: bool = false) -> void:
	if hp <= 0 or not _initialized:
		return
	hp = max(0, hp - dmg)
	_hurt_t = 0.28
	if _drawer and _drawer.has_method("flash_red"):
		if is_crit and _drawer.has_method("call"):
			_drawer.call("flash_red", true)
		else:
			_drawer.flash_red()
	elif _drawer:
		_drawer.modulate = Color(1.4, 0.2, 0.2, 1.0) if is_crit else Color(1.25, 0.4, 0.4, 1.0)
		await get_tree().create_timer(0.12).timeout
		if is_instance_valid(_drawer):
			_drawer.modulate = Color.WHITE
	var kb_power: float = 140.0 if not is_crit else 250.0
	var kb_dir: Vector2 = Vector2.RIGHT
	if attacker_pos != Vector2.ZERO:
		kb_dir = Vector2.RIGHT if global_position.x >= attacker_pos.x else Vector2.LEFT
	velocity += kb_dir * kb_power
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
	if _is_drawing and _draw_bow_t > 0.0:
		_draw_bow_t = max(0.0, _draw_bow_t - delta)
		if _draw_bow_t <= 0.0 and _current_target and is_instance_valid(_current_target):
			var fire_pos: Vector2 = _current_target.global_position
			_fire_arrow(fire_pos)
			_is_drawing = false
			_attack_cd = ATTACK_CD
			if _drawer and _drawer.has_method("release_arrow"):
				_drawer.call("release_arrow")
	_refind_tick += 1
	if _refind_tick % 5 == 0:
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
	var player_alive: bool = (_player_node != null) and is_instance_valid(_player_node)
	_current_target = _find_best_attack_target()
	var has_target: bool = _current_target != null
	var dist_target: float = 99999.0
	var dist_player: float = 99999.0
	if has_target:
		target_pos = _current_target.global_position
		dist_target = global_position.distance_to(target_pos)
	if player_alive:
		dist_player = global_position.distance_to(_player_node.global_position)
	var force_follow_player: bool = player_alive and (dist_player > MAX_ALLOWED_DIST_FROM_PLAYER)
	var follow_target_pos: Vector2 = _player_node.global_position if player_alive else global_position
	var in_shoot_range: bool = (not force_follow_player) and has_target and (dist_target <= ATTACK_RADIUS) and (dist_target >= MIN_SHOOT_DIST)
	var kite_needed: bool = (not force_follow_player) and has_target and dist_target < KITE_DIST
	var should_follow: bool = false
	if player_alive:
		if _state == "follow":
			should_follow = dist_player > FOLLOW_DEACTIVATE_DIST
		else:
			should_follow = dist_player > FOLLOW_ACTIVATE_DIST
	should_follow = force_follow_player or ((not has_target) and should_follow)
	var prev_state: String = _state
	if force_follow_player:
		_state = "follow"
		target_pos = follow_target_pos
	elif kite_needed and not in_shoot_range:
		_state = "kite"
	elif in_shoot_range:
		_state = "attack"
	elif has_target:
		_state = "approach"
	elif should_follow:
		_state = "follow"
		target_pos = follow_target_pos
	else:
		_state = "patrol"
	var move_x: float = 0.0
	match _state:
		"attack":
			_face_dir = 1.0 if (target_pos.x - global_position.x) >= 0.0 else -1.0
			move_x = 0.0
			if _attack_cd <= 0.0 and not _is_drawing:
				_is_drawing = true
				_draw_bow_t = DRAW_BOW_DUR
				if _drawer and _drawer.has_method("start_draw_bow"):
					_drawer.call("start_draw_bow", DRAW_BOW_DUR)
		"kite":
			_is_drawing = false
			_draw_bow_t = 0.0
			var kite_dir: float = -1.0 if (target_pos.x - global_position.x) > 0.0 else 1.0
			move_x = kite_dir * KITE_SPD
			_face_dir = -kite_dir
		"approach":
			_is_drawing = false
			_draw_bow_t = 0.0
			var ap_dir: float = 1.0 if (target_pos.x - global_position.x) >= 0.0 else -1.0
			move_x = ap_dir * CHASE_SPD
			_face_dir = ap_dir
		"follow":
			_is_drawing = false
			_draw_bow_t = 0.0
			var fd: float = 1.0 if (target_pos.x - global_position.x) >= 0.0 else -1.0
			var spd_factor: float = 1.0 if force_follow_player else 0.85
			move_x = fd * (CHASE_SPD * spd_factor)
			_face_dir = fd
		_:
			_is_drawing = false
			_draw_bow_t = 0.0
			var cx: float = global_position.x
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

func _fire_arrow(target_pos: Vector2) -> void:
	var arrow_scene: PackedScene = load(PATH_ARROW_FALLBACK)
	if arrow_scene == null:
		return
	var arrow: Node = arrow_scene.instantiate()
	if not arrow:
		return
	var world_parent: Node = get_parent()
	if world_parent == null:
		if get_tree() and get_tree().current_scene:
			world_parent = get_tree().current_scene
	if world_parent == null:
		return
	world_parent.add_child(arrow)
	var s: float = sign(_face_dir)
	if abs(s) < 0.001:
		s = 1.0
	var shoot_from: Vector2 = global_position + Vector2(16.0 * s, -16.0)
	arrow.global_position = shoot_from
	var dir: Vector2 = (target_pos + Vector2(0.0, -22.0)) - shoot_from
	if dir.length() < 0.001:
		dir = Vector2(s, 0.0)
	dir = dir.normalized()
	var base_dmg: int = randi_range(atk_min, atk_max)
	var is_crit: bool = randf() < CRIT_CHANCE
	if is_crit:
		base_dmg = int(float(base_dmg) * CRIT_MULTIPLIER)
	if arrow.has_method("fire"):
		arrow.call("fire", dir * 720.0, base_dmg, is_crit, true)
	hited_enemy.emit(base_dmg)
	if _drawer and _drawer.has_method("on_arrow_fired"):
		_drawer.call("on_arrow_fired", is_crit)

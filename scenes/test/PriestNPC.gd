extends CharacterBody2D
class_name PriestNPC
## 牧师 NPC（玩家盟友）：无攻击，持续群疗+跟随玩家
##  - 数值：HP55，低血量脆皮职业，每2秒给10格内所有友军恢复10%最大血量
##  - 行为：**强制紧跟玩家不超过6格(≈200px)**，敌人靠近时后退保命
##  - 视觉：DrawPriest 白袍+金饰+手持黄金权杖木柄+金色盟友光环

signal died()
signal healed_ally(unit: Node, amount: int)

const MAX_HP: int = 55
const PATROL_SPD: float = 55.0
const CHASE_SPD: float = 150.0
const RETREAT_SPD: float = 185.0
const PATROL_RANGE: float = 70.0
const GROUP_ALLY := "allies_v02"
const GROUP_ENEMY := "enemies_v02"
const GROUP_PLAYER_CANDIDATE := "player"
const HEAL_RADIUS: float = 340.0
const HEAL_INTERVAL: float = 2.0
const HEAL_PERCENT: float = 0.10
const FOLLOW_ACTIVATE_DIST: float = 180.0
const FOLLOW_DEACTIVATE_DIST: float = 140.0
const MAX_ALLOWED_DIST_FROM_PLAYER: float = 200.0
const DANGER_DIST: float = 120.0

var hp: int = MAX_HP
var max_hp: int = MAX_HP
var _heal_cd: float = 0.8
var _heal_anim_t: float = 0.0
var _is_healing_anim: bool = false
var _state: String = "follow"
var _spawn_x: float = 0.0
var _patrol_dir: float = 1.0
var _player_node: CharacterBody2D = null
var _scene_root: Node = null
var _drawer: Node2D = null
var _face_dir: float = 1.0
var _hurt_t: float = 0.0
var _initialized: bool = false
var _name_tag: String = "牧师"
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
		_drawer.call("set_halo_on", true, Color(1.0, 0.86, 0.35, 0.88))
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

func _find_nearest_enemy() -> CharacterBody2D:
	if get_tree() == null:
		return null
	var best: CharacterBody2D = null
	var best_d: float = 99999.0
	var cands := get_tree().get_nodes_in_group(GROUP_ENEMY)
	for n in cands:
		if n == null or not is_instance_valid(n) or not (n is CharacterBody2D):
			continue
		if n.has_method("get"):
			var nhp = n.get("hp")
			if typeof(nhp) == TYPE_INT or typeof(nhp) == TYPE_FLOAT:
				if int(nhp) <= 0:
					continue
		var nd: float = global_position.distance_to(n.global_position)
		if nd < best_d:
			best_d = nd
			best = n
	return best

func _collect_healable_allies() -> Array:
	var result: Array = []
	if get_tree() == null:
		return result
	var groups: Array[String] = [GROUP_ALLY, GROUP_PLAYER_CANDIDATE]
	for g in groups:
		var cands := get_tree().get_nodes_in_group(g)
		for n in cands:
			if n == null or not is_instance_valid(n):
				continue
			if n != self and not (n is CharacterBody2D):
				continue
			var info = _get_unit_hp_info(n)
			if info == null:
				continue
			var cur: int = info["cur"]
			var mx: int = info["max"]
			if cur <= 0 or cur >= mx:
				continue
			var nd: float = global_position.distance_to(n.global_position)
			var dy_ok: bool = abs(global_position.y - n.global_position.y) < 220.0
			if nd <= HEAL_RADIUS and dy_ok:
				result.append(n)
	if self.has_method("get"):
		var shp = self.get("hp")
		var smax = self.get("max_hp")
		if typeof(shp) in [TYPE_INT, TYPE_FLOAT] and typeof(smax) in [TYPE_INT, TYPE_FLOAT]:
			if int(shp) < int(smax) and int(shp) > 0:
				if not result.has(self):
					result.append(self)
	return result

func _get_unit_hp_info(n: Node) -> Dictionary:
	if n == null or not is_instance_valid(n):
		return null
	if n.has_method("get"):
		var nhp = n.get("hp")
		var nmax = n.get("max_hp")
		if (typeof(nhp) == TYPE_INT or typeof(nhp) == TYPE_FLOAT) and (typeof(nmax) == TYPE_INT or typeof(nmax) == TYPE_FLOAT):
			return {"cur": int(nhp), "max": int(nmax), "mode": "direct", "target": n}
	if n is CharacterBody2D and n.is_in_group(GROUP_PLAYER_CANDIDATE):
		var wrapper: Node = _find_player_wrapper(n)
		if wrapper and wrapper.has_method("get"):
			var whp = wrapper.get("_hp")
			var wmax = wrapper.get("_hp_max")
			if (typeof(whp) == TYPE_INT or typeof(whp) == TYPE_FLOAT) and (typeof(wmax) == TYPE_INT or typeof(wmax) == TYPE_FLOAT):
				return {"cur": int(whp), "max": int(wmax), "mode": "wrapper", "target": wrapper}
	return null

func _find_player_wrapper(player_node: CharacterBody2D) -> Node:
	if player_node == null:
		return null
	var p: Node = player_node.get_parent()
	var tries: int = 0
	while p and tries < 4:
		if p.has_method("set_hp") or (p.has_method("get") and (p.get("_hp") != null or p.get("player_hp") != null)):
			return p
		p = p.get_parent()
		tries += 1
	if _scene_root and is_instance_valid(_scene_root):
		if _scene_root.has_method("set_hp") or _scene_root.has_method("get"):
			var r_hp = _scene_root.get("_hp")
			if typeof(r_hp) == TYPE_INT or typeof(r_hp) == TYPE_FLOAT:
				return _scene_root
	return null

func _apply_heal_to_unit(n: Node, heal_amt: int) -> bool:
	if n == null:
		return false
	if n == self:
		var before: int = hp
		hp = clamp(hp + heal_amt, 0, max_hp)
		return hp > before
	if n.has_method("set_hp"):
		var info = _get_unit_hp_info(n)
		if info and info.has("cur"):
			var target_val: int = clamp(int(info["cur"]) + heal_amt, 0, int(info["max"]))
			if info["mode"] == "wrapper":
				if info["target"].has_method("set_hp"):
					info["target"].call("set_hp", target_val)
					return true
			else:
				n.call("set_hp", target_val)
				return true
	elif n.has_method("get"):
		var info = _get_unit_hp_info(n)
		if info and info.has("cur") and info.has("target"):
			var tgt: Node = info["target"]
			var field_name: String = "hp" if info["mode"] == "direct" else "_hp"
			var target_val: int = clamp(int(info["cur"]) + heal_amt, 0, int(info["max"]))
			tgt.set(field_name, target_val)
			if tgt.has_method("_refresh_bars"):
				tgt.call("_refresh_bars")
			return true
	return false

func _do_heal_burst() -> void:
	var allies: Array = _collect_healable_allies()
	var healed_count: int = 0
	for n in allies:
		if n == null or not is_instance_valid(n):
			continue
		var info = _get_unit_hp_info(n)
		if info == null:
			continue
		var mx: int = int(info["max"])
		var heal_amt: int = max(1, int(float(mx) * HEAL_PERCENT))
		if _apply_heal_to_unit(n, heal_amt):
			healed_count += 1
			healed_ally.emit(n, heal_amt)
	if healed_count > 0:
		_is_healing_anim = true
		_heal_anim_t = 0.45
		if _drawer and _drawer.has_method("trigger_heal_flash"):
			_drawer.call("trigger_heal_flash", healed_count)

func take_damage(dmg: int, attacker_pos: Vector2 = Vector2.ZERO, is_crit: bool = false) -> void:
	if hp <= 0 or not _initialized:
		return
	hp = max(0, hp - dmg)
	_hurt_t = 0.3
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
	var kb_power: float = 160.0 if not is_crit else 280.0
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

func _process(delta: float) -> void:
	if _is_healing_anim and _heal_anim_t > 0.0:
		_heal_anim_t = max(0.0, _heal_anim_t - delta)
		if _heal_anim_t <= 0.0:
			_is_healing_anim = false

func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	if _hurt_t > 0.0:
		_hurt_t = max(0.0, _hurt_t - delta)
	if _heal_cd > 0.0:
		_heal_cd = max(0.0, _heal_cd - delta)
	if _heal_cd <= 0.0:
		_do_heal_burst()
		_heal_cd = HEAL_INTERVAL
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
	var nearest_enemy: CharacterBody2D = _find_nearest_enemy()
	var has_danger: bool = nearest_enemy != null
	var dist_enemy: float = 99999.0
	var dist_player: float = 99999.0
	if has_danger:
		dist_enemy = global_position.distance_to(nearest_enemy.global_position)
	if player_alive:
		dist_player = global_position.distance_to(_player_node.global_position)
	var force_follow_player: bool = player_alive and (dist_player > MAX_ALLOWED_DIST_FROM_PLAYER)
	var follow_target_pos: Vector2 = _player_node.global_position if player_alive else global_position
	var need_retreat: bool = (not force_follow_player) and has_danger and (dist_enemy < DANGER_DIST)
	var should_follow: bool = false
	if player_alive:
		if _state == "follow":
			should_follow = dist_player > FOLLOW_DEACTIVATE_DIST
		else:
			should_follow = dist_player > FOLLOW_ACTIVATE_DIST
	should_follow = force_follow_player or ((not has_danger or need_retreat) and should_follow)
	var prev_state: String = _state
	if force_follow_player:
		_state = "follow"
		target_pos = follow_target_pos
	elif need_retreat:
		_state = "retreat"
	elif should_follow:
		_state = "follow"
		target_pos = follow_target_pos
	else:
		_state = "patrol"
	var move_x: float = 0.0
	match _state:
		"retreat":
			var retreat_dir: float = -1.0 if (nearest_enemy.global_position.x - global_position.x) > 0.0 else 1.0
			var follow_bias: float = 0.0
			if player_alive:
				var pd: float = _player_node.global_position.x - global_position.x
				if (retreat_dir > 0 and pd < -40.0) or (retreat_dir < 0 and pd > 40.0):
					follow_bias = 0.55
			move_x = retreat_dir * RETREAT_SPD * (1.0 - follow_bias * 0.4)
			_face_dir = -retreat_dir
			if player_alive and dist_player > MAX_ALLOWED_DIST_FROM_PLAYER * 0.85:
				var fd: float = 1.0 if (_player_node.global_position.x - global_position.x) >= 0.0 else -1.0
				move_x = fd * CHASE_SPD * 0.92
				_face_dir = fd
		"follow":
			var fd: float = 1.0 if (target_pos.x - global_position.x) >= 0.0 else -1.0
			var spd_factor: float = 1.0 if force_follow_player else 0.82
			move_x = fd * (CHASE_SPD * spd_factor)
			_face_dir = fd
		_:
			var cx: float = global_position.x
			var patrol_anchor: float = _player_node.global_position.x if player_alive else _spawn_x
			if cx > patrol_anchor + PATROL_RANGE:
				_patrol_dir = -1.0
			elif cx < patrol_anchor - PATROL_RANGE:
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

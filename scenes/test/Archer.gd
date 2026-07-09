extends Scarecrow
class_name Archer
## 弓箭手敌人：**完全复用 Scarecrow 的移动/碰撞/巡逻/追击逻辑（100%确保能动！）**
##  - 继承自Scarecrow，血量 20HP（低血量）
##  - 20米内检测到玩家立刻行动（CHASE_DIST/ATTACK范围调大）
##  - 攻击覆盖为远程射箭，15伤害，拉弓动画

const OVERRIDE_MAX_HP: int = 20
const OVERRIDE_ARROW_DAMAGE: int = 15
const OVERRIDE_SIGHT: float = 2000.0
const OVERRIDE_SHOOT_MIN: float = 180.0
const OVERRIDE_SHOOT_MAX: float = 1500.0
const OVERRIDE_PATROL_SPD: float = 55.0
const OVERRIDE_CHASE_SPD: float = 120.0
const OVERRIDE_PATROL_RANGE: float = 260.0
const OVERRIDE_ATTACK_DIST: float = 1500.0
const OVERRIDE_ALERT: float = 2200.0
const OVERRIDE_ATTACK_CD: float = 1.1
const DRAW_DUR: float = 0.48
const PATH_ARROW_FALLBACK := "res://scenes/test/Arrow.tscn"

var _draw_bow_t: float = 0.0
var _is_drawing: bool = false
var _last_target_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	super._init()
	MAX_HP = OVERRIDE_MAX_HP
	ATK = OVERRIDE_ARROW_DAMAGE
	PATROL_SPD = OVERRIDE_PATROL_SPD
	CHASE_SPD = OVERRIDE_CHASE_SPD
	PATROL_RANGE = OVERRIDE_PATROL_RANGE
	CHASE_DIST = OVERRIDE_SIGHT
	ATTACK_DIST = OVERRIDE_ATTACK_DIST
	ALERT_DIST = OVERRIDE_ALERT
	ATTACK_CD = OVERRIDE_ATTACK_CD
	name = "Archer"

func _ready() -> void:
	hp = OVERRIDE_MAX_HP
	super._ready()
	_initialized = true
	set_process(true)
	set_physics_process(true)

func _setup_atk_hitbox() -> void:
	pass

func _do_attack() -> void:
	if _attack_cd > 0.0:
		return
	if not _target_node or not is_instance_valid(_target_node):
		return
	_last_target_pos = _target_node.global_position
	if not _is_drawing:
		_is_drawing = true
		_draw_bow_t = DRAW_DUR
		if _drawer and _drawer.has_method("start_draw_bow"):
			_drawer.call("start_draw_bow", DRAW_DUR)
		return
	if _draw_bow_t > 0.0:
		return
	_fire_arrow(_last_target_pos)
	_is_drawing = false
	_attack_cd = ATTACK_CD
	if _drawer and _drawer.has_method("release_arrow"):
		_drawer.call("release_arrow")

func _physics_process(delta: float) -> void:
	if not _initialized:
		super._physics_process(delta)
		return
	if _hurt_t > 0.0:
		_hurt_t = max(0.0, _hurt_t - delta)
	if _attack_cd > 0.0:
		_attack_cd = max(0.0, _attack_cd - delta)
	if _refind_target_cooldown > 0.0:
		_refind_target_cooldown = max(0.0, _refind_target_cooldown - delta)
	else:
		_refind_target_cooldown = 0.18
		_try_refind_target(false)
	if _is_drawing and _draw_bow_t > 0.0:
		_draw_bow_t = max(0.0, _draw_bow_t - delta)
		if _draw_bow_t <= 0.0 and _target_node and is_instance_valid(_target_node):
			_last_target_pos = _target_node.global_position
			_fire_arrow(_last_target_pos)
			_is_drawing = false
			_attack_cd = ATTACK_CD
			if _drawer and _drawer.has_method("release_arrow"):
				_drawer.call("release_arrow")
	var now_ms: int = Time.get_ticks_msec()
	var target_alive: bool = _target_node and is_instance_valid(_target_node)
	var target_pos: Vector2 = _target_node.global_position if target_alive else global_position
	var dist: float = global_position.distance_to(target_pos) if target_alive else 99999.0
	var dist_x: float = target_pos.x - global_position.x
	var forced_chase: bool = now_ms < _forced_chase_until
	var dy_ok: bool = abs(target_pos.y - global_position.y) < 160.0
	var in_shoot_range: bool = target_alive and (dist >= OVERRIDE_SHOOT_MIN) and (dist <= OVERRIDE_SHOOT_MAX) and dy_ok
	var in_chase_range: bool = (target_alive and (dist < OVERRIDE_SIGHT)) or forced_chase
	var too_close: bool = target_alive and dist < (OVERRIDE_SHOOT_MIN - 20.0)
	var prev_state: String = _state
	if too_close:
		if prev_state == "patrol" and target_alive:
			_trigger_sight_alert(target_pos)
		_state = "kite"
	elif in_shoot_range:
		_state = "attack"
	elif in_chase_range:
		if prev_state == "patrol" and target_alive:
			_trigger_sight_alert(target_pos)
		_state = "chase"
	else:
		_state = "patrol"
		_alerted_by_sight = false
	var move_x: float = 0.0
	match _state:
		"patrol":
			_is_drawing = false
			_draw_bow_t = 0.0
			var cx: float = global_position.x
			if cx > _spawn_x + PATROL_RANGE:
				_patrol_dir = -1.0
			elif cx < _spawn_x - PATROL_RANGE:
				_patrol_dir = 1.0
			move_x = _patrol_dir * PATROL_SPD
			_face_dir = _patrol_dir
		"chase":
			_is_drawing = false
			_draw_bow_t = 0.0
			var chase_dir: float = 1.0 if dist_x > 0.0 else -1.0
			if not target_alive:
				chase_dir = _patrol_dir
			move_x = chase_dir * CHASE_SPD
			_face_dir = chase_dir
		"kite":
			_is_drawing = false
			_draw_bow_t = 0.0
			var kite_dir: float = -1.0 if dist_x > 0.0 else 1.0
			if not target_alive:
				kite_dir = _patrol_dir
			move_x = kite_dir * CHASE_SPD
			_face_dir = -kite_dir
		"attack":
			_face_dir = 1.0 if dist_x >= 0.0 else -1.0
			move_x = 0.0
			if _attack_cd <= 0.0 and not _is_drawing:
				_is_drawing = true
				_draw_bow_t = DRAW_DUR
				if _drawer and _drawer.has_method("start_draw_bow"):
					_drawer.call("start_draw_bow", DRAW_DUR)
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
	var shoot_from: Vector2 = global_position + Vector2(16.0 * s, -12.0)
	arrow.global_position = shoot_from
	var dir: Vector2 = (target_pos + Vector2(0.0, -22.0)) - shoot_from
	if dir.length() < 0.001:
		dir = Vector2(s, 0.0)
	dir = dir.normalized()
	if arrow.has_method("fire"):
		arrow.call("fire", dir * 680.0, OVERRIDE_ARROW_DAMAGE)

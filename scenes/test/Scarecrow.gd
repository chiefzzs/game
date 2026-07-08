extends CharacterBody2D
class_name Scarecrow
## Scarecrow enemy AI: patrol / chase / melee-attack player.
##   - HP 30, ATK 10, patrol speed 40, chase speed 80
##   - Patrols ±40px from spawn; chases player when <180px distance;
##     attacks when <34px, 1.2s cooldown, calls damage_player(ATK) on scene root
##   - take_damage(dmg) -> blood flash + HP down; emits died() when killed
##   - Scene root should connect died() to drop gold pickups.
signal died()
signal hited_someone(dmg: int)

const MAX_HP: int = 30
const ATK: int = 10
const PATROL_SPD: float = 40.0
const CHASE_SPD: float = 80.0
const PATROL_RANGE: float = 40.0
const CHASE_DIST: float = 180.0
const ATTACK_DIST: float = 34.0
const ATTACK_CD: float = 1.2

var hp: int = MAX_HP
var _attack_cd: float = 0.0
var _state: String = "patrol"  # patrol | chase | attack
var _spawn_x: float = 0.0
var _patrol_dir: float = 1.0
var _player_node: CharacterBody2D = null
var _scene_root: Node = null
var _drawer: Node2D = null
var _face_dir: float = -1.0  # face left by default for scarecrows on the right of map
var _hurt_t: float = 0.0

func _ready() -> void:
	_spawn_x = global_position.x
	# grab nodes using fixed scene structure of V01_InputCollisionTest
	if get_tree().current_scene:
		_scene_root = get_tree().current_scene
		var w: Node = _scene_root.get_node_or_null("World")
		if w and w.has_node("Player"):
			_player_node = w.get_node("Player")
	_drawer = get_node_or_null("Drawer")
	# physics settings: Layer 2=Enemy; mask 1=Player + 4=Terrain
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
	# pushback (knockback)
	if _player_node:
		var dir := Vector2.RIGHT if global_position.x > _player_node.global_position.x else Vector2.LEFT
		velocity += dir * 90.0
	if hp <= 0:
		hp = 0
		died.emit()
		queue_free()

func _physics_process(delta: float) -> void:
	if _hurt_t > 0.0:
		_hurt_t = max(0.0, _hurt_t - delta)
	if _attack_cd > 0.0:
		_attack_cd = max(0.0, _attack_cd - delta)
	# ---- 1. find target (player) & compute distance ----
	var target_pos: Vector2 = global_position
	var dist_x: float = 9999.0
	var dist: float = 9999.0
	if _player_node and is_instance_valid(_player_node):
		target_pos = _player_node.global_position
		dist_x = target_pos.x - global_position.x
		dist = global_position.distance_to(target_pos)
	# ---- 2. state switch ----
	if dist < ATTACK_DIST and abs(target_pos.y - global_position.y) < 22.0:
		_state = "attack"
	elif dist < CHASE_DIST:
		_state = "chase"
	else:
		_state = "patrol"
	# ---- 3. compute velocity by state ----
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
			move_x = chase_dir * CHASE_SPD
			_face_dir = chase_dir
		"attack":
			# face player, stop movement
			_face_dir = 1.0 if dist_x >= 0.0 else -1.0
			move_x = 0.0
			if _attack_cd <= 0.0:
				_do_attack()
	velocity.x = move_x
	velocity.y += 1100.0 * delta  # gravity
	velocity.y = min(velocity.y, 900.0)
	# mirror drawer sprite
	if _drawer:
		_drawer.scale.x = 1.0 if _face_dir >= 0.0 else -1.0
	move_and_slide()
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)

func _do_attack() -> void:
	_attack_cd = ATTACK_CD
	# Call scene root damage_player(ATK) — scene must implement this method
	if _scene_root and _scene_root.has_method("damage_player"):
		_scene_root.call("damage_player", ATK)
	hited_someone.emit(ATK)
	# visual tell: drawer shake briefly via modulate (light red pulse)
	if _drawer:
		_drawer.modulate = Color(1.1, 0.8, 0.2, 1.0)
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(_drawer) and hp > 0:
			_drawer.modulate = Color.WHITE

extends Area2D
class_name Arrow
## 弓箭手发射的箭矢：
##  - 高速直线飞行，敌方箭打玩家/友军；友方箭打敌人
##  - 撞到地形或 2.4 秒后自动销毁
## 公共API：fire(velocity_vector, damage_amount, is_crit=false, is_ally=false)

const GROUP_PLAYER_CANDIDATE := "player"
const GROUP_ALLY := "allies_v02"
const GROUP_ENEMY := "enemies_v02"
const GROUP_WORLD_HIT := "world"

var _damage: int = 15
var _life: float = 2.4
var _fired: bool = false
var _vel: Vector2 = Vector2.ZERO
var _trail_t: float = 0.0
var _dead: bool = false
var _is_crit: bool = false
var _is_ally_arrow: bool = false
var _attacker_tag: String = "archer"

func _ready() -> void:
	body_entered.connect(_on_body_hit)
	area_entered.connect(_on_area_hit)
	set_process(true)

func fire(v: Vector2, dmg: int, is_crit: bool = false, is_ally: bool = false) -> void:
	_vel = v
	_damage = dmg
	_is_crit = is_crit
	_is_ally_arrow = is_ally
	_attacker_tag = "hunter" if is_ally else "archer"
	_fired = true
	rotation = v.angle()

func _process(delta: float) -> void:
	if not _fired or _dead:
		return
	_life -= delta
	_trail_t += delta
	if _life <= 0.0:
		_destroy_self()
		return
	var prev_pos: Vector2 = global_position
	var next_pos: Vector2 = prev_pos + _vel * delta
	global_position = next_pos
	rotation = _vel.angle()
	if _vel.length() > 1.0:
		var space_state := get_world_2d().direct_space_state
		if space_state:
			var query := PhysicsRayQueryParameters2D.create(prev_pos, next_pos)
			query.collision_mask = 4
			var res = space_state.intersect_ray(query)
			if not res.is_empty():
				_destroy_self()

func _on_body_hit(b: Node) -> void:
	if _dead:
		return
	if b == self:
		return
	var should_hit: bool = false
	var is_player_target: bool = false
	if _is_ally_arrow:
		if b.is_in_group(GROUP_ENEMY):
			should_hit = true
	else:
		if b.is_in_group(GROUP_PLAYER_CANDIDATE):
			should_hit = true
			is_player_target = true
		elif b.is_in_group(GROUP_ALLY):
			should_hit = true
	if should_hit:
		if b.has_method("take_damage"):
			b.call("take_damage", _damage, global_position, _is_crit, _attacker_tag)
		elif b.has_method("get_parent") and is_instance_valid(b.get_parent()):
			var p: Node = b.get_parent()
			if p and p.has_method("damage_player") and is_player_target:
				p.call("damage_player", _damage)
			elif p and p.has_method("take_damage"):
				p.call("take_damage", _damage, global_position, _is_crit, _attacker_tag)
		_destroy_self()
		return
	if b.collision_layer & 4:
		_destroy_self()

func _on_area_hit(a: Area2D) -> void:
	if _dead:
		return
	if a.is_in_group("pickup") or a.name == "RakePickup" or a.name == "Gold" or a.name == "Potion":
		return
	if a.has_method("get_parent") and is_instance_valid(a.get_parent()):
		var p: Node = a.get_parent()
		var should_hit_area: bool = false
		var is_player_area: bool = false
		if _is_ally_arrow:
			if p and p.is_in_group(GROUP_ENEMY):
				should_hit_area = true
		else:
			if p and (p.is_in_group(GROUP_PLAYER_CANDIDATE) or p.is_in_group(GROUP_ALLY)):
				should_hit_area = true
				if p.is_in_group(GROUP_PLAYER_CANDIDATE):
					is_player_area = true
		if should_hit_area:
			if p.has_method("take_damage"):
				p.call("take_damage", _damage, global_position, _is_crit, _attacker_tag)
			elif p.has_method("get_parent") and is_instance_valid(p.get_parent()):
				var pp: Node = p.get_parent()
				if pp and pp.has_method("damage_player") and is_player_area:
					pp.call("damage_player", _damage)
			_destroy_self()

func _destroy_self() -> void:
	if _dead:
		return
	_dead = true
	set_process(false)
	queue_free()

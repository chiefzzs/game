extends Scarecrow
class_name EliteScarecrow
## 精英敌人（持盾稻草人）：
##  - 在普通稻草人基础上，增加左手盾牌
##  - 正面攻击（玩家/樵夫面对敌人正面）时：盾牌格挡，伤害无效
##  - 樵夫攻击3次后，盾牌消失，可正常造成伤害
signal shield_broken()

const WOODCUTTER_BREAK_HITS: int = 3
const ELITE_MAX_HP: int = 70
const _ELITE_COLLISION_LAYER: int = 2
const _ELITE_COLLISION_MASK: int = 4
var has_shield: bool = true
var woodcutter_hit_count: int = 0
var shield_break_flash_t: float = 0.0

func _init() -> void:
	super._init()
	collision_layer = _ELITE_COLLISION_LAYER
	collision_mask = _ELITE_COLLISION_MASK
	if not is_in_group(GROUP_ENEMY):
		add_to_group(GROUP_ENEMY)
	name = "EliteScarecrow"

func _ready() -> void:
	collision_layer = _ELITE_COLLISION_LAYER
	collision_mask = _ELITE_COLLISION_MASK
	if not is_in_group(GROUP_ENEMY):
		add_to_group(GROUP_ENEMY)
	super._ready()
	hp = ELITE_MAX_HP
	_initialized = true
	set_process(true)
	set_physics_process(true)
	if not _drawer or not is_instance_valid(_drawer):
		_drawer = get_node_or_null("Drawer")
	if _drawer:
		_drawer.set_process(true)
		_drawer.queue_redraw()
	if not _atk_hitbox or not is_instance_valid(_atk_hitbox):
		_setup_atk_hitbox()
	_try_refind_target(true)

func take_damage(dmg: int, attacker_pos: Vector2 = Vector2.ZERO, is_crit: bool = false, killer_type: String = "") -> void:
	if hp <= 0 or not _initialized:
		return
	if killer_type != "":
		last_killer_type = killer_type
	if has_shield:
		var attacker_in_front: bool = false
		if attacker_pos != Vector2.ZERO:
			if _face_dir > 0.0:
				attacker_in_front = attacker_pos.x >= global_position.x
			else:
				attacker_in_front = attacker_pos.x <= global_position.x
		elif _target_node and is_instance_valid(_target_node):
			if _face_dir > 0.0:
				attacker_in_front = _target_node.global_position.x >= global_position.x
			else:
				attacker_in_front = _target_node.global_position.x <= global_position.x
		if attacker_in_front:
			shield_break_flash_t = 0.25
			var is_woodcutter: bool = (killer_type == "woodcutter")
			if is_woodcutter:
				woodcutter_hit_count += 1
				if _drawer and _drawer.has_method("on_shield_hit_woodcutter"):
					_drawer.call("on_shield_hit_woodcutter", woodcutter_hit_count, WOODCUTTER_BREAK_HITS)
				elif _drawer:
					_drawer.queue_redraw()
				if woodcutter_hit_count >= WOODCUTTER_BREAK_HITS:
					has_shield = false
					shield_broken.emit()
					if _drawer and _drawer.has_method("on_shield_broken"):
						_drawer.call("on_shield_broken")
					elif _drawer:
						_drawer.queue_redraw()
					var scene_root = _scene_root
					if scene_root and scene_root.has_method("hud"):
						scene_root.call("hud", "🛡️💥 精英怪盾牌被樵夫击碎！可正常造成伤害")
			else:
				if _drawer and _drawer.has_method("on_shield_blocked"):
					_drawer.call("on_shield_blocked")
				elif _drawer:
					_drawer.queue_redraw()
			return
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
	if shield_break_flash_t > 0.0:
		shield_break_flash_t = max(0.0, shield_break_flash_t - delta)
		if _drawer:
			_drawer.queue_redraw()
	super._physics_process(delta)

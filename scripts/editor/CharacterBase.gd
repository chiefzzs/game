extends CharacterBody2D
class_name CharacterBase
## V0.2 迭代2 T02-P01：CharacterBase 角色基类（并行开发组）
## 统一 HP/受伤/硬直/朝向/死亡 接口。
## 玩家 PlayerController / 同伴 Companion / 敌人 EnemyBase 都继承此基类。
## 所有数值默认值从 ConfigManager L2 balance.json 读取（缺失时走下面的 fallback）。

signal hp_changed(old_hp: int, new_hp: int, max_hp: int)
signal died(killer: Node)
signal hit(dmg: int, source: Node, is_crit: bool)
signal face_changed(old_face: float, new_face: float)

const DEFAULT_MAX_HP: int = 100
const DEFAULT_ATK: int = 10
const DEFAULT_HITSTUN: float = 0.18
const DEFAULT_KNOCKBACK: float = 120.0

enum CharacterKind { PLAYER, COMPANION, ENEMY }

var kind: int = CharacterKind.PLAYER
var character_id: String = "unnamed"
var display_name: String = "角色"

var max_hp: int = DEFAULT_MAX_HP
var hp: int = DEFAULT_MAX_HP
var atk: int = DEFAULT_ATK
var hitstun: float = 0.0
var is_dead: bool = false
var facing: float = 1.0  # 1.0 朝右, -1.0 朝左（与 drawer.scale.x 对齐语义）
var is_invulnerable: bool = false
var invulnerable_timer: float = 0.0
var last_damage_source: Node = null
var last_damage_ts: int = 0

func _ready() -> void:
	hp = max_hp
	set_process(true)
	set_physics_process(true)

func set_max_hp(new_max: int, auto_fill: bool = true) -> void:
	if new_max <= 0:
		return
	var old := max_hp
	max_hp = new_max
	if auto_fill:
		set_hp(max_hp, null)
	elif hp > max_hp:
		set_hp(max_hp, null)
	else:
		hp_changed.emit(hp, hp, max_hp)

func set_hp(new_hp: int, source: Node = null) -> void:
	if is_dead:
		return
	var old := hp
	hp = clamp(new_hp, 0, max_hp)
	if hp != old:
		hp_changed.emit(old, hp, max_hp)
	last_damage_source = source
	if hp <= 0:
		die(source)

func take_damage(dmg: int, source: Node = null, opts: Dictionary = {}) -> int:
	if is_dead or is_invulnerable:
		return 0
	if dmg <= 0:
		return 0
	# opts: {"crit":bool, "knockback":float, "hitstun":float, "ignore_block":bool}
	var final_dmg := dmg
	var is_crit := opts.get("crit", false)
	# apply hitstun
	hitstun = max(hitstun, opts.get("hitstun", DEFAULT_HITSTUN))
	# apply knockback (X only; caller also can set velocity after)
	var kb: float = opts.get("knockback", DEFAULT_KNOCKBACK)
	if kb > 0.0 and source and is_instance_valid(source):
		var dir := 1.0 if source.global_position.x < global_position.x else -1.0
		velocity.x += dir * kb
	# final dmg clamp (keep 1 min)
	final_dmg = max(1, final_dmg)
	last_damage_ts = Time.get_ticks_msec()
	hit.emit(final_dmg, source, is_crit)
	set_hp(hp - final_dmg, source)
	return final_dmg

func heal(amount: int, source: Node = null) -> int:
	if is_dead or amount <= 0:
		return 0
	var old := hp
	set_hp(hp + amount, source)
	return hp - old

func set_facing(new_face: float) -> void:
	if abs(new_face) < 0.01:
		return
	var sign_val := 1.0 if new_face >= 0.0 else -1.0
	if sign_val != facing:
		var old := facing
		facing = sign_val
		face_changed.emit(old, facing)

func set_invulnerable(duration: float) -> void:
	if duration <= 0.0:
		is_invulnerable = false
		invulnerable_timer = 0.0
		return
	is_invulnerable = true
	invulnerable_timer = max(invulnerable_timer, duration)

func die(source: Node = null) -> void:
	if is_dead:
		return
	is_dead = true
	hp = 0
	died.emit(source)

func _process(delta: float) -> void:
	if is_invulnerable and invulnerable_timer > 0.0:
		invulnerable_timer = max(0.0, invulnerable_timer - delta)
		if invulnerable_timer <= 0.0:
			is_invulnerable = false

func _physics_process(delta: float) -> void:
	if hitstun > 0.0:
		hitstun = max(0.0, hitstun - delta)
	# 子类 override 实现具体移动/战斗逻辑

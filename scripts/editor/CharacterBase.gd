extends CharacterBody2D
class_name CharacterBase
## V0.2 迭代2 T02-P01：CharacterBase 角色基类（并行开发组）
## 统一 HP/受伤/硬直/朝向/死亡 接口。
## 玩家 PlayerController / 同伴 Companion / 敌人 EnemyBase 都继承此基类。
## 所有数值默认值从 ConfigManager L2 balance.json 读取（缺失时走下面的 fallback）。
##
## V0.3c 增量（签名 100% 冻结 One Track 兼容）：
##  - FSM 8 状态骨架：state/prev_state + change_state() 严格跳转表
##  - take_damage 内部接入 CDC（仅 opts._use_cdc=true 时启用；否则走 V0.2 原逻辑）
##  - stamina / max_stamina + 每秒恢复
##  - _autoload(name) 安全取单例（杜绝 Engine.get_singleton）

signal hp_changed(old_hp: int, new_hp: int, max_hp: int)
signal died(killer: Node)
signal hit(dmg: int, source: Node, is_crit: bool)
signal face_changed(old_face: float, new_face: float)
# V0.3c 新增信号（追加末尾，不碰旧 4 个）
signal state_changed(old_state: int, new_state: int)
signal stats_changed()

const DEFAULT_MAX_HP: int = 100
const DEFAULT_ATK: int = 10
const DEFAULT_HITSTUN: float = 0.18
const DEFAULT_KNOCKBACK: float = 120.0
# V0.3c 新增默认值
const DEFAULT_MAX_STAMINA: int = 50
const DEFAULT_DEFENSE: int = 1
const _STAMINA_REGEN_PER_SEC: float = 10.0

const _CDC_SCRIPT := preload("res://scripts/combat/CombatDamageCalculator.gd")
const _CE := preload("res://scripts/config/CharacterEnums.gd")

enum CharacterKind { PLAYER, COMPANION, ENEMY }

# V0.3c FSM 状态枚举（追加末尾，不碰旧 CharacterKind 数值）
enum FSMState {
	IDLE,      # 0  静止待机
	RUN,       # 1  左右移动
	JUMP,      # 2  跳跃上升/下落
	ATTACK1,   # 3  一段攻击
	ATTACK2,   # 4  二段连击（V0.3d 玩家实装）
	ATTACK3,   # 5  三段连击
	HURT,      # 6  受伤硬直
	BLOCK,     # 7  举盾格挡
	DEAD,      # 8  死亡（自锁）
	DOUBLEJUMP,# 9  V0.3d 新增：二段跳上升/下落
	DASH       # 10 V0.3d 新增：冲刺位移+无敌帧
}

# ========= V0.2 旧字段（全部保留，一字不动顺序/类型） =========
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
## V0.3d 别名：外部统一使用 is_invincible / invincible_timer（双写同步旧 V0.2 名）
var is_invincible: bool = false:
	get: return is_invulnerable
	set(v): is_invulnerable = v
var invincible_timer: float = 0.0:
	get: return invulnerable_timer
	set(v): invulnerable_timer = v
var last_damage_source: Node = null
var last_damage_ts: int = 0

# ========= V0.3c 新增字段（全部追加末尾，不碰旧字段偏移） =========
var state: int = FSMState.IDLE
var prev_state: int = FSMState.IDLE
var defense: int = DEFAULT_DEFENSE
var max_stamina: int = DEFAULT_MAX_STAMINA
var stamina: int = DEFAULT_MAX_STAMINA
var no_die: bool = false
var move_speed: float = 260.0
var jump_force: float = -520.0
var gravity: float = 1800.0
var weapon: Dictionary = {}

# FSM 合法跳转表（索引 = From 状态；数组元素 = 允许的 To 状态）
var _legal_transition: Dictionary = {
	FSMState.IDLE:    [FSMState.IDLE, FSMState.RUN, FSMState.JUMP, FSMState.ATTACK1, FSMState.HURT, FSMState.BLOCK, FSMState.DEAD, FSMState.DASH],
	FSMState.RUN:     [FSMState.IDLE, FSMState.RUN, FSMState.JUMP, FSMState.ATTACK1, FSMState.HURT, FSMState.BLOCK, FSMState.DEAD, FSMState.DASH],
	FSMState.JUMP:    [FSMState.IDLE, FSMState.RUN, FSMState.JUMP, FSMState.ATTACK1, FSMState.HURT, FSMState.DEAD, FSMState.DOUBLEJUMP, FSMState.DASH],
	FSMState.ATTACK1: [FSMState.ATTACK1, FSMState.ATTACK2, FSMState.HURT, FSMState.DEAD],
	FSMState.ATTACK2: [FSMState.ATTACK2, FSMState.ATTACK3, FSMState.HURT, FSMState.DEAD],
	FSMState.ATTACK3: [FSMState.IDLE, FSMState.ATTACK3, FSMState.HURT, FSMState.DEAD],
	FSMState.HURT:    [FSMState.IDLE, FSMState.HURT, FSMState.DEAD],
	FSMState.BLOCK:   [FSMState.IDLE, FSMState.BLOCK, FSMState.HURT, FSMState.DEAD, FSMState.DASH],
	FSMState.DEAD:    [FSMState.DEAD],
	FSMState.DOUBLEJUMP: [FSMState.IDLE, FSMState.RUN, FSMState.HURT, FSMState.DEAD],
	FSMState.DASH:    [FSMState.IDLE, FSMState.RUN, FSMState.JUMP, FSMState.HURT, FSMState.DEAD]
}

# ========= V0.3c 新增：安全 _autoload 工具函数（杜绝 Engine.get_singleton） =========
func _autoload(name: String) -> Node:
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("/root/" + name)

func _ready() -> void:
	hp = max_hp
	stamina = max_stamina
	set_process(true)
	set_physics_process(true)
	# V0.3c：FSM 初始状态
	state = FSMState.IDLE
	prev_state = FSMState.IDLE

# V0.3c 新增：FSM 状态切换（严格按跳转表；非法返回错误码，state 不变；非崩溃）
func change_state(to: int) -> Error:
	if state == FSMState.DEAD and to != FSMState.DEAD:
		return ERR_DOES_NOT_EXIST
	if to < 0 or to > FSMState.DASH:
		return ERR_INVALID_PARAMETER
	if not _legal_transition.has(state):
		return ERR_INVALID_PARAMETER
	var allows: Array = _legal_transition[state]
	if to not in allows:
		return ERR_DOES_NOT_EXIST
	if state == to:
		return OK
	prev_state = state
	state = to
	state_changed.emit(prev_state, state)
	_on_state_enter(prev_state, to)
	return OK

# V0.3c 可被子类 override 的状态进入钩子
func _on_state_enter(_from: int, _to: int) -> void:
	pass

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
	stats_changed.emit()

func set_hp(new_hp: int, source: Node = null) -> void:
	if is_dead:
		return
	var old := hp
	hp = clamp(new_hp, 0, max_hp)
	if hp != old:
		hp_changed.emit(old, hp, max_hp)
	last_damage_source = source
	if hp <= 0 and not no_die:
		die(source)

# =====================================================================
# take_damage（签名 100% 冻结 = V0.2 一字不动！！！One Track 保证）
#  扩展逻辑：仅当 opts 有 _use_cdc=true + 3 个 CDC 入参字典时走新路径；
#            否则 100% 走 V0.2 原逻辑（稻草人/巡逻兵零行为变化）
# =====================================================================
func take_damage(dmg: int, source: Node = null, opts: Dictionary = {}) -> int:
	if is_dead or is_invulnerable:
		return 0

	# ========= V0.3c 新增：CDC 路径（显式开关 _use_cdc=true 才进入） =========
	var use_cdc: bool = bool(opts.get("_use_cdc", false))
	if use_cdc and _CDC_SCRIPT != null and opts.has("attacker_dict") and opts.has("context_dict"):
		var atkr_dict: Dictionary = opts["attacker_dict"]
		var ctx_dict: Dictionary = opts["context_dict"]
		var victim_override: Dictionary = opts.get("victim_override", {})
		var victim_stats: Dictionary = _build_victim_stats_for_cdc(victim_override)
		var cdc: RefCounted = _CDC_SCRIPT.new()
		var r: Dictionary = cdc.calculate_damage(atkr_dict, victim_stats, ctx_dict)
		var final_dmg: int = int(r.final_damage)
		if final_dmg <= 0:
			final_dmg = 1
		var is_crit: bool = bool(r.is_crit)
		# 应用 V0.2 兼容处理：hitstun / 击退
		hitstun = max(hitstun, opts.get("hitstun", DEFAULT_HITSTUN))
		if r.has("knockback") and source and is_instance_valid(source):
			var kb_vec: Vector2 = r.knockback
			if abs(kb_vec.x) > 0.01:
				velocity.x += kb_vec.x
			if abs(kb_vec.y) > 0.01:
				velocity.y += kb_vec.y
		last_damage_ts = Time.get_ticks_msec()
		# V0.2 旧信号（一字不动，订阅者零修改）
		hit.emit(final_dmg, source, is_crit)
		set_hp(hp - final_dmg, source)
		# V0.3c FSM：自动切 HURT（除非已经 DEAD）
		if state != FSMState.DEAD:
			change_state(FSMState.HURT)
		return final_dmg

	# ========= V0.2 原逻辑（未开启 CDC 时，100% 字节级相同；稻草人/巡逻兵专用） =========
	if dmg <= 0:
		return 0
	# opts: {"crit":bool, "knockback":float, "hitstun":float, "ignore_block":bool}
	var final_dmg: int = dmg
	var is_crit: bool = bool(opts.get("crit", false))
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
	# V0.3c FSM：V0.2 路径下也自动切 HURT（保持一致用户感知）
	if state != FSMState.DEAD:
		change_state(FSMState.HURT)
	return final_dmg

# V0.3c 辅助：构造 CDC 受害者字典（victim_override 覆盖 self 字段，方便测试）
func _build_victim_stats_for_cdc(override: Dictionary) -> Dictionary:
	var base: Dictionary = {
		"def": defense,
		"hp": hp,
		"hp_max": max_hp,
		"stamina": stamina,
		"stamina_max": max_stamina,
		"facing": int(facing),
		"is_blocking": state == FSMState.BLOCK,
		"position": global_position,
		"kind": kind
	}
	for k in override.keys():
		base[k] = override[k]
	return base

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
	# V0.3c：碰撞体失效（安全兜底，子类也可再关）
	collision_layer = 0
	collision_mask = 0
	set_process(false)
	# V0.3c FSM：切 DEAD（自锁）
	change_state(FSMState.DEAD)
	died.emit(source)
	stats_changed.emit()
	# 延迟 2 秒后销毁（给动画/特效留时间；测试场景无树时，直接 call_deferred 不崩）
	if get_tree() != null and is_inside_tree():
		var t: SceneTreeTimer = get_tree().create_timer(2.0, false)
		t.timeout.connect(queue_free, CONNECT_ONE_SHOT)
	else:
		call_deferred("queue_free")

func _process(delta: float) -> void:
	if is_invulnerable and invulnerable_timer > 0.0:
		invulnerable_timer = max(0.0, invulnerable_timer - delta)
		if invulnerable_timer <= 0.0:
			is_invulnerable = false

func _physics_process(delta: float) -> void:
	if hitstun > 0.0:
		hitstun = max(0.0, hitstun - delta)
		if hitstun <= 0.0 and state == FSMState.HURT:
			change_state(FSMState.IDLE)
	if not is_dead and hitstun <= 0.0 and state != FSMState.DEAD and max_stamina > 0:
		var before: int = stamina
		stamina = clamp(int(float(stamina) + _STAMINA_REGEN_PER_SEC * delta), 0, max_stamina)
		if stamina != before:
			stats_changed.emit()

func regenerate_stamina(delta: float, is_blocking: bool = false) -> void:
	if is_dead or state == FSMState.DEAD or max_stamina <= 0:
		return
	var regen_rate: float = _STAMINA_REGEN_PER_SEC
	if is_blocking:
		regen_rate = -10.0
	var before: int = stamina
	stamina = clamp(int(float(stamina) + regen_rate * delta), 0, max_stamina)
	if stamina != before:
		stats_changed.emit()


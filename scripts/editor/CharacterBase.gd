## V0.3 scripts/editor/CharacterBase.gd — 所有角色公共基类（验收Phase1要求 + Phase5 FSM基础）

func _autoload(name: String) -> Node:
	var st: SceneTree = get_tree()
	if st == null or st.root == null:
		var ml = Engine.get_main_loop()
		if ml is SceneTree:
			st = ml
		else:
			return null
	return st.root.get_node_or_null(NodePath("/root/" + name))
## 核心: FSM状态机 + 属性字段 + 生命周期钩子 + 战斗伤害接收接口

extends CharacterBody2D
class_name CharacterBase

enum CharacterKind { INVALID = 0, PLAYER = 1, COMPANION = 2, ENEMY = 3 }
enum BaseState { IDLE = 0, RUN = 1, JUMP = 2, DOUBLEJUMP = 3, DASH = 4,
                 ATTACK1 = 5, ATTACK2 = 6, ATTACK3 = 7,
                 BLOCK = 8, HURT = 9, DEAD = 10 }

var kind: CharacterKind = CharacterKind.INVALID
var id_key: String = ""
var display_name: String = ""
var facing: float = 1.0 # 1 right, -1 left
var max_hp: int = 100
var hp: int = 100
var max_stamina: float = 100.0
var stamina: float = 100.0
var stamina_regen_per_sec: float = 15.0
var base_atk: int = 5
var base_def: int = 0
var move_speed: float = 240.0
var jump_force: float = -480.0
var gravity: float = 1800.0
var weapon: Dictionary = {}

var state: BaseState = BaseState.IDLE
var prev_state: BaseState = BaseState.IDLE
var state_timer: float = 0.0
var combo_index: int = 0
var combo_window_left: float = 0.0
var is_invincible: bool = false
var invincible_timer: float = 0.0
var alive: bool = true

# === FSM Core ===
func state_name(s: int) -> String:
	match s:
		BaseState.IDLE: return "IDLE"
		BaseState.RUN: return "RUN"
		BaseState.JUMP: return "JUMP"
		BaseState.DOUBLEJUMP: return "DOUBLEJUMP"
		BaseState.DASH: return "DASH"
		BaseState.ATTACK1: return "ATTACK1"
		BaseState.ATTACK2: return "ATTACK2"
		BaseState.ATTACK3: return "ATTACK3"
		BaseState.BLOCK: return "BLOCK"
		BaseState.HURT: return "HURT"
		BaseState.DEAD: return "DEAD"
	return "UNKNOWN"

func change_state(new_state: BaseState) -> bool:
	if state == new_state:
		return false
	if state == BaseState.DEAD and new_state != BaseState.DEAD:
		return false
	prev_state = state
	on_state_exit(prev_state, new_state)
	state = new_state
	state_timer = 0.0
	on_state_enter(state, prev_state)
	on_any_state_changed(prev_state, state)
	return true

func on_state_enter(_new_s: BaseState, _old_s: BaseState) -> void:
	pass
func on_state_exit(_old_s: BaseState, _new_s: BaseState) -> void:
	pass
func on_any_state_changed(_from: BaseState, _to: BaseState) -> void:
	pass

func tick_state(delta: float) -> void:
	state_timer += delta
	combo_window_left = max(0.0, combo_window_left - delta)
	if invincible_timer > 0.0:
		invincible_timer -= delta
		if invincible_timer <= 0.0:
			is_invincible = false
	match state:
		BaseState.IDLE:    _tick_idle(delta)
		BaseState.RUN:     _tick_run(delta)
		BaseState.JUMP, BaseState.DOUBLEJUMP: _tick_air(delta)
		BaseState.DASH:    _tick_dash(delta)
		BaseState.ATTACK1, BaseState.ATTACK2, BaseState.ATTACK3: _tick_attack(delta)
		BaseState.BLOCK:   _tick_block(delta)
		BaseState.HURT:    _tick_hurt(delta)
		BaseState.DEAD:    _tick_dead(delta)

func regenerate_stamina(delta: float, blocked: bool = false) -> void:
	if blocked:
		stamina = max(0.0, stamina - delta * 15.0)
	else:
		stamina = min(max_stamina, stamina + delta * stamina_regen_per_sec)

func take_damage(attacker: Node, raw_atk: int, dmg_type: String = "physical",
                 dir: Vector2 = Vector2.RIGHT, is_shield_break_weapon: bool = false) -> Dictionary:
	if not alive or state == BaseState.DEAD:
		return {"is_miss": true, "final_damage": 0, "reason": "already_dead"}
	if is_invincible:
		return {"is_miss": true, "final_damage": 0, "reason": "invincible"}
	var cdc_script: GDScript = load("res://scripts/combat/CombatDamageCalculator.gd")
	if cdc_script == null:
		var fallback: int = max(1, raw_atk - base_def)
		_apply_damage(fallback, attacker, dir, 100.0)
		return {"final_damage": fallback, "is_crit":false,"is_backstab":false,"is_blocked":false}
	var result := cdc_script.calculate(attacker, self, raw_atk, dmg_type, dir, is_shield_break_weapon)
	var dmg: int = int(result.get("final_damage", 0))
	var blocked: bool = bool(result.get("is_blocked", false))
	if blocked and dmg == 0:
		return result
	var kb: float = float(result.get("knockback", 80.0))
	_apply_damage(dmg, attacker, dir, kb)
	return result

func _apply_damage(dmg: int, attacker: Node, dir: Vector2, knockback_force: float) -> void:
	var before: int = hp
	hp = clamp(hp - dmg, 0, max_hp)
	if hp == 0 and alive:
		alive = false
		change_state(BaseState.DEAD)
		_on_death(attacker)
	elif state != BaseState.HURT and state != BaseState.DEAD and dmg > 0:
		change_state(BaseState.HURT)
	velocity.x = dir.x * knockback_force
	if velocity.y >= 0:
		velocity.y = min(velocity.y, -120.0)
	is_invincible = true
	invincible_timer = 0.4
	var ge1: Node = _autoload("GameEvents")
	if ge1:
		ge1.emit_signal("character_hp_changed", self, hp, max_hp, -(before - hp), attacker)

func heal(amount: int, source: Node) -> void:
	if not alive:
		return
	var before: int = hp
	hp = clamp(hp + amount, 0, max_hp)
	var ge2: Node = _autoload("GameEvents")
	if hp != before and ge2:
		ge2.emit_signal("character_hp_changed", self, hp, max_hp, hp - before, source)

func _on_death(killer: Node) -> void:
	var ge3: Node = _autoload("GameEvents")
	if ge3 == null:
		return
	match kind:
		CharacterKind.ENEMY:
			ge3.emit_signal("enemy_killed", self, killer, global_position)
		CharacterKind.COMPANION:
			ge3.emit_signal("companion_died", self, killer)
		CharacterKind.PLAYER:
			ge3.emit_signal("player_died", global_position)
	ge3.emit_signal("character_died", self, killer)

func current_attack_base() -> Dictionary:
	return { "windup_sec": 0.1, "active_sec": 0.15, "recovery_sec": 0.2, "atk_mult": 1.0, "knockback_mult": 1.0 }

# === 默认tick子类覆盖== =
func _tick_idle(_d: float) -> void: pass
func _tick_run(_d: float) -> void: pass
func _tick_air(_d: float) -> void: pass
func _tick_dash(_d: float) -> void: pass
func _tick_attack(_d: float) -> void: pass
func _tick_block(_d: float) -> void: pass
func _tick_hurt(_d: float) -> void:
	if state_timer >= 0.3:
		change_state(BaseState.IDLE)
func _tick_dead(_d: float) -> void:
	queue_redraw()

func setup_simple(props: Dictionary) -> void:
	for k in props.keys():
		if (self.has_method("set_" + k) == false) and (self.has(k)):
			self[k] = props[k]

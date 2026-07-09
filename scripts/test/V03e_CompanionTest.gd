extends RefCounted
## V0.3e V03e_CompanionTest.gd — 10 UC 无桩 Headless 验收
## 原则：不加载任何 .tscn；纯 RefCounted + Dictionary 模拟；鸭子类型调用

const _AXEMAN_SCRIPT := preload("res://scripts/characters/AxemanCompanion.gd")
const _COMPANION_SCRIPT := preload("res://scripts/characters/CompanionBase.gd")
const _BASE_SCRIPT := preload("res://scripts/editor/CharacterBase.gd")

var total: int = 0
var failed: int = 0

func run() -> int:
	print("\n===== V0.3e 樵夫同伴同行验收 10UC (无桩 Headless) =====")
	_t1_kind_is_companion()
	_t2_setup_companion_fields()
	_t3_set_ai_change_idle_to_follow()
	_t4_set_ai_same_no_change()
	_t5_attack_cd_prevents_double_swing()
	_t6_assist_enemy_switch_attack_state()
	_t7_follow_player_state_to_run()
	_t8_idle_near_velocity_zero()
	_t9_retreat_beyond_retreat_radius_runs()
	_t10_dummy_take_damage_reduces_hp()
	var passed: int = total - failed
	print("\n===== Result: %d / %d passed (failed=%d) =====" % [passed, total, failed])
	return 0 if failed == 0 else 1

# ---------------- 工具 ----------------
func _assert_eq(tag: String, got, want) -> void:
	total += 1
	if str(got) == str(want):
		print("  PASS %s  got=%s" % [tag, str(got)])
	else:
		failed += 1
		print("  FAIL %s  want=%s  got=%s" % [tag, str(want), str(got)])

func _assert_true(tag: String, cond: bool) -> void:
	total += 1
	if cond:
		print("  PASS %s" % tag)
	else:
		failed += 1
		print("  FAIL %s" % tag)

func _assert_close(tag: String, got: float, want: float, tol: float) -> void:
	total += 1
	if abs(got - want) <= tol:
		print("  PASS %s  got=%.3f want≈%.3f" % [tag, got, want])
	else:
		failed += 1
		print("  FAIL %s  got=%.3f want≈%.3f" % [tag, got, want])

func _make_cfg_axeman() -> Dictionary:
	return {
		"id": "axeman", "display_name": "樵夫·伯克",
		"max_hp": 120, "base_atk": 12, "base_def": 4,
		"move_speed": 220, "jump_force": -460,
		"weapon": { "id": "axe_2h", "name": "双手斧", "atk_mult": 1.2, "range": 58, "cd_sec": 1.2, "knockback": 240, "break_shield": true },
		"ai": { "follow_distance": 90, "alert_radius": 260, "attack_range": 55, "retreat_radius": 340 }
	}

func _make_follow_mock() -> Object:
	var m = Node2D.new()
	m.global_position = Vector2(900, 600)
	m.set_meta("is_follow_mock", true)
	return m

func _make_dummy_enemy(hp_v: int) -> Object:
	var s = _BASE_SCRIPT.new()
	s.kind = s.CharacterKind.ENEMY
	s.max_hp = hp_v
	s.hp = hp_v
	s.atk = 0
	s.defense = 3
	s.set_meta("enemy_id", "dummy")
	s.set_meta("is_training_dummy", true)
	s.display_name = "稻草人"
	return s

# ---------------- 10 UC ----------------

func _t1_kind_is_companion() -> void:
	print("\n--- T1 kind=COMPANION + 同伴类实例化成功 ---")
	var a = _AXEMAN_SCRIPT.new()
	a._ready()
	_assert_eq("T1 kind", int(a.kind), int(a.CharacterKind.COMPANION))
	_assert_true("T1 collision_layer = 2 (Companion层)", a.collision_layer == 2)

func _t2_setup_companion_fields() -> void:
	print("\n--- T2 setup_companion 写入 HP/ATK/AI/follow_distance ---")
	var a = _COMPANION_SCRIPT.new()
	var p = _make_follow_mock()
	a.setup_companion("axeman", _make_cfg_axeman(), p)
	_assert_eq("T2 max_hp", a.max_hp, 120)
	_assert_eq("T2 atk", a.atk, 12)
	_assert_eq("T2 defense", a.defense, 4)
	_assert_close("T2 follow_distance", a.follow_distance, 90.0, 0.01)
	_assert_close("T2 assist_range", a.assist_range, 260.0, 0.01)
	_assert_close("T2 retreat_radius", a.retreat_radius, 340.0, 0.01)
	_assert_eq("T2 display_name", a.display_name, "樵夫·伯克")
	p.queue_free()

func _t3_set_ai_change_idle_to_follow() -> void:
	print("\n--- T3 AI态切换 IDLE_NEAR → FOLLOW_PLAYER（状态成功变更）---")
	var a = _COMPANION_SCRIPT.new()
	var p = _make_follow_mock()
	a.setup_companion("axeman", _make_cfg_axeman(), p)
	a.companion_ai_state = a.CompanionAIState.IDLE_NEAR
	var r = a._set_ai(a.CompanionAIState.FOLLOW_PLAYER)
	_assert_eq("T3 _set_ai 返回 OK", int(r), int(OK))
	_assert_eq("T3 AI态变为 FOLLOW_PLAYER", a.companion_ai_state, int(a.CompanionAIState.FOLLOW_PLAYER))
	p.queue_free()

func _t4_set_ai_same_no_change() -> void:
	print("\n--- T4 _set_ai 重复同态，不抛错仍返回 OK ---")
	var a = _COMPANION_SCRIPT.new()
	a.companion_ai_state = a.CompanionAIState.ASSIST_ATTACK
	var r = a._set_ai(a.CompanionAIState.ASSIST_ATTACK)
	_assert_eq("T4 重复 ASSIST_ATTACK 返回 OK", int(r), int(OK))
	_assert_eq("T4 AI态保持 ASSIST_ATTACK", a.companion_ai_state, int(a.CompanionAIState.ASSIST_ATTACK))

func _t5_attack_cd_prevents_double_swing() -> void:
	print("\n--- T5 attack_cd_left > 0 → _do_attack 不重复调用 change_state(ATTACK1) ---")
	var a = _COMPANION_SCRIPT.new()
	var p = _make_follow_mock()
	a.setup_companion("axeman", _make_cfg_axeman(), p)
	var d = _make_dummy_enemy(300)
	a.attack_cd_left = 0.8
	a.state = a.FSMState.IDLE
	var old_state = a.state
	a._do_attack(d)
	_assert_eq("T5 冷却0.8秒 → 状态仍保持IDLE（不挥斧）", a.state, old_state)
	_assert_true("T5 cd>0 → ATTACK1未进入", a.state != a.FSMState.ATTACK1)
	p.queue_free()

func _t6_assist_enemy_switch_attack_state() -> void:
	print("\n--- T6 cd清零 + 敌人进入attack_range → ASSIST_ATTACK切ATTACK1 ---")
	var a = _COMPANION_SCRIPT.new()
	var p = _make_follow_mock()
	a.setup_companion("axeman", _make_cfg_axeman(), p)
	a.attack_cd_left = 0.0
	a.companion_ai_state = a.CompanionAIState.IDLE_NEAR
	var d = _make_dummy_enemy(300)
	d.global_position = a.global_position + Vector2(54, 0)
	a._do_attack(d)
	_assert_eq("T6 cd=0 → 攻击切ATTACK1", a.state, int(a.FSMState.ATTACK1))
	_assert_close("T6 攻击后cd写入1.2秒", a.attack_cd_left, 1.2, 0.001)
	p.queue_free()

func _t7_follow_player_state_to_run() -> void:
	print("\n--- T7 玩家距离 > follow_distance(90) → _move_toward → state=RUN ---")
	var a = _COMPANION_SCRIPT.new()
	var p = _make_follow_mock()
	a.setup_companion("axeman", _make_cfg_axeman(), p)
	p.global_position = a.global_position + Vector2(400, 0)
	a.companion_ai_state = a.CompanionAIState.IDLE_NEAR
	a.state = a.FSMState.IDLE
	var before = a.state
	a._move_toward(p.global_position)
	var facing_ok = a.facing == 1.0
	var vel_move = abs(a.velocity.x) > 10.0
	_assert_true("T7 向右跑 facing=+1", facing_ok)
	_assert_true("T7 velocity.x 被设置（abs>10，值%.1f）" % a.velocity.x, vel_move)
	p.queue_free()

func _t8_idle_near_velocity_zero() -> void:
	print("\n--- T8 距玩家近 < follow_distance → IDLE_NEAR，velocity.x→0 ---")
	var a = _COMPANION_SCRIPT.new()
	var p = _make_follow_mock()
	a.setup_companion("axeman", _make_cfg_axeman(), p)
	p.global_position = a.global_position + Vector2(10, 0)
	a.velocity.x = 120.0
	a.companion_ai_state = a.CompanionAIState.FOLLOW_PLAYER
	a.state = a.FSMState.RUN
	a._set_ai(a.CompanionAIState.IDLE_NEAR)
	_assert_eq("T8 手动切IDLE_NEAR成功", a.companion_ai_state, int(a.CompanionAIState.IDLE_NEAR))
	p.queue_free()

func _t9_retreat_beyond_retreat_radius_runs() -> void:
	print("\n--- T9 距玩家 > retreat_radius(340) → RETREAT 切RUN归位 ---")
	var a = _COMPANION_SCRIPT.new()
	var p = _make_follow_mock()
	a.setup_companion("axeman", _make_cfg_axeman(), p)
	p.global_position = a.global_position + Vector2(1200, 0)
	a.companion_ai_state = a.CompanionAIState.IDLE_NEAR
	a._set_ai(a.CompanionAIState.RETREAT)
	a.state = a.FSMState.IDLE
	a._move_toward(p.global_position)
	_assert_eq("T9 切RETREAT态成功", a.companion_ai_state, int(a.CompanionAIState.RETREAT))
	_assert_true("T9 跑向玩家 → velocity.x >10（%.1f）" % a.velocity.x, abs(a.velocity.x) > 10.0)
	p.queue_free()

func _t10_dummy_take_damage_reduces_hp() -> void:
	print("\n--- T10 稻草人被同伴 take_damage → hp 减少（CDC生效）---")
	var s = _BASE_SCRIPT.new()
	s.kind = s.CharacterKind.ENEMY
	s.max_hp = 200
	s.hp = 200
	s.atk = 0
	s.defense = 2
	s.display_name = "稻草人T10"
	s.state = s.FSMState.IDLE
	var opts: Dictionary = {
		"_use_cdc": true, "damage_type": "physical", "knockback": 120,
		"hitstun": 0.15, "weapon_break_shield": false,
		"attacker_weapon_mult": 1.2
	}
	var atk_mock = CharacterBody2D.new()
	atk_mock.set_meta("attacker_mock", "CompanionAxeman")
	var before = s.hp
	s.take_damage(12, atk_mock, opts)
	_assert_true("T10 攻击12 + mult1.2 + def2 → hp < %d（当前=%d）" % [before, s.hp], s.hp < before)
	_assert_eq("T10 受击后状态切HURT", s.state, int(s.FSMState.HURT))
	atk_mock.queue_free()

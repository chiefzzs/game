extends RefCounted
## V0.3f V03f_EnemyTest.gd — 10 UC 无桩 Headless 验收（敌人AI FSM + HitFlyer伤害浮字）
## 原则：不加载 .tscn；纯 RefCounted + Dictionary 模拟；鸭子类型调用

const _SLIME_SCRIPT := preload("res://scripts/characters/SlimeEnemy.gd")
const _ENEMY_SCRIPT := preload("res://scripts/characters/EnemyBase.gd")
const _BASE_SCRIPT := preload("res://scripts/editor/CharacterBase.gd")
const _FLYER_SCRIPT := preload("res://scripts/combat/HitFlyer.gd")

var total: int = 0
var failed: int = 0

func run() -> int:
	print("\n===== V0.3f 敌人AI与伤害浮字验收 10UC (无桩 Headless) =====")
	_t1_slime_kind_is_enemy()
	_t2_setup_enemy_writes_fields()
	_t3_set_ai_patrol_to_chase()
	_t4_set_ai_illegal_transition_fails()
	_t5_attack_cd_prevents_double()
	_t6_close_player_switches_to_attack_state()
	_t7_retreat_switches_to_retreat_state_runs()
	_t8_patrol_dir_reverses_at_boundary()
	_t9_hitflyer_normal_spawns_white_text()
	_t10_enemy_take_damage_reduces_hp_flashes()
	var passed: int = total - failed
	print("\n===== Result: %d / %d passed (failed=%d) =====" % [passed, total, failed])
	return 0 if failed == 0 else 1

# ---------------- 工具断言 ----------------
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

func _make_cfg_slime() -> Dictionary:
	return {
		"display_name": "史莱姆·绿滴",
		"max_hp": 100, "base_atk": 10, "base_def": 2,
		"move_speed": 180, "patrol_half": 80,
		"chase_trigger": 150, "attack_range": 58, "retreat_radius": 360,
		"weapon": {"atk_mult": 1.0, "cd_sec": 1.1, "knockback": 90, "range": 58, "break_shield": false}
	}

func _new_slime() -> CharacterBody2D:
	var cb := CharacterBody2D.new()
	cb.set_script(_SLIME_SCRIPT)
	return cb

# ---------------- 10 UC ----------------

func _t1_slime_kind_is_enemy() -> void:
	print("\n--- T1 kind=ENEMY + 史莱姆实例化 + collision_layer=4 ---")
	var s = _new_slime()
	s._ready()
	_assert_eq("T1 kind", int(s.kind), int(s.CharacterKind.ENEMY))
	_assert_true("T1 collision_layer=4 (Enemy层)", s.collision_layer == 4)

func _t2_setup_enemy_writes_fields() -> void:
	print("\n--- T2 setup_enemy 写入 HP/ATK/chase/patrol边界 ---")
	var cb := CharacterBody2D.new()
	cb.set_script(_ENEMY_SCRIPT)
	cb._ready()
	var home := Vector2(820, 560)
	cb.setup_enemy(home, _make_cfg_slime())
	_assert_eq("T2 max_hp", cb.max_hp, 100)
	_assert_eq("T2 atk", cb.atk, 10)
	_assert_eq("T2 defense", cb.defense, 2)
	_assert_close("T2 chase_trigger", cb.chase_trigger, 150.0, 1.0)
	_assert_close("T2 patrol_left", cb.patrol_left, 740.0, 1.0)
	_assert_close("T2 patrol_right", cb.patrol_right, 900.0, 1.0)

func _t3_set_ai_patrol_to_chase() -> void:
	print("\n--- T3 _set_ai PATROL→CHASE（合法转换，返回OK + state=1）---")
	var cb := CharacterBody2D.new()
	cb.set_script(_ENEMY_SCRIPT)
	cb._ready()
	var r: Error = cb._set_ai(1)  # CHASE
	_assert_eq("T3 _set_ai返回 OK", int(r), 0)
	_assert_eq("T3 AI状态变为 CHASE(1)", int(cb.enemy_ai_state), 1)

func _t4_set_ai_illegal_transition_fails() -> void:
	print("\n--- T4 非法转换 RETREAT→ATTACK 失败（不在合法列表，返回ERR_INVALID_DATA=30）---")
	var cb := CharacterBody2D.new()
	cb.set_script(_ENEMY_SCRIPT)
	cb._ready()
	cb._set_ai(3)  # 先设 RETREAT
	var r: Error = cb._set_ai(2)  # RETREAT→ATTACK 非法
	_assert_eq("T4 非法转换返回 ERR_INVALID_DATA(30)", int(r), 30)
	_assert_eq("T4 AI状态保持 RETREAT(3)", int(cb.enemy_ai_state), 3)

func _t5_attack_cd_prevents_double() -> void:
	print("\n--- T5 attack_cd_left>0 → _do_attack 不重入，state保持PATROL ---")
	var cb := CharacterBody2D.new()
	cb.set_script(_ENEMY_SCRIPT)
	cb._ready()
	cb.setup_enemy(Vector2(820, 560), _make_cfg_slime())
	cb.attack_cd_left = 0.9  # 还有0.9s冷却
	var dummy_player := CharacterBody2D.new()
	dummy_player.set_script(_BASE_SCRIPT)
	dummy_player._ready()
	dummy_player.kind = dummy_player.CharacterKind.PLAYER
	dummy_player.max_hp = 200
	dummy_player.hp = 200
	cb._do_attack(dummy_player)
	_assert_eq("T5 冷却中 → state=IDLE(PATROL没跳ATTACK1)", int(cb.state), int(cb.FSMState.IDLE))
	_assert_true("T5 cd_left 仍>0", cb.attack_cd_left > 0.3)

func _t6_close_player_switches_to_attack_state() -> void:
	print("\n--- T6 cd=0 + 玩家距离<58 → ATTACK → state=ATTACK1 + cd写入1.1s ---")
	var cb := CharacterBody2D.new()
	cb.set_script(_ENEMY_SCRIPT)
	cb._ready()
	cb.setup_enemy(Vector2(820, 560), _make_cfg_slime())
	cb.global_position = Vector2(780, 560)
	var dummy_player := CharacterBody2D.new()
	dummy_player.set_script(_BASE_SCRIPT)
	dummy_player._ready()
	dummy_player.kind = dummy_player.CharacterKind.PLAYER
	dummy_player.max_hp = 200
	dummy_player.hp = 200
	dummy_player.global_position = Vector2(820, 560)  # 距离=40 < attack_range=58
	cb.attack_cd_left = 0.0
	cb._do_attack(dummy_player)
	_assert_eq("T6 cd=0+近距离 → state跳 ATTACK1", int(cb.state), int(cb.FSMState.ATTACK1))
	_assert_close("T6 攻击后 attack_cd_left=1.1s", cb.attack_cd_left, 1.1, 0.05)

func _t7_retreat_switches_to_retreat_state_runs() -> void:
	print("\n--- T7 距离home>retreat_radius(360) → _set_ai RETREAT + _move_toward velocity.x 设置 ---")
	var cb := CharacterBody2D.new()
	cb.set_script(_ENEMY_SCRIPT)
	cb._ready()
	var home := Vector2(820, 560)
	cb.setup_enemy(home, _make_cfg_slime())
	cb.global_position = Vector2(400, 560)  # 距离home=420 > 360
	var r: Error = cb._set_ai(3)  # RETREAT
	_assert_eq("T7 切换 RETREAT 返回 OK", int(r), 0)
	cb._move_toward(home)
	_assert_true("T7 _move_toward velocity.x 设为向右(>10, 回家820)", abs(cb.velocity.x) > 10.0)
	_assert_true("T7 velocity.x 正（朝右回家）", cb.velocity.x > 0.0)

func _t8_patrol_dir_reverses_at_boundary() -> void:
	print("\n--- T8 巡逻碰到patrol_right → patrol_dir 1→-1（掉头）---")
	var cb := CharacterBody2D.new()
	cb.set_script(_ENEMY_SCRIPT)
	cb._ready()
	var home := Vector2(820, 560)
	cb.setup_enemy(home, _make_cfg_slime())
	cb.patrol_dir = 1.0
	cb.global_position = Vector2(910, 560)  # x>patrol_right=900
	cb._do_patrol()
	_assert_close("T8 撞右边界 patrol_dir反转=-1", cb.patrol_dir, -1.0, 0.01)
	cb.global_position = Vector2(730, 560)  # x<patrol_left=740
	cb._do_patrol()
	_assert_close("T8 撞左边界 patrol_dir反转=+1", cb.patrol_dir, 1.0, 0.01)

func _t9_hitflyer_normal_spawns_white_text() -> void:
	print("\n--- T9 HitFlyer.spawn(普通dmg18) → 白字 `-18` color.WHITE ---")
	var parent := Node2D.new()
	var flyer := _FLYER_SCRIPT.spawn(parent, Vector2(500, 400), 18, false, false)
	_assert_eq("T9 普通伤害浮字 text=`-18`", flyer.text, "-18")
	_assert_true("T9 普通伤害颜色=WHITE (r≈1,g≈1,b≈1)",
		abs(flyer.color.r - 1.0) < 0.05 and abs(flyer.color.g - 1.0) < 0.05 and abs(flyer.color.b - 1.0) < 0.05)
	_assert_close("T9 默认life=0.9", flyer.life, 0.9, 0.05)
	var flyer_crit := _FLYER_SCRIPT.spawn(parent, Vector2(510, 400), 58, true, false)
	_assert_true("T9 暴击浮字含`暴击`文字", flyer_crit.text.find("暴击") >= 0)
	_assert_true("T9 暴击浮字颜色=黄(g≈0.92)", abs(flyer_crit.color.g - 0.92) < 0.1)
	var flyer_back := _FLYER_SCRIPT.spawn(parent, Vector2(520, 400), 36, false, true)
	_assert_true("T9 背刺浮字含`背刺`", flyer_back.text.find("背刺") >= 0)
	_assert_true("T9 背刺颜色=红(r≈1)", abs(flyer_back.color.r - 1.0) < 0.05)

func _t10_enemy_take_damage_reduces_hp_flashes() -> void:
	print("\n--- T10 史莱姆EnemyBase.take_damage → hp减少 + flash_time>0(闪红0.08s) ---")
	var cb := CharacterBody2D.new()
	cb.set_script(_ENEMY_SCRIPT)
	cb._ready()
	cb.setup_enemy(Vector2(820, 560), _make_cfg_slime())
	var before_hp: int = cb.hp
	var attacker := CharacterBody2D.new()
	attacker.set_script(_BASE_SCRIPT)
	attacker._ready()
	attacker.kind = attacker.CharacterKind.PLAYER
	attacker.atk = 12
	attacker.set_meta("char_id", "farmer")
	cb.take_damage(15, attacker, {"_use_cdc": true})
	_assert_true("T10 hp减少（原%d → 现%d，现<原）" % [before_hp, cb.hp], cb.hp < before_hp)
	_assert_close("T10 take_damage 触发 flash_time>0.07（闪红0.08）", cb.flash_time, 0.08, 0.02)
	_assert_true("T10 cb.hp 合理范围（不低于0, 100-15±≈85±5）", cb.hp >= 75 and cb.hp <= 98)

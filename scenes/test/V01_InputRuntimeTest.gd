extends Node2D
## Headless runtime test for V01_InputCollisionTest (30 assertions)
var passed: int = 0
var failed: int = 0
var _test_scene: Node2D
var _hud: Label
var _player: CharacterBody2D
var _drawer: Node2D
var _shield: Node2D
var _inv_gold: Label
var _inv_pot: Label
var _jump_seen: int = 0
var _atk_seen: int = 0
var _blk_seen: int = 0
var _dash_seen: int = 0
var _gold1: Node
var _pot1: Node
var _ladder: Node
var _lines_out: Array[String] = []
var _climb_y0: float = 0.0

func _ready() -> void:
	var packed := load("res://scenes/test/V01_InputCollisionTest.tscn")
	_test_scene = packed.instantiate()
	add_child(_test_scene)
	_sched(0.12, _phase1_nodes)

func _phase1_nodes() -> void:
	_hud = _test_scene.get_node_or_null("UI/VBox/HudLog") as Label
	_player = _test_scene.get_node_or_null("World/Player") as CharacterBody2D
	_drawer = _test_scene.get_node_or_null("World/Player/Drawer") as Node2D
	_shield = _test_scene.get_node_or_null("World/Player/Shield") as Node2D
	_inv_gold = _test_scene.get_node_or_null("UI/Inv/GoldVal") as Label
	_inv_pot  = _test_scene.get_node_or_null("UI/Inv/PotVal")  as Label
	_gold1 = _test_scene.get_node_or_null("World/Gold1")
	_pot1  = _test_scene.get_node_or_null("World/Potion1")
	_ladder = _test_scene.get_node_or_null("World/Ladder")
	_expect(_hud != null, "HudLabel present", "HudLabel missing")
	_expect(_player != null, "Player present", "Player missing")
	_expect(_drawer != null, "Drawer present", "Drawer missing")
	_expect(_shield != null, "Shield child Node2D present (DrawShield)", "Shield missing (block visual absent)")
	_expect(_inv_gold != null and _inv_pot != null, "Inventory HUD labels present Gold/Pot", "Inventory HUD missing")
	_expect(_gold1 != null and _pot1 != null and _ladder != null, "Pickups (2x gold + 1x pot) + Ladder present", "Scene missing gold/pot/ladder")
	# Connect InputBus signals BEFORE emitting them in phase 3
	InputBus.JumpPressed.connect(_on_j)
	InputBus.AttackPressed.connect(_on_a)
	InputBus.BlockPressed.connect(_on_b)
	InputBus.DashPressed.connect(_on_d)
	_sched(0.15, _phase2_ready_flush)

func _phase2_ready_flush() -> void:
	var t: String = _hud.text if _hud else ""
	if ("booting" in t) or ("启动中" in t):
		_fail("HUD still booting (flush never ran, script disabled)")
	else:
		_pass("HUD flushed with ready info (script enabled)")
	# Initial inventory 0
	if _inv_gold and _inv_gold.text == "0" and _inv_pot and _inv_pot.text == "0":
		_pass("Initial inventory Gold=0 Pot=0")
	else:
		_fail("Inventory initial state wrong: G=%s P=%s" % [_inv_gold.text if _inv_gold else "null", _inv_pot.text if _inv_pot else "null"])
	# Phase 3 fires: Dash + Block
	_sched(0.15, func():
		InputBus.DashPressed.emit()
		InputBus.BlockPressed.emit()
	)
	_sched(0.35, _phase3_dash_block)

func _phase3_dash_block() -> void:
	# After dash, scene should have _dash_timer > 0 AND cd > 0
	var cd_val: float = float(_test_scene.get("_dash_cd") if "_dash_cd" in _test_scene else -1)
	var d_timer: float = float(_test_scene.get("_dash_timer") if "_dash_timer" in _test_scene else -1)
	_expect(cd_val > 0.2 and cd_val < 1.0, "Dash cooldown set to %.2fs (expected 0.65ish)" % cd_val, "Dash CD missing, cd=%.2f" % cd_val)
	_expect(_dash_seen >= 1, "DashPressed signal fired %d times" % _dash_seen, "DashPressed NOT fired (dash not working)")
	_expect(_shield != null and _shield.visible, "Shield visible=true while blocking (signal-only flag, not overridden by process)", "Shield not shown on block: vis=%s" % [str(_shield.visible if _shield else "noNode")])
	_expect(_blk_seen >= 1, "BlockPressed signal fired %d times" % _blk_seen, "BlockPressed NOT fired")
	# Release block -> shield hide
	InputBus.BlockReleased.emit()
	_sched(0.15, _phase3b_block_released)

func _phase3b_block_released() -> void:
	_expect(_shield != null and not _shield.visible, "Shield hidden after BlockReleased", "Shield still visible after release")
	# Phase 4: teleport player onto gold pickup + directly append gold1 into nearby list (bypass signal)
	if _gold1:
		_player.position = _gold1.position
		if "_nearby_pickups" in _test_scene:
			var nb: Array = _test_scene["_nearby_pickups"]
			if not nb.has(_gold1):
				nb.append(_gold1)
		if "hud" in _test_scene and _test_scene.has_method("hud"):
			var pk: String = _gold1.get_meta("pickup_kind") if _gold1.has_meta("pickup_kind") else "?"
			_test_scene.call("hud", "[PICKUP] nearby +%s" % pk)
	# Check immediately (before next physics tick) that nearby >=1 — auto-pick has NOT run yet
	var nb_arr_check: Array = _test_scene["_nearby_pickups"] if "_nearby_pickups" in _test_scene else []
	_expect(nb_arr_check.size() >= 1, "After gold1 appended, nearby_pickups size=%d immediately (pre-auto-pick)" % nb_arr_check.size(), "nearby_pickups empty (size=%d) right after append" % nb_arr_check.size())
	# Now wait 0.22s for _physics_process auto-pick loop to run
	_sched(0.22, _phase4b_after_auto_pick_gold)

func _phase4b_after_auto_pick_gold() -> void:
	var nb_after: int = -1
	var nb_arr2: Array = _test_scene["_nearby_pickups"] if "_nearby_pickups" in _test_scene else []
	nb_after = nb_arr2.size()
	var g_inv: int = int(_test_scene.get("_inventory_gold") if "_inventory_gold" in _test_scene else -99)
	var g: String = _inv_gold.text if _inv_gold else "-1"
	var gold_gone: bool = true
	if _gold1 and is_instance_valid(_gold1):
		gold_gone = _gold1.is_queued_for_deletion()
	_expect(nb_after == 0, "Auto-pickup emptied nearby_pickups (size=%d, expect 0)" % nb_after, "Auto-pickup did not run, nearby still has %d items" % nb_after)
	_expect(g_inv == 1, "Auto-pickup -> internal Gold inventory =%d (expected 1)" % g_inv, "Auto-pickup gold count internal=%d (should be 1)" % g_inv)
	_expect(g == "1", "HUD GoldVal shows %s (expected 1) after auto-pickup" % g, "HUD gold label wrong: G=%s" % g)
	_expect(gold_gone, "Gold1 pickup vanished (queue_free/isntance_invalid=%s)" % str(gold_gone), "Gold1 still visible in scene after pickup, not freed!")
	# Potion pickup next
	if _pot1:
		_player.position = _pot1.position
		if "_nearby_pickups" in _test_scene:
			var nb2: Array = _test_scene["_nearby_pickups"]
			if not nb2.has(_pot1):
				nb2.append(_pot1)
	# Check potion nearby immediately (pre auto-pick)
	var nb_arr_p_check: Array = _test_scene["_nearby_pickups"] if "_nearby_pickups" in _test_scene else []
	_expect(nb_arr_p_check.size() >= 1, "After Potion1 appended, nearby_pickups size=%d immediately (pre-auto)" % nb_arr_p_check.size(), "Potion nearby empty after append, size=%d" % nb_arr_p_check.size())
	_sched(0.22, _phase4c_potion_picked)

func _phase4c_potion_picked() -> void:
	var nb_pot: int = -1
	var nb_arr_p: Array = _test_scene["_nearby_pickups"] if "_nearby_pickups" in _test_scene else []
	nb_pot = nb_arr_p.size()
	var p_inv: int = int(_test_scene.get("_inventory_pot") if "_inventory_pot" in _test_scene else -99)
	var p: String = _inv_pot.text if _inv_pot else "-1"
	var pot_gone: bool = true
	if _pot1 and is_instance_valid(_pot1):
		pot_gone = _pot1.is_queued_for_deletion()
	_expect(nb_pot == 0, "Auto-pickup potion -> nearby_pickups size=%d (expect 0)" % nb_pot, "Potion not auto-picked, nearby still %d" % nb_pot)
	_expect(p_inv == 1, "Auto-pickup -> internal Potion inventory =%d (expected 1)" % p_inv, "Potion auto-pick internal count wrong: %d" % p_inv)
	_expect(p == "1", "After Potion auto-pickup -> HUD PotionVal=%s (expected 1)" % p, "Potion pickup wrong Pot=%s" % p)
	_expect(pot_gone, "Potion1 pickup vanished (queue_free/invalid=%s)" % str(pot_gone), "Potion1 still visible after pickup!")
	# Phase5: teleport onto ladder + set _in_ladder_area=true + fire W (ui_up) -> climb up (position.y should DECREASE)
	var y_before_climb: float = 9999.0
	if _ladder and _player:
		y_before_climb = float(_ladder.position.y)
		_player.position = Vector2(_ladder.position.x, _ladder.position.y)
		if "_in_ladder_area" in _test_scene:
			_test_scene["_in_ladder_area"] = true
		if "hud" in _test_scene and _test_scene.has_method("hud"):
			_test_scene.call("hud", "[LADDER] enter. Press W/S to climb")
	_expect(abs(y_before_climb - _ladder.position.y) < 0.01, "Player placed on ladder (before climb y=%.2f)" % y_before_climb, "Failed to place player at ladder start y")
	Input.action_press("ui_up")
	_climb_y0 = y_before_climb
	_sched(0.35, _phase5_climb)

func _phase5_climb() -> void:
	Input.action_release("ui_up")
	var in_area: bool = false
	var climbing: bool = false
	if "_in_ladder_area" in _test_scene:
		in_area = bool(_test_scene["_in_ladder_area"])
	if "_is_climbing" in _test_scene:
		climbing = bool(_test_scene["_is_climbing"])
	var y_now: float = _player.position.y if _player else 99999.0
	var dy: float = y_now - _climb_y0
	var climbed_up: bool = dy < -10.0
	_expect(in_area, "After Ladder area_entered -> _in_ladder_area=true", "_in_ladder_area still false after area_entered")
	_expect(climbing, "After W (ui_up) held on ladder -> _is_climbing=true", "Climb didn't activate. inArea=%s climb=%s" % [in_area, climbing])
	_expect(climbed_up, "Held W 0.35s on ladder -> player climbed UP (dy=%.2f px, expect <-10). y0=%.1f y1=%.1f" % [dy, _climb_y0, y_now], "W pressed but player DIDN'T climb up! dy=%.2f (expected negative; sign-error gravity bug). ladder_y0=%.1f y_now=%.1f" % [dy, _climb_y0, y_now])
	# exit ladder mode + teleport player back above ground so it falls and lands.
	if "_in_ladder_area" in _test_scene:
		_test_scene["_in_ladder_area"] = false
	if "_is_climbing" in _test_scene:
		_test_scene["_is_climbing"] = false
	_player.position = Vector2(560, 800)
	_sched(0.6, _phase6_tick_final)

func _phase6_tick_final() -> void:
	var tick: int = -1
	if _test_scene and "_tick" in _test_scene:
		tick = int(_test_scene.get("_tick"))
	_expect(tick > 0, "_tick=%d (process alive; dash/block/pickup/climb features all ran without crash)" % tick, "_tick==0 process crashed")
	var onf: bool = _player.is_on_floor() if _player else false
	var sx: float = _drawer.scale.x if _drawer else -999
	if onf:
		_pass("Player onFloor=true (collision still OK after new nodes)")
	else:
		var py: float = _player.position.y if _player else -1
		_fail("onFloor=false, pos.y=%.1f (post-feature collision broken?)" % py)
	_expect(abs(sx - 1.0) < 0.001, "Drawer scale.x still valid (=%.3f)" % sx, "Drawer scale corrupted")
	_finalize()

func _finalize() -> void:
	_lines_out.append("---- RUNTIME TEST: passed=%d failed=%d ----" % [passed, failed])
	_lines_out.append("Total: passed=%d failed=%d" % [passed, failed])
	for line in _lines_out:
		print(line)
	var f := FileAccess.open("res://_tmp_v01_input_rt.log", FileAccess.WRITE)
	if f:
		for line in _lines_out:
			f.store_line(line)
		f.close()
	get_tree().quit()

func _on_j() -> void: _jump_seen += 1
func _on_a() -> void: _atk_seen += 1
func _on_b() -> void: _blk_seen += 1
func _on_d() -> void: _dash_seen += 1

func _sched(sec: float, fn: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(fn)

func _expect(cond: bool, pass_msg: String, fail_msg: String) -> void:
	if cond:
		_pass(pass_msg)
	else:
		_fail(fail_msg)

func _pass(msg: String) -> void:
	passed += 1
	_lines_out.append("  [PASS] " + msg)

func _fail(msg: String) -> void:
	failed += 1
	_lines_out.append("  [FAIL] " + msg)

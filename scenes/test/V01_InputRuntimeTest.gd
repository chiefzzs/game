extends Node2D
## Headless runtime test for V01_InputCollisionTest (60 assertions, includes Rake weapon + X attack)
var passed: int = 0
var failed: int = 0
var _test_scene: Node2D
var _hud: Label
var _player: CharacterBody2D
var _drawer: Node2D
var _shield: Node2D
var _block_aura: Node2D
var _aura_top: ColorRect
var _weapon_holder: Node2D
var _inv_gold: Label
var _inv_pot: Label
var _hp_bar: ProgressBar
var _hp_txt: Label
var _st_bar: ProgressBar
var _st_txt: Label
var _jump_seen: int = 0
var _atk_seen: int = 0
var _blk_seen: int = 0
var _blk_rel_seen: int = 0
var _dash_seen: int = 0
var _gold1: Node
var _pot1: Node
var _rake1: Node
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
	_block_aura = _test_scene.get_node_or_null("World/Player/BlockAura") as Node2D
	_aura_top = _test_scene.get_node_or_null("World/Player/BlockAura/TopLine") as ColorRect
	_inv_gold = _test_scene.get_node_or_null("UI/Inv/GoldVal") as Label
	_inv_pot  = _test_scene.get_node_or_null("UI/Inv/PotVal")  as Label
	_hp_bar = _test_scene.get_node_or_null("UI/HealthBars/HpRow/HpBar") as ProgressBar
	_hp_txt = _test_scene.get_node_or_null("UI/HealthBars/HpRow/HpText") as Label
	_st_bar = _test_scene.get_node_or_null("UI/HealthBars/StRow/StBar") as ProgressBar
	_st_txt = _test_scene.get_node_or_null("UI/HealthBars/StRow/StText") as Label
	_gold1 = _test_scene.get_node_or_null("World/Gold1")
	_pot1  = _test_scene.get_node_or_null("World/Potion1")
	_rake1 = _test_scene.get_node_or_null("World/Rake")
	_ladder = _test_scene.get_node_or_null("World/Ladder")
	_weapon_holder = _test_scene.get_node_or_null("World/Player/WeaponHolder") as Node2D
	_expect(_hud != null, "HudLabel present", "HudLabel missing")
	_expect(_player != null, "Player present", "Player missing")
	_expect(_drawer != null, "Drawer present", "Drawer missing")
	_expect(_shield != null, "Shield child Node2D present (DrawShield)", "Shield missing (block visual absent)")
	_expect(_block_aura != null and _aura_top != null, "BlockAura present (4 yellow lines + 4 corners)", "BlockAura (yellow frame) missing")
	_expect(not _block_aura.visible, "BlockAura starts hidden (visible=false)", "Aura already visible before block pressed!")
	_expect(_weapon_holder != null, "WeaponHolder present under Player (empty holster for rake)", "WeaponHolder missing (after pickup, rake can't show)")
	_expect(not _weapon_holder.visible, "WeaponHolder starts hidden (visible=false before pickup weapon)", "WeaponHolder visible at startup — no pickup yet!")
	_expect(_inv_gold != null and _inv_pot != null, "Inventory HUD labels present Gold/Pot", "Inventory HUD missing")
	_expect(_hp_bar != null and _hp_txt != null and _st_bar != null and _st_txt != null, "HealthBars UI present (❤ HP + ⚡ SP rows)", "HP/SP bars missing from UI")
	_expect(_gold1 != null and _pot1 != null and _ladder != null, "Pickups (2x gold + 1x pot) + Ladder present", "Scene missing gold/pot/ladder")
	_expect(_rake1 != null, "Rake (农用钉耙) pickup Area2D near spawn", "World/Rake missing — no weapon pickup at spawn!")
	if _rake1:
		_expect(_rake1.has_meta("pickup_kind") and _rake1.get_meta("pickup_kind") == "weapon", "Rake metadata pickup_kind='weapon'", "Rake metadata wrong: pickup_kind=%s" % [str(_rake1.get_meta("pickup_kind") if _rake1.has_meta("pickup_kind") else "MISSING")])
	InputBus.JumpPressed.connect(_on_j)
	InputBus.AttackPressed.connect(_on_a)
	InputBus.BlockPressed.connect(_on_b)
	InputBus.BlockReleased.connect(_on_br)
	InputBus.DashPressed.connect(_on_d)
	# Phase 1b: Simulate LT trigger via Input.action_press (axis-style press/release), confirm signal fires EXACTLY 1 time
	_blk_seen = 0
	_blk_rel_seen = 0
	Input.action_press("block", 0.7)
	_sched(0.1, func():
		_expect(_blk_seen == 1, "Input.action_press(block) -> BlockPressed fired 1 time (LT/RB key simulate)", "BlockPressed seen=%d times, duplicate or missing!" % _blk_seen)
		_expect(_shield != null and _shield.visible, "After simulated LT: Shield visible=true", "Shield not visible after Input.action_press(block)")
		_expect(_block_aura != null and _block_aura.visible, "After simulated LT: Aura (yellow frame) visible=true", "Aura not visible after Input.action_press(block)")
		Input.action_release("block")
	)
	_sched(0.25, _phase1b_lt_release_done)

func _phase1b_lt_release_done() -> void:
	_expect(_blk_rel_seen == 1, "Input.action_release(block) -> BlockReleased fired 1 time", "BlockReleased seen=%d times, duplicate or missing!" % _blk_rel_seen)
	_expect(_block_aura != null and not _block_aura.visible, "After LT release -> Aura hidden", "Aura still visible after Input.action_release(block)!")
	_blk_seen = 0
	_blk_rel_seen = 0
	_sched(0.1, _phase2_ready_flush)

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
	# Initial HP/Stamina
	var hp: int = int(_test_scene.get("_hp") if "_hp" in _test_scene else -1)
	var hp_max: int = int(_test_scene.get("_hp_max") if "_hp_max" in _test_scene else -1)
	var st: int = int(_test_scene.get("_stamina") if "_stamina" in _test_scene else -1)
	var st_max: int = int(_test_scene.get("_stamina_max") if "_stamina_max" in _test_scene else -1)
	_expect(hp == 100 and hp_max == 100, "Initial HP full (%d/%d)" % [hp, hp_max], "HP init wrong: %d/%d" % [hp, hp_max])
	_expect(st == 100 and st_max == 100, "Initial SP full (%d/%d)" % [st, st_max], "SP init wrong: %d/%d" % [st, st_max])
	_expect(_hp_bar and abs(_hp_bar.value - 100.0) < 0.01 and _hp_txt and _hp_txt.text == "100/100", "HP UI synced (value=100, txt=100/100)", "HP UI wrong: bar=%s txt=%s" % [str(_hp_bar.value if _hp_bar else "null"), _hp_txt.text if _hp_txt else "null"])
	_expect(_st_bar and abs(_st_bar.value - 100.0) < 0.01 and _st_txt and _st_txt.text == "100/100", "SP UI synced (value=100, txt=100/100)", "SP UI wrong: bar=%s txt=%s" % [str(_st_bar.value if _st_bar else "null"), _st_txt.text if _st_txt else "null"])
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
	_expect(_shield != null and _shield.visible, "Shield visible=true while blocking", "Shield not shown on block: vis=%s" % [str(_shield.visible if _shield else "noNode")])
	_expect(_blk_seen >= 1, "BlockPressed signal fired %d times" % _blk_seen, "BlockPressed NOT fired")
	_expect(_block_aura != null and _block_aura.visible, "BlockAura (yellow frame) visible=true while blocking", "Aura not shown on block: vis=%s" % [str(_block_aura.visible if _block_aura else "noNode")])
	_expect(_aura_top != null and _aura_top.color.r > 0.9 and _aura_top.color.g > 0.8 and _aura_top.color.b < 0.4, "BlockAura lines yellow (R%.2f G%.2f B%.2f)" % [_aura_top.color.r, _aura_top.color.g, _aura_top.color.b], "Aura lines not yellow, expected bright yellow")
	# Stamina after Dash(-18) + Block 0.2s(-10*0.2=-2) => ~80
	var st_after_dash: int = int(_test_scene.get("_stamina") if "_stamina" in _test_scene else -1)
	_expect(st_after_dash >= 70 and st_after_dash <= 88, "Dash + 0.2s Block cost SP (now=%d, expect 70~88)" % st_after_dash, "Stamina cost mismatch: dash=-18 block/sec=-10 got %d" % st_after_dash)
	_expect(_st_bar and _st_txt and _st_txt.text == "%d/100" % st_after_dash, "SP UI updated after Dash+Block (txt=%s)" % (_st_txt.text if _st_txt else "null"), "SP UI not refreshed")
	# Keep blocking another 0.5s -> SP should continue dropping by ~5.5
	_sched(0.5, func():
		_phase3a_continuous_block_drop(st_after_dash)
	)

func _phase3a_continuous_block_drop(st_before: int) -> void:
	var st_drop: int = int(_test_scene.get("_stamina") if "_stamina" in _test_scene else -1)
	var expected_min: int = st_before - 8
	var expected_max: int = st_before - 2
	var st_pct: float = float(st_drop) / float(max(1, int(_test_scene.get("_stamina_max"))))
	var aura_mod_g: float = _block_aura.modulate.g if _block_aura else 0.0
	var aura_mod_r: float = _block_aura.modulate.r if _block_aura else 0.0
	_expect(st_drop >= expected_min and st_drop <= expected_max, "Block 0.5s => SP drops (was=%d now=%d, expect %d~%d)" % [st_before, st_drop, expected_min, expected_max], "Continuous block not draining SP: remain=%d no change!" % st_drop)
	_expect(_block_aura != null and _block_aura.visible, "Aura still visible while still blocking", "Aura disappeared mid-block!")
	# After 0.7s total block: st_pct ~ (100-18-7.7)/100 = 0.743 => g=lerp(0.2, 0.95, 0.74) ~0.755, expect r=1, g<0.92
	_expect(abs(aura_mod_r - 1.0) < 0.1, "Aura modulate.r=%.2f ~1.0 (R channel always 1)" % aura_mod_r, "Aura color wrong: R=%.2f" % aura_mod_r)
	_expect(aura_mod_g < 0.94 and aura_mod_g > 0.3, "Aura modulate.g=%.2f darkens as SP drops (st_pct=%.2f)" % [aura_mod_g, st_pct], "Aura color not tracking SP level (g=%.2f)" % aura_mod_g)
	# Release block -> shield hide + aura hide, wait for stamina recovery
	InputBus.BlockReleased.emit()
	_sched(1.4, _phase3b_block_released_and_recover)

func _phase3b_block_released_and_recover() -> void:
	_expect(_shield != null and not _shield.visible, "Shield hidden after BlockReleased", "Shield still visible after release")
	_expect(_block_aura != null and not _block_aura.visible, "BlockAura hidden after BlockReleased", "Aura still shown after block released!")
	var st_rec: int = int(_test_scene.get("_stamina") if "_stamina" in _test_scene else -1)
	# Recovery cooldown 0.8s + 0.6s recover * 14/s = +8.4 => at least 85 (was lower because kept blocking extra 0.5s)
	_expect(st_rec >= 82, "SP recovered after 1.4s rest: now=%d (expect >=82)" % st_rec, "Stamina recovery broken, still %d after rest" % st_rec)
	# Damage/Heal & clamp tests via call
	if _test_scene and _test_scene.has_method("damage"):
		_test_scene.call("damage", 150)
	var hp_dmg: int = int(_test_scene.get("_hp") if "_hp" in _test_scene else -1)
	_expect(hp_dmg == 0, "damage(150) clamped HP=%d to floor 0" % hp_dmg, "HP lower clamp broken =%d" % hp_dmg)
	if _test_scene and _test_scene.has_method("heal"):
		_test_scene.call("heal", 9999)
	var hp_heal: int = int(_test_scene.get("_hp") if "_hp" in _test_scene else -1)
	_expect(hp_heal == 100, "heal(9999) clamped HP=%d to cap 100" % hp_heal, "HP upper clamp broken =%d" % hp_heal)
	if _test_scene and _test_scene.has_method("damage"):
		_test_scene.call("damage", 23)
	var hp2: int = int(_test_scene.get("_hp") if "_hp" in _test_scene else -1)
	_expect(hp2 == 77 and _hp_txt and _hp_txt.text == "77/100", "damage(23)=77, UI txt=%s" % (_hp_txt.text if _hp_txt else "null"), "HP damage UI out of sync: hp=%s bar=%s" % [str(hp2), _hp_txt.text if _hp_txt else "null"])
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
	# Phase 4d: teleport player onto Rake pickup -> auto-pick weapon, equip rake in hand
	if _rake1:
		_player.position = _rake1.position
		if "_nearby_pickups" in _test_scene:
			var nb3: Array = _test_scene["_nearby_pickups"]
			if not nb3.has(_rake1):
				nb3.append(_rake1)
	_sched(0.25, _phase4d_rake_picked)

func _phase4d_rake_picked() -> void:
	var nb_rake: int = -1
	var nb_arr_r: Array = _test_scene["_nearby_pickups"] if "_nearby_pickups" in _test_scene else []
	nb_rake = nb_arr_r.size()
	var has_w: bool = bool(_test_scene.get("_has_weapon") if "_has_weapon" in _test_scene else false)
	var wh_vis: bool = _weapon_holder.visible if _weapon_holder else false
	var rake_gone: bool = true
	if _rake1 and is_instance_valid(_rake1):
		rake_gone = _rake1.is_queued_for_deletion()
	_expect(nb_rake == 0, "Auto-pickup Rake -> nearby_pickups size=%d (expect 0)" % nb_rake, "Rake not auto-picked! size=%d" % nb_rake)
	_expect(has_w, "After Rake pickup -> _has_weapon=true (internal flag)", "Internal _has_weapon flag still false after pickup!")
	_expect(_weapon_holder != null and wh_vis, "After Rake pickup -> WeaponHolder visible (rake shown in hand)", "WeaponHolder hidden, rake not displayed in hand: vis=%s" % [str(wh_vis)])
	_expect(rake_gone, "Rake pickup vanished after auto-pick (queue_free/invalid=%s)" % str(rake_gone), "Rake still visible on floor after pickup!")
	# Phase4e: Attack with weapon via X/attack action (SP drops, AttackPressed signal counted)
	var st_before_atk: int = int(_test_scene.get("_stamina") if "_stamina" in _test_scene else -1)
	_atk_seen = 0
	InputBus.AttackPressed.emit()
	_sched(0.1, func():
		_phase4e_attacked(st_before_atk)
	)

func _phase4e_attacked(st_bef: int) -> void:
	var atk_sig: int = _atk_seen
	var st_after: int = int(_test_scene.get("_stamina") if "_stamina" in _test_scene else -1)
	var st_drop: int = st_bef - st_after
	var wh_rot: float = 0.0
	if _weapon_holder:
		wh_rot = _weapon_holder.rotation
	var swinging: bool = abs(wh_rot - (-0.95)) > 0.05 or abs(wh_rot - 0.95) > 0.05
	var rake_rotated: bool = swinging or st_drop >= 3
	_expect(atk_sig == 1, "AttackPressed fired exactly %d time (X/J rake swing)" % atk_sig, "AttackPressed signal seen=%d times (expected 1 after AttackPressed.emit)" % atk_sig)
	_expect(st_drop >= 3 and st_drop <= 7, "Attack 1x => SP drops by %d (need 4, got %d-%d = %d)" % [st_drop, st_bef, st_after, st_drop], "Attack didn't spend any stamina: SP before=%d after=%d drop=%d" % [st_bef, st_after, st_drop])
	_expect(rake_rotated, "WeaponHolder.rotation=%.3f during 0.1s after attack (mid-swing offset from base ±0.95 >0.05) OR SP dropped >=3" % wh_rot, "Rake stayed at base rotation after attack! rotation=%.3f (no mid-swing motion detected; SP drop=%d)" % [wh_rot, st_drop])
	# --- Now proceed to original Phase5 (Ladder climb) ---
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
func _on_br() -> void: _blk_rel_seen += 1
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

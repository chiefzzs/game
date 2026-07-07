extends Node2D
## Headless runtime test for V01_InputCollisionTest.
var passed: int = 0
var failed: int = 0
var _test_scene: Node2D
var _hud: Label
var _player: CharacterBody2D
var _drawer: Node2D
var _jump_seen: int = 0
var _atk_seen: int = 0
var _blk_seen: int = 0
var _dash_seen: int = 0
var _lines_out: Array[String] = []

func _ready() -> void:
	var packed := load("res://scenes/test/V01_InputCollisionTest.tscn")
	_test_scene = packed.instantiate()
	add_child(_test_scene)
	_sched(0.1, _phase1_nodes_present)

func _phase1_nodes_present() -> void:
	_hud = _test_scene.get_node_or_null("UI/VBox/HudLog") as Label
	_player = _test_scene.get_node_or_null("World/Player") as CharacterBody2D
	_drawer = _test_scene.get_node_or_null("World/Player/Drawer") as Node2D
	_expect(_hud != null, "HudLabel present", "HudLabel missing")
	_expect(_player != null, "Player present", "Player missing")
	_expect(_drawer != null, "Drawer present", "Drawer missing")
	_sched(0.1, _phase2_hud_flushed)

func _phase2_hud_flushed() -> void:
	var t: String = _hud.text if _hud else ""
	if "启动中" in t:
		_fail("HUD still shows 启动中 (flush never happened)")
	elif "Scene ready" in t:
		_pass("HUD flushed with Scene ready log (_ready ran, script not disabled)")
	else:
		_fail("HUD missing ready text: %.120s" % t)
	# Hook signal counters
	InputBus.JumpPressed.connect(_on_j)
	InputBus.AttackPressed.connect(_on_a)
	InputBus.BlockPressed.connect(_on_b)
	InputBus.DashPressed.connect(_on_d)
	# Fire InputBus signals directly (InputBus kbd->signal mapping was already
	# validated in Config/Save acceptance; here we test scene signal callbacks
	# stay alive (not disabled by _process crash) and flush HUD correctly.)
	_sched(0.1, func():
		InputBus.MoveLeftPressed.emit()
		InputBus.AttackPressed.emit()
	)
	_sched(0.3, func():
		InputBus.MoveRightPressed.emit()
		InputBus.BlockPressed.emit()
		InputBus.JumpPressed.emit()
		InputBus.DashPressed.emit()
	)
	_sched(0.45, func():
		InputBus.BlockReleased.emit()
	)
	_sched(1.8, _phase3_signals_and_tick)

func _phase3_signals_and_tick() -> void:
	_expect(_jump_seen >= 1, "JumpPressed fired %d times" % _jump_seen, "JumpPressed NOT fired")
	_expect(_atk_seen >= 1, "AttackPressed fired %d times" % _atk_seen, "AttackPressed NOT fired")
	_expect(_blk_seen >= 1, "BlockPressed fired %d times" % _blk_seen, "BlockPressed NOT fired")
	_expect(_dash_seen >= 1, "DashPressed fired %d times" % _dash_seen, "DashPressed NOT fired")
	var hud_txt: String = _hud.text if _hud else ""
	var got_event: bool = ("JumpPressed" in hud_txt) or ("AttackPressed" in hud_txt) or ("BlockPressed" in hud_txt)
	_expect(got_event, "HUD received event log (callbacks alive)", "HUD missing event log: %.200s" % hud_txt)
	var tick: int = -1
	if _test_scene and "_tick" in _test_scene:
		tick = int(_test_scene.get("_tick"))
	_expect(tick > 0, "_tick=%d (process alive, velocity declared)" % tick, "_tick==0, _process likely crashed")
	var sx: float = _drawer.scale.x if _drawer else -999.0
	_expect(abs(sx - 1.0) < 0.001, "Drawer scale.x=%.3f after move_right (no Sprite2D crash)" % sx, "Drawer bad scale.x=%.3f" % sx)
	var onf: bool = _player.is_on_floor() if _player else false
	if onf:
		_pass("Player onFloor=true (collision layer/mask 4 vs 4 OK)")
	else:
		var py: float = _player.position.y if _player else -1
		_fail("onFloor=false, pos.y=%.1f (maybe still falling?)" % py)
	_finalize()

func _finalize() -> void:
	_lines_out.append("---- RUNTIME TEST: passed=%d failed=%d ----" % [passed, failed])
	_lines_out.append("Total: passed=%d failed=%d" % [passed, failed])
	for line in _lines_out:
		print(line)
	# Also flush to file in project root (user:// location is hard to locate on windows)
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

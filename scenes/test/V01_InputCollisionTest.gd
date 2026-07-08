extends Node2D
## V0.1 F4 scene: Input + Collision + Dash + Block + Pickups + Ladder climb
## Controls
##   A/D or stick-L -> move
##   Space or pad-A -> jump
##   K or pad-Y -> dash (has cooldown)
##   Left Shift or pad-LT -> block (draws shield in front of player)
##   E or pad-B -> interact / pick up nearby items
##   W/S or stick-U/D while on ladder -> climb
@onready var lbl: Label = $UI/VBox/HudLog
@onready var player: CharacterBody2D = $World/Player
@onready var drawer: Node2D = $World/Player/Drawer
@onready var shield: Node2D = $World/Player/Shield
@onready var inv_gold: Label = $UI/Inv/GoldVal
@onready var inv_pot: Label = $UI/Inv/PotVal
var lines: Array[String] = ["Move:A/D | Jump:Space | Dash:K/Y | Block:Shift/LT | Pickup:E/B | Climb:W/S on ladder | Esc back"]
var velocity: Vector2 = Vector2.ZERO
var _tick: int = 0

var _dash_cd: float = 0.0
var _dash_speed: float = 650.0
var _dash_dur: float = 0.16
var _dash_timer: float = 0.0
var _dash_dir: float = 0.0
var _is_blocking: bool = false
var _inventory_gold: int = 0
var _inventory_pot: int = 0
var _nearby_pickups: Array[Node] = []
var _is_climbing: bool = false
var _in_ladder_area: bool = false

var _jump_buffer_timer: float = 0.0
const JUMP_BUFFER_WINDOW: float = 0.12
var _coyote_timer: float = 0.0
const COYOTE_WINDOW: float = 0.10
var _is_jumping: bool = false
const JUMP_CUT_MULTIPLIER: float = 0.45

func _ready() -> void:
	InputBus.JumpPressed.connect(_on_jump)
	InputBus.AttackPressed.connect(func(): hud("[OK] AttackPressed (X/J)"))
	InputBus.DashPressed.connect(_on_dash)
	InputBus.BlockPressed.connect(_on_block_p)
	InputBus.BlockReleased.connect(_on_block_r)
	InputBus.InteractPressed.connect(_on_interact)
	# connect all Area2D nodes (Pickups/Ladder) body_entered/exited -> our callbacks (player is the body entering Area)
	for child in $World.get_children():
		if child is Area2D:
			var area: Area2D = child
			area.body_entered.connect(func(b: Node): _on_area2d_body_entered(area, b))
			area.body_exited.connect(func(b: Node): _on_area2d_body_exited(area, b))
	hud("[OK] Scene ready. onFloor=%s" % player.is_on_floor())
	hud("[INFO] Gold=0 Potion=0 Nearby=0 Climb=false DashCD=0.0")
	_refresh_inventory()
	_flush()

func hud(msg: String) -> void:
	lines.append(msg)
	while lines.size() > 11:
		lines.pop_front()
	_flush()

func _flush() -> void:
	if not lbl:
		return
	var blocking_txt := "[BLOCK] " if _is_blocking else "         "
	var dash_txt := "DASH!" if _dash_timer > 0.0 else ("cd%.1f" % _dash_cd) if _dash_cd > 0.0 else "dashOK"
	var climb_txt := "CLIMB" if _is_climbing else ("LADDER" if _in_ladder_area else "     ")
	lines[0] = "%s  %s  %s  ax=%.2f bl=%.2f onF=%s tick=%d" % [blocking_txt, dash_txt, climb_txt, InputBus.moveAxis, InputBus.blockStrength, player.is_on_floor(), _tick]
	lbl.text = "\n".join(lines)

func _refresh_inventory() -> void:
	if inv_gold:
		inv_gold.text = str(_inventory_gold)
	if inv_pot:
		inv_pot.text = str(_inventory_pot)

func _on_jump() -> void:
	_jump_buffer_timer = JUMP_BUFFER_WINDOW
	if _is_climbing:
		_is_climbing = false
		hud("[LADDER] jump -> off ladder")
	else:
		hud("[OK] JumpPressed (buffered %.0fms)" % [JUMP_BUFFER_WINDOW * 1000.0])

func _on_dash() -> void:
	if _dash_cd > 0.0 or _dash_timer > 0.0:
		hud("[DASH] skipped (on cd %.1fs)" % _dash_cd)
		return
	var dir: float = InputBus.moveAxis
	if abs(dir) < 0.05:
		dir = -1.0 if drawer and drawer.scale.x < 0.0 else 1.0
	_dash_dir = dir
	_dash_timer = _dash_dur
	_dash_cd = 0.65
	hud("[DASH] fire dir=%.1f" % _dash_dir)

func _on_block_p() -> void:
	_is_blocking = true
	if shield:
		shield.visible = true
	hud("[OK] BlockPressed (shield ON)")

func _on_block_r() -> void:
	_is_blocking = false
	if shield:
		shield.visible = false
	hud("[OK] BlockReleased (shield OFF)")

func _on_interact() -> void:
	hud("[PICKUP] auto-pickup enabled. Walk over items to collect them")

func _pickup_one(pickup: Node) -> void:
	if pickup == null or not is_instance_valid(pickup):
		return
	var kind: String = "?"
	if pickup.has_meta("pickup_kind"):
		kind = str(pickup.get_meta("pickup_kind"))
	match kind:
		"gold":
			_inventory_gold += 1
			hud("[AUTO-PICKUP] +1 Gold  (total %d)" % _inventory_gold)
		"potion":
			_inventory_pot += 1
			hud("[AUTO-PICKUP] +1 Potion (total %d)" % _inventory_pot)
		_:
			hud("[AUTO-PICKUP] unknown kind=%s" % kind)
	if pickup.has_method("queue_free"):
		pickup.queue_free()
	_refresh_inventory()

func _on_area2d_body_entered(area: Area2D, body: Node) -> void:
	if not (body is CharacterBody2D):
		return
	var role: String = str(area.get_meta("role") if area.has_meta("role") else "")
	match role:
		"pickup":
			if not _nearby_pickups.has(area):
				_nearby_pickups.append(area)
				var kind: String = str(area.get_meta("pickup_kind") if area.has_meta("pickup_kind") else "?")
				hud("[PICKUP] detect +%s  (near=%d). Will auto-pick" % [kind, _nearby_pickups.size()])
		"ladder":
			_in_ladder_area = true
			hud("[LADDER] enter. Press W/S (or stick up/down) to climb")

func _on_area2d_body_exited(area: Area2D, body: Node) -> void:
	if not (body is CharacterBody2D):
		return
	var role: String = str(area.get_meta("role") if area.has_meta("role") else "")
	match role:
		"pickup":
			_nearby_pickups.erase(area)
			hud("[PICKUP] item left area (near=%d)" % _nearby_pickups.size())
		"ladder":
			_in_ladder_area = false
			if _is_climbing:
				_is_climbing = false
				hud("[LADDER] exit (fell off ladder)")

func _physics_process(delta: float) -> void:
	_tick += 1
	var speed: float = float(Config.GetL2("player.moveSpeed", 260.0))
	var jf: float = float(Config.GetL2("player.jumpForce", -720.0))
	var gravity_scale: float = float(Config.GetL1("physics.gravity_scale_default", 1.3))
	var max_fall: float = float(Config.GetL1("physics.max_fall_speed", 1200.0))
	var climb_speed: float = 200.0
	# climb activation: in ladder + vertical input
	var v_axis: float = Input.get_axis("ui_up", "ui_down")
	var stick_y: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y) if Input.get_connected_joypads().size() > 0 else 0.0
	if abs(stick_y) > 0.25:
		v_axis = stick_y
	if _in_ladder_area and (abs(v_axis) > 0.15 or _is_climbing):
		_is_climbing = true
		velocity.y = -v_axis * climb_speed
		velocity.x = move_toward(velocity.x, InputBus.moveAxis * speed * 0.45, 900.0 * delta)
	else:
		_is_climbing = false
		_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)
		if player.is_on_floor():
			_coyote_timer = COYOTE_WINDOW
		else:
			_coyote_timer = max(0.0, _coyote_timer - delta)
		velocity.x = move_toward(velocity.x, InputBus.moveAxis * speed, 1200.0 * delta)
		velocity.y += 980.0 * gravity_scale * delta
		velocity.y = min(velocity.y, max_fall)
		if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
			velocity.y = jf
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0
			_is_jumping = true
		if _is_jumping and velocity.y < 0.0 and not InputBus.IsJumpHeld():
			velocity.y *= JUMP_CUT_MULTIPLIER
			_is_jumping = false
	# dash timer
	if _dash_timer > 0.0:
		_dash_timer = max(0.0, _dash_timer - delta)
		velocity.x = _dash_dir * _dash_speed
		if _dash_timer == 0.0:
			hud("[DASH] finished")
	if _dash_cd > 0.0:
		_dash_cd = max(0.0, _dash_cd - delta)
	player.velocity = velocity
	player.move_and_slide()
	velocity = player.velocity
	if velocity.y >= 0.0:
		_is_jumping = false
	while _nearby_pickups.size() > 0:
		var item: Node = _nearby_pickups.pop_front()
		_pickup_one(item)
	if abs(InputBus.moveAxis) > 0.01 and drawer:
		drawer.scale.x = -1.0 if InputBus.moveAxis < 0.0 else 1.0
		if shield:
			shield.position.x = 18.0 if drawer.scale.x > 0.0 else -18.0
	_flush()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
	if e is InputEventKey:
		match e.physical_keycode:
			KEY_F1:
				get_tree().change_scene_to_file("res://scenes/test/V01_ConfigTest.tscn")
			KEY_F2:
				get_tree().change_scene_to_file("res://scenes/test/V01_FlagsTest.tscn")
			KEY_F3:
				get_tree().change_scene_to_file("res://scenes/test/V01_SaveTest.tscn")
			KEY_F4:
				pass

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
@onready var block_aura: Node2D = $World/Player/BlockAura
@onready var inv_gold: Label = $UI/Inv/GoldVal
@onready var inv_pot: Label = $UI/Inv/PotVal
@onready var hp_bar: ProgressBar = $UI/HealthBars/HpRow/HpBar
@onready var hp_txt: Label = $UI/HealthBars/HpRow/HpText
@onready var st_bar: ProgressBar = $UI/HealthBars/StRow/StBar
@onready var st_txt: Label = $UI/HealthBars/StRow/StText
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

var _hp_max: int = 100
var _hp: int = 100
var _stamina_max: int = 100
var _stamina: int = 100
var _stamina_f_acc: float = 100.0
var _stamina_recovery_rate: float = 14.0
var _stamina_recovery_cd: float = 0.0
const STAMINA_RECOVERY_COOLDOWN: float = 0.8
const DASH_STAMINA_COST: int = 18
const BLOCK_STAMINA_TICK: float = 11.0
var _aura_pulse_t: float = 0.0

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
	_refresh_bars()
	_flush()

func hud(msg: String) -> void:
	lines.append(msg)
	while lines.size() > 11:
		lines.pop_front()
	_flush()

func set_hp(value: int) -> void:
	var old: int = _hp
	_hp = clamp(value, 0, _hp_max)
	if _hp != old:
		_refresh_bars()

func damage(amount: int) -> void:
	if amount <= 0:
		return
	var old: int = _hp
	set_hp(_hp - amount)
	hud("[DAMAGE] -%d HP  (%d -> %d)" % [amount, old, _hp])

func heal(amount: int) -> void:
	if amount <= 0:
		return
	var old: int = _hp
	set_hp(_hp + amount)
	if _hp > old:
		hud("[HEAL] +%d HP  (%d -> %d)" % [_hp - old, old, _hp])

func set_stamina(value: int) -> void:
	var old: int = _stamina
	_stamina = clamp(value, 0, _stamina_max)
	_stamina_f_acc = float(_stamina)
	if _stamina != old:
		_refresh_bars()

func spend_stamina(amount: int) -> bool:
	if amount <= 0:
		return true
	if _stamina < amount:
		return false
	_stamina -= amount
	_stamina_f_acc = float(_stamina)
	_stamina_recovery_cd = STAMINA_RECOVERY_COOLDOWN
	_refresh_bars()
	return true

func recover_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	var old: int = _stamina
	_stamina_f_acc = clamp(_stamina_f_acc + amount, 0.0, float(_stamina_max))
	var next: int = int(_stamina_f_acc)
	_stamina = clamp(next, 0, _stamina_max)
	if _stamina != old:
		_refresh_bars()

func _refresh_bars() -> void:
	if hp_bar:
		hp_bar.max_value = float(_hp_max)
		hp_bar.value = float(_hp)
	if hp_txt:
		hp_txt.text = "%d/%d" % [_hp, _hp_max]
	if st_bar:
		st_bar.max_value = float(_stamina_max)
		st_bar.value = float(_stamina)
	if st_txt:
		st_txt.text = "%d/%d" % [_stamina, _stamina_max]

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
		var jf: float = float(Config.GetL2("player.jumpForce", -720.0))
		velocity.y = jf
		_is_jumping = true
		hud("[LADDER] jump off ladder")
	else:
		hud("[OK] JumpPressed (buffered %.0fms)" % [JUMP_BUFFER_WINDOW * 1000.0])

func _on_dash() -> void:
	if _dash_cd > 0.0 or _dash_timer > 0.0:
		hud("[DASH] skipped (on cd %.1fs)" % _dash_cd)
		return
	if not spend_stamina(DASH_STAMINA_COST):
		hud("[DASH] skipped (need %d SP, have %d)" % [DASH_STAMINA_COST, _stamina])
		return
	var dir: float = InputBus.moveAxis
	if abs(dir) < 0.05:
		dir = -1.0 if drawer and drawer.scale.x < 0.0 else 1.0
	_dash_dir = dir
	_dash_timer = _dash_dur
	_dash_cd = 0.65
	hud("[DASH] fire dir=%.1f  (-%d SP, remain=%d)" % [_dash_dir, DASH_STAMINA_COST, _stamina])

func _on_block_p() -> void:
	if _stamina <= 0:
		hud("[BLOCK] skipped (no stamina)")
		return
	_is_blocking = true
	if shield:
		shield.visible = true
	if block_aura:
		block_aura.visible = true
	_update_aura_color()
	hud("[OK] BlockPressed (shield + yellow aura ON)")

func _on_block_r() -> void:
	_is_blocking = false
	if shield:
		shield.visible = false
	if block_aura:
		block_aura.visible = false
	hud("[OK] BlockReleased (shield + aura OFF)")

func _update_aura_color() -> void:
	if not block_aura:
		return
	var pct: float = clamp(float(_stamina) / max(1.0, float(_stamina_max)), 0.0, 1.0)
	var r: float = 1.0
	var g: float = lerp(0.2, 0.95, pct)
	var b: float = lerp(0.0, 0.18, pct)
	var pulse: float = 0.82 + 0.18 * sin(_aura_pulse_t * 7.0)
	var col: Color = Color(r, g, b, 0.8 + 0.2 * pulse)
	block_aura.modulate = col

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
		velocity.y = v_axis * climb_speed
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
	# block 持续消耗体力 + 体力耗尽自动解除格挡
	if _is_blocking:
		_aura_pulse_t += delta
		var cost: float = BLOCK_STAMINA_TICK * delta
		_stamina_f_acc = clamp(_stamina_f_acc - cost, 0.0, float(_stamina_max))
		var st_new: int = int(_stamina_f_acc)
		if st_new != _stamina:
			_stamina = st_new
			_refresh_bars()
		_update_aura_color()
		if _stamina_f_acc <= 0.0:
			_stamina = 0
			_stamina_f_acc = 0.0
			_is_blocking = false
			if shield:
				shield.visible = false
			if block_aura:
				block_aura.visible = false
			hud("[BLOCK] out of stamina -> released")
		_stamina_recovery_cd = STAMINA_RECOVERY_COOLDOWN
	else:
		if _stamina_recovery_cd > 0.0:
			_stamina_recovery_cd = max(0.0, _stamina_recovery_cd - delta)
		elif _stamina < _stamina_max:
			recover_stamina(_stamina_recovery_rate * delta)
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

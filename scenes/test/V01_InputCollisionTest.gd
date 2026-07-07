extends Node2D
## V0.1 input + collision test scene (F4 entry from main menu)
## - A/D or stick-L move
## - Space/A jump
## - LT/Left Shift block (blockStrength>0.35 shows in HUD)
## - K/Y dash
@onready var lbl: Label = $UI/VBox/HudLog
@onready var player: CharacterBody2D = $World/Player
@onready var drawer: Node2D = $World/Player/Drawer
var lines: Array[String] = ["A/D or stick-L to move | Space/A jump | LT/Shift block | K/Y dash | Esc back to menu"]
var velocity: Vector2 = Vector2.ZERO
var _tick: int = 0

func _ready() -> void:
	InputBus.JumpPressed.connect(func(): hud("[OK] JumpPressed"))
	InputBus.AttackPressed.connect(func(): hud("[OK] AttackPressed (X / J)"))
	InputBus.DashPressed.connect(func(): hud("[OK] DashPressed (Y / K)"))
	InputBus.BlockPressed.connect(func(): hud("[OK] BlockPressed (LT / Shift)"))
	InputBus.BlockReleased.connect(func(): hud("[OK] BlockReleased"))
	InputBus.InteractPressed.connect(func(): hud("[OK] InteractPressed (B / E)"))
	hud("[OK] Scene ready. onFloor=%s" % player.is_on_floor())
	_flush()

func hud(msg: String) -> void:
	lines.append(msg)
	while lines.size() > 12:
		lines.pop_front()
	_flush()

func _flush() -> void:
	if lbl:
		lbl.text = "\n".join(lines)

func _process(delta: float) -> void:
	_tick += 1
	var speed: float = float(Config.GetL2("player.moveSpeed", 260.0))
	var jf: float = float(Config.GetL2("player.jumpForce", -560.0))
	var gravity_scale: float = float(Config.GetL1("physics.gravity_scale_default", 1.8))
	var max_fall: float = float(Config.GetL1("physics.max_fall_speed", 1200.0))
	velocity.x = move_toward(velocity.x, InputBus.moveAxis * speed, 1200.0 * delta)
	velocity.y += 980.0 * gravity_scale * delta
	velocity.y = min(velocity.y, max_fall)
	if InputBus.IsJumpHeld() and player.is_on_floor():
		velocity.y = jf
	player.velocity = velocity
	player.move_and_slide()
	velocity = player.velocity
	if abs(InputBus.moveAxis) > 0.01 and drawer:
		drawer.scale.x = -1.0 if InputBus.moveAxis < 0.0 else 1.0
	lines[0] = "moveAxis=%.2f | blockStrength=%.2f | onFloor=%s | tick=%d" % [
		InputBus.moveAxis, InputBus.blockStrength, player.is_on_floor(), _tick
	]
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

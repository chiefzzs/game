extends Node2D
## V0.1 输入+碰撞测试：
## - A/D 或 摇杆 左右移动
## - Space/A 跳跃
## - LT/左Shift 格挡（blockStrength>0.35有指示）
## - K/Y 冲刺
## - 观察HUD日志；角色要站在地面不穿墙
@onready var lbl: Label = $UI/VBox/HudLog
@onready var player: CharacterBody2D = $World/Player
var lines: Array[String] = ["移动：A/D或摇杆L ｜ 跳跃：Space/A ｜ 格挡：LT/Shift ｜ 冲刺：K/Y ｜ Esc回主菜单"]

func _ready() -> void:
	InputBus.JumpPressed.connect(func(): log("⬆ JumpPressed"))
	InputBus.AttackPressed.connect(func(): log("⚔ AttackPressed (X键)"))
	InputBus.DashPressed.connect(func(): log("💨 DashPressed (Y键)"))
	InputBus.BlockPressed.connect(func(): log("🛡 BlockPressed (LT)"))
	InputBus.BlockReleased.connect(func(): log("🛡~BlockReleased"))
	InputBus.InteractPressed.connect(func(): log("🤝 InteractPressed (B键/E)"))

func log(msg: String) -> void:
	lines.append(msg)
	while lines.size() > 12: lines.pop_front()
	lbl.text = String("\n").join(lines)

func _process(delta: float) -> void:
	# ---------- 简化版移动/跳跃（V0.3会替换成正式手感，这里只为验证输入+碰撞） ----------
	var speed := Config.GetL2("player.moveSpeed", 260.0)
	var jf := Config.GetL2("player.jumpForce", -560.0)
	var gravity_scale := Config.GetL1("physics.gravity_scale_default", 1.8)
	velocity.x = move_toward(velocity.x, InputBus.moveAxis * speed, 1200.0 * delta)
	velocity.y += 980.0 * gravity_scale * delta
	velocity.y = min(velocity.y, Config.GetL1("physics.max_fall_speed", 1200.0))
	if InputBus.IsJumpHeld() and player.is_on_floor():
		velocity.y = jf
	player.velocity = velocity
	player.move_and_slide()
	# 翻转角色
	if abs(InputBus.moveAxis) > 0.01:
		player.get_node("Sprite2D").flip_h = InputBus.moveAxis < 0
	# HUD 持续显示block/axis状态
	lines[0] = "moveAxis=%.2f | blockStrength=%.2f | onFloor=%s | Esc回菜单" % [
		InputBus.moveAxis, InputBus.blockStrength, player.is_on_floor()
	]
	lbl.text = String("\n").join(lines)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
	# 快速切测试场景：F1=Config F2=Flags F3=Save F4=这里
	if e is InputEventKey:
		match e.physical_keycode:
			KEY_F1: get_tree().change_scene_to_file("res://scenes/test/V01_ConfigTest.tscn")
			KEY_F2: get_tree().change_scene_to_file("res://scenes/test/V01_FlagsTest.tscn")
			KEY_F3: get_tree().change_scene_to_file("res://scenes/test/V01_SaveTest.tscn")
			KEY_F4: pass

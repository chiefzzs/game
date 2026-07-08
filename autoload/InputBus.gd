extends Node
## V0.3 InputBus.gd - 全局输入解耦单例
## 职责：把Godot原生 _input 统一翻译为游戏语义信号，所有角色/UI/系统只订阅本Bus不直接读Input
signal axis_changed(horizontal: float, vertical: float)
signal move_left_pressed
signal move_right_pressed
signal jump_pressed(held: bool)
signal jump_released
signal dash_pressed
signal attack_pressed
signal block_pressed
signal block_released
signal interact_pressed
signal pause_pressed
signal weapon_changed(slot: int)
signal pickup_manual_pressed

var axis_h: float = 0.0
var axis_v: float = 0.0
var is_blocking: bool = false
var jump_held: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _physics_process(_delta: float) -> void:
	var h: float = Input.get_axis("move_left", "move_right")
	var v: float = 0.0
	if abs(h - axis_h) > 0.001 or abs(v - axis_v) > 0.001:
		axis_h = h
		axis_v = v
		emit_signal("axis_changed", h, v)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_held = true
		emit_signal("jump_pressed", true)
	elif event.is_action_released("jump"):
		jump_held = false
		emit_signal("jump_released")
	elif event.is_action_pressed("dash"):
		emit_signal("dash_pressed")
	elif event.is_action_pressed("attack"):
		emit_signal("attack_pressed")
	elif event.is_action_pressed("block"):
		is_blocking = true
		emit_signal("block_pressed")
	elif event.is_action_released("block"):
		is_blocking = false
		emit_signal("block_released")
	elif event.is_action_pressed("interact"):
		emit_signal("interact_pressed")
	elif event.is_action_pressed("pause"):
		emit_signal("pause_pressed")
	elif event.is_action_pressed("weapon_1"):
		emit_signal("weapon_changed", 1)
	elif event.is_action_pressed("weapon_2"):
		emit_signal("weapon_changed", 2)
	elif event.is_action_pressed("weapon_3"):
		emit_signal("weapon_changed", 3)

func force_release_all() -> void:
	if is_blocking:
		is_blocking = false
		emit_signal("block_released")
	if jump_held:
		jump_held = false
		emit_signal("jump_released")

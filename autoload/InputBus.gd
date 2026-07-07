extends Node
## 输入总线（Autoload单例，Node名：InputBus，避免和Godot内置Input重名）
## 所有玩家代码只监听这些信号，不直接读物理按键

signal MoveLeftPressed()
signal MoveRightPressed()
signal JumpPressed()
signal JumpReleased()
signal AttackPressed()
signal DashPressed()
signal BlockPressed()
signal BlockReleased()
signal InteractPressed()
signal PausePressed()

var blockStrength: float = 0.0
var moveAxis: float = 0.0

func _process(_delta: float) -> void:
	moveAxis = Input.get_axis("move_left", "move_right")
	blockStrength = clamp(Input.get_action_strength("block"), 0.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"): JumpPressed.emit()
	if event.is_action_released("jump"): JumpReleased.emit()
	if event.is_action_pressed("attack"): AttackPressed.emit()
	if event.is_action_pressed("dash"): DashPressed.emit()
	if event.is_action_pressed("block"): BlockPressed.emit()
	if event.is_action_released("block"): BlockReleased.emit()
	if event.is_action_pressed("interact"): InteractPressed.emit()
	if event.is_action_pressed("pause"): PausePressed.emit()
	if event.is_action_pressed("move_left"): MoveLeftPressed.emit()
	if event.is_action_pressed("move_right"): MoveRightPressed.emit()

func IsJumpHeld() -> bool: return Input.is_action_pressed("jump")
func IsBlockHeld() -> bool: return blockStrength > 0.35

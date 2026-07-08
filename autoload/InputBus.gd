extends Node
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
signal AxisChanged(h_axis: float, v_axis: float)
signal WeaponChanged(slot: int)

var blockStrength: float = 0.0
var moveAxis: float = 0.0
var _block_strength_prev: float = 0.0
var _last_axis_h: float = 0.0
const BLOCK_THRESHOLD: float = 0.35

func _process(_delta: float) -> void:
	moveAxis = Input.get_axis("move_left", "move_right")
	var st: float = clamp(Input.get_action_strength("block"), 0.0, 1.0)
	blockStrength = st
	if _block_strength_prev < BLOCK_THRESHOLD and st >= BLOCK_THRESHOLD:
		if not Input.is_action_just_pressed("block"):
			BlockPressed.emit()
	elif _block_strength_prev >= BLOCK_THRESHOLD and st < BLOCK_THRESHOLD:
		if not Input.is_action_just_released("block"):
			BlockReleased.emit()
	_block_strength_prev = st
	var v_axis: float = 0.0
	if abs(moveAxis - _last_axis_h) > 0.001:
		AxisChanged.emit(moveAxis, v_axis)
		_last_axis_h = moveAxis

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
	if event.is_action_pressed("weapon_1"): WeaponChanged.emit(1)
	if event.is_action_pressed("weapon_2"): WeaponChanged.emit(2)
	if event.is_action_pressed("weapon_3"): WeaponChanged.emit(3)

func IsJumpHeld() -> bool: return Input.is_action_pressed("jump")
func IsBlockHeld() -> bool: return blockStrength >= BLOCK_THRESHOLD

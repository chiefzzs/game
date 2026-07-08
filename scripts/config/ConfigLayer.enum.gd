extends RefCounted
class_name ConfigLayer
## 配置层枚举（纯常量类，ConfigManager内部用或外部查类型用）
const L1_CONSTANTS := 0
const L2_BALANCE := 1
const L3_LEVELS := 2
const L4_USER_SETTINGS := 3

static func NameOf(layer: int) -> String:
	match layer:
		L1_CONSTANTS: return "L1_CONSTANTS"
		L2_BALANCE: return "L2_BALANCE"
		L3_LEVELS: return "L3_LEVELS"
		L4_USER_SETTINGS: return "L4_USER"
		_: return "UNKNOWN"

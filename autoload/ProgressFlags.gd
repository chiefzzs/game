extends Node
## V0.3 ProgressFlags.gd - 进度标志存储器（自动序列化进存档）
## 两套 API：布尔型 Set/Get/Has + KeyValue型 SetKV/GetKV

class_name ProgressFlagsCore

var _bools: Dictionary = {}
var _kvs: Dictionary = {}

func Set(key: String, value: bool) -> void:
	_bools[key] = value

func Get(key: String) -> bool:
	if not _bools.has(key):
		return false
	return _bools[key]

func Has(key: String) -> bool:
	return _bools.has(key)

func SetKV(key: String, value: Variant) -> void:
	_kvs[key] = value

func GetKV(key: String, default: Variant = null) -> Variant:
	if not _kvs.has(key):
		return default
	return _kvs[key]

func HasKV(key: String) -> bool:
	return _kvs.has(key)

func serialize() -> Dictionary:
	return {"bools": _bools.duplicate(true), "kvs": _kvs.duplicate(true)}

func deserialize(data: Dictionary) -> void:
	if data == null:
		_bools.clear()
		_kvs.clear()
		return
	if data.has("bools") and typeof(data["bools"]) == TYPE_DICTIONARY:
		_bools = data["bools"].duplicate(true)
	else:
		_bools.clear()
	if data.has("kvs") and typeof(data["kvs"]) == TYPE_DICTIONARY:
		_kvs = data["kvs"].duplicate(true)
	else:
		_kvs.clear()

func clear_all() -> void:
	_bools.clear()
	_kvs.clear()

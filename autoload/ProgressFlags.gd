extends Node
## 全局进度标记（Autoload单例，Node名：Flags）
## Set("cp_01") Has("cp_01") SetKV("gold", 123) GetKV("gold", 0)

var _flags: Dictionary = {}
var _kv: Dictionary = {}

signal FlagSet(key: String, value: bool)
signal FlagCleared(key: String)
signal KVSet(key: String, value)
signal FlagsReset()

# ---------- Bool Flags ----------
func Set(key: String, value: bool = true) -> void:
	if key == null or key.is_empty():
		return
	var old: bool = _flags.get(key, false)
	_flags[key] = value
	if old != value:
		FlagSet.emit(key, value)

func Unset(key: String) -> void:
	if _flags.has(key):
		_flags.erase(key)
		FlagCleared.emit(key)

func Has(key: String) -> bool:
	return _flags.get(key, false)

# ---------- Generic KV ----------
func SetKV(key: String, value) -> void:
	if key == null or key.is_empty():
		return
	_kv[key] = value
	KVSet.emit(key, value)

func GetKV(key: String, def_val = null):
	return _kv.get(key, def_val)

func HasKV(key: String) -> bool:
	return _kv.has(key)

func ResetAll() -> void:
	_flags.clear()
	_kv.clear()
	FlagsReset.emit()

# ---------- Serialize ----------
func ToDictionary() -> Dictionary:
	return {
		"schema_ver": 1,
		"flags": _flags.duplicate(true),
		"kv": _kv.duplicate(true),
		"saved_at_unix": Time.get_unix_time_from_system()
	}

func FromDictionary(data: Dictionary) -> bool:
	if not data.has("schema_ver") or int(data.get("schema_ver", 0)) != 1:
		push_warning("[Flags] schema mismatch, skip load.")
		return false
	ResetAll()
	if data.has("flags") and typeof(data["flags"]) == TYPE_DICTIONARY:
		_flags = (data["flags"] as Dictionary).duplicate(true)
	if data.has("kv") and typeof(data["kv"]) == TYPE_DICTIONARY:
		_kv = (data["kv"] as Dictionary).duplicate(true)
	return true

func Dump() -> void:
	print("=== Progress Flags ===")
	print("Flags(n=", _flags.size(), "): ", JSON.stringify(_flags))
	print("KV(n=", _kv.size(), "): ", JSON.stringify(_kv))

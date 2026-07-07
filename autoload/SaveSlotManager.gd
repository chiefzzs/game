extends Node
## 存档槽管理器（Autoload单例，Node名：Saves）
## 3个存档槽：Saves.NewGame(0) Saves.Save(0) Saves.Load(0) Saves.Delete(0) Saves.ListSlots()

const SLOT_COUNT := 3
const SCHEMA_VERSION := 1

signal SlotSaved(slot_idx: int)
signal SlotLoaded(slot_idx: int)
signal SlotDeleted(slot_idx: int)

func _ready() -> void:
	if not DirAccess.dir_exists_absolute("user://saves"):
		DirAccess.make_dir_absolute("user://saves")

static func _SlotPath(slot_idx: int) -> String:
	return "user://saves/slot_%02d.sav" % [slot_idx + 1]

static func _MakeEmpty(slot_idx: int) -> Dictionary:
	return {
		"schema_ver": SCHEMA_VERSION,
		"slot_idx": slot_idx,
		"created_at_unix": Time.get_unix_time_from_system(),
		"last_played_at_unix": Time.get_unix_time_from_system(),
		"play_seconds_total": 0,
		"chapter_id_current": "prologue",
		"map_id_current": "farm_01",
		"progress_flags": {},
		"player_snapshot": {},
		"companions_snapshot": [],
		"meta": {
			"title": "序章 农场",
			"player_hp": 100,
			"player_hp_max": 100,
			"gold": 0,
			"level_name": "farm_01",
			"preview_b64": ""
		}
	}

func ListSlots() -> Array:
	var result: Array = []
	for i in SLOT_COUNT:
		var path := _SlotPath(i)
		if FileAccess.file_exists(path):
			var data := _ReadFile(path)
			result.append({
				"slot_idx": i,
				"exists": true,
				"last_played_at_unix": data.get("last_played_at_unix", 0),
				"play_seconds_total": data.get("play_seconds_total", 0),
				"meta": data.get("meta", {})
			})
		else:
			result.append({"slot_idx": i, "exists": false})
	return result

func NewGame(slot_idx: int) -> void:
	Flags.ResetAll()
	var dto := _MakeEmpty(slot_idx)
	dto.progress_flags = Flags.ToDictionary()
	_WriteFile(_SlotPath(slot_idx), dto)
	SlotSaved.emit(slot_idx)

func Save(slot_idx: int) -> void:
	var path := _SlotPath(slot_idx)
	var data: Dictionary
	if FileAccess.file_exists(path):
		data = _ReadFile(path)
	else:
		data = _MakeEmpty(slot_idx)
	data["schema_ver"] = SCHEMA_VERSION
	data["slot_idx"] = slot_idx
	data["last_played_at_unix"] = Time.get_unix_time_from_system()
	data["progress_flags"] = Flags.ToDictionary()
	if not data.has("meta") or typeof(data["meta"]) != TYPE_DICTIONARY:
		data["meta"] = {}
	_WriteFile(path, data)
	SlotSaved.emit(slot_idx)

func Load(slot_idx: int) -> bool:
	var path := _SlotPath(slot_idx)
	if not FileAccess.file_exists(path):
		push_warning("[Saves] slot %d 空" % slot_idx)
		return false
	var data := _ReadFile(path)
	if data.has("progress_flags"):
		Flags.FromDictionary(data.progress_flags)
	SlotLoaded.emit(slot_idx)
	return true

func Delete(slot_idx: int) -> void:
	var path := _SlotPath(slot_idx)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		SlotDeleted.emit(slot_idx)

# ---------- I/O ----------
static func _ReadFile(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

static func _WriteFile(path: String, data: Dictionary) -> void:
	var d := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(d):
		DirAccess.make_dir_absolute(d)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[Saves] 写失败: " + path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

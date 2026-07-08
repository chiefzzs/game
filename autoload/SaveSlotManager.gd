extends Node

func _autoload(name: String) -> Node:
	var st: SceneTree = get_tree()
	if st == null or st.root == null:
		var ml = Engine.get_main_loop()
		if ml is SceneTree:
			st = ml
		else:
			return null
	return st.root.get_node_or_null(NodePath("/root/" + name))
## V0.3 SaveSlotManager.gd - 3槽存档管理
## 存档格式V2: 兼容V0.3战斗状态 (HP/Stamina/Weapon/Gold/Team/Checkpoint)

const MAX_SLOT := 3
const SAVE_DIR := "user://"
const SAVE_FILE_FMT := "slot_%d.sav"
const SETTINGS_FILE := "settings.json"
const SAVE_VERSION := 2

signal slots_refreshed(slots: Array)
signal save_succeeded(slot: int, path: String, ts: String)
signal save_failed(slot: int, reason: String)
signal load_succeeded(slot: int)
signal load_failed(slot: int, reason: String)

func slot_path(slot: int) -> String:
	return SAVE_DIR + SAVE_FILE_FMT % slot

func NewGame(slot: int) -> Error:
	var PF: Node = _autoload("ProgressFlags")
	var flags_data: Dictionary = {}
	if PF:
		flags_data = PF.call("serialize")
	var empty: Dictionary = {
		"version": SAVE_VERSION,
		"slot": slot,
		"created_at_unix": Time.get_unix_time_from_system(),
		"updated_at_unix": Time.get_unix_time_from_system(),
		"player": {
			"hp": 100, "max_hp": 100,
			"stamina": 100, "max_stamina": 100,
			"weapon": "axe",
			"gold": 0,
			"position": Vector2(400, 200),
			"facing": 1.0,
		},
		"team": {
			"active_companions": [], # ["axeman","hunter","shepherd"]
			"companion_hp": {}
		},
		"progress": {
			"chapter_id": 0,
			"chapter_key": "prologue_farm",
			"checkpoint_key": "prologue_farm_start",
		},
		"flags": flags_data,
		"playtime_sec": 0,
	}
	return _write_slot(slot, empty)

func Save(slot: int, extra: Dictionary = {}) -> Error:
	if slot < 1 or slot > MAX_SLOT:
		emit_signal("save_failed", slot, "slot out of range")
		return ERR_INVALID_PARAMETER
	var data: Dictionary = {}
	if FileAccess.file_exists(slot_path(slot)):
		data = _read_slot(slot)
	data.version = SAVE_VERSION
	data.updated_at_unix = Time.get_unix_time_from_system()
	if extra != null and typeof(extra) == TYPE_DICTIONARY:
		for k in extra.keys():
			data[k] = extra[k]
	if data.has("flags") == false:
		data.flags = ProgressFlags.serialize()
	var err := _write_slot(slot, data)
	if err == OK:
		emit_signal("save_succeeded", slot, slot_path(slot), Time.get_datetime_string_from_system())
		emit_signal("slots_refreshed", ListSlots())
		if GameEvents:
			GameEvents.emit_signal("save_completed", slot, slot_path(slot))
	else:
		emit_signal("save_failed", slot, "file write err=%d" % err)
	return err

func Load(slot: int) -> Dictionary:
	if slot < 1 or slot > MAX_SLOT:
		emit_signal("load_failed", slot, "slot out of range")
		return {}
	if not FileAccess.file_exists(slot_path(slot)):
		emit_signal("load_failed", slot, "file not exists")
		return {}
	var data := _read_slot(slot)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		emit_signal("load_failed", slot, "corrupt save")
		return {}
	if data.has("flags"):
		var PF3: Node = _autoload("ProgressFlags")
		if PF3:
			PF3.call("deserialize", data.flags)
	emit_signal("load_succeeded", slot)
	var GE2: Node = _autoload("GameEvents")
	if GE2:
		GE2.emit_signal("load_completed", slot)
	return data

func ListSlots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(1, MAX_SLOT + 1):
		var entry: Dictionary = {"slot": i, "exists": false, "version": 0,
			"updated_at_unix": 0, "chapter_id": -1, "player_hp": 0, "gold": 0}
		if FileAccess.file_exists(slot_path(i)):
			var d: Dictionary = _read_slot(i)
			if d != null:
				entry.exists = true
				entry.version = int(d.get("version", 0))
				entry.updated_at_unix = int(d.get("updated_at_unix", 0))
				var p: Dictionary = d.get("player", {})
				if typeof(p) == TYPE_DICTIONARY:
					entry.player_hp = int(p.get("hp", 0))
					entry.gold = int(p.get("gold", 0))
				var pr: Dictionary = d.get("progress", {})
				if typeof(pr) == TYPE_DICTIONARY:
					entry.chapter_id = int(pr.get("chapter_id", -1))
		out.append(entry)
	return out

func DeleteSlot(slot: int) -> Error:
	if not FileAccess.file_exists(slot_path(slot)):
		return OK
	return DirAccess.remove_absolute(slot_path(slot))

func SaveSettings() -> Error:
	if ConfigManager:
		return ConfigManager.save_settings()
	return OK

func LoadSettings() -> Dictionary:
	var p := "user://" + SETTINGS_FILE
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var s := f.get_as_text()
	f.close()
	var r = JSON.parse_string(s)
	if typeof(r) == TYPE_DICTIONARY:
		return r
	return {}

func _read_slot(slot: int) -> Dictionary:
	var p: String = slot_path(slot)
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var s: String = f.get_as_text()
	f.close()
	var r = JSON.parse_string(s)
	if typeof(r) == TYPE_DICTIONARY:
		return r
	return {}

func _write_slot(slot: int, data: Dictionary) -> Error:
	var p: String = slot_path(slot)
	DirAccess.make_dir_absolute(SAVE_DIR)
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return ERR_FILE_CANT_OPEN
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return OK

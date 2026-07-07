extends RefCounted
class_name SaveGameDTO
## 存档结构定义（V0.3+玩家/同伴快照扩展时改这里）
const SCHEMA_VERSION := 1
const SLOT_COUNT := 3

static func PathOf(slot_idx: int) -> String:
	return "user://saves/slot_%02d.sav" % [slot_idx + 1]

static func MakeEmpty(slot_idx: int) -> Dictionary:
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

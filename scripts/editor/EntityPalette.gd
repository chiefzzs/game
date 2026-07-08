extends Control
class_name EntityPalette
## V0.2 T02-04：实体放置面板 — 6大类 20个官方模板实体
## 用法：EditorMain 中选中一个模板 → 鼠标点击 TileMap 画布 → 在该世界坐标放置一个实体。
## 每个实体模板的元数据结构：{id, kind, name, default_props, icon_color}
## 发出 place_requested(kind, default_props, world_pos) 由 EditorMain 执行放置。

signal place_requested(entity_id: String, kind: String, name: String, default_props: Dictionary, world_pos: Vector2)
signal selection_changed(entity_id: String, kind: String, name: String)

const CATALOG := {
	"🤝 NPC 同伴/NPC": [
		{"id": "npc_farmer",  "kind": "npc", "name": "Farmer John 农夫",
			"props": {"dialog": "join_me_farm", "recruit_cost": 50, "hp": 60, "atk": 8, "patrol_r": 0}},
		{"id": "npc_archer",  "kind": "npc", "name": "Archer Lisa 弓箭手",
			"props": {"dialog": "join_me_forest", "recruit_cost": 120, "hp": 45, "atk": 14, "patrol_r": 0}},
		{"id": "npc_warrior", "kind": "npc", "name": "Warrior Tom 武士",
			"props": {"dialog": "join_me_village", "recruit_cost": 200, "hp": 140, "atk": 18, "patrol_r": 0}},
	],
	"👹 Enemy 敌人": [
		{"id": "enemy_scarecrow", "kind": "enemy", "name": "Scarecrow 稻草人",
			"props": {"hp": 30, "atk": 10, "patrol_r": 40, "chase_r": 180, "attack_r": 34, "cd": 1.2}},
		{"id": "enemy_soldier",  "kind": "enemy", "name": "Soldier 士兵",
			"props": {"hp": 80, "atk": 14, "patrol_r": 60, "chase_r": 220, "attack_r": 38, "cd": 1.0}},
		{"id": "enemy_archer",   "kind": "enemy", "name": "Archer 弓手",
			"props": {"hp": 45, "atk": 18, "patrol_r": 40, "chase_r": 320, "attack_r": 300, "cd": 1.8}},
		{"id": "enemy_knight",   "kind": "enemy", "name": "Knight 骑士",
			"props": {"hp": 180, "atk": 24, "patrol_r": 80, "chase_r": 260, "attack_r": 42, "cd": 1.4}},
	],
	"📦 Chest 宝箱": [
		{"id": "chest_gold",    "kind": "chest", "name": "Gold Chest 金币箱",
			"props": {"loot": {"gold": 30}, "is_locked": false}},
		{"id": "chest_potion",  "kind": "chest", "name": "Potion Chest 药水箱",
			"props": {"loot": {"potion": 3}, "is_locked": false}},
		{"id": "chest_mix",     "kind": "chest", "name": "Mixed Chest 混合箱",
			"props": {"loot": {"gold": 15, "potion": 1, "unlock": []}, "is_locked": true}},
	],
	"🚩 Checkpoint 检查点": [
		{"id": "cp_default",    "kind": "checkpoint", "name": "Checkpoint 保存点",
			"props": {"cp_id": "cp_1", "restore_hp": true, "restore_companions": false}},
	],
	"🚪 Portal 传送门": [
		{"id": "portal_next",   "kind": "portal", "name": "Portal→Next 下一关",
			"props": {"target_level": "village_edge_01", "need_objectives_done": true}},
		{"id": "portal_back",   "kind": "portal", "name": "Portal↩Back 返回",
			"props": {"target_level": "farm_01", "need_objectives_done": false}},
	],
	"⚡ Trigger 触发器": [
		{"id": "trig_reach",   "kind": "trigger", "name": "ReachArea 到达区域",
			"props": {"obj_id": "reach_1", "size_w": 80, "size_h": 80, "action": "objective_done"}},
		{"id": "trig_dialog",  "kind": "trigger", "name": "Dialog 对话触发",
			"props": {"dialog_id": "intro_farm", "one_shot": true, "action": "play_dialog"}},
		{"id": "trig_spawn",   "kind": "trigger", "name": "SpawnEnemy 刷怪",
			"props": {"wave": [["enemy_soldier", 2], ["enemy_archer", 1]], "action": "spawn_wave"}},
		{"id": "trig_camera",  "kind": "trigger", "name": "CameraZone 相机区",
			"props": {"action": "camera_bounds", "min_x": 0, "max_x": 1600, "lock_y": true}},
	],
}

var _selected_id: String = ""
var _selected_kind: String = ""

func _ready() -> void:
	pass

func all_entity_ids() -> Array:
	var out := []
	for category in CATALOG.values():
		for tpl in category:
			out.append(tpl["id"])
	return out

func find_template(id: String) -> Dictionary:
	for category in CATALOG.values():
		for tpl in category:
			if tpl["id"] == id:
				return tpl.duplicate(true)
	return {}

func select_by_id(id: String) -> void:
	var t := find_template(id)
	if t.is_empty():
		return
	_selected_id = id
	_selected_kind = str(t.get("kind", ""))
	selection_changed.emit(_selected_id, _selected_kind, str(t.get("name", "")))

func request_place(world_pos: Vector2) -> Dictionary:
	if _selected_id == "":
		return {}
	var t := find_template(_selected_id)
	if t.is_empty():
		return {}
	place_requested.emit(
		_selected_id,
		str(t.get("kind", "")),
		str(t.get("name", "")),
		t.get("props", {}),
		world_pos
	)
	return t

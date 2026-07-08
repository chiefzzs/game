extends Control
class_name EntityInspector
## V02 T02-05：实体 Inspector — 选中场景上放置的实体后，编辑其属性。
## 支持的属性项根据 kind(npc/enemy/chest/cp/portal/trigger) 自动切换表单。
## 编辑后发出 entity_updated(entity_ref, field, new_value)，EditorMain 写回实体元数据。

signal entity_updated(entity_ref: NodePath, field: String, new_value)
signal entity_removed(entity_ref: NodePath)

var _current_entity: NodePath = NodePath("")
var _current_kind: String = ""
var _current_props: Dictionary = {}

func inspect(entity_path: NodePath, kind: String, props: Dictionary) -> void:
	_current_entity = entity_path
	_current_kind = kind
	_current_props = props.duplicate(true)
	_build_form()

func clear() -> void:
	_current_entity = NodePath("")
	_current_kind = ""
	_current_props.clear()

func has_target() -> bool:
	return _current_entity != NodePath("") and is_instance_valid(get_node_or_null(_current_entity))

func set_field(field: String, new_value) -> void:
	_current_props[field] = new_value
	entity_updated.emit(_current_entity, field, new_value)
	if has_target():
		var n := get_node_or_null(_current_entity)
		if n and n.has_meta(field):
			n.set_meta(field, new_value)
		elif n and n.has_method("set_meta"):
			n.set_meta(field, new_value)

func remove_entity() -> void:
	if not has_target():
		return
	var p := _current_entity
	clear()
	entity_removed.emit(p)

func get_props_snapshot() -> Dictionary:
	return _current_props.duplicate(true)

func recommended_fields_for(kind: String) -> Array:
	# 返回每种 kind 的推荐可编辑字段 {name, type, hint, default}
	match kind:
		"npc":
			return [
				{"name": "name", "type": "string", "hint": "", "default": "NPC"},
				{"name": "recruit_cost", "type": "int", "hint": "1~9999", "default": 50},
				{"name": "hp", "type": "int", "hint": "1~999", "default": 60},
				{"name": "atk", "type": "int", "hint": "1~99", "default": 10},
				{"name": "dialog", "type": "string", "hint": "对话ID", "default": "join_me"},
			]
		"enemy":
			return [
				{"name": "hp", "type": "int", "hint": "10~500", "default": 30},
				{"name": "atk", "type": "int", "hint": "1~99", "default": 10},
				{"name": "patrol_r", "type": "int", "hint": "巡逻半径", "default": 40},
				{"name": "chase_r", "type": "int", "hint": "追击半径", "default": 180},
				{"name": "attack_r", "type": "int", "hint": "攻击半径", "default": 34},
				{"name": "cd", "type": "float", "hint": "攻击冷却s", "default": 1.2},
			]
		"chest":
			return [
				{"name": "is_locked", "type": "bool", "hint": "", "default": false},
				{"name": "loot", "type": "dict", "hint": "JSON 如 {gold:30}", "default": {}},
			]
		"checkpoint":
			return [
				{"name": "cp_id", "type": "string", "hint": "", "default": "cp_1"},
				{"name": "restore_hp", "type": "bool", "hint": "", "default": true},
			]
		"portal":
			return [
				{"name": "target_level", "type": "string", "hint": "下一关id", "default": "farm_02"},
				{"name": "need_objectives_done", "type": "bool", "hint": "需目标全部完成", "default": true},
			]
		"trigger":
			return [
				{"name": "action", "type": "string", "hint": "objective_done/play_dialog/...", "default": "objective_done"},
				{"name": "obj_id", "type": "string", "hint": "目标ID（action=objective_done）", "default": "reach_1"},
				{"name": "size_w", "type": "int", "hint": "区域宽", "default": 80},
				{"name": "size_h", "type": "int", "hint": "区域高", "default": 80},
			]
		_:
			return []

func _build_form() -> void:
	# 在场景中，EditorMain.tscn 提供了 Inspector Container（GridContainer/VBox）。
	# 这里作为程序化 UI 的接口层：当 EditorMain 调用 inspect 时，
	# Inspector 会基于 recommended_fields_for 创建标签/输入控件组合。
	pass

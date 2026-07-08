extends Node
class_name MapSchemaValidator
## V0.2 T02-14：Map JSON Schema 校验器 — 保存前/加载后均校验必填字段，错误以 {path, message} 返回。
## 无第三方 Schema 库，手写规则引擎。

const REQUIRED_TOP_FIELDS := [
	"version", "map_id", "display_name", "tilesets",
	"layers", "entities", "objectives",
]
const FIELD_TYPES := {
	"version": "string",
	"map_id": "string",
	"display_name": "string",
	"tilesets": "array",
	"layers": "array",
	"entities": "array",
	"objectives": "array",
	"meta": "dict",
}
const LAYER_FIELDS := ["index", "name", "cells"]
const ENTITY_FIELDS := ["id", "kind", "x", "y", "props"]
const OBJ_REQUIRED := ["id", "type"]

func validate(json_dict: Dictionary) -> Array:
	var errors: Array = []
	# 1. top-level required
	for f in REQUIRED_TOP_FIELDS:
		if not json_dict.has(f):
			errors.append({"path": "$." + f, "message": "缺少必填字段 '%s'" % f})
	# 2. top-level types
	for f in FIELD_TYPES.keys():
		if json_dict.has(f):
			if not _check_type(json_dict[f], str(FIELD_TYPES[f])):
				errors.append({"path": "$." + f, "message": "字段 '%s' 类型错误，需要 %s" % [f, FIELD_TYPES[f]]})
	# 3. layers
	if json_dict.has("layers") and json_dict["layers"] is Array:
		var li := 0
		for layer in json_dict["layers"]:
			if not (layer is Dictionary):
				errors.append({"path": "$.layers[%d]" % li, "message": "layer 必须是对象"})
				li += 1
				continue
			for f in LAYER_FIELDS:
				if not layer.has(f):
					errors.append({"path": "$.layers[%d].%s" % [li, f], "message": "layer 缺少 '%s'" % f})
			if layer.has("cells") and not (layer["cells"] is Array):
				errors.append({"path": "$.layers[%d].cells" % li, "message": "cells 必须是数组"})
			li += 1
	# 4. entities
	if json_dict.has("entities") and json_dict["entities"] is Array:
		var ei := 0
		for ent in json_dict["entities"]:
			if not (ent is Dictionary):
				errors.append({"path": "$.entities[%d]" % ei, "message": "entity 必须是对象"})
				ei += 1
				continue
			for f in ENTITY_FIELDS:
				if not ent.has(f):
					errors.append({"path": "$.entities[%d].%s" % [ei, f], "message": "entity 缺少 '%s'" % f})
			if ent.has("props") and not (ent["props"] is Dictionary):
				errors.append({"path": "$.entities[%d].props" % ei, "message": "props 必须是对象"})
			ei += 1
	# 5. objectives
	if json_dict.has("objectives") and json_dict["objectives"] is Array:
		var oi := 0
		for obj in json_dict["objectives"]:
			if not (obj is Dictionary):
				errors.append({"path": "$.objectives[%d]" % oi, "message": "objective 必须是对象"})
				oi += 1
				continue
			if obj.has("logic"):
				oi += 1
				continue
			for f in OBJ_REQUIRED:
				if not obj.has(f):
					errors.append({"path": "$.objectives[%d].%s" % [oi, f], "message": "objective 缺少 '%s'" % f})
			oi += 1
	return errors

func is_valid(json_dict: Dictionary) -> bool:
	return validate(json_dict).is_empty()

func errors_to_string(errors: Array) -> String:
	if errors.is_empty():
		return "OK"
	var s := "%d 个校验错误:\n" % errors.size()
	for e in errors:
		s += "  · [%s] %s\n" % [str(e.get("path", "?")), str(e.get("message", ""))]
	return s

func _check_type(val, type_name: String) -> bool:
	match type_name:
		"string":
			return val is String
		"array":
			return val is Array
		"dict":
			return val is Dictionary
		"int":
			return val is int
		"float":
			return val is float or val is int
		"bool":
			return val is bool
		_:
			return true

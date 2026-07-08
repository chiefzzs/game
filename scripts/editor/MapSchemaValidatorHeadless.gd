extends SceneTree
## V0.3 MapSchemaValidatorHeadless.gd — Phase2验收: Godot --headless -s 入口
## 验证3个内建模板 map.json 符合 schema；全部通过 exit code = 0 否则非0
## 运行方式 (见03-自动化验收V0.3.cmd Line 84):
##   %GODOT% --no-window --headless --path %PROJ% -s res://scripts/editor/MapSchemaValidatorHeadless.gd

const TEMPLATES := [
	"res://scenes/workshop/templates/farm.map.json",
	"res://scenes/workshop/templates/empty.map.json",
	"res://scenes/workshop/templates/arena.map.json",
]

const REQUIRED_TOP_LEVEL := ["version", "meta", "layers", "entities"]
const REQUIRED_META := ["spawn", "template_name"]

func _init() -> void:
	pass

func _process(_delta: float) -> bool:
	var fail_count: int = 0
	for path in TEMPLATES:
		var res := _validate_one(path)
		if not res.get("ok", false):
			fail_count += 1
			print("[MapSchemaValidator][FAIL] %s  reason=%s" % [path, res.get("reason","unknown")])
		else:
			print("[MapSchemaValidator][ OK ] %s  (version=%s, entities=%d)" % [
				path, res.get("version","?"), res.get("entities_count", 0)])
	print("-----------------------------------------------------")
	if fail_count == 0:
		print("[MapSchemaValidator][SUMMARY] ALL %d TEMPLATES PASSED -> exit 0" % TEMPLATES.size())
		quit(0)
	else:
		print("[MapSchemaValidator][SUMMARY] %d/%d FAILED -> exit %d" % [fail_count, TEMPLATES.size(), fail_count])
		quit(fail_count)
	return true

func run_headless(map_name: String) -> Dictionary:
	var out: Dictionary = {
		"schema_valid": false, "schema_errors": [],
		"object_count": 0, "player_spawn_count": 0
	}
	var path_map: Dictionary = {
		"level_1_intro": "res://scenes/workshop/templates/farm.map.json",
		"level_2_forest_edge": "res://scenes/workshop/templates/empty.map.json",
		"arena": "res://scenes/workshop/templates/arena.map.json"
	}
	var path: String = path_map.get(map_name, TEMPLATES[0])
	var res := _validate_one(path)
	if res.ok:
		out.schema_valid = true
		out.object_count = int(res.entities_count)
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				var ents: Array = parsed.get("entities", [])
				for e in ents:
					if typeof(e) == TYPE_DICTIONARY:
						var ek: String = str(e.get("kind", ""))
						if ek == "player" or ek.find("player") >= 0:
							out.player_spawn_count += 1
	else:
		out.schema_errors.append(res.reason)
		print("[MapSchemaValidator][run_headless] map=%s -> valid=%s err=%s" % [
			map_name, str(out.schema_valid), str(out.schema_errors)])
	return out

func _validate_one(path: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "reason": "", "entities_count": 0, "version": "?"}
	if not FileAccess.file_exists(path):
		out.reason = "file_not_found"
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		out.reason = "open_error"
		return out
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		out.reason = "json_not_object"
		return out
	var d: Dictionary = parsed
	for req in REQUIRED_TOP_LEVEL:
		if not d.has(req):
			out.reason = "missing_top_level_key:%s" % req
			return out
	var meta: Variant = d.get("meta", null)
	if typeof(meta) != TYPE_DICTIONARY:
		out.reason = "meta_not_dict"
		return out
	var md: Dictionary = meta
	for req in REQUIRED_META:
		if not md.has(req):
			out.reason = "meta missing: %s" % req
			return out
	if typeof(d.get("entities", [])) != TYPE_ARRAY:
		out.reason = "entities not array"
		return out
	var ents: Array = d.get("entities", [])
	out.entities_count = ents.size()
	out.version = str(d.get("version", "?"))
	out.ok = true
	return out

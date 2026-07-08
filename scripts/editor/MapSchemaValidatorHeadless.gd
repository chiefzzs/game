@tool
extends SceneTree
## Phase2 Headless：加载 3 张官方模板 .map.json + 调用 MapSchemaValidator 校验，0错误=Exit0
func _init() -> void:
	var validator_script: Script = load("res://scripts/editor/MapSchemaValidator.gd")
	var serializer_script: Script = load("res://scripts/editor/MapSerializer.gd")
	var validator: RefCounted = validator_script.new()
	var serializer: RefCounted = serializer_script.new()
	var files: Array[String] = [
		ProjectSettings.globalize_path("res://scenes/workshop/templates/empty.map.json"),
		ProjectSettings.globalize_path("res://scenes/workshop/templates/farm.map.json"),
		ProjectSettings.globalize_path("res://scenes/workshop/templates/arena.map.json"),
	]
	var errors_total: int = 0
	for f in files:
		if not FileAccess.file_exists(f):
			print("[Phase2][SKIP] 缺失：", f)
			continue
		var dict: Dictionary = serializer.load_from_file(f, true)
		var errs: Array = validator.validate(dict)
		if errs.is_empty():
			print("[Phase2][OK] ", f.get_file())
		else:
			print("[Phase2][FAIL] ", f.get_file(), "  错误:", errs.size())
			for e in errs:
				var ep: String = e.get("path") if e.has("path") else "?"
				var em: String = e.get("message") if e.has("message") else ""
				print("    · ", ep, "  ", em)
			errors_total += errs.size()
	print("——————————————————")
	print("Schema 校验总错误数 = ", errors_total)
	quit(errors_total)

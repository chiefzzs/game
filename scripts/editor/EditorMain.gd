extends Control
## V0.2 T02-01~T02-12：编辑器主体场景的主控制器（三栏布局 Canvas + Tab + Toolbar）
##
## 场景结构（在 EditorMain.tscn 中由 Godot 编辑器挂载，或由本脚本按需 build 占位节点）：
##   EditorMain (Control/脚本)
##   ├─ Toolbar (HBoxContainer)    # 顶部 4按钮 + 标签
##   │   ├─ BtnNew / BtnEdit / BtnOfficial / BtnTest
##   ├─ MainSplit (HSplitContainer)
##   │   ├─ LeftTab (TabContainer)
##   │   │   ├─ TilePalette (Control+脚本 TilePalette)
##   │   │   └─ EntityPalette (Control+脚本 EntityPalette)
##   │   ├─ CanvasHolder (CenterContainer/SubViewportContainer + SubViewport)
##   │   │   └─ CanvasRoot (Node2D)
##   │   │       ├─ TileMap (8层)
##   │   │       ├─ EntitiesRoot (Node2D)
##   │   │       └─ PlayerSpawn (Marker2D)
##   │   └─ RightTab (TabContainer)
##   │       ├─ Inspector (Control+脚本 EntityInspector)
##   │       └─ ObjectivesEditor (Control+脚本 ObjectivesEditor)
##   └─ StatusBar (HBoxContainer / Label)   # 底部状态栏
##
## 本脚本负责：
##   1. 4 工具栏按钮 —— 新建空图 / 打开已有 .map.json / 官方模板 / 一键测试
##   2. 绘制模式切换 —— LeftTab Tile / Entity 模式自动切换
##   3. 画布鼠标事件 —— 绘制 Tile（DrawTools） / 放置实体（EntityPalette） / 选中实体（Inspector）
##   4. 保存/加载 —— MapSerializer 写 .map.json
##   5. 一键测试 —— 保存 → OS.create_process 启动 Godot 游戏进程，传参 --map="..."
##   6. ObjectivesEditor / EntityInspector / TilePalette 信号连线

signal status(message: String, level: int)   # 0=info 1=warn 2=error

@onready var _toolbar: HBoxContainer = $Toolbar
@onready var _btn_new: Button = $Toolbar/BtnNew
@onready var _btn_edit: Button = $Toolbar/BtnEdit
@onready var _btn_official: Button = $Toolbar/BtnOfficial
@onready var _btn_test: Button = $Toolbar/BtnTest
@onready var _btn_save: Button = $Toolbar/BtnSave
@onready var _btn_save_as: Button = $Toolbar/BtnSaveAs
@onready var _left_tab: TabContainer = $MainSplit/LeftTab
@onready var _tile_palette: TilePalette = $MainSplit/LeftTab/TilePalette
@onready var _entity_palette: EntityPalette = $MainSplit/LeftTab/EntityPalette
@onready var _canvas_holder: SubViewportContainer = $MainSplit/CanvasHolder
@onready var _canvas_viewport: SubViewport = $MainSplit/CanvasHolder/Viewport
@onready var _canvas_root: Node2D = $MainSplit/CanvasHolder/Viewport/CanvasRoot
@onready var _tilemap: TileMap = $MainSplit/CanvasHolder/Viewport/CanvasRoot/TileMap
@onready var _entities_root: Node2D = $MainSplit/CanvasHolder/Viewport/CanvasRoot/EntitiesRoot
@onready var _right_tab: TabContainer = $MainSplit/RightTab
@onready var _inspector: EntityInspector = $MainSplit/RightTab/Inspector
@onready var _objectives: ObjectivesEditor = $MainSplit/RightTab/ObjectivesEditor
@onready var _status: Label = $StatusBar/Label
@onready var _status_mode: Label = $StatusBar/ModeLabel
@onready var _status_layer: Label = $StatusBar/LayerLabel
@onready var _status_file: Label = $StatusBar/FileLabel

const MODE_TILE := 0
const MODE_ENTITY := 1
const MODE_SELECT := 2

var _mode: int = MODE_TILE
var _draw: DrawTools = DrawTools.new()
var _serializer: MapSerializer = MapSerializer.new()
var _current_file: String = ""
var _map_id: String = "untitled"
var _display_name: String = "未命名地图"
var _selected_entity: NodePath = NodePath("")
var _rect_start: Vector2i = Vector2i.ZERO
var _is_filling_rect: bool = false

func _ready() -> void:
	randomize()
	# --- 绑定 TileMap 到 DrawTools ---
	for i in range(_tilemap.get_layers_count(), 8):
		_tilemap.add_layer(i)
	_draw.bind_tilemap(_tilemap)
	# --- 工具栏按钮 ---
	if _btn_new:  _btn_new.pressed.connect(_on_new_map)
	if _btn_edit: _btn_edit.pressed.connect(_on_edit_existing)
	if _btn_official: _btn_official.pressed.connect(_on_official_templates)
	if _btn_test: _btn_test.pressed.connect(_on_test_map)
	if _btn_save: _btn_save.pressed.connect(_on_save)
	if _btn_save_as: _btn_save_as.pressed.connect(_on_save_as)
	# --- Tab 切换 ---
	if _left_tab:
		_left_tab.tab_changed.connect(_on_left_tab_changed)
	# --- TilePalette ---
	if _tile_palette:
		_tile_palette.tile_selected.connect(_on_tile_selected)
		_tile_palette.layer_changed.connect(_on_layer_changed)
	# --- EntityPalette ---
	if _entity_palette:
		_entity_palette.selection_changed.connect(_on_entity_template_selected)
	# --- EntityInspector ---
	if _inspector:
		_inspector.entity_updated.connect(_on_entity_updated)
		_inspector.entity_removed.connect(_on_entity_removed)
	# --- ObjectivesEditor ---
	if _objectives:
		_objectives.objectives_changed.connect(func(x): set_status("目标已更新 (共%d项)" % x.size(), 0))
	# --- 画布鼠标事件 ---
	if _canvas_holder:
		_canvas_holder.gui_input.connect(_on_canvas_gui_input)
	# --- DrawTools 撤销栈信号 ---
	_draw.undo_performed.connect(func(n): set_status("撤销完成，剩余 %d 步可撤销" % n, 0))
	_draw.redo_performed.connect(func(n): set_status("重做完成，剩余 %d 步可重做" % n, 0))
	# --- 快捷键 ---
	process_mode = PROCESS_MODE_ALWAYS
	# --- 默认 ---
	_on_left_tab_changed(0)
	_on_tile_selected(_tile_palette.get_tile(), "Farm") if _tile_palette else pass
	_on_layer_changed(_tile_palette.get_layer()) if _tile_palette else pass
	set_status("编辑器就绪：请选择『新建』或打开一张 .map.json 地图", 0)
	_refresh_status()

# ---------- 工具栏 4 按钮 + 保存 ----------
func _on_new_map() -> void:
	_clear_canvas()
	_map_id = "map_" + str(Time.get_unix_time_from_system())
	_display_name = "新建地图"
	_current_file = ""
	_objectives.clear() if _objectives else pass
	set_status("已新建空地图 (id=%s)" % _map_id, 0)
	_refresh_status()

func _on_edit_existing() -> void:
	var dir := _serializer.user_maps_dir()
	set_status("请把 .map.json 文件拷贝到以下目录后重新打开：%s  （骨架：打开用户目录下第一张map）" % dir, 1)
	# 骨架：尝试加载该目录下第一个 .map.json
	var da := DirAccess.open(dir)
	if da == null:
		set_status("用户地图目录无法打开: " + dir, 2)
		return
	da.list_dir_begin()
	var f := da.get_next()
	var pick := ""
	while f != "":
		if f.ends_with(".map.json") and not f.ends_with(".bak"):
			pick = dir.path_join(f)
			break
		f = da.get_next()
	da.list_dir_end()
	if pick == "":
		set_status("未检测到已有地图，请先『新建』或把 .map.json 放进 %s" % dir, 1)
		return
	_load_from_file(pick)

func _on_official_templates() -> void:
	# 打开官方模板：scenes/workshop/templates/farm.map.json（如不存在则生成）
	var builtin: String = "res://scenes/workshop/templates/farm.map.json"
	var abs: String = ProjectSettings.globalize_path(builtin)
	if FileAccess.file_exists(abs):
		_load_from_file(abs)
		return
	# 无模板 → 创建一张 40×25 草地关卡
	_on_new_map()
	var saved_path := _serializer.resolve_map_path("farm_empty_template.map.json")
	_populate_empty_farm_example()
	_save_to_file(saved_path)

func _on_test_map() -> void:
	if _current_file == "" or not FileAccess.file_exists(_current_file):
		set_status("请先保存地图（骨架：先自动保存到临时目录再启动）", 1)
		var tmp_path := _serializer.resolve_map_path("__tmp_test__.map.json")
		_save_to_file(tmp_path, true)
	return _launch_game_with_map(_current_file)

func _on_save() -> void:
	if _current_file == "":
		_on_save_as()
		return
	_save_to_file(_current_file)

func _on_save_as() -> void:
	var fname := _map_id + ".map.json"
	var path := _serializer.resolve_map_path(fname)
	_save_to_file(path)

# ---------- 核心：保存/加载 ----------
func _save_to_file(path: String, silent: bool = false) -> void:
	var layers: Array = []
	for li in range(8):
		var cells := []
		var used: Array = _tilemap.get_used_cells(li)
		for c in used:
			var src: int = _tilemap.get_cell_source_id(li, c)
			var alt: Vector2i = _tilemap.get_cell_atlas_coords(li, c)
			var tile_id := alt.x  # 单图集：atlas.x 就是 tile_id
			cells.append([c.x, c.y, tile_id if src >= 0 else -1])
		layers.append({"index": li, "name": _tile_palette.get_layer_name(li), "cells": cells})
	var entities: Array = []
	if _entities_root:
		for e in _entities_root.get_children():
			if not (e is Node2D):
				continue
			var kind: String = str(e.get_meta("kind", "enemy"))
			var props: Dictionary = {}
			for m in e.get_meta_list():
				if m not in ["kind", "role", "entity_id"]:
					props[m] = e.get_meta(m)
			var eid: String = str(e.get_meta("entity_id", e.name))
			entities.append({"id": eid, "kind": kind, "x": int(e.global_position.x), "y": int(e.global_position.y), "props": props})
	var objectives_arr: Array = _objectives.to_json_array() if _objectives else []
	var meta: Dictionary = {
		"spawn": {"x": 560, "y": 800},
		"next_level": "",
		"author": OS.get_environment("USERNAME"),
		"mode": "PVE",
		"min_rank": 1,
		"bounds": {"x": 0, "y": 0, "w": 1920, "h": 1080},
	}
	var dict := _serializer.build_map_dict(_map_id, _display_name, layers, entities, objectives_arr, meta)
	var res: int = _serializer.save_to_file(dict, path, true)
	if res < 0:
		var errors := _serializer.validator.validate(dict)
		set_status("保存失败，校验错误：" + _serializer.validator.errors_to_string(errors), 2)
		return
	_current_file = path
	var name_only := path.get_file()
	if not silent:
		set_status("保存成功 → %s  (%d Bytes, %d entities, %d objectives)" % [name_only, res, entities.size(), objectives_arr.size()], 0)
	_refresh_status()

func _load_from_file(path: String) -> void:
	var dict: Dictionary = _serializer.load_from_file(path, true)
	if dict.is_empty():
		set_status("加载失败 → 请检查文件格式（需要 .map.json）", 2)
		return
	_clear_canvas()
	_map_id = str(dict.get("map_id", "unknown"))
	_display_name = str(dict.get("display_name", _map_id))
	_current_file = path
	# layers
	if dict.has("layers") and dict["layers"] is Array:
		for layer in dict["layers"]:
			if not (layer is Dictionary):
				continue
			var li: int = clamp(int(layer.get("index", 0)), 0, 7)
			var cells: Array = layer.get("cells", [])
			if cells is Array:
				for c in cells:
					if c is Array and c.size() >= 3:
						var cx := int(c[0]); var cy := int(c[1]); var tid := int(c[2])
						if tid >= 0:
							_tilemap.set_cell(li, Vector2i(cx, cy), 0, Vector2i(tid, 0), 0)
						else:
							_tilemap.erase_cell(li, Vector2i(cx, cy))
	# entities
	if dict.has("entities") and dict["entities"] is Array:
		for ent in dict["entities"]:
			if not (ent is Dictionary):
				continue
			var n: Node2D = _spawn_entity_node(
				str(ent.get("kind", "enemy")),
				str(ent.get("id", "e_" + str(randi()))),
				ent.get("props", {})
			)
			if n:
				n.global_position = Vector2(float(ent.get("x", 0)), float(ent.get("y", 0)))
				_entities_root.add_child(n)
	# objectives
	if dict.has("objectives") and _objectives:
		_objectives.load_objectives(dict.get("objectives", []))
	set_status("加载成功 ← %s  (id=%s)" % [path.get_file(), _map_id], 0)
	_refresh_status()

func _populate_empty_farm_example() -> void:
	# 快速画一条地面：y=14 一整行 grass(1)，上一行 y=13 放几块 stone(3) 做平台
	for x in range(0, 60):
		_tilemap.set_cell(2, Vector2i(x, 14), 0, Vector2i(1, 0), 0)
	for x in range(10, 22):
		_tilemap.set_cell(2, Vector2i(x, 10), 0, Vector2i(3, 0), 0)
	for x in range(30, 42):
		_tilemap.set_cell(2, Vector2i(x, 8), 0, Vector2i(3, 0), 0)

# ---------- 画布输入：绘制Tile / 放置实体 / 选中实体 ----------
func _on_canvas_gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) and not (ev is InputEventMouseMotion):
		return
	var gpos := _screen_to_world(ev.position) if ev is InputEvent else Vector2.ZERO
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				if _mode == MODE_ENTITY and _entity_palette and _entity_palette._selected_id != "":
					var t := _entity_palette.request_place(gpos)
					if not t.is_empty():
						var node := _spawn_entity_node(str(t.get("kind", "")), str(t.get("id", "")) + "_" + str(_entities_root.get_child_count()), t.get("props", {}))
						if node:
							node.global_position = gpos
							_entities_root.add_child(node)
							set_status("已放置: %s  at (%.0f, %.0f)" % [str(t.get("name", "")), gpos.x, gpos.y], 0)
					return
				if _mode == MODE_SELECT:
					return _try_select_entity(gpos)
				# 绘制
				var coord: Vector2i = _tilemap.local_to_map(gpos)
				_draw.begin_batch()
				if _draw.current_tool == DrawTools.TOOL_RECT_FILL:
					_rect_start = coord
					_is_filling_rect = true
					return
				_draw.paint_cell(coord)
			else:  # release
				if _is_filling_rect and _draw.current_tool == DrawTools.TOOL_RECT_FILL:
					var end_coord := _tilemap.local_to_map(gpos)
					var n := _draw.flood_fill_area(_rect_start, _draw.current_tile_id, true, end_coord)
					set_status("矩形填充：%d 格" % n, 0)
				else:
					_draw.end_batch()
				_is_filling_rect = false
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			# 右键：切换到橡皮擦一下
			var old := _draw.current_tool
			_draw.current_tool = DrawTools.TOOL_ERASER
			var coord := _tilemap.local_to_map(gpos)
			_draw.begin_batch()
			_draw.paint_cell(coord)
			_draw.end_batch()
			_draw.current_tool = old
		elif ev.button_index == MOUSE_BUTTON_MIDDLE and ev.pressed:
			_try_select_entity(gpos)
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if _mode == MODE_TILE and _draw.current_tool in [DrawTools.TOOL_BRUSH, DrawTools.TOOL_ERASER]:
			var coord: Vector2i = _tilemap.local_to_map(gpos)
			_draw.paint_cell(coord)

# ---------- 内部辅助 ----------
func _on_tile_selected(tile_id: int, _name: String) -> void:
	_draw.current_tile_id = tile_id
	_mode = MODE_TILE
	_refresh_status()

func _on_layer_changed(layer_idx: int, _layer_name: String = "") -> void:
	_draw.current_layer = layer_idx
	_refresh_status()

func _on_left_tab_changed(idx: int) -> void:
	if idx == 0:
		_mode = MODE_TILE
	elif idx == 1:
		_mode = MODE_ENTITY
	_refresh_status()

func _on_entity_template_selected(_id: String, _kind: String, _name: String) -> void:
	_mode = MODE_ENTITY
	_refresh_status()
	set_status("已选中实体模板：%s — 左键画布放置（ESC取消）" % _name, 0)

func _on_entity_updated(ep: NodePath, field: String, new_val) -> void:
	set_status("实体更新 [%s] %s → %s" % [str(ep), field, str(new_val)], 0)

func _on_entity_removed(ep: NodePath) -> void:
	var n := get_node_or_null(ep)
	if n:
		n.queue_free()
		set_status("实体已删除", 0)

func _try_select_entity(world_pos: Vector2) -> void:
	if _entities_root == null:
		return
	var best: Node2D = null
	var best_d: float = 1e9
	for e in _entities_root.get_children():
		if e is Node2D:
			var d := e.global_position.distance_to(world_pos)
			if d < 40.0 and d < best_d:
				best_d = d
				best = e
	if best == null:
		_inspector.clear() if _inspector else pass
		_selected_entity = NodePath("")
		_refresh_status()
		return
	_selected_entity = best.get_path()
	var kind: String = str(best.get_meta("kind", "enemy"))
	var props: Dictionary = {}
	for m in best.get_meta_list():
		if m not in ["kind", "role"]:
			props[m] = best.get_meta(m)
	_inspector.inspect(_selected_entity, kind, props) if _inspector else pass
	_mode = MODE_SELECT
	set_status("选中实体: %s (kind=%s)" % [best.name, kind], 0)
	_refresh_status()

func _spawn_entity_node(kind: String, id: String, props: Dictionary) -> Node2D:
	var kind_lower := kind.to_lower()
	var node: Node2D
	var mloader := MapLoader.new()
	node = mloader._make_entity_node(kind_lower, id, props)
	if node == null:
		# fallback Area2D
		node = Area2D.new()
		node.name = id
		node.set_meta("kind", kind_lower)
		node.set_meta("role", kind_lower)
	for k in props.keys():
		node.set_meta(k, props[k])
	node.set_meta("entity_id", id)
	# 外观：ColorRect 子精灵，颜色按 kind 区分
	var spr := ColorRect.new()
	spr.name = "Sprite"
	var kind_color := {
		"npc": Color(0.3, 0.6, 0.9),
		"enemy": Color(0.9, 0.3, 0.3),
		"chest": Color(0.92, 0.7, 0.2),
		"checkpoint": Color(0.3, 0.9, 0.4),
		"portal": Color(0.6, 0.3, 0.9),
		"trigger": Color(0.9, 0.6, 0.2),
	}
	var c := kind_color.get(kind_lower, Color(0.7, 0.7, 0.7))
	spr.color = c
	spr.size = Vector2(28, 28)
	spr.position = Vector2(-14, -14)
	node.add_child(spr)
	return node

func _clear_canvas() -> void:
	if _tilemap:
		for li in range(8):
			var used := _tilemap.get_used_cells(li)
			for c in used:
				_tilemap.erase_cell(li, c)
	if _entities_root:
		for e in _entities_root.get_children():
			e.queue_free()
	_draw.clear_history()
	_selected_entity = NodePath("")
	_inspector.clear() if _inspector else pass

func _screen_to_world(local_in_holder: Vector2) -> Vector2:
	if _canvas_viewport == null:
		return local_in_holder
	var sz := _canvas_holder.size
	var vsz := _canvas_viewport.size
	if sz.x <= 0 or vsz.x <= 0:
		return local_in_holder
	var s := Vector2(vsz.x / sz.x, vsz.y / sz.y)
	return local_in_holder * s

func _refresh_status() -> void:
	if _status_mode:
		_status_mode.text = "模式: " + ["绘制Tile", "放置实体", "选中实体"][_mode]
	if _status_layer:
		_status_layer.text = "图层: L%d  %s" % [_draw.current_layer, _tile_palette.get_layer_name(_draw.current_layer) if _tile_palette else ""]
	if _status_file:
		var name := _current_file.get_file() if _current_file != "" else "(未保存)"
		_status_file.text = "文件: " + name

func set_status(msg: String, level: int = 0) -> void:
	if _status:
		var pref := ["ℹ ", "⚠ ", "❌ "][clamp(level, 0, 2)]
		_status.text = pref + msg
		if level == 0: _status.modulate = Color(0.85, 1.0, 0.85)
		elif level == 1: _status.modulate = Color(1.0, 0.95, 0.65)
		else: _status.modulate = Color(1.0, 0.55, 0.55)
	status.emit(msg, level)

func _launch_game_with_map(map_file: String) -> void:
	if map_file == "" or not FileAccess.file_exists(map_file):
		set_status("测试失败：找不到地图文件 " + map_file, 2)
		return
	var godot_bin: String = "D:/tools/game/Godot_v4.6.2/Godot_v4.6.2-stable_win64.exe"
	if not FileAccess.file_exists(godot_bin):
		godot_bin = OS.get_executable_path()
	var project_path := OS.get_executable_path().get_base_dir()  # fallback
	var args := PackedStringArray()
	args.append("--path")
	args.append(ProjectSettings.globalize_path("res://"))
	args.append("--map=" + map_file)
	args.append("res://scenes/bootstrap/Main.tscn")
	var pid: int = OS.create_process(godot_bin, args)
	if pid == -1:
		set_status("一键测试启动失败：检查 Godot 可执行文件位置 D:/tools/game/Godot_v4.6.2/...", 2)
		return
	set_status("一键测试已启动（PID=%d，地图=%s）" % [pid, map_file.get_file()], 0)

# ---------- 快捷键（Ctrl+S 保存 / Ctrl+Z 撤销 / Ctrl+Y 重做 / Esc 取消） ----------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _mode == MODE_ENTITY:
				_mode = MODE_SELECT
				_refresh_status()
			return
		if event.ctrl_pressed and event.keycode == KEY_S:
			_on_save()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode == KEY_Z:
			_draw.undo()
			get_viewport().set_input_as_handled()
		elif (event.ctrl_pressed and event.keycode == KEY_Y) or (event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_Z):
			_draw.redo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F:
			_draw.current_tool = DrawTools.TOOL_RECT_FILL
			set_status("绘制工具：矩形填充 (左键拖)", 0)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_B:
			_draw.current_tool = DrawTools.TOOL_BRUSH
			set_status("绘制工具：笔刷 (左键绘制/右键擦)", 0)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			_draw.current_tool = DrawTools.TOOL_ERASER
			set_status("绘制工具：橡皮", 0)
			get_viewport().set_input_as_handled()

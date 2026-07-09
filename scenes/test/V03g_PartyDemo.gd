extends Node2D

## V0.3g V03g_PartyDemo.gd — 三角色编队切换（Tab循环 / F1农民 F2锤兵 F3枪兵）
## 肉眼 5 步验收（用户手册 §三）：
## 1. 进入场景：农民(F1 x=300) + 锤兵(F2 x=480) + 枪兵(F3 x=660) 站一排，农民脚下黄光
## 2. 按Tab → 脚下黄光切到锤兵；再按→枪兵；再按→农民（循环）
## 3. F1/F2/F3 直接选角 → 黄光+顶部HP卡边框金光+底部金色大字
## 4. 切到任一角色，按A/D移动 → 只有当前选中的动，另两个站着（速度不同：枪>农>锤）
## 5. J攻击3种不同形状：农民镰刀弧/锤兵圆形紫/枪兵长条红

const _FARMER_SCRIPT := preload("res://scripts/characters/FarmerPlayer.gd")
const _MACE_SCRIPT := preload("res://scripts/characters/MaceFighterPlayer.gd")
const _SPEAR_SCRIPT := preload("res://scripts/characters/SpearmanPlayer.gd")

var characters: Array[CharacterBody2D] = []
var halos: Array[Node2D] = []
var hp_cards: Array[Control] = []
var hp_bars: Array[ProgressBar] = []
var hp_labels: Array[Label] = []
var floor_root: Node2D
var decor_root: Node2D
var cloud_root: Node2D
var hill_root: Node2D
var main_camera: Camera2D
var sky_root: Node2D
var _sky_chunk_width: float = 2400.0
var _sky_right_x: float = 0.0
var _sky_left_x: float = 0.0

var _floor_right_x: float = 0.0
var _floor_left_x: float = 0.0
const _FLOOR_CHUNK: float = 3000.0
const _FLOOR_TOP_Y: float = 360.0
const _FLOOR_H: float = 120.0
const _GRASS_STEP: float = 240.0

const _TREE_MIN_SPACING: float = 350.0
const _TREE_MAX_SPACING: float = 700.0
const _ROCK_MIN_SPACING: float = 280.0
const _ROCK_MAX_SPACING: float = 550.0
const _FLOWER_MIN_SPACING: float = 90.0
const _FLOWER_MAX_SPACING: float = 180.0
const _CLOUD_MIN_SPACING: float = 500.0
const _CLOUD_MAX_SPACING: float = 900.0
const _HILL_MIN_SPACING: float = 800.0
const _HILL_MAX_SPACING: float = 1400.0

@onready var canvas_layer_ui: CanvasLayer
@onready var top_bar: HBoxContainer
@onready var lbl_title: Label
@onready var lbl_current: Label
@onready var lbl_hint: Label

func _ready() -> void:
	randomize()
	_setup_ui()
	_setup_floor()
	_spawn_all()
	_setup_party_manager()
	_refresh_active_ui()
	lbl_title.text = "🌳 V0.1蓝4 马里奥式无限滚动环境 | 向右走→动态生成树木/石头/花朵/云朵/山丘 | Tab循环选角 F1/F2/F3选角 A/D移动 J攻击"
	lbl_current.text = "当前: 🧑‍🌾 布衣农夫 John（1号位）"
	lbl_current.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))

func _process(_d: float) -> void:
	_refresh_all_hp()
	_check_tab_fkeys()
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _physics_process(_delta: float) -> void:
	var active_char: CharacterBody2D = null
	for c in characters:
		if c == null or not is_instance_valid(c):
			continue
		if bool(c.get("is_active_controllable")):
			active_char = c
			_ensure_floor_around(c.global_position.x)
			_ensure_sky_around(c.global_position.x)
			break
	if active_char != null and main_camera != null:
		var target_pos: Vector2 = active_char.global_position + Vector2(180.0, -60.0)
		main_camera.global_position = main_camera.global_position.lerp(target_pos, 0.08)

func _ensure_floor_around(x: float) -> void:
	var need_left: float = x - 1200.0
	var need_right: float = x + 1200.0
	while _floor_left_x > need_left:
		var new_left: float = _floor_left_x - _FLOOR_CHUNK
		_build_floor_chunk(new_left, _floor_left_x)
		_floor_left_x = new_left
	while _floor_right_x < need_right:
		var new_right: float = _floor_right_x + _FLOOR_CHUNK
		_build_floor_chunk(_floor_right_x, new_right)
		_floor_right_x = new_right

func _build_floor_chunk(x0: float, x1: float) -> void:
	if x1 <= x0:
		return
	var w: float = x1 - x0
	var cx: float = (x0 + x1) * 0.5
	var cy: float = _FLOOR_TOP_Y + _FLOOR_H * 0.5
	var st := StaticBody2D.new()
	st.collision_layer = 4
	st.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, _FLOOR_H)
	cs.shape = rs
	cs.position = Vector2(cx, cy)
	st.add_child(cs)
	floor_root.add_child(st)
	var floor_bg := ColorRect.new()
	floor_bg.position = Vector2(x0, _FLOOR_TOP_Y)
	floor_bg.size = Vector2(w, _FLOOR_H)
	floor_bg.color = Color(0.2, 0.32, 0.22)
	floor_root.add_child(floor_bg)
	var g_start: int = int(ceil(x0 / _GRASS_STEP))
	var g_end: int = int(floor(x1 / _GRASS_STEP))
	for i in range(g_start, g_end + 1):
		var gx: float = float(i) * _GRASS_STEP
		var grass := ColorRect.new()
		grass.position = Vector2(gx, _FLOOR_TOP_Y - 4.0)
		grass.size = Vector2(140, 8)
		grass.color = Color(0.3, 0.55, 0.3)
		floor_root.add_child(grass)
	_build_decor_for_chunk(x0, x1)

func _build_decor_for_chunk(x0: float, x1: float) -> void:
	_spawn_trees(x0, x1)
	_spawn_rocks(x0, x1)
	_spawn_flowers(x0, x1)
	_spawn_clouds(x0, x1)
	_spawn_hills(x0, x1)

func _spawn_trees(x0: float, x1: float) -> void:
	var x: float = x0 + randf_range(50.0, 150.0)
	while x < x1 - 100.0:
		_build_tree(x)
		x += randf_range(_TREE_MIN_SPACING, _TREE_MAX_SPACING)

func _build_tree(x: float) -> void:
	var tree_node := Node2D.new()
	tree_node.position = Vector2(x, _FLOOR_TOP_Y)
	decor_root.add_child(tree_node)
	var trunk_h: float = randf_range(70.0, 110.0)
	var trunk_w: float = randf_range(14.0, 22.0)
	var trunk := ColorRect.new()
	trunk.position = Vector2(-trunk_w * 0.5, -trunk_h)
	trunk.size = Vector2(trunk_w, trunk_h)
	trunk.color = Color(0.35, 0.2, 0.1)
	tree_node.add_child(trunk)
	var leaf_r: float = randf_range(40.0, 60.0)
	var leaf_colors := [Color(0.2, 0.55, 0.25), Color(0.25, 0.6, 0.28), Color(0.18, 0.5, 0.22)]
	for j in range(3):
		var leaf := ColorRect.new()
		var lw: float = leaf_r * (2.0 - float(j) * 0.25)
		var lh: float = leaf_r * (1.6 - float(j) * 0.15)
		leaf.position = Vector2(-lw * 0.5, -trunk_h - leaf_r * 0.6 - float(j) * leaf_r * 0.45)
		leaf.size = Vector2(lw, lh)
		leaf.color = leaf_colors[j % leaf_colors.size()]
		tree_node.add_child(leaf)

func _spawn_rocks(x0: float, x1: float) -> void:
	var x: float = x0 + randf_range(80.0, 200.0)
	while x < x1 - 80.0:
		if randf() < 0.7:
			_build_rock(x)
		x += randf_range(_ROCK_MIN_SPACING, _ROCK_MAX_SPACING)

func _build_rock(x: float) -> void:
	var rock_node := Node2D.new()
	rock_node.position = Vector2(x, _FLOOR_TOP_Y)
	decor_root.add_child(rock_node)
	var rw: float = randf_range(28.0, 50.0)
	var rh: float = randf_range(18.0, 32.0)
	var rock := ColorRect.new()
	rock.position = Vector2(-rw * 0.5, -rh)
	rock.size = Vector2(rw, rh)
	rock.color = Color(0.5, 0.5, 0.52)
	rock_node.add_child(rock)
	var rock_top := ColorRect.new()
	rock_top.position = Vector2(-rw * 0.4, -rh - 6.0)
	rock_top.size = Vector2(rw * 0.8, 10.0)
	rock_top.color = Color(0.58, 0.58, 0.6)
	rock_node.add_child(rock_top)

func _spawn_flowers(x0: float, x1: float) -> void:
	var x: float = x0 + randf_range(30.0, 80.0)
	while x < x1 - 30.0:
		if randf() < 0.85:
			_build_flower(x)
		x += randf_range(_FLOWER_MIN_SPACING, _FLOWER_MAX_SPACING)

func _build_flower(x: float) -> void:
	var flower_node := Node2D.new()
	flower_node.position = Vector2(x, _FLOOR_TOP_Y)
	decor_root.add_child(flower_node)
	var stem_h: float = randf_range(10.0, 18.0)
	var stem := ColorRect.new()
	stem.position = Vector2(-1.0, -stem_h)
	stem.size = Vector2(2.0, stem_h)
	stem.color = Color(0.25, 0.5, 0.25)
	flower_node.add_child(stem)
	var petal_colors := [Color(1.0, 0.4, 0.5), Color(1.0, 0.85, 0.2), Color(0.5, 0.7, 1.0), Color(1.0, 0.6, 0.9), Color(1.0, 1.0, 0.7)]
	var petal_color: Color = petal_colors[randi() % petal_colors.size()]
	var petal_r: float = randf_range(3.5, 5.5)
	for angle_deg in range(0, 360, 60):
		var angle: float = deg_to_rad(float(angle_deg))
		var px: float = cos(angle) * petal_r * 0.6 - petal_r * 0.5
		var py: float = sin(angle) * petal_r * 0.6 - stem_h - petal_r
		var petal := ColorRect.new()
		petal.position = Vector2(px, py)
		petal.size = Vector2(petal_r, petal_r)
		petal.color = petal_color
		flower_node.add_child(petal)
	var center := ColorRect.new()
	center.position = Vector2(-petal_r * 0.4, -stem_h - petal_r - petal_r * 0.1)
	center.size = Vector2(petal_r * 0.8, petal_r * 0.8)
	center.color = Color(1.0, 0.9, 0.2)
	flower_node.add_child(center)

func _spawn_clouds(x0: float, x1: float) -> void:
	var x: float = x0 + randf_range(100.0, 300.0)
	while x < x1:
		_build_cloud(x)
		x += randf_range(_CLOUD_MIN_SPACING, _CLOUD_MAX_SPACING)

func _build_cloud(x: float) -> void:
	var cloud_node := Node2D.new()
	var y: float = randf_range(40.0, 160.0)
	cloud_node.position = Vector2(x, y)
	cloud_root.add_child(cloud_node)
	var cloud_w: float = randf_range(80.0, 160.0)
	var cloud_h: float = randf_range(26.0, 44.0)
	var parts := 3 + randi() % 3
	for i in range(parts):
		var part := ColorRect.new()
		var pw: float = cloud_w * (0.5 + randf() * 0.5)
		var ph: float = cloud_h * (0.7 + randf() * 0.5)
		part.position = Vector2(float(i) * cloud_w * 0.25 - pw * 0.3 + randf_range(-10.0, 10.0), randf_range(-8.0, 8.0) - ph * 0.3)
		part.size = Vector2(pw, ph)
		part.color = Color(0.95 + randf() * 0.05, 0.97 + randf() * 0.03, 1.0, 0.85 + randf() * 0.15)
		cloud_node.add_child(part)

func _spawn_hills(x0: float, x1: float) -> void:
	var x: float = x0 + randf_range(0.0, 400.0)
	while x < x1:
		_build_hill(x)
		x += randf_range(_HILL_MIN_SPACING, _HILL_MAX_SPACING)

func _build_hill(x: float) -> void:
	var hill_node := Node2D.new()
	hill_node.position = Vector2(x, _FLOOR_TOP_Y)
	hill_root.add_child(hill_node)
	var hill_w: float = randf_range(350.0, 600.0)
	var hill_h: float = randf_range(80.0, 150.0)
	var hill := ColorRect.new()
	hill.position = Vector2(-hill_w * 0.5, -hill_h)
	hill.size = Vector2(hill_w, hill_h)
	hill.color = Color(0.25, 0.42, 0.26)
	hill_node.add_child(hill)
	var hill_top_w: float = hill_w * 0.7
	var hill2 := ColorRect.new()
	hill2.position = Vector2(-hill_top_w * 0.5 + hill_w * 0.1, -hill_h * 0.75)
	hill2.size = Vector2(hill_top_w, hill_h * 0.8)
	hill2.color = Color(0.28, 0.48, 0.3)
	hill_node.add_child(hill2)

func _build_sky_chunk(x0: float, x1: float) -> void:
	if x1 <= x0:
		return
	var w: float = x1 - x0
	var sky_bg := ColorRect.new()
	sky_bg.position = Vector2(x0, -200.0)
	sky_bg.size = Vector2(w, _FLOOR_TOP_Y + 200.0)
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.8, 1.0))
	g.set_color(1, Color(0.85, 0.95, 1.0))
	sky_bg.color = Color(0.62, 0.84, 1.0)
	sky_root.add_child(sky_bg)
	var x: float = x0 + randf_range(200.0, 400.0)
	while x < x1:
		_build_distant_mountain(x)
		x += randf_range(600.0, 1000.0)

func _build_distant_mountain(x: float) -> void:
	var m_node := Node2D.new()
	m_node.position = Vector2(x, _FLOOR_TOP_Y)
	sky_root.add_child(m_node)
	var mw: float = randf_range(450.0, 750.0)
	var mh: float = randf_range(120.0, 220.0)
	var mountain := ColorRect.new()
	mountain.position = Vector2(-mw * 0.5, -mh)
	mountain.size = Vector2(mw, mh)
	mountain.color = Color(0.35, 0.5, 0.65, 0.7)
	m_node.add_child(mountain)
	var peak_w := mw * 0.55
	var peak_h := mh * 0.6
	var peak := ColorRect.new()
	peak.position = Vector2(-peak_w * 0.5 + mw * 0.08, -mh - peak_h * 0.4)
	peak.size = Vector2(peak_w, peak_h)
	peak.color = Color(0.4, 0.55, 0.7, 0.7)
	m_node.add_child(peak)
	var snow_w := peak_w * 0.45
	var snow_h := 18.0 + randf() * 12.0
	var snow := ColorRect.new()
	snow.position = Vector2(-snow_w * 0.5 + mw * 0.08, -mh - peak_h * 0.4 - 2.0)
	snow.size = Vector2(snow_w, snow_h)
	snow.color = Color(0.95, 0.97, 1.0, 0.85)
	m_node.add_child(snow)

func _ensure_sky_around(x: float) -> void:
	var need_left: float = x - 2400.0
	var need_right: float = x + 2400.0
	while _sky_left_x > need_left:
		var new_left: float = _sky_left_x - _sky_chunk_width
		_build_sky_chunk(new_left, _sky_left_x)
		_sky_left_x = new_left
	while _sky_right_x < need_right:
		var new_right: float = _sky_right_x + _sky_chunk_width
		_build_sky_chunk(_sky_right_x, new_right)
		_sky_right_x = new_right

func _setup_floor() -> void:
	sky_root = Node2D.new()
	sky_root.name = "SkyRoot"
	sky_root.z_index = -200
	sky_root.z_as_relative = false
	add_child(sky_root)
	hill_root = Node2D.new()
	hill_root.name = "HillRoot"
	hill_root.z_index = -150
	hill_root.z_as_relative = false
	add_child(hill_root)
	cloud_root = Node2D.new()
	cloud_root.name = "CloudRoot"
	cloud_root.z_index = -100
	cloud_root.z_as_relative = false
	add_child(cloud_root)
	decor_root = Node2D.new()
	decor_root.name = "DecorRoot"
	decor_root.z_index = -20
	decor_root.z_as_relative = false
	add_child(decor_root)
	floor_root = Node2D.new()
	floor_root.name = "FloorRoot"
	floor_root.z_index = -10
	floor_root.z_as_relative = false
	add_child(floor_root)
	main_camera = Camera2D.new()
	main_camera.name = "MainCamera"
	add_child(main_camera)
	main_camera.make_current()
	main_camera.position_smoothing_enabled = true
	main_camera.position_smoothing_speed = 6.0
	main_camera.limit_left = -1000000
	main_camera.limit_right = 1000000
	main_camera.limit_top = -1000000
	main_camera.limit_bottom = 1000000
	_sky_left_x = 0.0
	_sky_right_x = 0.0
	_build_sky_chunk(0.0, 7200.0)
	_sky_left_x = 0.0
	_sky_right_x = 7200.0
	_floor_left_x = 0.0
	_floor_right_x = 0.0
	_build_floor_chunk(0.0, 6000.0)
	_floor_left_x = 0.0
	_floor_right_x = 6000.0

func _setup_ui() -> void:
	canvas_layer_ui = CanvasLayer.new()
	canvas_layer_ui.layer = 100
	add_child(canvas_layer_ui)
	var vb_root := VBoxContainer.new()
	vb_root.custom_minimum_size = Vector2(1280, 720)
	vb_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer_ui.add_child(vb_root)
	lbl_title = Label.new()
	lbl_title.add_theme_font_size_override("font_size", 18)
	lbl_title.add_theme_color_override("font_color", Color(1, 1, 1))
	vb_root.add_child(lbl_title)
	top_bar = HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 14)
	vb_root.add_child(top_bar)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb_root.add_child(spacer)
	var bottom_box := VBoxContainer.new()
	bottom_box.add_theme_constant_override("separation", 4)
	vb_root.add_child(bottom_box)
	lbl_current = Label.new()
	lbl_current.add_theme_font_size_override("font_size", 28)
	lbl_current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_box.add_child(lbl_current)
	lbl_hint = Label.new()
	lbl_hint.text = "  ▶ 🌲 向右走探索无限世界！动态生成树木/石头/花朵/云朵/山丘 | Tab=下一人 F1/F2/F3=选角 A/D移动 Space跳 J攻击 K格挡 Shift冲刺 Esc回菜单"
	lbl_hint.add_theme_font_size_override("font_size", 16)
	lbl_hint.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	bottom_box.add_child(lbl_hint)
	for i in range(3):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(230, 72)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.12, 0.18, 0.82)
		style.border_color = Color(0.35, 0.4, 0.5, 0.9)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		card.add_theme_stylebox_override("panel", style)
		top_bar.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 2)
		card.add_child(cv)
		var lb := Label.new()
		lb.add_theme_font_size_override("font_size", 15)
		lb.text = ["🧑‍🌾  F1 农民", "⚔  F2 锤兵", "🔱  F3 枪兵"][i]
		lb.add_theme_color_override("font_color", Color(1, 1, 1))
		cv.add_child(lb)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(212, 16)
		bar.max_value = 100
		bar.value = 100
		bar.show_percentage = false
		cv.add_child(bar)
		var lh := Label.new()
		lh.add_theme_font_size_override("font_size", 13)
		lh.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		cv.add_child(lh)
		hp_cards.append(card)
		hp_bars.append(bar)
		hp_labels.append(lh)

func _spawn_all() -> void:
	var xs := [800.0, 960.0, 1120.0]
	var scripts: Array = [_FARMER_SCRIPT, _MACE_SCRIPT, _SPEAR_SCRIPT]
	for i in range(3):
		var c: CharacterBody2D = CharacterBody2D.new()
		c.set_script(scripts[i])
		c.position = Vector2(xs[i], 200)
		c.set("is_active_controllable", false)
		c.z_index = 50 + i
		c.z_as_relative = false
		c.modulate.a = 1.0
		c.show()
		c.set_process(true)
		c.set_physics_process(true)
		c.set_process_input(true)
		add_child(c)
		characters.append(c)
		var cam := c.get_node_or_null("Camera2D")
		if cam != null:
			cam.queue_free()
		for cn in c.get_children():
			if cn is Node2D and cn.name != "Camera2D":
				cn.z_index = 51 + i
				cn.z_as_relative = false
				cn.show()
				cn.modulate.a = 1.0
		c.queue_redraw()
		var halo: HaloRing = HaloRing.new()
		halo.visible = false
		halo.z_index = 60 + i
		halo.z_as_relative = false
		add_child(halo)
		halos.append(halo)
	call_deferred("_fix_char_z_after_ready")
	characters[0].set("is_active_controllable", true)
	if halos.size() > 0 and halos[0] != null:
		halos[0].visible = true
		halos[0].set_color(Color(1.0, 0.95, 0.3, 0.9))

func _fix_char_z_after_ready() -> void:
	for i in range(characters.size()):
		var c := characters[i]
		if c == null:
			continue
		c.z_index = 50 + i
		c.z_as_relative = false
		for cn in c.get_children():
			if cn is Node2D and cn.name != "Camera2D":
				cn.z_index = 51 + i
				cn.z_as_relative = false

func _setup_party_manager() -> void:
	var pm: Node = _autoload("PartyManager")
	if pm == null:
		return
	pm.clear()
	for c in characters:
		pm.call("register", c)
	if pm.has_signal("party_switched"):
		pm.party_switched.connect(_on_party_switched)
	var ge: Node = _autoload("GameEvents")
	if ge != null and ge.has_signal("party_switched") and pm.has_signal("party_switched"):
		if not pm.party_switched.is_connected(ge.party_switched.emit):
			pm.party_switched.connect(func(oi, ni, nc):
				if ge != null and ge.has_signal("party_switched"):
					ge.emit_signal("party_switched", oi, ni, nc))

func _check_tab_fkeys() -> void:
	var pm: Node = _autoload("PartyManager")
	if pm == null:
		return
	if Input.is_action_just_pressed("party_next"):
		pm.call("switch_next")
	if Input.is_action_just_pressed("party_pick_1"):
		pm.call("switch_to", 0)
	if Input.is_action_just_pressed("party_pick_2"):
		pm.call("switch_to", 1)
	if Input.is_action_just_pressed("party_pick_3"):
		pm.call("switch_to", 2)

func _on_party_switched(old_idx: int, new_idx: int, new_char: CharacterBody2D) -> void:
	for i in range(characters.size()):
		characters[i].set("is_active_controllable", i == new_idx)
		if not characters[i].get("is_active_controllable"):
			characters[i].velocity.x = move_toward(characters[i].velocity.x, 0.0, 9999.0)
	_refresh_active_ui()

func _refresh_active_ui() -> void:
	var pm: Node = _autoload("PartyManager")
	var cur_idx: int = 0
	if pm != null:
		cur_idx = int(pm.get("active_idx"))
	for i in range(3):
		if i < halos.size() and halos[i] != null and is_instance_valid(halos[i]):
			halos[i].visible = i == cur_idx
			if characters.size() > i:
				halos[i].global_position = characters[i].global_position + Vector2(0, 28)
			if i == cur_idx and halos[i].has_method("set_color"):
				halos[i].call("set_color", Color(1.0, 0.95, 0.3, 0.9))
		var card: Control = hp_cards[i] if i < hp_cards.size() else null
		if card != null:
			var style: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
			if style != null:
				if i == cur_idx:
					style.border_color = Color(1.0, 0.92, 0.3, 1.0)
					style.bg_color = Color(0.22, 0.2, 0.08, 0.9)
				else:
					style.border_color = Color(0.35, 0.4, 0.5, 0.9)
					style.bg_color = Color(0.1, 0.12, 0.18, 0.82)
	var names := ["🧑‍🌾 布衣农夫 John（1号位）", "🛡 铁壁锤兵 Gregor（2号位）", "🔱 疾风枪兵 Lance（3号位）"]
	lbl_current.text = "当前: %s" % names[clamp(cur_idx, 0, names.size() - 1)]

func _refresh_all_hp() -> void:
	var pm: Node = _autoload("PartyManager")
	var cur_idx: int = 0
	if pm != null:
		cur_idx = int(pm.get("active_idx"))
	for i in range(3):
		if i >= characters.size():
			continue
		var ch: CharacterBody2D = characters[i]
		if ch == null:
			continue
		var h: int = int(ch.get("hp") if "hp" in ch else 0)
		var m: int = int(ch.get("max_hp") if "max_hp" in ch else 100)
		var dn: String = str(ch.get("display_name") if "display_name" in ch else "角色"+str(i+1))
		var bar := hp_bars[i]
		var lb := hp_labels[i]
		if bar != null:
			bar.max_value = max(m, 1)
			bar.value = clamp(h, 0, bar.max_value)
			var t: float = float(h) / float(max(m, 1))
			match true:
				t > 0.6: bar.add_theme_color_override("fill_color", Color(0.3, 0.85, 0.42))
				t > 0.3: bar.add_theme_color_override("fill_color", Color(0.95, 0.78, 0.25))
				_: bar.add_theme_color_override("fill_color", Color(0.95, 0.3, 0.35))
		if lb != null:
			lb.text = "%s   HP: %d / %d  %s" % [dn.substr(max(0, dn.length()-10), min(10, dn.length())), h, m, ("◀正在操作" if i == cur_idx else "")]
	for i in range(3):
		if i < halos.size() and characters.size() > i and halos[i] != null and is_instance_valid(halos[i]):
			halos[i].global_position = characters[i].global_position + Vector2(0, 28)
			halos[i].queue_redraw()

func _autoload(name: String) -> Node:
	var t := get_tree()
	if t == null or t.root == null:
		return null
	if t.root.has_node(name):
		return t.root.get_node(name)
	return null

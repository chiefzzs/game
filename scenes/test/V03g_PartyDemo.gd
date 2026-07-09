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
	lbl_title.text = "👥 V0.3g 三角色编队切换 | Tab循环 / F1农民 / F2锤兵 / F3枪兵 / A/D移动 J攻击 K格挡 Space跳 Shift冲刺 Esc回菜单"
	lbl_current.text = "当前: 🧑‍🌾 布衣农夫 John（1号位）"
	lbl_current.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))

func _process(_d: float) -> void:
	_refresh_all_hp()
	_check_tab_fkeys()
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

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
	lbl_hint.text = "  ▶ Tab=下一人   F1/F2/F3=选1/2/3号   操作：A/D移动 · Space双跳 · J普攻 · K格挡 · Shift冲刺 · Esc=回菜单"
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

func _setup_floor() -> void:
	floor_root = Node2D.new()
	floor_root.name = "FloorRoot"
	add_child(floor_root)
	var st := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(1920, 120)
	cs.shape = rs
	cs.position = Vector2(960, 420)
	st.add_child(cs)
	floor_root.add_child(st)
	var floor_bg := ColorRect.new()
	floor_bg.position = Vector2(0, 360)
	floor_bg.size = Vector2(1920, 120)
	floor_bg.color = Color(0.2, 0.32, 0.22)
	floor_root.add_child(floor_bg)
	for i in range(8):
		var grass := ColorRect.new()
		grass.position = Vector2(float(i) * 240.0, 356)
		grass.size = Vector2(140, 8)
		grass.color = Color(0.3, 0.55, 0.3)
		floor_root.add_child(grass)

func _spawn_all() -> void:
	var xs := [800.0, 960.0, 1120.0]
	var scripts: Array = [_FARMER_SCRIPT, _MACE_SCRIPT, _SPEAR_SCRIPT]
	for i in range(3):
		var c: CharacterBody2D = CharacterBody2D.new()
		c.set_script(scripts[i])
		c.position = Vector2(xs[i], 360)
		c.set("is_active_controllable", false)
		add_child(c)
		characters.append(c)
		var halo: HaloRing = HaloRing.new()
		halo.visible = false
		add_child(halo)
		halos.append(halo)
	characters[0].set("is_active_controllable", true)
	if halos.size() > 0 and halos[0] != null:
		halos[0].visible = true
		halos[0].set_color(Color(1.0, 0.95, 0.3, 0.9))

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

extends CanvasLayer
## V0.3 scripts/ui/CombatHUDController.gd — 战斗HUD
## 实现: HP条/SP条/金币/武器槽/目标敌人血条/Combo显示 6要素
## 以CanvasLayer为基类，所有控件通过代码动态创建，不依赖预设

class_name CombatHUDController

const PLAYER_HUD_BG := Color(0.0, 0.0, 0.0, 0.55)
const HP_FILL := Color(0.95, 0.25, 0.25, 0.95)
const SP_FILL := Color(0.25, 0.65, 1.0, 0.95)
const ENEMY_HP_FILL := Color(0.9, 0.15, 0.15, 0.9)
const TEXT_COL := Color(1.0, 1.0, 1.0, 1.0)

var root_panel: PanelContainer
var hp_bar_bg: ColorRect
var hp_bar_fill: ColorRect
var hp_text: Label
var sp_bar_bg: ColorRect
var sp_bar_fill: ColorRect
var gold_text: Label
var weapon_slot_icons: Array[ColorRect] = []
var weapon_slot_labels: Array[Label] = []
var combo_container: MarginContainer
var combo_label: Label
var enemy_hud_visible: bool = false
var enemy_hud_bar_bg: ColorRect
var enemy_hud_bar_fill: ColorRect
var enemy_hud_name: Label
var enemy_hud_dmg: Label
var last_enemy: Node = null
var last_enemy_dmg: int = 0
var last_enemy_timer: float = 0.0

var float_text_nodes: Array[Node] = []

func _ready() -> void:
	layer = 10
	_build_player_hud()
	_build_weapon_slots()
	_build_combo_label()
	_build_enemy_hud()
	_register_events()

func _build_player_hud() -> void:
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.color = PLAYER_HUD_BG
	hp_bar_bg.size = Vector2(300, 20)
	hp_bar_bg.position = Vector2(20, 20)
	add_child(hp_bar_bg)
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = HP_FILL
	hp_bar_fill.size = Vector2(300, 20)
	hp_bar_fill.position = Vector2(20, 20)
	add_child(hp_bar_fill)
	hp_text = Label.new()
	hp_text.add_theme_font_size_override("font_size", 12)
	hp_text.text = "HP: 100 / 100"
	hp_text.position = Vector2(26, 20)
	hp_text.modulate = TEXT_COL
	add_child(hp_text)

	sp_bar_bg = ColorRect.new()
	sp_bar_bg.color = PLAYER_HUD_BG
	sp_bar_bg.size = Vector2(300, 12)
	sp_bar_bg.position = Vector2(20, 44)
	add_child(sp_bar_bg)
	sp_bar_fill = ColorRect.new()
	sp_bar_fill.color = SP_FILL
	sp_bar_fill.size = Vector2(300, 12)
	sp_bar_fill.position = Vector2(20, 44)
	add_child(sp_bar_fill)

	gold_text = Label.new()
	gold_text.add_theme_font_size_override("font_size", 14)
	gold_text.text = "金币: 0"
	gold_text.position = Vector2(20, 62)
	gold_text.modulate = Color(1.0, 0.85, 0.3)
	add_child(gold_text)

func _build_weapon_slots() -> void:
	var names := ["Fist", "Axe", "Bow"]
	var cols := [Color(0.7, 0.7, 0.7), Color(0.78, 0.55, 0.30), Color(0.45, 0.7, 0.35)]
	for i in range(3):
		var s := ColorRect.new()
		s.color = PLAYER_HUD_BG
		s.size = Vector2(56, 56)
		s.position = Vector2(20 + i * 62, 90)
		add_child(s)
		var ic := ColorRect.new()
		ic.color = cols[i]
		ic.size = Vector2(44, 44)
		ic.position = Vector2(26 + i * 62, 96)
		add_child(ic)
		weapon_slot_icons.append(ic)
		var lb := Label.new()
		lb.add_theme_font_size_override("font_size", 10)
		lb.text = "[%d] %s" % [i+1, names[i]]
		lb.position = Vector2(22 + i * 62, 148)
		lb.modulate = TEXT_COL
		add_child(lb)
		weapon_slot_labels.append(lb)
	_select_weapon(0)

func _select_weapon(index: int) -> void:
	for i in range(weapon_slot_icons.size()):
		var s: ColorRect = weapon_slot_icons[i]
		s.color.a = 1.0 if i == index else 0.4

func _build_combo_label() -> void:
	combo_label = Label.new()
	combo_label.add_theme_font_size_override("font_size", 22)
	combo_label.text = ""
	combo_label.position = Vector2(20, 180)
	combo_label.modulate = Color(1.0, 0.9, 0.4)
	combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	combo_label.add_theme_constant_override("outline_size", 3)
	add_child(combo_label)

func _build_enemy_hud() -> void:
	enemy_hud_bar_bg = ColorRect.new()
	enemy_hud_bar_bg.color = PLAYER_HUD_BG
	enemy_hud_bar_bg.size = Vector2(420, 22)
	enemy_hud_bar_bg.position = Vector2(-500, 400)
	add_child(enemy_hud_bar_bg)
	enemy_hud_bar_fill = ColorRect.new()
	enemy_hud_bar_fill.color = ENEMY_HP_FILL
	enemy_hud_bar_fill.size = Vector2(420, 22)
	enemy_hud_bar_fill.position = Vector2(-500, 400)
	add_child(enemy_hud_bar_fill)
	enemy_hud_name = Label.new()
	enemy_hud_name.add_theme_font_size_override("font_size", 12)
	enemy_hud_name.text = ""
	enemy_hud_name.position = Vector2(-500, 402)
	enemy_hud_name.modulate = TEXT_COL
	add_child(enemy_hud_name)
	enemy_hud_dmg = Label.new()
	enemy_hud_dmg.add_theme_font_size_override("font_size", 14)
	enemy_hud_dmg.text = ""
	enemy_hud_dmg.position = Vector2(-500, 370)
	enemy_hud_dmg.modulate = Color(1.0, 0.4, 0.4)
	add_child(enemy_hud_dmg)

func _register_events() -> void:
	if GameEvents:
		GameEvents.character_stats_changed.connect(_on_stats)
		GameEvents.character_attack_connected.connect(_on_atk)
		GameEvents.gold_picked.connect(_on_gold)
		GameEvents.weapon_changed.connect(_on_weapon)
		GameEvents.combo_changed.connect(_on_combo)
		GameEvents.float_damage_requested.connect(_on_float_dmg)
		GameEvents.damage_calculated.connect(_on_dmg_calc)

func _process(delta: float) -> void:
	if last_enemy_timer > 0.0:
		last_enemy_timer -= delta
		if last_enemy_timer <= 0.0:
			_hide_enemy_hud()
	for i in range(float_text_nodes.size() - 1, -1, -1):
		var entry: Dictionary = float_text_nodes[i]
		entry["t"] += delta
		var t: float = entry["t"]
		var lbl: Label = entry["label"]
		lbl.position.y = entry["y0"] - t * 50.0
		lbl.modulate.a = max(0.0, 1.0 - t)
		if t >= 1.0:
			lbl.queue_free()
			float_text_nodes.remove_at(i)
	if enemy_hud_visible and last_enemy and is_instance_valid(last_enemy):
		var hp: int = int(last_enemy.get("hp", 0)) if last_enemy.has("hp") else 0
		var mh: int = int(last_enemy.get("max_hp", 1)) if last_enemy.has("max_hp") else 1
		enemy_hud_bar_fill.size.x = 420.0 * clamp(float(hp) / float(mh), 0.0, 1.0)

func _on_stats(c: CharacterBase) -> void:
	if c == null or c.kind != 0:
		return
	var hp: int = c.hp ; var mh: int = c.max_hp
	var sp: float = c.stamina ; var ms: float = c.max_stamina
	hp_bar_fill.size.x = 300.0 * clamp(float(hp) / float(mh), 0.0, 1.0)
	hp_text.text = "HP: %d / %d" % [hp, mh]
	sp_bar_fill.size.x = 300.0 * clamp(sp / max(1.0, ms), 0.0, 1.0)
	var g := int(c.get("gold", 0)) if c.has("gold") else 0
	gold_text.text = "金币: %d" % g

func _on_gold(_a: int, _b: Node, total: int) -> void:
	gold_text.text = "金币: %d" % total

func _on_weapon(_whom: Node, wid: String) -> void:
	var idx := 0
	match wid:
		"fist": idx = 0
		"axe":  idx = 1
		"bow":  idx = 2
		_:      idx = 0
	_select_weapon(idx)

func _on_combo(_a: Node, idx: int, maxidx: int, _w: float) -> void:
	if idx <= 0 or maxidx <= 0:
		combo_label.text = ""
		return
	combo_label.text = "COMBO %d / %d!" % [idx, maxidx]

func _on_atk(attacker: Node, victim: Node, dmg: int) -> void:
	if victim and victim.get("kind") if victim.has("kind") else -1 != 0:
		_show_enemy_hud(victim, dmg)

func _on_dmg_calc(res: Dictionary) -> void:
	var vic := res.get("victim", null)
	if vic and vic.has("kind"):
		if int(vic.get("kind", -1)) == 2:
			_show_enemy_hud(vic, int(res.get("final_damage", 0)))

func _show_enemy_hud(enemy: Node, fresh_dmg: int) -> void:
	last_enemy = enemy
	last_enemy_timer = 3.0
	enemy_hud_visible = true
	last_enemy_dmg += fresh_dmg
	var name_s := str(enemy.get("display_name", "?")) if enemy.has("display_name") else "?"
	var hp: int = int(enemy.get("hp", 0)) if enemy.has("hp") else 0
	var mh: int = int(enemy.get("max_hp", 1)) if enemy.has("max_hp") else 1
	var vp := get_viewport().get_visible_rect().size
	var x := vp.x * 0.5 - 210
	var y := 70.0
	enemy_hud_bar_bg.position = Vector2(x, y)
	enemy_hud_bar_fill.position = Vector2(x, y)
	enemy_hud_bar_fill.size.x = 420.0 * clamp(float(hp) / float(mh), 0.0, 1.0)
	enemy_hud_name.position = Vector2(x + 6, y + 2)
	enemy_hud_name.text = "%s  HP %d / %d" % [name_s, hp, mh]
	enemy_hud_dmg.position = Vector2(x + 200, y - 28)
	enemy_hud_dmg.text = "-%d" % last_enemy_dmg
	await get_tree().create_timer(1.4).timeout
	last_enemy_dmg = 0

func _hide_enemy_hud() -> void:
	enemy_hud_visible = false
	enemy_hud_bar_bg.position = Vector2(-2000, -2000)
	enemy_hud_bar_fill.position = Vector2(-2000, -2000)
	enemy_hud_name.position = Vector2(-2000, -2000)
	enemy_hud_dmg.position = Vector2(-2000, -2000)
	last_enemy_dmg = 0

func _on_float_dmg(pos: Vector2, text: String, col: Color, _fs: int) -> void:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.text = text
	lbl.modulate = col
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	var cv := get_viewport().get_canvas_transform()
	var sp := get_viewport().get_visible_rect().size
	lbl.position = pos # 简化: 直接在世界坐标近似
	lbl.z_index = 100
	add_child(lbl)
	float_text_nodes.append({"label": lbl, "t": 0.0, "y0": pos.y})

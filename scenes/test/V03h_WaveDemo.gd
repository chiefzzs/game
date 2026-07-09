extends Node2D
## V0.3h V03h_WaveDemo.gd — 多波次战斗演示（3波：1/2/3 史莱姆围攻）
## 肉眼 5 步验收（用户手册 §三）：
## 1. 进入场景：红色大字幕 "第 1 波 / 共 3 波" 1.6s 淡出 + 1 只绿史莱姆
## 2. 走近史莱姆：头顶绿条，J攻击 → 每刀闪红+HP条掉（绿→黄→红）+伤害浮字
## 3. 波1清完 2s → 蓝色字幕 "第 2 波 / 共 3 波"，刷 2 只
## 4. 波2清完 2s → 紫色字幕 "第 3 波 / 共 3 波"，刷 3 只
## 5. 波3清完 → 弹出 🏆 VICTORY 金色卡片（击杀/耗时/波次），Esc 回菜单

const _SLIME_SCRIPT := preload("res://scripts/characters/SlimeEnemy.gd")
const _FARMER_SCRIPT := preload("res://scripts/characters/FarmerPlayer.gd")
const _HITFLYER_SCRIPT := preload("res://scripts/combat/HitFlyer.gd")

var player: CharacterBody2D
var enemies_alive: Array[CharacterBody2D] = []
var world_root: Node2D
var flyers_layer: Node2D
var floor_root: Node2D
var t_wave_banner: Tween
var t_wave_clear_banner: Tween
var banner_lbl: Label
var banner_bg: ColorRect
var victory_root: Control
var lbl_stats: Label
var kills_label: Label
var wave_hud: Label

func _ready() -> void:
	randomize()
	_setup_floor()
	_setup_ui()
	_spawn_player()
	_setup_wm_signals()
	_setup_hp_flyers_bus()
	_call_deferred_start_first()

func _process(delta: float) -> void:
	_tick_banner(delta)
	_wave_hud_refresh()
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func _physics_process(delta: float) -> void:
	if player != null:
		pass

func _setup_floor() -> void:
	floor_root = Node2D.new()
	floor_root.name = "FloorRoot"
	add_child(floor_root)
	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)
	flyers_layer = Node2D.new()
	flyers_layer.name = "Flyers"
	world_root.add_child(flyers_layer)
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
	for i in range(10):
		var grass := ColorRect.new()
		grass.position = Vector2(float(i) * 192.0, 356)
		grass.size = Vector2(110, 8)
		grass.color = Color(0.3, 0.55, 0.3)
		floor_root.add_child(grass)
	for i in range(6):
		var tree := ColorRect.new()
		tree.position = Vector2(60.0 + float(i) * 310.0, 180)
		tree.size = Vector2(70, 180)
		tree.color = Color(0.22, 0.42, 0.22)
		floor_root.add_child(tree)
		var leaf := ColorRect.new()
		leaf.position = Vector2(40.0 + float(i) * 310.0, 140)
		leaf.size = Vector2(110, 90)
		leaf.color = Color(0.3, 0.65, 0.3)
		floor_root.add_child(leaf)

func _setup_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	banner_bg = ColorRect.new()
	banner_bg.color = Color(0, 0, 0, 0.0)
	banner_bg.custom_minimum_size = Vector2(900, 110)
	banner_bg.position = Vector2(1920 / 2.0 - 450, 720 / 2.0 - 120)
	banner_bg.size = Vector2(900, 110)
	cl.add_child(banner_bg)
	banner_lbl = Label.new()
	banner_lbl.custom_minimum_size = Vector2(900, 110)
	banner_lbl.position = Vector2(1920 / 2.0 - 450, 720 / 2.0 - 120)
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_lbl.add_theme_font_size_override("font_size", 54)
	banner_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	banner_lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.02, 0.02, 0))
	banner_lbl.add_theme_constant_override("outline_size", 10)
	banner_lbl.text = ""
	cl.add_child(banner_lbl)
	wave_hud = Label.new()
	wave_hud.position = Vector2(1500, 20)
	wave_hud.custom_minimum_size = Vector2(380, 40)
	wave_hud.add_theme_font_size_override("font_size", 22)
	wave_hud.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	wave_hud.text = "波次：0/3 ｜ 击杀：0"
	cl.add_child(wave_hud)
	var esc := Label.new()
	esc.position = Vector2(30, 20)
	esc.add_theme_font_size_override("font_size", 18)
	esc.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 1))
	esc.text = "🏠 Esc = 回主菜单 ｜ A/D=移动 ｜ Space=跳 ｜ J=攻击 ｜ K=格挡 ｜ Shift=冲刺"
	cl.add_child(esc)
	victory_root = Control.new()
	victory_root.visible = false
	victory_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(victory_root)
	var vb_vic := VBoxContainer.new()
	vb_vic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb_vic.custom_minimum_size = Vector2(520, 420)
	victory_root.add_child(vb_vic)
	var vic_card := PanelContainer.new()
	vic_card.custom_minimum_size = Vector2(520, 420)
	var vstyle := StyleBoxFlat.new()
	vstyle.bg_color = Color(1.0, 0.98, 0.85, 0.97)
	vstyle.border_color = Color(1.0, 0.8, 0.12, 1.0)
	vstyle.border_width_left = 6
	vstyle.border_width_top = 6
	vstyle.border_width_right = 6
	vstyle.border_width_bottom = 6
	vstyle.corner_radius_top_left = 16
	vstyle.corner_radius_top_right = 16
	vstyle.corner_radius_bottom_right = 16
	vstyle.corner_radius_bottom_left = 16
	vic_card.add_theme_stylebox_override("panel", vstyle)
	vb_vic.add_child(vic_card)
	var cvic := VBoxContainer.new()
	cvic.add_theme_constant_override("separation", 10)
	cvic.add_theme_constant_override("margin_left", 24)
	cvic.add_theme_constant_override("margin_right", 24)
	cvic.add_theme_constant_override("margin_top", 18)
	cvic.add_theme_constant_override("margin_bottom", 18)
	vic_card.add_child(cvic)
	var l1 := Label.new()
	l1.text = "🏆 胜  利"
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l1.add_theme_font_size_override("font_size", 52)
	l1.add_theme_color_override("font_color", Color(0.72, 0.42, 0.0))
	l1.add_theme_color_override("font_outline_color", Color(1, 0.92, 0.35, 1))
	l1.add_theme_constant_override("outline_size", 10)
	cvic.add_child(l1)
	var lsep := HSeparator.new()
	cvic.add_child(lsep)
	lbl_stats = Label.new()
	lbl_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_stats.add_theme_font_size_override("font_size", 22)
	lbl_stats.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	cvic.add_child(lbl_stats)
	kills_label = Label.new()
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_label.add_theme_font_size_override("font_size", 20)
	kills_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12, 1))
	cvic.add_child(kills_label)
	var lsep2 := HSeparator.new()
	cvic.add_child(lsep2)
	var btn_back := Button.new()
	btn_back.custom_minimum_size = Vector2(420, 68)
	btn_back.add_theme_font_size_override("font_size", 26)
	btn_back.text = "🏠 回主菜单（或按 Esc）"
	btn_back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn"))
	cvic.add_child(btn_back)

func _spawn_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(_FARMER_SCRIPT)
	player.position = Vector2(960, 360)
	world_root.add_child(player)

func _call_deferred_start_first() -> void:
	call_deferred("_start_first_wave_internal")

func _start_first_wave_internal() -> void:
	var wm: Node = _autoload("WaveManager")
	if wm != null:
		wm.call("clear")
		wm.call("start_from_first")

func _setup_wm_signals() -> void:
	var wm: Node = _autoload("WaveManager")
	if wm == null:
		return
	if wm.has_signal("wave_started"):
		if not wm.wave_started.is_connected(_on_wm_wave_started):
			wm.wave_started.connect(_on_wm_wave_started)
	if wm.has_signal("wave_cleared"):
		if not wm.wave_cleared.is_connected(_on_wm_wave_cleared):
			wm.wave_cleared.connect(_on_wm_wave_cleared)
	if wm.has_signal("all_waves_cleared"):
		if not wm.all_waves_cleared.is_connected(_on_wm_all_cleared):
			wm.all_waves_cleared.connect(_on_wm_all_cleared)
	var ge: Node = _autoload("GameEvents")
	if ge != null and ge.has_signal("wave_started") and wm.has_signal("wave_started"):
		if not wm.wave_started.is_connected(_relay_ge_wave_started):
			wm.wave_started.connect(_relay_ge_wave_started)
	if ge != null and ge.has_signal("wave_cleared") and wm.has_signal("wave_cleared"):
		if not wm.wave_cleared.is_connected(_relay_ge_wave_cleared):
			wm.wave_cleared.connect(_relay_ge_wave_cleared)
	if ge != null and ge.has_signal("all_waves_cleared") and wm.has_signal("all_waves_cleared"):
		if not wm.all_waves_cleared.is_connected(_relay_ge_all_cleared):
			wm.all_waves_cleared.connect(_relay_ge_all_cleared)

func _relay_ge_wave_started(wi: int, tw: int, ec: int) -> void:
	var ge: Node = _autoload("GameEvents")
	if ge != null and ge.has_signal("wave_started"):
		ge.emit_signal("wave_started", wi, tw, ec)

func _relay_ge_wave_cleared(wi: int, kw: int, tk: int) -> void:
	var ge: Node = _autoload("GameEvents")
	if ge != null and ge.has_signal("wave_cleared"):
		ge.emit_signal("wave_cleared", wi, kw, tk)

func _relay_ge_all_cleared(tk: int, ts: float) -> void:
	var ge: Node = _autoload("GameEvents")
	if ge != null and ge.has_signal("all_waves_cleared"):
		ge.emit_signal("all_waves_cleared", tk, ts)

func _on_wm_wave_started(idx: int, total: int, enemy_count: int) -> void:
	_spawn_wave_enemies(idx, enemy_count)
	var colors: Array[Color] = [
		Color(1.0, 0.28, 0.28), Color(0.35, 0.6, 1.0), Color(0.7, 0.38, 1.0)
	]
	var c: Color = colors[clamp(idx, 0, colors.size() - 1)]
	_show_banner("第 %d 波  /  共 %d 波" % [idx + 1, total], c, 1.6)

func _on_wm_wave_cleared(idx: int, kills_in_wave: int, total_kills: int) -> void:
	_show_corner("✔  第 %d 波清完，击杀 %d 只（累计 %d）" % [idx + 1, kills_in_wave, total_kills], Color(0.3, 0.9, 0.4))

func _on_wm_all_cleared(total_kills: int, total_sec: float) -> void:
	_show_victory(total_kills, total_sec)

func _spawn_wave_enemies(idx: int, n: int) -> void:
	var base_xs: Array[float] = [900.0, 1100.0, 720.0, 1250.0, 580.0, 1400.0]
	for i in range(n):
		var e: CharacterBody2D = CharacterBody2D.new()
		e.set_script(_SLIME_SCRIPT)
		var xi: int = clamp(i, 0, base_xs.size() - 1)
		var px: float = base_xs[xi] + float(idx * 28) + randf_range(-30.0, 30.0)
		var home := Vector2(px, 360)
		e.position = home
		world_root.add_child(e)
		if not enemies_alive.has(e):
			enemies_alive.append(e)
		var cfg := {
			"display_name": "史莱姆·绿滴",
			"max_hp": 80 + idx * 15,
			"base_atk": 8 + idx * 2,
			"base_def": 1 + idx,
			"move_speed": 180.0 + float(idx) * 20.0,
			"patrol_half": 90.0,
			"chase_trigger": 260.0,
			"attack_range": 56.0,
			"retreat_radius": 520.0,
			"weapon": {"atk_mult": 1.0, "cd_sec": 1.0, "knockback": 90, "range": 56, "break_shield": false}
		}
		if e.has_method("setup_enemy"):
			e.call("setup_enemy", home, cfg)
		if e.has_method("has_signal") and e.has_signal("died") and not e.died.is_connected(_on_enemy_died):
			e.died.connect(_on_enemy_died.bind(e))

func _on_enemy_died(_who, ekey: String, _pos: Vector2, the_enemy: Node2D) -> void:
	if enemies_alive.has(the_enemy):
		enemies_alive.erase(the_enemy)
	var wm: Node = _autoload("WaveManager")
	if wm != null:
		wm.call("notify_enemy_killed")

func _setup_hp_flyers_bus() -> void:
	var ge: Node = _autoload("GameEvents")
	if ge == null:
		return
	if ge.has_signal("enemy_damaged"):
		if not ge.enemy_damaged.is_connected(_on_enemy_damaged_show_flyer):
			ge.enemy_damaged.connect(_on_enemy_damaged_show_flyer)

func _on_enemy_damaged_show_flyer(who: Node, dmg: float, is_cr: bool, is_bs: bool) -> void:
	if who == null or not is_instance_valid(who):
		return
	var nd: Node2D = who as Node2D
	if nd == null or flyers_layer == null:
		return
	_HITFLYER_SCRIPT.spawn(flyers_layer, nd.global_position + Vector2(randf_range(-10.0, 10.0), -36.0), int(dmg), is_cr, is_bs)

var _banner_alpha: float = 0.0
var _banner_left: float = 0.0
var _banner_color: Color = Color(1, 1, 1, 1)

func _show_banner(txt: String, col: Color, dur: float) -> void:
	banner_lbl.text = txt
	_banner_color = col
	_banner_alpha = 1.0
	_banner_left = dur
	_apply_banner_alpha()

func _show_corner(txt: String, col: Color) -> void:
	wave_hud.text = "%s ｜ %s" % [wave_hud.text, txt]
	wave_hud.add_theme_color_override("font_color", col)
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(self):
			_wave_hud_refresh())

func _tick_banner(delta: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left < 0.3:
			_banner_alpha = clamp(_banner_left / 0.3, 0.0, 1.0)
		_apply_banner_alpha()
	else:
		if _banner_alpha > 0.0:
			_banner_alpha = 0.0
			_apply_banner_alpha()

func _apply_banner_alpha() -> void:
	var c: Color = _banner_color
	c.a = _banner_alpha
	banner_lbl.add_theme_color_override("font_color", c)
	var outl: Color = Color(c.r * 0.3, c.g * 0.2, c.b * 0.2, min(_banner_alpha, 0.85))
	banner_lbl.add_theme_color_override("font_outline_color", outl)
	banner_lbl.add_theme_constant_override("outline_size", 10)

func _wave_hud_refresh() -> void:
	var wm: Node = _autoload("WaveManager")
	if wm == null:
		return
	var wi: int = int(wm.get("current_wave_idx")) if wm.get("current_wave_idx") != null else -1
	var tw: int = int(wm.call("total_waves")) if wm.has_method("total_waves") else 3
	var tk: int = int(wm.get("total_kills"))
	var disp_wave: int = wi + 1 if wi >= 0 else 0
	wave_hud.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	wave_hud.text = "波次：%d/%d ｜ 击杀：%d" % [min(disp_wave, tw), tw, tk]

func _show_victory(tk: int, ts: float) -> void:
	victory_root.visible = true
	lbl_stats.text = "\n总击杀：  %d  只 史莱姆\n\n通关耗时：  %.2f  秒\n\n完成波次：  3 / 3\n" % [tk, ts]
	kills_label.text = "评价：  %s" % _star_rating(tk, ts)

func _star_rating(kills: int, sec: float) -> String:
	if sec < 25.0 and kills >= 6:
		return "⭐⭐⭐  （疾风斩将！）"
	elif sec < 45.0 and kills >= 5:
		return "⭐⭐  （稳扎稳打）"
	else:
		return "⭐  （成功通关）"

func _autoload(name: String) -> Node:
	var t := get_tree()
	if t == null or t.root == null:
		return null
	if t.root.has_node(name):
		return t.root.get_node(name)
	return null

extends Node2D
## V0.3i V03i_KdaDemo.gd — 在 V03h WaveDemo 基础上升级 KDA HUD + 最大连击 + 结算评级
## 肉眼 5 步（用户手册 §三 有详细描述）

const _SLIME_SCRIPT := preload("res://scripts/characters/SlimeEnemy.gd")
const _FARMER_SCRIPT := preload("res://scripts/characters/FarmerPlayer.gd")
const _HITFLYER_SCRIPT := preload("res://scripts/combat/HitFlyer.gd")

var player: CharacterBody2D
var enemies_alive: Array[CharacterBody2D] = []
var world_root: Node2D
var flyers_layer: Node2D
var floor_root: Node2D
var banner_lbl: Label
var banner_bg: ColorRect
var victory_root: Control
var lbl_stats: Label
var kills_label: Label
var wave_hud: Label
var rating_big: Label
var kda_detail_lbl: Label

# --- V0.3i KDA HUD ---
var kda_root: Control
var lbl_kill: Label
var lbl_death: Label
var lbl_block: Label
var combo_root: Control
var combo_lbl_c: Label
var combo_lbl_max: Label

func _ready() -> void:
	randomize()
	_setup_floor()
	_setup_ui()
	_setup_kda_combo_hud()
	_spawn_player()
	_setup_wm_signals()
	_setup_hp_flyers_bus()
	_setup_kda_listeners()
	_call_deferred_start_first()

func _process(delta: float) -> void:
	_tick_banner(delta)
	_wave_hud_refresh()
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

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
	esc.text = "🏠 Esc = 回主菜单 ｜ A/D=移动 ｜ Space=跳 ｜ J=攻击 ｜ K=格挡 ｜ Shift=冲刺 ｜ 目标=拿【S】评级"
	cl.add_child(esc)
	# ---- 胜利卡片 ----
	victory_root = Control.new()
	victory_root.visible = false
	victory_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(victory_root)
	var vb_vic := VBoxContainer.new()
	vb_vic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb_vic.custom_minimum_size = Vector2(680, 620)
	victory_root.add_child(vb_vic)
	var vic_card := PanelContainer.new()
	vic_card.custom_minimum_size = Vector2(680, 620)
	var vstyle := StyleBoxFlat.new()
	vstyle.bg_color = Color(1.0, 0.98, 0.85, 0.98)
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
	cvic.add_theme_constant_override("separation", 8)
	cvic.add_theme_constant_override("margin_left", 24)
	cvic.add_theme_constant_override("margin_right", 24)
	cvic.add_theme_constant_override("margin_top", 16)
	cvic.add_theme_constant_override("margin_bottom", 16)
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
	# KDA 明细
	var lbl_kda_t := Label.new()
	lbl_kda_t.text = "═════════  KDA 明 细（V0.3i 新增） ═════════"
	lbl_kda_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_kda_t.add_theme_font_size_override("font_size", 22)
	lbl_kda_t.add_theme_color_override("font_color", Color(0.45, 0.25, 0.0))
	cvic.add_child(lbl_kda_t)
	kda_detail_lbl = Label.new()
	kda_detail_lbl.name = "LblKdaDetail"
	kda_detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kda_detail_lbl.add_theme_font_size_override("font_size", 20)
	kda_detail_lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1))
	cvic.add_child(kda_detail_lbl)
	var lsep3 := HSeparator.new()
	cvic.add_child(lsep3)
	rating_big = Label.new()
	rating_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_big.add_theme_font_size_override("font_size", 96)
	rating_big.add_theme_color_override("font_color", Color(1.0, 0.12, 0.12, 1))
	rating_big.add_theme_color_override("font_outline_color", Color(1, 0.9, 0.1, 1))
	rating_big.add_theme_constant_override("outline_size", 14)
	rating_big.text = "S"
	cvic.add_child(rating_big)
	var lsep4 := HSeparator.new()
	cvic.add_child(lsep4)
	var btn_back := Button.new()
	btn_back.custom_minimum_size = Vector2(420, 68)
	btn_back.add_theme_font_size_override("font_size", 26)
	btn_back.text = "🏠 回主菜单（或按 Esc）"
	btn_back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn"))
	cvic.add_child(btn_back)

func _setup_kda_combo_hud() -> void:
	var cl2 := CanvasLayer.new()
	cl2.layer = 120
	add_child(cl2)
	kda_root = Control.new()
	kda_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	kda_root.position = Vector2(20, 70)
	kda_root.custom_minimum_size = Vector2(320, 160)
	cl2.add_child(kda_root)
	# Kill
	var k_panel := PanelContainer.new()
	k_panel.position = Vector2(0, 0)
	k_panel.custom_minimum_size = Vector2(300, 42)
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color(0.08, 0.06, 0.0, 0.82)
	ks.border_color = Color(1.0, 0.8, 0.2, 0.95)
	ks.border_width_left = 3
	ks.border_width_top = 3
	ks.border_width_right = 3
	ks.border_width_bottom = 3
	ks.corner_radius_top_left = 8
	ks.corner_radius_top_right = 8
	ks.corner_radius_bottom_right = 8
	ks.corner_radius_bottom_left = 8
	k_panel.add_theme_stylebox_override("panel", ks)
	lbl_kill = Label.new()
	lbl_kill.custom_minimum_size = Vector2(300, 42)
	lbl_kill.add_theme_font_size_override("font_size", 24)
	lbl_kill.add_theme_color_override("font_color", Color(1.0, 0.9, 0.15, 1))
	lbl_kill.text = "🗡  KILL  击杀 K：  0"
	k_panel.add_child(lbl_kill)
	kda_root.add_child(k_panel)
	# Death/Hit
	var d_panel := PanelContainer.new()
	d_panel.position = Vector2(0, 50)
	d_panel.custom_minimum_size = Vector2(300, 42)
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.1, 0.0, 0.02, 0.82)
	ds.border_color = Color(1.0, 0.25, 0.3, 0.95)
	ds.border_width_left = 3
	ds.border_width_top = 3
	ds.border_width_right = 3
	ds.border_width_bottom = 3
	ds.corner_radius_top_left = 8
	ds.corner_radius_top_right = 8
	ds.corner_radius_bottom_right = 8
	ds.corner_radius_bottom_left = 8
	d_panel.add_theme_stylebox_override("panel", ds)
	lbl_death = Label.new()
	lbl_death.custom_minimum_size = Vector2(300, 42)
	lbl_death.add_theme_font_size_override("font_size", 24)
	lbl_death.add_theme_color_override("font_color", Color(1.0, 0.42, 0.45, 1))
	lbl_death.text = "💀  DEATH 死亡 D：  0   HIT受击：  0"
	d_panel.add_child(lbl_death)
	kda_root.add_child(d_panel)
	# Block
	var b_panel := PanelContainer.new()
	b_panel.position = Vector2(0, 100)
	b_panel.custom_minimum_size = Vector2(300, 42)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.0, 0.06, 0.12, 0.82)
	bs.border_color = Color(0.35, 0.7, 1.0, 0.95)
	bs.border_width_left = 3
	bs.border_width_top = 3
	bs.border_width_right = 3
	bs.border_width_bottom = 3
	bs.corner_radius_top_left = 8
	bs.corner_radius_top_right = 8
	bs.corner_radius_bottom_right = 8
	bs.corner_radius_bottom_left = 8
	b_panel.add_theme_stylebox_override("panel", bs)
	lbl_block = Label.new()
	lbl_block.custom_minimum_size = Vector2(300, 42)
	lbl_block.add_theme_font_size_override("font_size", 24)
	lbl_block.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0, 1))
	lbl_block.text = "🛡  BLOCK 格挡 A：  0"
	b_panel.add_child(lbl_block)
	kda_root.add_child(b_panel)

	# Combo HUD 右上
	combo_root = Control.new()
	combo_root.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	combo_root.position = Vector2(1920 - 420, 70)
	combo_root.custom_minimum_size = Vector2(380, 110)
	cl2.add_child(combo_root)
	var c_panel := PanelContainer.new()
	c_panel.name = "ComboPanel"
	c_panel.custom_minimum_size = Vector2(380, 110)
	var cs2 := StyleBoxFlat.new()
	cs2.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	cs2.border_color = Color(1, 0.9, 0.2, 0.0)
	cs2.border_width_left = 3
	cs2.border_width_top = 3
	cs2.border_width_right = 3
	cs2.border_width_bottom = 3
	cs2.corner_radius_top_left = 10
	cs2.corner_radius_top_right = 10
	cs2.corner_radius_bottom_right = 10
	cs2.corner_radius_bottom_left = 10
	c_panel.add_theme_stylebox_override("panel", cs2)
	combo_root.add_child(c_panel)
	var vb_c := VBoxContainer.new()
	vb_c.custom_minimum_size = Vector2(380, 110)
	vb_c.add_theme_constant_override("separation", 2)
	c_panel.add_child(vb_c)
	combo_lbl_c = Label.new()
	combo_lbl_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_lbl_c.custom_minimum_size = Vector2(380, 66)
	combo_lbl_c.add_theme_font_size_override("font_size", 50)
	combo_lbl_c.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1))
	combo_lbl_c.add_theme_constant_override("outline_size", 10)
	combo_lbl_c.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 1))
	combo_lbl_c.text = "Combo x 0"
	vb_c.add_child(combo_lbl_c)
	combo_lbl_max = Label.new()
	combo_lbl_max.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_lbl_max.custom_minimum_size = Vector2(380, 32)
	combo_lbl_max.add_theme_font_size_override("font_size", 22)
	combo_lbl_max.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1))
	combo_lbl_max.text = "Max Combo： 0"
	vb_c.add_child(combo_lbl_max)

func _spawn_player() -> void:
	player = CharacterBody2D.new()
	player.set_script(_FARMER_SCRIPT)
	player.position = Vector2(960, 360)
	world_root.add_child(player)

func _call_deferred_start_first() -> void:
	call_deferred("_start_first_wave_internal")

func _start_first_wave_internal() -> void:
	var wm := _autoload("WaveManager")
	if wm != null:
		wm.call("clear")
		wm.call("start_from_first")

func _setup_wm_signals() -> void:
	var wm := _autoload("WaveManager")
	if wm == null:
		return
	if wm.has_signal("wave_started"):
		wm.connect("wave_started", Callable(self, "_on_wm_wave_started"))
	if wm.has_signal("wave_cleared"):
		wm.connect("wave_cleared", Callable(self, "_on_wm_wave_cleared"))
	if wm.has_signal("all_waves_cleared"):
		wm.connect("all_waves_cleared", Callable(self, "_on_wm_all_cleared"))
	if wm.has_signal("kda_stat_changed"):
		wm.connect("kda_stat_changed", Callable(self, "_on_wm_kda_changed"))
	if wm.has_signal("combo_changed"):
		wm.connect("combo_changed", Callable(self, "_on_wm_combo_changed"))
	if wm.has_signal("block_succeeded"):
		wm.connect("block_succeeded", Callable(self, "_on_wm_block_ok"))
	var ge := _autoload("GameEvents")
	if ge != null:
		if ge.has_signal("wave_started") and wm.has_signal("wave_started"):
			wm.connect("wave_started", Callable(self, "_relay_ge_wave_started"))
		if ge.has_signal("wave_cleared") and wm.has_signal("wave_cleared"):
			wm.connect("wave_cleared", Callable(self, "_relay_ge_wave_cleared"))
		if ge.has_signal("all_waves_cleared") and wm.has_signal("all_waves_cleared"):
			wm.connect("all_waves_cleared", Callable(self, "_relay_ge_all_cleared"))
		if ge.has_signal("kda_stat_changed") and wm.has_signal("kda_stat_changed"):
			wm.connect("kda_stat_changed", Callable(self, "_relay_ge_kda"))
		if ge.has_signal("combo_changed") and wm.has_signal("combo_changed"):
			wm.connect("combo_changed", Callable(self, "_relay_ge_combo"))
		if ge.has_signal("block_succeeded") and wm.has_signal("block_succeeded"):
			wm.connect("block_succeeded", Callable(self, "_relay_ge_block"))

func _relay_ge_wave_started(wi: int, tw: int, ec: int) -> void:
	var ge := _autoload("GameEvents")
	if ge != null and ge.has_signal("wave_started"):
		ge.emit_signal("wave_started", wi, tw, ec)

func _relay_ge_wave_cleared(wi: int, kw: int, tk: int) -> void:
	var ge := _autoload("GameEvents")
	if ge != null and ge.has_signal("wave_cleared"):
		ge.emit_signal("wave_cleared", wi, kw, tk)

func _relay_ge_all_cleared(tk: int, ts: float) -> void:
	var ge := _autoload("GameEvents")
	if ge != null and ge.has_signal("all_waves_cleared"):
		ge.emit_signal("all_waves_cleared", tk, ts)

func _relay_ge_kda(n: String, v: int) -> void:
	var ge := _autoload("GameEvents")
	if ge != null and ge.has_signal("kda_stat_changed"):
		ge.emit_signal("kda_stat_changed", n, v)

func _relay_ge_combo(c: int, m: int) -> void:
	var ge := _autoload("GameEvents")
	if ge != null and ge.has_signal("combo_changed"):
		ge.emit_signal("combo_changed", c, m)

func _relay_ge_block(a: int) -> void:
	var ge := _autoload("GameEvents")
	if ge != null and ge.has_signal("block_succeeded"):
		ge.emit_signal("block_succeeded", a)

func _setup_kda_listeners() -> void:
	var ge := _autoload("GameEvents")
	if ge == null:
		return
	if ge.has_signal("damage_calculated"):
		ge.connect("damage_calculated", Callable(self, "_on_ge_damage_calculated"))
	if ge.has_signal("character_stats_changed"):
		ge.connect("character_stats_changed", Callable(self, "_on_ge_char_stats"))
	if ge.has_signal("shield_broken"):
		ge.connect("shield_broken", Callable(self, "_on_ge_shield_broken"))

func _on_ge_damage_calculated(attacker: Node, victim: Node, details: Dictionary) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	var wm := _autoload("WaveManager")
	if wm == null:
		return
	var is_player_hit: bool = _is_player_character(victim)
	var is_player_atk: bool = _is_player_character(attacker)
	var real_dmg: int = int(details.get("final_damage", details.get("result", 0)))
	if is_player_atk and real_dmg >= 0:
		var victim_killed: bool = false
		if victim != null and is_instance_valid(victim):
			var hp_now: Variant = victim.get("hp") if victim.has("hp") else 9999
			if hp_now != null:
				victim_killed = int(hp_now) <= 0
		wm.call("notify_dealt_damage", max(0, real_dmg), victim_killed)
	if is_player_hit:
		var blocking: bool = false
		if victim != null and is_instance_valid(victim):
			if victim.has("state"):
				var s: Variant = victim.get("state")
				if s != null:
					blocking = int(s) == 9
		if blocking and real_dmg >= 0:
			wm.call("notify_block_success", max(0, real_dmg))
			_flyer_block(victim as Node2D, real_dmg)
		else:
			if real_dmg > 0:
				wm.call("notify_player_hit")
				var hp_now: int = 0
				if victim != null and is_instance_valid(victim) and victim.has("hp"):
					var v: Variant = victim.get("hp")
					hp_now = int(v) if v != null else 1
				if hp_now <= 0:
					wm.call("notify_player_death")
					_flyer_death(victim as Node2D)
					call_deferred("_revive_player_after_sec")

func _on_ge_shield_broken(who: Node, _by: Node) -> void:
	if not _is_player_character(who):
		return
	var wm := _autoload("WaveManager")
	if wm != null:
		wm.call("notify_block_success", 1)

func _on_ge_char_stats(who: Node, key: String, _v) -> void:
	pass

func _revive_player_after_sec() -> void:
	var t := get_tree().create_timer(2.2, false)
	t.timeout.connect(func():
		if player == null or not is_instance_valid(player):
			return
		player.set("hp", int(player.get("max_hp")))
		player.set("state", 0)  # IDLE
		queue_redraw())

func _flyer_block(nd: Node2D, absorbed: int) -> void:
	if nd == null or flyers_layer == null:
		return
	var pos := nd.global_position + Vector2(-30, -50)
	var txt := "🛡 +1 BLOCK  吸 %d" % absorbed
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(0.35, 1.0, 0.48, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 7)
	l.position = pos
	flyers_layer.add_child(l)
	var tw := get_tree().create_tween().bind_node(l)
	tw.tween_property(l, "position:y", pos.y - 60.0, 0.85).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.85)
	tw.tween_callback(l.queue_free)

func _flyer_death(nd: Node2D) -> void:
	if nd == null or flyers_layer == null:
		return
	var pos := nd.global_position + Vector2(-40, -70)
	var l := Label.new()
	l.text = "💀 +1 DEATH"
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(1.0, 0.28, 0.28, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 8)
	l.position = pos
	flyers_layer.add_child(l)
	var tw2 := get_tree().create_tween().bind_node(l)
	tw2.tween_property(l, "position:y", pos.y - 90.0, 1.1).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(l, "modulate:a", 0.0, 1.1)
	tw2.tween_callback(l.queue_free)

func _on_wm_block_ok(absorbed: int) -> void:
	pass  # 已在 _flyer_block 中显示

func _is_player_character(who: Node) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	if who == player:
		return true
	if not (who is CharacterBody2D):
		return false
	var groups := who.get_groups()
	if groups.has("player") or groups.has("party"):
		return true
	# fallback: FarmerPlayer / Axeman / Mace / Spear 脚本名里含 Player/Companion
	var nm: String = ""
	if who.get_script() != null:
		nm = String(who.get_script().resource_path)
	return nm.find("Player") >= 0 or nm.find("Companion") >= 0

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

func _on_wm_kda_changed(_name: String, _v: int) -> void:
	_refresh_kda_hud_texts()

func _on_wm_combo_changed(cur: int, mx: int) -> void:
	_refresh_combo_hud(cur, mx)
	if cur >= 3 and cur % 3 == 0:
		_mini_combo_flyer(cur)

func _refresh_kda_hud_texts() -> void:
	var wm := _autoload("WaveManager")
	if wm == null:
		return
	var k: int = int(wm.get("total_kills"))
	var d: int = int(wm.get("stat_player_deaths"))
	var hit: int = int(wm.get("stat_player_hits"))
	var b: int = int(wm.get("stat_blocks"))
	lbl_kill.text = "🗡  KILL  击杀 K：  %d" % k
	lbl_death.text = "💀  DEATH 死亡 D：  %d   HIT受击：  %d" % [d, hit]
	lbl_block.text = "🛡  BLOCK 格挡 A：  %d" % b

func _refresh_combo_hud(cur: int, mx: int) -> void:
	combo_lbl_c.text = "Combo x %d" % cur
	combo_lbl_max.text = "Max Combo： %d" % mx
	# 颜色 5 红 10 金 20 紫
	var panel: PanelContainer = combo_root.get_node_or_null("ComboPanel") as PanelContainer
	if cur >= 20:
		combo_lbl_c.add_theme_color_override("font_color", Color(0.85, 0.32, 1.0, 1))
		if panel:
			var ps := StyleBoxFlat.new()
			ps.bg_color = Color(0.08, 0.0, 0.14, 0.85)
			ps.border_color = Color(0.85, 0.3, 1.0, 1)
			ps.border_width_left = 4
			ps.border_width_top = 4
			ps.border_width_right = 4
			ps.border_width_bottom = 4
			ps.corner_radius_top_left = 10
			ps.corner_radius_top_right = 10
			ps.corner_radius_bottom_right = 10
			ps.corner_radius_bottom_left = 10
			panel.add_theme_stylebox_override("panel", ps)
	elif cur >= 10:
		combo_lbl_c.add_theme_color_override("font_color", Color(1.0, 0.86, 0.15, 1))
		if panel:
			var ps := StyleBoxFlat.new()
			ps.bg_color = Color(0.12, 0.08, 0.0, 0.85)
			ps.border_color = Color(1, 0.85, 0.15, 1)
			ps.border_width_left = 4
			ps.border_width_top = 4
			ps.border_width_right = 4
			ps.border_width_bottom = 4
			ps.corner_radius_top_left = 10
			ps.corner_radius_top_right = 10
			ps.corner_radius_bottom_right = 10
			ps.corner_radius_bottom_left = 10
			panel.add_theme_stylebox_override("panel", ps)
	elif cur >= 5:
		combo_lbl_c.add_theme_color_override("font_color", Color(1.0, 0.32, 0.3, 1))
		if panel:
			var ps := StyleBoxFlat.new()
			ps.bg_color = Color(0.12, 0.0, 0.02, 0.8)
			ps.border_color = Color(1, 0.3, 0.3, 1)
			ps.border_width_left = 3
			ps.border_width_top = 3
			ps.border_width_right = 3
			ps.border_width_bottom = 3
			ps.corner_radius_top_left = 10
			ps.corner_radius_top_right = 10
			ps.corner_radius_bottom_right = 10
			ps.corner_radius_bottom_left = 10
			panel.add_theme_stylebox_override("panel", ps)
	else:
		combo_lbl_c.add_theme_color_override("font_color", Color(0.88, 0.88, 0.9, 1))
		if panel:
			var ps := StyleBoxFlat.new()
			ps.bg_color = Color(0, 0, 0, 0.72)
			ps.border_color = Color(1, 1, 1, 0.0)
			ps.border_width_left = 3
			ps.border_width_top = 3
			ps.border_width_right = 3
			ps.border_width_bottom = 3
			ps.corner_radius_top_left = 10
			ps.corner_radius_top_right = 10
			ps.corner_radius_bottom_right = 10
			ps.corner_radius_bottom_left = 10
			panel.add_theme_stylebox_override("panel", ps)

func _mini_combo_flyer(cur: int) -> void:
	if flyers_layer == null or player == null:
		return
	var pos := player.global_position + Vector2(-28, -80)
	var l := Label.new()
	l.text = "COMBO x %d !" % cur
	l.add_theme_font_size_override("font_size", 26)
	if cur >= 20:
		l.add_theme_color_override("font_color", Color(0.9, 0.3, 1.0, 1))
	elif cur >= 10:
		l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
	else:
		l.add_theme_color_override("font_color", Color(1.0, 0.3, 0.32, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 8)
	l.position = pos
	flyers_layer.add_child(l)
	var tw3 := get_tree().create_tween().bind_node(l)
	tw3.tween_property(l, "position:y", pos.y - 70.0, 0.85)
	tw3.parallel().tween_property(l, "modulate:a", 0.0, 0.85)
	tw3.tween_callback(l.queue_free)

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
		if e.has_signal("died"):
			if not e.is_connected("died", Callable(self, "_on_enemy_died").bind(e)):
				e.connect("died", Callable(self, "_on_enemy_died").bind(e))

func _on_enemy_died(killer: Node, the_enemy: Node2D) -> void:
	if enemies_alive.has(the_enemy):
		enemies_alive.erase(the_enemy)
	var wm := _autoload("WaveManager")
	if wm != null:
		wm.call("notify_enemy_killed")

func _setup_hp_flyers_bus() -> void:
	var ge := _autoload("GameEvents")
	if ge == null:
		return
	if ge.has_signal("enemy_damaged"):
		ge.connect("enemy_damaged", Callable(self, "_on_enemy_damaged_show_flyer"))

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

func _wave_hud_refresh() -> void:
	var wm := _autoload("WaveManager")
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
	var wm := _autoload("WaveManager")
	var kd: int = int(wm.get("total_kills")) if wm else 0
	var dd: int = int(wm.get("stat_player_deaths")) if wm else 0
	var bk: int = int(wm.get("stat_blocks")) if wm else 0
	var mc: int = int(wm.get("stat_max_combo")) if wm else 0
	var dmg: int = int(wm.call("final_damage_dealt")) if wm and wm.has_method("final_damage_dealt") else 0
	var ht: int = int(wm.get("stat_player_hits")) if wm else 0
	var rating: String = wm.call("compute_rating") if wm and wm.has_method("compute_rating") else "C"
	if kda_detail_lbl:
		kda_detail_lbl.text = ("🗡  击杀 K:  %3d        |   💥  伤害输出:  %d\n" +
			"💀  死亡 D:  %3d        |   ⚔  MAX 连击:  %d\n" +
			"🛡  格挡 A:  %3d        |   🩸  受击次数:  %d\n" +
			"\n评分公式 = K×3 + A×2 + ComboMax×1.5 − D×6 + (60s内+10分)") % [kd, dmg, dd, mc, bk, ht]
	rating_big.text = rating
	if rating == "S":
		rating_big.add_theme_color_override("font_color", Color(1.0, 0.12, 0.12, 1))
		rating_big.add_theme_color_override("font_outline_color", Color(1, 0.9, 0.1, 1))
	elif rating == "A":
		rating_big.add_theme_color_override("font_color", Color(0.95, 0.6, 0.1, 1))
		rating_big.add_theme_color_override("font_outline_color", Color(1, 0.95, 0.5, 1))
	elif rating == "B":
		rating_big.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0, 1))
		rating_big.add_theme_color_override("font_outline_color", Color(0.8, 0.9, 1.0, 1))
	elif rating == "C":
		rating_big.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55, 1))
	else:
		rating_big.add_theme_color_override("font_color", Color(0.4, 0.3, 0.3, 1))

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

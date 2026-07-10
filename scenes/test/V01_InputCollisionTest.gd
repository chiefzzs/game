extends Node2D
## V0.1 F4 scene: Input + Collision + Dash + Block + Pickups + Ally + Enemies
## Controls
##   A/D or stick-L -> move
##   Space or pad-A -> jump
##   K or pad-Y -> dash (has cooldown)
##   Left Shift or pad-LT -> block (draws shield in front of player)
##   E or pad-B -> interact / pick up nearby items
@onready var lbl: Label = $UI/VBox/HudLog
@onready var player: CharacterBody2D = $World/Player
@onready var drawer: Node2D = $World/Player/Drawer
@onready var shield: Node2D = $World/Player/Shield
@onready var block_aura: Node2D = $World/Player/BlockAura
@onready var weapon_holder: Node2D = $World/Player/WeaponHolder
@onready var rake_sprite: Node2D = $World/Player/WeaponHolder/RakeSprite
@onready var wood_sword_sprite: Node2D = $World/Player/WeaponHolder/WoodSwordSprite
@onready var attack_hitbox: Area2D = $World/Player/AttackHitbox
@onready var inv_gold: Label = $UI/Inv/GoldVal
@onready var inv_pot: Label = $UI/Inv/PotVal
@onready var hp_bar: ProgressBar = $UI/HealthBars/HpRow/HpBar
@onready var hp_txt: Label = $UI/HealthBars/HpRow/HpText
@onready var st_bar: ProgressBar = $UI/HealthBars/StRow/StBar
@onready var st_txt: Label = $UI/HealthBars/StRow/StText
@onready var world_root: Node2D = $World

var sky_root: Node2D
var hill_root: Node2D
var cloud_root: Node2D
var decor_root: Node2D
var floor_dyn_root: Node2D
var main_camera: Camera2D

var _floor_right_x: float = 0.0
var _floor_left_x: float = 0.0
const _FLOOR_CHUNK: float = 3000.0
const _FLOOR_TOP_Y: float = 880.0
const _FLOOR_H: float = 120.0
const _GRASS_STEP: float = 240.0

var _sky_right_x: float = 0.0
var _sky_left_x: float = 0.0
const _SKY_CHUNK: float = 2400.0

const _HOUSE_MIN_SPACING: float = 520.0
const _HOUSE_MAX_SPACING: float = 980.0
const _FARM_MIN_SPACING: float = 420.0
const _FARM_MAX_SPACING: float = 760.0
const _FENCE_MIN_SPACING: float = 260.0
const _FENCE_MAX_SPACING: float = 460.0
const _CLOUD_MIN_SPACING: float = 500.0
const _CLOUD_MAX_SPACING: float = 900.0
const _VILLAGE_SKY_MIN_SPACING: float = 800.0
const _VILLAGE_SKY_MAX_SPACING: float = 1400.0

var lines: Array[String] = ["🏘️ Move:A/D 向右→无限村庄! | Jump:Space | Dash:K/Y | Block:Shift/LT | Attack:X/J(默认木剑) | 武器1耙2木剑 | Pickup:auto | Esc back"]
var velocity: Vector2 = Vector2.ZERO
var _tick: int = 0

var _dash_cd: float = 0.0
var _dash_speed: float = 650.0
var _dash_dur: float = 0.16
var _dash_timer: float = 0.0
var _dash_dir: float = 0.0
var _is_blocking: bool = false
var _inventory_gold: int = 0
var _inventory_pot: int = 0
var _has_weapon: bool = true
var _current_weapon: String = "wood_sword"
var _last_facing: float = 1.0
var _nearby_pickups: Array[Node] = []
var _attack_cd: float = 0.0
const WEAPON_RAKE_COOLDOWN: float = 0.32
const WEAPON_WOOD_SWORD_COOLDOWN: float = 0.18
var _attack_tween: Tween = null
const WEAPON_RAKE_STAMINA_COST: int = 2
const WEAPON_WOOD_SWORD_STAMINA_COST: int = 2
const WEAPON_BASE_ROT: float = -0.95
const WEAPON_HOLD_X_RIGHT: float = 14.0
const WEAPON_RAKE_DAMAGE_MIN: int = 13
const WEAPON_RAKE_DAMAGE_MAX: int = 16
const WEAPON_WOOD_SWORD_DAMAGE_MIN: int = 5
const WEAPON_WOOD_SWORD_DAMAGE_MAX: int = 8
const WEAPON_RAKE_HITBOX_DUR: float = 0.18
const WEAPON_WOOD_SWORD_HITBOX_DUR: float = 0.11

var _hp_max: int = 100
var _hp: int = 100
var _stamina_max: int = 100
var _stamina: int = 100
var _stamina_f_acc: float = 100.0
var _stamina_recovery_rate: float = 14.0
var _stamina_recovery_cd: float = 0.0
const STAMINA_RECOVERY_COOLDOWN: float = 0.8
const DASH_STAMINA_COST: int = 18
const BLOCK_STAMINA_TICK: float = 11.0
var _aura_pulse_t: float = 0.0

var _jump_buffer_timer: float = 0.0
const JUMP_BUFFER_WINDOW: float = 0.12
var _coyote_timer: float = 0.0
const COYOTE_WINDOW: float = 0.10
var _is_jumping: bool = false
const JUMP_CUT_MULTIPLIER: float = 0.45

func _ready() -> void:
	if not player.is_in_group("player"):
		player.add_to_group("player")
	InputBus.JumpPressed.connect(_on_jump)
	InputBus.AttackPressed.connect(_on_attack)
	InputBus.DashPressed.connect(_on_dash)
	InputBus.BlockPressed.connect(_on_block_p)
	InputBus.BlockReleased.connect(_on_block_r)
	InputBus.InteractPressed.connect(_on_interact)
	InputBus.WeaponChanged.connect(_on_weapon_changed)
	for child in $World.get_children():
		if child is Area2D:
			var area: Area2D = child
			area.body_entered.connect(func(b: Node): _on_area2d_body_entered(area, b))
			area.body_exited.connect(func(b: Node): _on_area2d_body_exited(area, b))
		if child is CharacterBody2D and child != player and child.has_method("take_damage"):
			if child.has_signal("died"):
				if child.is_in_group("enemies_v02"):
					child.died.connect(func (): _on_enemy_died(child))
				elif child.is_in_group("allies_v02"):
					child.died.connect(func (): _on_ally_died(child))
	if attack_hitbox:
		attack_hitbox.monitoring = false
		attack_hitbox.monitorable = false
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	hud("[OK] Scene ready. onFloor=%s" % player.is_on_floor())
	hud("[INFO] Gold=0 Potion=0 Nearby=0 DashCD=0.0")
	# 初始化最近朝向：从场景里 drawer 的初始 scale.x 读取（支持场景默认朝左）
	if drawer:
		_last_facing = 1.0 if drawer.scale.x >= 0.0 else -1.0
	else:
		_last_facing = 1.0
	_refresh_inventory()
	_refresh_bars()
	_setup_infinite_world()
	if wood_sword_sprite:
		wood_sword_sprite.visible = true
	if rake_sprite:
		rake_sprite.visible = false
	if weapon_holder:
		weapon_holder.visible = true
	hud("🏘️ 村庄式无限环境已加载！向右走→动态生成房屋/谷仓/水井/篱笆/农田/村庄远景")
	hud("🗡️ 初始武器：木剑！伤害5-8 / 攻速0.18s / 体力-2   按1切换耙子 / 按2切回木剑（所有武器挥击体力统一-2）")
	var _ally_world: Node = $World
	if _ally_world:
		var _ax: float = player.global_position.x
		var _ay: float = player.global_position.y
		var _hc: CharacterBody2D = CharacterBody2D.new()
		_hc.name = "HunterAlly"
		_hc.set_script(load("res://scenes/test/HunterNPC.gd"))
		_hc.collision_layer = 8
		_hc.collision_mask = 4
		var _hcs: CollisionShape2D = CollisionShape2D.new()
		var _hrs: RectangleShape2D = RectangleShape2D.new()
		_hrs.size = Vector2(28, 48)
		_hcs.shape = _hrs
		_hc.add_child(_hcs)
		var _hdraw: Node2D = Node2D.new()
		_hdraw.name = "Drawer"
		_hdraw.set_script(load("res://scenes/test/DrawHunter.gd"))
		_hc.add_child(_hdraw)
		_hc.global_position = Vector2(_ax + 120.0, _ay)
		if _hc.has_signal("died"):
			_hc.died.connect(func (): _on_ally_died(_hc))
		_ally_world.add_child(_hc)
		var _pc: CharacterBody2D = CharacterBody2D.new()
		_pc.name = "PriestAlly"
		_pc.set_script(load("res://scenes/test/PriestNPC.gd"))
		_pc.collision_layer = 8
		_pc.collision_mask = 4
		var _pcs: CollisionShape2D = CollisionShape2D.new()
		var _prs: RectangleShape2D = RectangleShape2D.new()
		_prs.size = Vector2(28, 48)
		_pcs.shape = _prs
		_pc.add_child(_pcs)
		var _pdraw: Node2D = Node2D.new()
		_pdraw.name = "Drawer"
		_pdraw.set_script(load("res://scenes/test/DrawPriest.gd"))
		_pc.add_child(_pdraw)
		_pc.global_position = Vector2(_ax - 120.0, _ay)
		if _pc.has_signal("died"):
			_pc.died.connect(func (): _on_ally_died(_pc))
		_ally_world.add_child(_pc)
		hud("🤝 队友已加入！🪓樵夫(绿近战) + 🏹猎人(蓝远程右120px) + ⛪牧师(金群疗左120px) —— 牧师2秒/次10格内回10%HP")
	_flush()

func hud(msg: String) -> void:
	lines.append(msg)
	while lines.size() > 11:
		lines.pop_front()
	_flush()

func set_hp(value: int) -> void:
	var old: int = _hp
	_hp = clamp(value, 0, _hp_max)
	if _hp != old:
		_refresh_bars()
		if _hp <= 0:
			call_deferred("_reload_scene")

func heal_hp_on_kill(amount: int) -> void:
	if amount <= 0:
		return
	var before: int = _hp
	set_hp(_hp + amount)
	var healed: int = _hp - before
	if healed > 0:
		hud("🩸 击杀敌人！回复 +%d HP（当前 %d/%d）" % [healed, _hp, _hp_max])

func _reload_scene() -> void:
	get_tree().reload_current_scene()

func damage(amount: int) -> void:
	if amount <= 0:
		return
	var old: int = _hp
	set_hp(_hp - amount)
	hud("[DAMAGE] -%d HP  (%d -> %d)" % [amount, old, _hp])

func heal(amount: int) -> void:
	if amount <= 0:
		return
	var old: int = _hp
	set_hp(_hp + amount)
	if _hp > old:
		hud("[HEAL] +%d HP  (%d -> %d)" % [_hp - old, old, _hp])

func set_stamina(value: int) -> void:
	var old: int = _stamina
	_stamina = clamp(value, 0, _stamina_max)
	_stamina_f_acc = float(_stamina)
	if _stamina != old:
		_refresh_bars()

func spend_stamina(amount: int) -> bool:
	if amount <= 0:
		return true
	if _stamina < amount:
		return false
	_stamina -= amount
	_stamina_f_acc = float(_stamina)
	_stamina_recovery_cd = STAMINA_RECOVERY_COOLDOWN
	_refresh_bars()
	return true

func recover_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	var old: int = _stamina
	_stamina_f_acc = clamp(_stamina_f_acc + amount, 0.0, float(_stamina_max))
	var next: int = int(_stamina_f_acc)
	_stamina = clamp(next, 0, _stamina_max)
	if _stamina != old:
		_refresh_bars()

func _refresh_bars() -> void:
	if hp_bar:
		hp_bar.max_value = float(_hp_max)
		hp_bar.value = float(_hp)
	if hp_txt:
		hp_txt.text = "%d/%d" % [_hp, _hp_max]
	if st_bar:
		st_bar.max_value = float(_stamina_max)
		st_bar.value = float(_stamina)
	if st_txt:
		st_txt.text = "%d/%d" % [_stamina, _stamina_max]

func _flush() -> void:
	if not lbl:
		return
	var blocking_txt := "[BLOCK] " if _is_blocking else "         "
	var dash_txt := "DASH!" if _dash_timer > 0.0 else ("cd%.1f" % _dash_cd) if _dash_cd > 0.0 else "dashOK"
	lines[0] = "%s  %s  ax=%.2f bl=%.2f onF=%s tick=%d" % [blocking_txt, dash_txt, InputBus.moveAxis, InputBus.blockStrength, player.is_on_floor(), _tick]
	lbl.text = "\n".join(lines)

func _refresh_inventory() -> void:
	if inv_gold:
		inv_gold.text = str(_inventory_gold)
	if inv_pot:
		inv_pot.text = str(_inventory_pot)

func _on_jump() -> void:
	_jump_buffer_timer = JUMP_BUFFER_WINDOW
	hud("[OK] JumpPressed (buffered %.0fms)" % [JUMP_BUFFER_WINDOW * 1000.0])

func _on_dash() -> void:
	if _dash_cd > 0.0 or _dash_timer > 0.0:
		hud("[DASH] skipped (on cd %.1fs)" % _dash_cd)
		return
	if not spend_stamina(DASH_STAMINA_COST):
		hud("[DASH] skipped (need %d SP, have %d)" % [DASH_STAMINA_COST, _stamina])
		return
	var dir: float = InputBus.moveAxis
	if abs(dir) < 0.05:
		dir = -1.0 if drawer and drawer.scale.x < 0.0 else 1.0
	_dash_dir = dir
	_dash_timer = _dash_dur
	_dash_cd = 0.65
	hud("[DASH] fire dir=%.1f  (-%d SP, remain=%d)" % [_dash_dir, DASH_STAMINA_COST, _stamina])

func _on_block_p() -> void:
	if _stamina <= 0:
		hud("[BLOCK] skipped (no stamina)")
		return
	_is_blocking = true
	if shield:
		shield.visible = true
		shield.position.x = 18.0 if _last_facing > 0.0 else -18.0
	if block_aura:
		block_aura.visible = true
	_update_aura_color()
	hud("[OK] BlockPressed (shield + yellow aura ON, facing %s)" % ["→R" if _last_facing>0 else "←L"])

func _on_block_r() -> void:
	_is_blocking = false
	if shield:
		shield.visible = false
	if block_aura:
		block_aura.visible = false
	hud("[OK] BlockReleased (shield + aura OFF)")

func _on_weapon_changed(slot: int) -> void:
	if slot == 1:
		_current_weapon = "rake"
		if rake_sprite:
			rake_sprite.visible = true
		if wood_sword_sprite:
			wood_sword_sprite.visible = false
		_refresh_inventory()
		hud("[WEAPON] 切换：耙子（Rake）  伤害13-16 攻速0.32s 体力-2")
	elif slot == 2:
		_current_weapon = "wood_sword"
		if rake_sprite:
			rake_sprite.visible = false
		if wood_sword_sprite:
			wood_sword_sprite.visible = true
		_refresh_inventory()
		hud("[WEAPON] 切换：木剑（Wood Sword）  伤害5-8 攻速0.18s 体力-2")
	elif slot == 3:
		hud("[WEAPON] 槽位3：未装备武器")

func _get_weapon_cd() -> float:
	if _current_weapon == "wood_sword":
		return WEAPON_WOOD_SWORD_COOLDOWN
	return WEAPON_RAKE_COOLDOWN

func _get_weapon_stamina_cost() -> int:
	if _current_weapon == "wood_sword":
		return WEAPON_WOOD_SWORD_STAMINA_COST
	return WEAPON_RAKE_STAMINA_COST

func _get_weapon_damage() -> int:
	var r := randf()
	if _current_weapon == "wood_sword":
		return WEAPON_WOOD_SWORD_DAMAGE_MIN + int(r * float(WEAPON_WOOD_SWORD_DAMAGE_MAX - WEAPON_WOOD_SWORD_DAMAGE_MIN + 1))
	return WEAPON_RAKE_DAMAGE_MIN + int(r * float(WEAPON_RAKE_DAMAGE_MAX - WEAPON_RAKE_DAMAGE_MIN + 1))

func _get_weapon_hitbox_dur() -> float:
	if _current_weapon == "wood_sword":
		return WEAPON_WOOD_SWORD_HITBOX_DUR
	return WEAPON_RAKE_HITBOX_DUR

func _get_weapon_name_cn() -> String:
	if _current_weapon == "wood_sword":
		return "木剑"
	return "耙子"

func _get_weapon_swing_dur() -> Array:
	if _current_weapon == "wood_sword":
		return [0.06, 0.12, 0.05]
	return [0.11, 0.20, 0.08]

func _on_attack() -> void:
	if not _has_weapon:
		hud("[ATTACK]  skipped（无武器，先捡起耙子）")
		return
	if _attack_cd > 0.0:
		return
	var sp_cost: int = _get_weapon_stamina_cost()
	if _stamina < sp_cost:
		hud("[ATTACK] skipped（需%d体力，当前%d）" % [sp_cost, _stamina])
		return
	spend_stamina(sp_cost)
	_attack_cd = _get_weapon_cd()
	_stamina_recovery_cd = STAMINA_RECOVERY_COOLDOWN
	var fw: float = _last_facing
	if fw == 0.0:
		fw = 1.0
		_last_facing = 1.0
	var wname: String = _get_weapon_name_cn()
	var cd_show: float = _get_weapon_cd()
	hud("[ATTACK] %s挥击 %s！  （-%d体力  CD=%.2fs）" % [wname, ("→右" if fw > 0.0 else "←左"), sp_cost, cd_show])
	var hitbox_dur: float = _get_weapon_hitbox_dur()
	var d1: float = 0.11
	var d2: float = 0.20
	var d3: float = 0.08
	var res: Array = _get_weapon_swing_dur()
	if res.size() >= 3:
		d1 = res[0]
		d2 = res[1]
		d3 = res[2]
	if weapon_holder:
		if _attack_tween and _attack_tween.is_valid():
			_attack_tween.kill()
		weapon_holder.scale.x = fw
		weapon_holder.position.x = WEAPON_HOLD_X_RIGHT * fw
		weapon_holder.position.y = 6.0
		var base_rot: float = WEAPON_BASE_ROT * fw
		weapon_holder.rotation = base_rot + 1.05
		_attack_tween = create_tween()
		_attack_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_attack_tween.tween_property(weapon_holder, "rotation", base_rot - 1.25, d1)
		_attack_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_attack_tween.tween_property(weapon_holder, "rotation", base_rot - 0.3, d2)
		_attack_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_attack_tween.tween_property(weapon_holder, "rotation", base_rot, d3)
	if attack_hitbox:
		var hb_x: float = 28.0 * fw
		var hb_y: float = -4.0
		attack_hitbox.position = Vector2(hb_x, hb_y)
		attack_hitbox.scale.x = 1.0
		attack_hitbox.monitoring = true
		attack_hitbox.monitorable = true
		await get_tree().create_timer(hitbox_dur).timeout
		if is_instance_valid(attack_hitbox):
			attack_hitbox.monitoring = false
			attack_hitbox.monitorable = false

## Enemy melee / ranged: damage HP directly; called from Scarecrow.gd when player in attack range.
## Blocking reduces damage to 1 (from full ATK) + shields stamina for SP drain handled separately.
func damage_player(amount: int) -> void:
	if amount <= 0:
		return
	if _is_blocking:
		var blocked := amount - 1
		hud("[HIT] Blocked! absorbed %d dmg, chip -1 HP" % blocked)
		set_hp(max(0, _hp - 1))
		return
	set_hp(max(0, _hp - amount))
	hud("[HIT] -%d HP! (remain %d/%d)" % [amount, _hp, _hp_max])

## When an enemy (e.g. Scarecrow) dies, drop 1 Gold pickup at its position.
func _on_enemy_died(enemy: CharacterBody2D) -> void:
	if not is_instance_valid(enemy):
		return
	var die_pos: Vector2 = enemy.global_position
	_inventory_gold += 1
	hud("[KILL] Scarecrow slain! +1 Gold (total %d)" % _inventory_gold)
	_refresh_inventory()
	var kill_type: String = ""
	if enemy.has_method("get"):
		var v = enemy.get("last_killer_type")
		if typeof(v) == TYPE_STRING:
			kill_type = v
	if kill_type == "player":
		heal_hp_on_kill(5)

func _on_ally_died(ally: CharacterBody2D) -> void:
	if not is_instance_valid(ally):
		return
	hud("[ALLY] 樵夫阵亡！击败敌人为他报仇！")

## Weapon attack hitbox — hit Layer2=Enemy bodies.  Each sweep damages each enemy once (first hit).
func _on_attack_hitbox_body_entered(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body == player:
		return
	if body.is_in_group("allies_v02"):
		return
	if not body.has_method("take_damage"):
		return
	if not body.is_in_group("hit_%d" % (Time.get_ticks_msec() / 50)):
		var dmg := _get_weapon_damage()
		var wname: String = _get_weapon_name_cn()
		body.call("take_damage", dmg, player.global_position, false, "player")
		hud("[HITBOX] %s命中！ -%d HP  (位置 %d,%d)" % [wname, dmg, int(body.global_position.x), int(body.global_position.y)])

func _update_aura_color() -> void:
	if not block_aura:
		return
	var pct: float = clamp(float(_stamina) / max(1.0, float(_stamina_max)), 0.0, 1.0)
	var r: float = 1.0
	var g: float = lerp(0.2, 0.95, pct)
	var b: float = lerp(0.0, 0.18, pct)
	var pulse: float = 0.82 + 0.18 * sin(_aura_pulse_t * 7.0)
	var col: Color = Color(r, g, b, 0.8 + 0.2 * pulse)
	block_aura.modulate = col

func _on_interact() -> void:
	hud("[PICKUP] auto-pickup enabled. Walk over items to collect them")

func _pickup_one(pickup: Node) -> void:
	if pickup == null or not is_instance_valid(pickup):
		return
	var kind: String = "?"
	if pickup.has_meta("pickup_kind"):
		kind = str(pickup.get_meta("pickup_kind"))
	match kind:
		"gold":
			_inventory_gold += 1
			hud("[AUTO-PICKUP] +1 Gold  (total %d)" % _inventory_gold)
		"potion":
			_inventory_pot += 1
			hud("[AUTO-PICKUP] +1 Potion (total %d)" % _inventory_pot)
		"weapon":
			if _has_weapon and _current_weapon == "rake":
				hud("[PICKUP] 已装备耙子（Rake），按1切换，按2切回木剑")
				return
			_has_weapon = true
			if weapon_holder:
				weapon_holder.visible = true
				var f: float = _last_facing
				if f == 0.0:
					f = 1.0
					_last_facing = 1.0
				weapon_holder.scale.x = f
				weapon_holder.position.x = WEAPON_HOLD_X_RIGHT * f
				weapon_holder.position.y = 6.0
				weapon_holder.rotation = WEAPON_BASE_ROT * f
			_current_weapon = "rake"
			if rake_sprite:
				rake_sprite.visible = true
			if wood_sword_sprite:
				wood_sword_sprite.visible = false
			_refresh_inventory()
			hud("[AUTO-PICKUP] + 农用耙子！按X/J攻击，按1=耙子 / 按2=木剑切换武器  (%s)" % ["→朝右" if _last_facing > 0.0 else "←朝左"])
		_:
			hud("[AUTO-PICKUP] unknown kind=%s" % kind)
	if pickup.has_method("queue_free"):
		pickup.queue_free()
	_refresh_inventory()

func _on_area2d_body_entered(area: Area2D, body: Node) -> void:
	if not (body is CharacterBody2D):
		return
	var role: String = str(area.get_meta("role") if area.has_meta("role") else "")
	match role:
		"pickup":
			if not _nearby_pickups.has(area):
				_nearby_pickups.append(area)
				var kind: String = str(area.get_meta("pickup_kind") if area.has_meta("pickup_kind") else "?")
				hud("[PICKUP] detect +%s  (near=%d). Will auto-pick" % [kind, _nearby_pickups.size()])

func _on_area2d_body_exited(area: Area2D, body: Node) -> void:
	if not (body is CharacterBody2D):
		return
	var role: String = str(area.get_meta("role") if area.has_meta("role") else "")
	match role:
		"pickup":
			_nearby_pickups.erase(area)
			hud("[PICKUP] item left area (near=%d)" % _nearby_pickups.size())

func _process(delta: float) -> void:
	if _hp <= 0:
		call_deferred("_reload_scene")
	queue_redraw()

func _physics_process(delta: float) -> void:
	_tick += 1
	var speed: float = float(Config.GetL2("player.moveSpeed", 260.0))
	var jf: float = float(Config.GetL2("player.jumpForce", -720.0))
	var gravity_scale: float = float(Config.GetL1("physics.gravity_scale_default", 1.3))
	var max_fall: float = float(Config.GetL1("physics.max_fall_speed", 1200.0))
	_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)
	if player.is_on_floor():
		_coyote_timer = COYOTE_WINDOW
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)
	velocity.x = move_toward(velocity.x, InputBus.moveAxis * speed, 1200.0 * delta)
	velocity.y += 980.0 * gravity_scale * delta
	velocity.y = min(velocity.y, max_fall)
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jf
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_is_jumping = true
	if _is_jumping and velocity.y < 0.0 and not InputBus.IsJumpHeld():
		velocity.y *= JUMP_CUT_MULTIPLIER
		_is_jumping = false
	# dash timer
	if _dash_timer > 0.0:
		_dash_timer = max(0.0, _dash_timer - delta)
		velocity.x = _dash_dir * _dash_speed
		if _dash_timer == 0.0:
			hud("[DASH] finished")
	if _dash_cd > 0.0:
		_dash_cd = max(0.0, _dash_cd - delta)
	player.velocity = velocity
	player.move_and_slide()
	velocity = player.velocity
	if velocity.y >= 0.0:
		_is_jumping = false
	while _nearby_pickups.size() > 0:
		var item: Node = _nearby_pickups.pop_front()
		_pickup_one(item)
	if abs(InputBus.moveAxis) > 0.01 and drawer:
		drawer.scale.x = -1.0 if InputBus.moveAxis < 0.0 else 1.0
		_last_facing = drawer.scale.x
		if shield:
			shield.position.x = 18.0 if drawer.scale.x > 0.0 else -18.0
	# WeaponHolder 朝向/位置 每帧维护（不再依赖 moveAxis>0，静止时也保持一致），
	# 但挥击动画期间（_attack_cd > 0）完全不修改 transform，保证挥击轴心和方向不变
	if weapon_holder and _attack_cd <= 0.0:
		var fw: float = 1.0 if drawer and drawer.scale.x >= 0.0 else _last_facing
		# 额外防御：若上一次 fw 没读到，用缓存的最近朝向
		if fw == 0.0:
			fw = _last_facing
		weapon_holder.scale.x = fw
		weapon_holder.position.x = WEAPON_HOLD_X_RIGHT * fw
		weapon_holder.position.y = 6.0
		weapon_holder.rotation = WEAPON_BASE_ROT * fw
	# 格挡中（即使无移动输入），盾的朝向也跟随最近朝向，避免盾停留在旧方向
	if shield and _is_blocking:
		shield.position.x = 18.0 if _last_facing > 0.0 else -18.0
	if _attack_cd > 0.0:
		_attack_cd = max(0.0, _attack_cd - delta)
	# block 持续消耗体力 + 体力耗尽自动解除格挡
	if _is_blocking:
		_aura_pulse_t += delta
		var cost: float = BLOCK_STAMINA_TICK * delta
		_stamina_f_acc = clamp(_stamina_f_acc - cost, 0.0, float(_stamina_max))
		var st_new: int = int(_stamina_f_acc)
		if st_new != _stamina:
			_stamina = st_new
			_refresh_bars()
		_update_aura_color()
		if _stamina_f_acc <= 0.0:
			_stamina = 0
			_stamina_f_acc = 0.0
			_is_blocking = false
			if shield:
				shield.visible = false
			if block_aura:
				block_aura.visible = false
			hud("[BLOCK] out of stamina -> released")
		_stamina_recovery_cd = STAMINA_RECOVERY_COOLDOWN
	else:
		if _stamina_recovery_cd > 0.0:
			_stamina_recovery_cd = max(0.0, _stamina_recovery_cd - delta)
		elif _stamina < _stamina_max:
			recover_stamina(_stamina_recovery_rate * delta)
	_ensure_floor_around(player.global_position.x)
	_ensure_sky_around(player.global_position.x)
	if main_camera != null:
		var target_pos: Vector2 = player.global_position + Vector2(200.0, -120.0)
		main_camera.global_position = main_camera.global_position.lerp(target_pos, 0.08)
	_flush()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
	if e is InputEventKey:
		match e.physical_keycode:
			KEY_F1:
				get_tree().change_scene_to_file("res://scenes/test/V01_ConfigTest.tscn")
			KEY_F2:
				get_tree().change_scene_to_file("res://scenes/test/V01_FlagsTest.tscn")
			KEY_F3:
				get_tree().change_scene_to_file("res://scenes/test/V01_SaveTest.tscn")
			KEY_F4:
				pass

func _setup_infinite_world() -> void:
	randomize()
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
	floor_dyn_root = Node2D.new()
	floor_dyn_root.name = "FloorDynRoot"
	floor_dyn_root.z_index = -10
	floor_dyn_root.z_as_relative = false
	add_child(floor_dyn_root)
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
	if world_root:
		world_root.z_index = 0
		world_root.z_as_relative = false
	if player:
		player.z_index = 50
		player.z_as_relative = false
		if drawer:
			drawer.z_index = 55
			drawer.z_as_relative = false
		if shield:
			shield.z_index = 58
			shield.z_as_relative = false
		if block_aura:
			block_aura.z_index = 59
			block_aura.z_as_relative = false
		if weapon_holder:
			weapon_holder.z_index = 57
			weapon_holder.z_as_relative = false
	if world_root:
		for c in world_root.get_children():
			if c is CharacterBody2D and c != player:
				if c.is_in_group("allies_v02"):
					c.z_index = 48
				else:
					c.z_index = 45
				c.z_as_relative = false
				var d := c.get_node_or_null("Drawer")
				if d:
					d.z_index = c.z_index + 1
					d.z_as_relative = false
			if c is Area2D:
				var pk = c.get_meta("pickup_kind", "")
				if pk != "":
					c.z_index = 40
					c.z_as_relative = false
					for cd in c.get_children():
						if cd is Node2D:
							cd.z_index = 41
							cd.z_as_relative = false
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

func _ensure_sky_around(x: float) -> void:
	var need_left: float = x - 2400.0
	var need_right: float = x + 2400.0
	while _sky_left_x > need_left:
		var new_left: float = _sky_left_x - _SKY_CHUNK
		_build_sky_chunk(new_left, _sky_left_x)
		_sky_left_x = new_left
	while _sky_right_x < need_right:
		var new_right: float = _sky_right_x + _SKY_CHUNK
		_build_sky_chunk(_sky_right_x, new_right)
		_sky_right_x = new_right

func _build_floor_chunk(x0: float, x1: float) -> void:
	if x1 <= x0:
		return
	var w: float = x1 - x0
	var cx: float = (x0 + x1) * 0.5
	var cy: float = _FLOOR_TOP_Y + _FLOOR_H * 0.5
	var st := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, _FLOOR_H)
	cs.shape = rs
	cs.position = Vector2(cx, cy)
	st.collision_layer = 4
	st.collision_mask = 0
	st.add_child(cs)
	floor_dyn_root.add_child(st)
	var floor_bg := ColorRect.new()
	floor_bg.position = Vector2(x0, _FLOOR_TOP_Y)
	floor_bg.size = Vector2(w, _FLOOR_H)
	floor_bg.color = Color(0.24, 0.35, 0.2)
	floor_dyn_root.add_child(floor_bg)
	var grass_strip := ColorRect.new()
	grass_strip.position = Vector2(x0, _FLOOR_TOP_Y - 10.0)
	grass_strip.size = Vector2(w, 12.0)
	grass_strip.color = Color(0.34, 0.6, 0.32)
	floor_dyn_root.add_child(grass_strip)
	var path_w: float = 90.0
	var path_y: float = _FLOOR_TOP_Y + 6.0
	var village_path := ColorRect.new()
	village_path.position = Vector2(x0, path_y)
	village_path.size = Vector2(w, path_w)
	village_path.color = Color(0.62, 0.48, 0.3)
	floor_dyn_root.add_child(village_path)
	var edge_w: float = 14.0
	var path_edge_left := ColorRect.new()
	path_edge_left.position = Vector2(x0, path_y - 2.0)
	path_edge_left.size = Vector2(w, 4.0)
	path_edge_left.color = Color(0.52, 0.4, 0.24)
	floor_dyn_root.add_child(path_edge_left)
	var path_edge_right := ColorRect.new()
	path_edge_right.position = Vector2(x0, path_y + path_w - 2.0)
	path_edge_right.size = Vector2(w, 4.0)
	path_edge_right.color = Color(0.52, 0.4, 0.24)
	floor_dyn_root.add_child(path_edge_right)
	var pebble_count: int = int(max(2.0, w / 200.0))
	for i in range(pebble_count):
		var px: float = x0 + randf() * w
		var py: float = path_y + randf_range(6.0, path_w - 10.0)
		var pebble := ColorRect.new()
		var ps: float = randf_range(3.0, 6.0)
		pebble.position = Vector2(px, py)
		pebble.size = Vector2(ps, ps)
		pebble.color = Color(0.48, 0.36, 0.22)
		floor_dyn_root.add_child(pebble)
	_build_decor_for_chunk(x0, x1)

func _build_decor_for_chunk(x0: float, x1: float) -> void:
	_spawn_houses(x0, x1)
	_spawn_farms(x0, x1)
	_spawn_fences(x0, x1)
	_spawn_clouds(x0, x1)
	_spawn_village_sky(x0, x1)

func _spawn_houses(x0: float, x1: float) -> void:
	var x: float = x0 + randf_range(120.0, 260.0)
	while x < x1 - 180.0:
		var kind: int = randi() % 4
		match kind:
			0:
				_build_house_cottage(x)
			1:
				_build_house_tall(x)
			2:
				_build_barn(x)
			_:
				_build_well(x)
		x += randf_range(_HOUSE_MIN_SPACING, _HOUSE_MAX_SPACING)

func _build_house_cottage(x: float) -> void:
	var n := Node2D.new()
	n.position = Vector2(x, _FLOOR_TOP_Y - 12.0)
	decor_root.add_child(n)
	var wall_w: float = randf_range(110.0, 150.0)
	var wall_h: float = randf_range(72.0, 100.0)
	var wall_colors := [Color(0.92, 0.82, 0.66), Color(0.86, 0.78, 0.6), Color(0.94, 0.88, 0.76)]
	var wall := ColorRect.new()
	wall.position = Vector2(-wall_w * 0.5, -wall_h)
	wall.size = Vector2(wall_w, wall_h)
	wall.color = wall_colors[randi() % wall_colors.size()]
	n.add_child(wall)
	var roof_overhang: float = 16.0
	var roof_h: float = randf_range(44.0, 60.0)
	var roof_colors := [Color(0.8, 0.28, 0.22), Color(0.4, 0.32, 0.28), Color(0.5, 0.4, 0.32)]
	var roof := ColorRect.new()
	roof.position = Vector2(-wall_w * 0.5 - roof_overhang * 0.5, -wall_h - roof_h * 0.75)
	roof.size = Vector2(wall_w + roof_overhang, roof_h)
	roof.rotation = deg_to_rad(-8.0)
	roof.color = roof_colors[randi() % roof_colors.size()]
	n.add_child(roof)
	var door_w: float = 20.0 + randf() * 6.0
	var door_h: float = 36.0 + randf() * 8.0
	var door := ColorRect.new()
	door.position = Vector2(-door_w * 0.5 + randf_range(-14.0, 14.0), -door_h)
	door.size = Vector2(door_w, door_h)
	door.color = Color(0.35, 0.22, 0.14)
	n.add_child(door)
	var knob := ColorRect.new()
	knob.position = Vector2(door.position.x + door_w - 6.0, -door_h * 0.5)
	knob.size = Vector2(3.0, 3.0)
	knob.color = Color(1.0, 0.9, 0.4)
	n.add_child(knob)
	for i in range(2):
		var ww: float = 18.0 + randf() * 8.0
		var wh: float = 18.0 + randf() * 6.0
		var win := ColorRect.new()
		var wx: float = -wall_w * 0.38 if i == 0 else wall_w * 0.12
		win.position = Vector2(wx, -wall_h + 18.0)
		win.size = Vector2(ww, wh)
		win.color = Color(0.78, 0.9, 1.0)
		n.add_child(win)
		var frame_col := Color(0.32, 0.22, 0.12)
		var hb1 := ColorRect.new()
		hb1.position = Vector2(wx, -wall_h + 18.0 + wh * 0.48)
		hb1.size = Vector2(ww, 2.0)
		hb1.color = frame_col
		n.add_child(hb1)
		var vb1 := ColorRect.new()
		vb1.position = Vector2(wx + ww * 0.48, -wall_h + 18.0)
		vb1.size = Vector2(2.0, wh)
		vb1.color = frame_col
		n.add_child(vb1)
	if randf() < 0.72:
		var cx: float = wall_w * 0.36
		var cw: float = randf_range(12.0, 18.0)
		var ch: float = randf_range(28.0, 40.0)
		var chimney := ColorRect.new()
		chimney.position = Vector2(cx - cw * 0.5, -wall_h - roof_h * 0.65 - ch + 14.0)
		chimney.size = Vector2(cw, ch)
		chimney.color = Color(0.65, 0.3, 0.25)
		n.add_child(chimney)
		for si in range(3):
			var sr: float = randf_range(6.0, 10.0)
			var sn := Node2D.new()
			sn.position = Vector2(cx + randf_range(-4.0, 4.0), -wall_h - roof_h * 0.65 - ch - float(si) * 12.0 + randf_range(-6.0, 0.0))
			var s: ColorRect = ColorRect.new()
			s.position = Vector2(-sr * 0.5, -sr * 0.5)
			s.size = Vector2(sr, sr)
			s.color = Color(0.88, 0.88, 0.9, clamp(0.35 - float(si) * 0.08, 0.08, 0.5))
			sn.add_child(s)
			n.add_child(sn)
	var base_w: float = wall_w * 1.2
	var s1 := ColorRect.new()
	s1.position = Vector2(-base_w * 0.5, -4.0)
	s1.size = Vector2(base_w, 6.0)
	s1.color = Color(0.45, 0.32, 0.2)
	n.add_child(s1)

func _build_house_tall(x: float) -> void:
	var n := Node2D.new()
	n.position = Vector2(x, _FLOOR_TOP_Y - 12.0)
	decor_root.add_child(n)
	var wall_w: float = randf_range(90.0, 120.0)
	var wall_h: float = randf_range(120.0, 160.0)
	var wall := ColorRect.new()
	wall.position = Vector2(-wall_w * 0.5, -wall_h)
	wall.size = Vector2(wall_w, wall_h)
	wall.color = Color(0.84, 0.74, 0.58)
	n.add_child(wall)
	var trim_h: float = 8.0
	var trim1 := ColorRect.new()
	trim1.position = Vector2(-wall_w * 0.5, -wall_h + wall_h * 0.5 - trim_h * 0.5)
	trim1.size = Vector2(wall_w, trim_h)
	trim1.color = Color(0.55, 0.38, 0.26)
	n.add_child(trim1)
	var roof_h: float = 52.0 + randf() * 10.0
	var roof := ColorRect.new()
	roof.position = Vector2(-wall_w * 0.5 - 12.0, -wall_h - roof_h * 0.78)
	roof.size = Vector2(wall_w + 24.0, roof_h)
	roof.rotation = deg_to_rad(-10.0)
	roof.color = Color(0.32, 0.25, 0.2)
	n.add_child(roof)
	for floor_idx in range(2):
		var yoff: float = -wall_h + 20.0 + float(floor_idx) * (wall_h * 0.5)
		for wi in range(2):
			var ww: float = 20.0
			var wh: float = 22.0
			var wx: float = -wall_w * 0.33 if wi == 0 else wall_w * 0.13
			var win := ColorRect.new()
			win.position = Vector2(wx, yoff)
			win.size = Vector2(ww, wh)
			win.color = Color(0.78, 0.9, 1.0)
			n.add_child(win)
			var fc := Color(0.32, 0.22, 0.12)
			var hb := ColorRect.new()
			hb.position = Vector2(wx, yoff + wh * 0.48)
			hb.size = Vector2(ww, 2.0)
			hb.color = fc
			n.add_child(hb)
			var vb := ColorRect.new()
			vb.position = Vector2(wx + ww * 0.48, yoff)
			vb.size = Vector2(2.0, wh)
			vb.color = fc
			n.add_child(vb)
	var door_w: float = 22.0
	var door_h: float = 40.0
	var door := ColorRect.new()
	door.position = Vector2(-door_w * 0.5, -door_h)
	door.size = Vector2(door_w, door_h)
	door.color = Color(0.28, 0.18, 0.1)
	n.add_child(door)
	var lamp_n := Node2D.new()
	lamp_n.position = Vector2(-wall_w * 0.5 - 18.0, -34.0)
	n.add_child(lamp_n)
	var post := ColorRect.new()
	post.position = Vector2(-1.5, 0.0)
	post.size = Vector2(3.0, 34.0)
	post.color = Color(0.2, 0.18, 0.14)
	lamp_n.add_child(post)
	var lamp := ColorRect.new()
	lamp.position = Vector2(-6.0, -12.0)
	lamp.size = Vector2(12.0, 12.0)
	lamp.color = Color(1.0, 0.85, 0.35)
	lamp_n.add_child(lamp)

func _build_barn(x: float) -> void:
	var n := Node2D.new()
	n.position = Vector2(x, _FLOOR_TOP_Y - 12.0)
	decor_root.add_child(n)
	var wall_w: float = randf_range(130.0, 180.0)
	var wall_h: float = randf_range(90.0, 130.0)
	var wall := ColorRect.new()
	wall.position = Vector2(-wall_w * 0.5, -wall_h)
	wall.size = Vector2(wall_w, wall_h)
	wall.color = Color(0.72, 0.2, 0.18)
	n.add_child(wall)
	var trim := ColorRect.new()
	trim.position = Vector2(-wall_w * 0.5, -wall_h + wall_h - 10.0)
	trim.size = Vector2(wall_w, 10.0)
	trim.color = Color(0.42, 0.3, 0.2)
	n.add_child(trim)
	var trim_top := ColorRect.new()
	trim_top.position = Vector2(-wall_w * 0.5, -wall_h)
	trim_top.size = Vector2(wall_w, 10.0)
	trim_top.color = Color(0.42, 0.3, 0.2)
	n.add_child(trim_top)
	var roof_h: float = randf_range(70.0, 100.0)
	var roof := ColorRect.new()
	roof.position = Vector2(-wall_w * 0.5 - 14.0, -wall_h - roof_h * 0.78)
	roof.size = Vector2(wall_w + 28.0, roof_h)
	roof.rotation = deg_to_rad(-14.0)
	roof.color = Color(0.35, 0.22, 0.16)
	n.add_child(roof)
	var cross_w: float = 16.0
	for cx in [-wall_w * 0.3, wall_w * 0.0, wall_w * 0.3]:
		var xv := ColorRect.new()
		xv.position = Vector2(cx - 1.5, -wall_h + 16.0)
		xv.size = Vector2(3.0, wall_h - 26.0)
		xv.color = Color(0.98, 0.95, 0.9)
		n.add_child(xv)
		var xh := ColorRect.new()
		xh.position = Vector2(cx - cross_w * 0.5, -wall_h * 0.5 - 1.5 + 8.0)
		xh.size = Vector2(cross_w, 3.0)
		xh.color = Color(0.98, 0.95, 0.9)
		n.add_child(xh)
	var door_w: float = 46.0
	var door_h: float = 70.0
	var door := ColorRect.new()
	door.position = Vector2(-door_w * 0.5, -door_h)
	door.size = Vector2(door_w, door_h)
	door.color = Color(0.46, 0.3, 0.2)
	n.add_child(door)
	var d_split := ColorRect.new()
	d_split.position = Vector2(-1.5, -door_h)
	d_split.size = Vector2(3.0, door_h)
	d_split.color = Color(0.28, 0.18, 0.1)
	n.add_child(d_split)
	if randf() < 0.8:
		var hay_wall_w: float = randf_range(40.0, 58.0)
		var hay_wall_h: float = randf_range(26.0, 38.0)
		var hay_n := Node2D.new()
		hay_n.position = Vector2(wall_w * 0.5 + randf_range(36.0, 60.0), -hay_wall_h)
		n.add_child(hay_n)
		var hay_body := ColorRect.new()
		hay_body.position = Vector2(-hay_wall_w * 0.5, 0.0)
		hay_body.size = Vector2(hay_wall_w, hay_wall_h)
		hay_body.color = Color(0.94, 0.82, 0.38)
		hay_n.add_child(hay_body)
		for line in range(3):
			var hl := ColorRect.new()
			hl.position = Vector2(-hay_wall_w * 0.45, float(line + 1) * (hay_wall_h / 4.0) - 1.0)
			hl.size = Vector2(hay_wall_w * 0.9, 2.0)
			hl.color = Color(0.78, 0.66, 0.3)
			hay_n.add_child(hl)

func _build_well(x: float) -> void:
	var n := Node2D.new()
	n.position = Vector2(x, _FLOOR_TOP_Y - 12.0)
	decor_root.add_child(n)
	var well_w: float = 44.0
	var well_h: float = 30.0
	var stone_wall := ColorRect.new()
	stone_wall.position = Vector2(-well_w * 0.5, -well_h)
	stone_wall.size = Vector2(well_w, well_h)
	stone_wall.color = Color(0.55, 0.55, 0.58)
	n.add_child(stone_wall)
	for row in range(3):
		for col in range(4):
			var brick := ColorRect.new()
			brick.position = Vector2(-well_w * 0.5 + 2.0 + float(col) * (well_w - 4.0) / 4.0 + (1.0 if row % 2 == 1 else 0.0) * 5.0, -well_h + 2.0 + float(row) * 9.0)
			brick.size = Vector2(8.0, 7.0)
			brick.color = Color(0.45, 0.45, 0.48)
			n.add_child(brick)
	var water := ColorRect.new()
	water.position = Vector2(-well_w * 0.5 + 5.0, -well_h + 6.0)
	water.size = Vector2(well_w - 10.0, well_h - 12.0)
	water.color = Color(0.18, 0.4, 0.65)
	n.add_child(water)
	var roof_h: float = 30.0
	var roof := ColorRect.new()
	roof.position = Vector2(-well_w * 0.5 - 10.0, -well_h - 30.0 - roof_h * 0.78)
	roof.size = Vector2(well_w + 20.0, roof_h)
	roof.rotation = deg_to_rad(-15.0)
	roof.color = Color(0.5, 0.35, 0.22)
	n.add_child(roof)
	for si in range(2):
		var post := ColorRect.new()
		post.position = Vector2((-well_w * 0.5 + 4.0) if si == 0 else (well_w * 0.5 - 6.0), -well_h - 30.0)
		post.size = Vector2(3.0, 30.0)
		post.color = Color(0.38, 0.26, 0.16)
		n.add_child(post)
	var bucket_n := Node2D.new()
	bucket_n.position = Vector2(0.0, -well_h - 12.0)
	n.add_child(bucket_n)
	var rope := ColorRect.new()
	rope.position = Vector2(-0.5, 0.0)
	rope.size = Vector2(1.5, 10.0)
	rope.color = Color(0.35, 0.28, 0.22)
	bucket_n.add_child(rope)
	var bucket := ColorRect.new()
	bucket.position = Vector2(-7.0, 10.0)
	bucket.size = Vector2(14.0, 12.0)
	bucket.color = Color(0.42, 0.3, 0.18)
	bucket_n.add_child(bucket)

func _spawn_farms(x0: float, x1: float) -> void:
	var x: float = x0 + randf_range(180.0, 320.0)
	while x < x1 - 220.0:
		_build_farm_plot(x)
		x += randf_range(_FARM_MIN_SPACING, _FARM_MAX_SPACING)

func _build_farm_plot(x: float) -> void:
	var n := Node2D.new()
	n.position = Vector2(x, _FLOOR_TOP_Y - 12.0)
	decor_root.add_child(n)
	var plot_w: float = randf_range(180.0, 280.0)
	var plot_h: float = randf_range(60.0, 90.0)
	var plot := ColorRect.new()
	plot.position = Vector2(-plot_w * 0.5, -plot_h)
	plot.size = Vector2(plot_w, plot_h)
	plot.color = Color(0.5, 0.36, 0.2)
	n.add_child(plot)
	var row_count: int = 4 + randi() % 3
	for i in range(row_count + 1):
		var row := ColorRect.new()
		var yy: float = -plot_h + float(i) * plot_h / float(row_count)
		row.position = Vector2(-plot_w * 0.5, yy - 1.0)
		row.size = Vector2(plot_w, 3.0)
		row.color = Color(0.38, 0.28, 0.16)
		n.add_child(row)
	var crop_type: int = randi() % 3
	for col in range(int(plot_w / 14.0)):
		for row in range(row_count):
			if randf() < 0.82:
				var cx: float = -plot_w * 0.5 + 6.0 + float(col) * 14.0 + randf_range(-3.0, 3.0)
				var cy: float = -plot_h + (float(row) + 0.5) * plot_h / float(row_count)
				match crop_type:
					0:
						var stem_h: float = randf_range(10.0, 16.0)
						var stem := ColorRect.new()
						stem.position = Vector2(cx - 1.0, cy - stem_h)
						stem.size = Vector2(2.0, stem_h)
						stem.color = Color(0.25, 0.55, 0.25)
						n.add_child(stem)
						var head := ColorRect.new()
						head.position = Vector2(cx - 4.0, cy - stem_h - 8.0)
						head.size = Vector2(8.0, 10.0)
						head.color = Color(0.95, 0.85, 0.3)
						n.add_child(head)
					1:
						var leaf := ColorRect.new()
						leaf.position = Vector2(cx - 5.0, cy - 10.0)
						leaf.size = Vector2(10.0, 12.0)
						leaf.color = Color(0.35, 0.58, 0.3)
						n.add_child(leaf)
						var orange := ColorRect.new()
						orange.position = Vector2(cx - 3.0, cy - 4.0)
						orange.size = Vector2(6.0, 6.0)
						orange.color = Color(0.95, 0.45, 0.2)
						n.add_child(orange)
					_:
						var stalk_h: float = randf_range(14.0, 22.0)
						var stalk := ColorRect.new()
						stalk.position = Vector2(cx - 1.0, cy - stalk_h)
						stalk.size = Vector2(2.0, stalk_h)
						stalk.color = Color(0.6, 0.5, 0.2)
						n.add_child(stalk)
						var cob := ColorRect.new()
						cob.position = Vector2(cx - 2.5, cy - stalk_h * 0.55)
						cob.size = Vector2(5.0, stalk_h * 0.4)
						cob.color = Color(0.95, 0.75, 0.2)
						n.add_child(cob)
	var fence_col := Color(0.42, 0.28, 0.16)
	for side in [-1.0, 1.0]:
		for pi in range(int(plot_w / 22.0) + 1):
			var px: float = -plot_w * 0.5 + float(pi) * 22.0
			var fy: float = 0.0 if side > 0.0 else -plot_h
			var post := ColorRect.new()
			post.position = Vector2(px - 2.0, fy - 18.0 + 8.0 * side)
			post.size = Vector2(4.0, 18.0)
			post.color = fence_col
			n.add_child(post)

func _spawn_fences(x0: float, x1: float) -> void:
	var x: float = x0 + randf_range(120.0, 240.0)
	while x < x1 - 60.0:
		if randf() < 0.85:
			_build_fence_run(x)
		x += randf_range(_FENCE_MIN_SPACING, _FENCE_MAX_SPACING)

func _build_fence_run(x: float) -> void:
	var n := Node2D.new()
	n.position = Vector2(x, _FLOOR_TOP_Y - 12.0)
	decor_root.add_child(n)
	var count: int = 3 + randi() % 6
	var spacing: float = 18.0
	var fence_col := Color(0.45, 0.32, 0.18)
	var top_y: float = -38.0
	var bottom_y: float = -12.0
	for i in range(count):
		var px: float = float(i) * spacing
		var post := ColorRect.new()
		post.position = Vector2(px - 2.0, -44.0)
		post.size = Vector2(4.0, 44.0)
		post.color = fence_col
		n.add_child(post)
		var point_w: float = 6.0
		var point := ColorRect.new()
		point.position = Vector2(px - point_w * 0.5, -50.0)
		point.size = Vector2(point_w, 8.0)
		point.color = fence_col
		point.rotation = deg_to_rad(45.0)
		n.add_child(point)
	var top_rail := ColorRect.new()
	top_rail.position = Vector2(-2.0, top_y)
	top_rail.size = Vector2(float(count) * spacing + 4.0, 3.0)
	top_rail.color = fence_col
	n.add_child(top_rail)
	var mid_rail := ColorRect.new()
	mid_rail.position = Vector2(-2.0, bottom_y - 10.0)
	mid_rail.size = Vector2(float(count) * spacing + 4.0, 3.0)
	mid_rail.color = fence_col
	n.add_child(mid_rail)
	if randf() < 0.35:
		var sign_n := Node2D.new()
		sign_n.position = Vector2(float(count / 2) * spacing, -82.0)
		n.add_child(sign_n)
		var post_s := ColorRect.new()
		post_s.position = Vector2(-1.5, 0.0)
		post_s.size = Vector2(3.0, 40.0)
		post_s.color = fence_col
		sign_n.add_child(post_s)
		var board := ColorRect.new()
		board.position = Vector2(-26.0, -34.0)
		board.size = Vector2(52.0, 22.0)
		board.color = Color(0.7, 0.58, 0.4)
		sign_n.add_child(board)
		var border := ColorRect.new()
		border.position = Vector2(-26.0, -34.0)
		border.size = Vector2(52.0, 2.0)
		border.color = Color(0.45, 0.32, 0.18)
		sign_n.add_child(border)
		var border2 := ColorRect.new()
		border2.position = Vector2(-26.0, -14.0)
		border2.size = Vector2(52.0, 2.0)
		border2.color = Color(0.45, 0.32, 0.18)
		sign_n.add_child(border2)

func _spawn_clouds(x0: float, x1: float) -> void:
	var x: float = x0 + randf_range(100.0, 300.0)
	while x < x1:
		_build_cloud(x)
		x += randf_range(_CLOUD_MIN_SPACING, _CLOUD_MAX_SPACING)

func _build_cloud(x: float) -> void:
	var cloud_node := Node2D.new()
	var y: float = randf_range(180.0, 460.0)
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

func _spawn_village_sky(x0: float, x1: float) -> void:
	var x: float = x0 + randf_range(0.0, 400.0)
	while x < x1:
		_build_village_skyline(x)
		x += randf_range(_VILLAGE_SKY_MIN_SPACING, _VILLAGE_SKY_MAX_SPACING)

func _build_village_skyline(x: float) -> void:
	var village_n := Node2D.new()
	village_n.position = Vector2(x, _FLOOR_TOP_Y)
	hill_root.add_child(village_n)
	var hill_bg_w: float = randf_range(700.0, 1000.0)
	var hill_bg_h: float = randf_range(80.0, 140.0)
	var hill_bg := ColorRect.new()
	hill_bg.position = Vector2(-hill_bg_w * 0.5, -hill_bg_h - 6.0)
	hill_bg.size = Vector2(hill_bg_w, hill_bg_h + 10.0)
	hill_bg.color = Color(0.28, 0.4, 0.55, 0.55)
	village_n.add_child(hill_bg)
	var house_count: int = 4 + randi() % 4
	var cluster_w: float = hill_bg_w * 0.85
	for i in range(house_count):
		var hx: float = -cluster_w * 0.5 + randf() * cluster_w
		var hw: float = randf_range(60.0, 110.0)
		var hh: float = randf_range(50.0, 90.0)
		var house := ColorRect.new()
		house.position = Vector2(hx - hw * 0.5, -hh - hill_bg_h * 0.35)
		house.size = Vector2(hw, hh)
		house.color = Color(0.38, 0.48, 0.6, 0.65)
		village_n.add_child(house)
		var rh: float = randf_range(26.0, 42.0)
		var roof := ColorRect.new()
		roof.position = Vector2(hx - hw * 0.5 - 6.0, -hh - hill_bg_h * 0.35 - rh * 0.78)
		roof.size = Vector2(hw + 12.0, rh)
		roof.rotation = deg_to_rad(-10.0)
		roof.color = Color(0.3, 0.4, 0.52, 0.65)
		village_n.add_child(roof)
	var church_x: float = randf_range(-cluster_w * 0.2, cluster_w * 0.2)
	var church_w: float = randf_range(70.0, 100.0)
	var church_h: float = randf_range(120.0, 170.0)
	var church := ColorRect.new()
	church.position = Vector2(church_x - church_w * 0.5, -church_h - hill_bg_h * 0.45)
	church.size = Vector2(church_w, church_h)
	church.color = Color(0.4, 0.5, 0.62, 0.7)
	village_n.add_child(church)
	var steeple_w: float = church_w * 0.35
	var steeple_h: float = randf_range(70.0, 100.0)
	var steeple := ColorRect.new()
	steeple.position = Vector2(church_x - steeple_w * 0.5, -church_h - hill_bg_h * 0.45 - steeple_h)
	steeple.size = Vector2(steeple_w, steeple_h)
	steeple.color = Color(0.32, 0.42, 0.55, 0.7)
	village_n.add_child(steeple)
	var cross_s := 8.0
	var cross1 := ColorRect.new()
	cross1.position = Vector2(church_x - 1.5, -church_h - hill_bg_h * 0.45 - steeple_h - 2.0 - cross_s)
	cross1.size = Vector2(3.0, cross_s)
	cross1.color = Color(0.85, 0.85, 0.9, 0.75)
	village_n.add_child(cross1)
	var cross2 := ColorRect.new()
	cross2.position = Vector2(church_x - cross_s * 0.5, -church_h - hill_bg_h * 0.45 - steeple_h - 2.0 - cross_s * 0.7)
	cross2.size = Vector2(cross_s, 3.0)
	cross2.color = Color(0.85, 0.85, 0.9, 0.75)
	village_n.add_child(cross2)

func _build_sky_chunk(x0: float, x1: float) -> void:
	if x1 <= x0:
		return
	var w: float = x1 - x0
	var sky_bg := ColorRect.new()
	sky_bg.position = Vector2(x0, -200.0)
	sky_bg.size = Vector2(w, _FLOOR_TOP_Y + 200.0)
	sky_bg.color = Color(0.68, 0.86, 1.0)
	sky_root.add_child(sky_bg)
	var sun_n := Node2D.new()
	sun_n.position = Vector2(x0 + randf_range(w * 0.15, w * 0.45), randf_range(100.0, 180.0))
	sky_root.add_child(sun_n)
	var sun_r: float = 36.0
	var sun := ColorRect.new()
	sun.position = Vector2(-sun_r * 0.5, -sun_r * 0.5)
	sun.size = Vector2(sun_r, sun_r)
	sun.color = Color(1.0, 0.95, 0.55, 0.95)
	sun_n.add_child(sun)
	for ri in range(8):
		var angle_deg: float = float(ri) * 45.0
		var a: float = deg_to_rad(angle_deg)
		var ray_len: float = 58.0
		var ray_w: float = 6.0
		var ray := ColorRect.new()
		ray.position = Vector2(-ray_w * 0.5 + cos(a) * 40.0, -ray_len * 0.5 + sin(a) * 40.0)
		ray.size = Vector2(ray_w, ray_len)
		ray.rotation = a
		ray.color = Color(1.0, 0.92, 0.45, 0.6)
		sun_n.add_child(ray)
	var x: float = x0 + randf_range(200.0, 400.0)
	while x < x1:
		_build_distant_field(x)
		x += randf_range(700.0, 1100.0)

func _build_distant_field(x: float) -> void:
	var m_node := Node2D.new()
	m_node.position = Vector2(x, _FLOOR_TOP_Y)
	sky_root.add_child(m_node)
	var mw: float = randf_range(700.0, 1000.0)
	var mh: float = randf_range(90.0, 150.0)
	var field := ColorRect.new()
	field.position = Vector2(-mw * 0.5, -mh)
	field.size = Vector2(mw, mh)
	field.color = Color(0.36, 0.5, 0.3, 0.75)
	m_node.add_child(field)
	var stripes: int = 5 + randi() % 4
	for si in range(stripes):
		var stripe := ColorRect.new()
		var sy: float = -mh + float(si) * (mh / float(stripes)) + (mh / float(stripes)) * 0.5 - 2.0
		stripe.position = Vector2(-mw * 0.5, sy)
		stripe.size = Vector2(mw, 3.0)
		stripe.color = Color(0.28, 0.42, 0.25, 0.85)
		m_node.add_child(stripe)
	var tree_count: int = 3 + randi() % 5
	for ti in range(tree_count):
		var tx: float = -mw * 0.45 + randf() * mw * 0.9
		var tw: float = randf_range(22.0, 36.0)
		var th: float = randf_range(46.0, 68.0)
		var tt := ColorRect.new()
		tt.position = Vector2(tx - tw * 0.5, -mh * 0.35 - th)
		tt.size = Vector2(tw, th)
		tt.color = Color(0.2, 0.4, 0.22, 0.85)
		m_node.add_child(tt)
		var tw2: float = tw * 0.8
		var th2: float = th * 0.6
		var tt2 := ColorRect.new()
		tt2.position = Vector2(tx - tw2 * 0.5 + tw * 0.1, -mh * 0.35 - th * 0.75 - th2 * 0.5)
		tt2.size = Vector2(tw2, th2)
		tt2.color = Color(0.23, 0.45, 0.25, 0.85)
		m_node.add_child(tt2)

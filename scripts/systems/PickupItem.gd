extends Area2D
## V0.3 scripts/systems/PickupItem.gd — 可拾取实体（金币/药瓶）
## 玩家/同伴进入Area2D即触发拾取

class_name PickupItem

@export var item_id: String = "gold"
@export var value: int = 1
@export var auto_pick_radius: float = 48.0

var float_phase: float = 0.0
var base_y: float = 0.0
var pickup_attempted: bool = false

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	base_y = position.y

func _process(delta: float) -> void:
	float_phase += delta * 2.8
	position.y = base_y + sin(float_phase) * 3.0
	rotation = sin(float_phase * 0.7) * 0.05

func _on_body_entered(b: Node) -> void:
	if pickup_attempted:
		return
	if b and (b.get("kind") if b.has("kind") else -1) == 0:
		_do_pickup(b)

func _on_area_entered(a: Area2D) -> void:
	pass

func _do_pickup(by_who: Node) -> void:
	if pickup_attempted:
		return
	pickup_attempted = true
	if by_who == null:
		return
	match item_id:
		"gold":
			var before := int(by_who.get("gold", 0)) if by_who.has("gold") else 0
			if by_who.has("gold"):
				by_who.set("gold", before + value)
			var total := before + value
			if GameEvents:
				GameEvents.emit_signal("gold_picked", value, by_who, total)
		"potion_hp":
			var heal_v := value
			if by_who.has_method("heal"):
				by_who.heal(heal_v, by_who)
			if GameEvents:
				GameEvents.emit_signal("potion_picked", heal_v, by_who)
		_:
			if GameEvents:
				GameEvents.emit_signal("generic_picked", item_id, value, by_who)
	queue_free()

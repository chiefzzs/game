extends Node
class_name PickupSystemAutoload
## V0.3 autoload/PickupSystem.gd — Autoload版本（与scripts/systems/PickupSystem.gd一致，满足P1清单#12）

const SCENES_DIR := "res://scenes/characters/"

var registry: Dictionary = {}
var drops: Array[Dictionary] = []

func _autoload(name: String) -> Node:
	var st: SceneTree = get_tree()
	if st == null or st.root == null:
		var ml = Engine.get_main_loop()
		if ml is SceneTree:
			st = ml
		else:
			return null
	return st.root.get_node_or_null(NodePath("/root/" + name))

func _ready() -> void:
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	var CM: Node = _autoload("ConfigManager")
	if CM == null:
		return
	registry = CM.call("cfg_get", "pickups.items", {})
	var _raw_drops: Array = CM.call("cfg_get", "pickups.drops", [])
	drops.clear()
	for d in _raw_drops:
		if typeof(d) == TYPE_DICTIONARY:
			drops.append(d)

func get_item(id: String) -> Dictionary:
	if registry.has(id):
		return registry[id]
	return {"name": id, "type": "misc", "value_default": 1, "color": "#FFFFFF", "shape": "circle"}

func roll_drop_table(enemy_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in drops:
		if str(d.get("enemy_id","*")) == "*" or str(d.get("enemy_id","*")) == enemy_id:
			var items: Array = d.get("items", [])
			var at_most: int = int(d.get("max_items_per_kill", 0))
			var count: int = 0
			for item_row in items:
				if typeof(item_row) != TYPE_ARRAY or item_row.size() < 3:
					continue
				var iid: String = str(item_row[0])
				var chance: float = float(item_row[1])
				var lo: int = int(item_row[2])
				var hi: int = int(item_row[3]) if item_row.size() >= 4 else lo
				if randf() < chance:
					var val: int = lo if lo == hi else randi_range(lo, hi)
					if val > 0:
						out.append({"item_id": iid, "value": val})
						count += 1
						if at_most > 0 and count >= at_most:
							break
	return out

func spawn_drop(world_pos: Vector2, item_id: String, value: int) -> void:
	var packed := load(SCENES_DIR + "GoldPickup.tscn")
	if packed == null:
		return
	var inst: Node = packed.instantiate()
	if inst.has_method("set"):
		inst.set("item_id", item_id)
		inst.set("value", value)
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(inst)
		(inst as Node2D).global_position = world_pos
	else:
		add_child(inst)
		(inst as Node2D).global_position = world_pos

func spawn_drops(world_pos: Vector2, enemy_id: String) -> Array[Dictionary]:
	var rolled: Array[Dictionary] = roll_drop_table(enemy_id)
	for r in rolled:
		var offset := Vector2(randf_range(-10.0, 10.0), randf_range(-15.0, -5.0))
		spawn_drop(world_pos + offset, r.item_id, r.value)
	return rolled

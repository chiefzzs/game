extends CharacterBody2D
## V0.3 ProjectileArrow.gd — 箭矢：直线飞行+碰撞伤害+过期

class_name ProjectileArrow

var velocity_2d: Vector2 = Vector2.ZERO
var source: Node = null
var damage_value: int = 0
var life_left: float = 2.0
var in_flight: bool = false
var hit: bool = false

func _ready() -> void:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(20, 4)
	cs.shape = rs
	cs.position = Vector2(10, 0)
	add_child(cs)
	collision_layer = 16
	collision_mask = 8 | 4 | 1 | 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)

func launch(direction_with_speed: Vector2, src: Node, dmg: int) -> void:
	velocity_2d = direction_with_speed
	source = src
	damage_value = dmg
	rotation = velocity_2d.angle()
	in_flight = true
	life_left = 2.0
	hit = false

func _physics_process(delta: float) -> void:
	if not in_flight:
		return
	life_left -= delta
	if life_left <= 0.0:
		queue_free()
		return
	velocity = velocity_2d
	move_and_slide()
	if is_colliding():
		var col := get_slide_collision(0)
		if col:
			var n: Node = col.get_collider()
			if n and n != source and not hit:
				hit = true
				_apply_hit(n)
				queue_free()

func _apply_hit(target: Node) -> void:
	var dir: Vector2 = velocity_2d.normalized()
	if dir.x == 0 and dir.y == 0:
		dir = Vector2.RIGHT
	var sb: bool = false
	CombatDamageCalculator.calculate(source, target, damage_value, "arrow", dir, sb, 1.0)
	if target and target.has_method("take_damage"):
		target.take_damage(source, damage_value, "arrow", dir, sb)

func _on_body_entered(body: Node) -> void:
	if hit or body == source or not in_flight:
		return
	hit = true
	_apply_hit(body)
	queue_free()

func _on_body_exited(_body: Node) -> void: pass
func _on_area_entered(_area: Area2D) -> void: pass

func _draw() -> void:
	draw_line(Vector2.ZERO, Vector2(18, 0), Color(0.65, 0.5, 0.3), 2.0)
	var tri := PackedVector2Array([Vector2(18,0), Vector2(12,-4), Vector2(12,4)])
	draw_colored_polygon(tri, Color(0.8, 0.8, 0.85))
	draw_line(Vector2(-2,-4), Vector2(2,-4), Color(0.5, 0.5, 0.6), 1.5)
	draw_line(Vector2(-2, 4), Vector2(2, 4), Color(0.5, 0.5, 0.6), 1.5)

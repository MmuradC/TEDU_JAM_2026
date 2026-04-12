extends Area3D

@export var speed: float = 120.0
@export var lifetime: float = 2.0

func _ready() -> void:
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	area_entered.connect(_on_impact)
	body_entered.connect(_on_impact)

func _process(delta: float) -> void:
	global_translate(-global_transform.basis.z * speed * delta)

func _on_impact(node: Node) -> void:
	var target = node
	if node is Area3D:
		target = node.get_parent()

	if target.has_method("take_damage"):
		target.take_damage(25.0)
	elif target.has_method("has_been_hit"):
		target.has_been_hit()

	var explosion_scene = load("res://1_entities/3_objects/1_bullet/Explosion.tscn")
	if explosion_scene:
		var exp = explosion_scene.instantiate()
		get_parent().add_child(exp)
		exp.global_position = global_position
		exp.scale = Vector3(0.15, 0.15, 0.15)
		if exp.has_method("setup"): exp.setup(0.0)

	queue_free()

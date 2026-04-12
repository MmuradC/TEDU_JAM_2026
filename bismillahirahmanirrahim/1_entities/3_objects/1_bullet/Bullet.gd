extends Area3D

@export var speed: float = 150.0
@export var lifetime: float = 4.0

func _ready() -> void:
	# Clean up bullet after lifetime expires
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Connect signals for both area and body detection
	area_entered.connect(_on_impact)
	body_entered.connect(_on_impact)

func _process(delta: float) -> void:
	# Move bullet forward
	global_translate(-global_transform.basis.z * speed * delta)

func _on_impact(node: Node) -> void:
	# Check for damageable entities (Player or AA Gun)
	var target = node
	# If we hit an area, the logic might be on the parent (like the airplane)
	if node is Area3D:
		target = node.get_parent()
	
	if target.has_method("take_damage"):
		target.take_damage(20.0)
	elif target.has_method("has_been_hit"):
		target.has_been_hit()
	
	# Visual effect on impact
	var explosion_scene = load("res://1_entities/3_objects/1_bullet/Explosion.tscn")
	if explosion_scene:
		var exp = explosion_scene.instantiate()
		get_parent().add_child(exp)
		exp.global_position = global_position
		if exp.has_method("setup"): exp.setup(0.0) # Immediate explosion
	
	queue_free()

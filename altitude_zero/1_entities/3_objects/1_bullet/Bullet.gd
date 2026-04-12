extends Area3D

@export var speed: float = 150.0
@export var lifetime: float = 4.0

func _ready() -> void:
	# Clean up bullet after lifetime expires
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Connect collision signal
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	# Move bullet forward
	global_translate(-global_transform.basis.z * speed * delta)

func _on_area_entered(area: Area3D) -> void:
	# Check if hit player's hitbox
	var player = area.get_parent()
	if player and player.has_method("has_been_hit"):
		print("--- PLAYER HIT DETECTED ---")
		player.has_been_hit()
	
	# Destroy bullet on any area entry
	queue_free()

extends Area3D

@export var speed: float = 0.0 # Initial forward speed inherited from plane
@export var damage: float = 100.0
@export var lifetime: float = 10.0

var velocity: Vector3 = Vector3.ZERO
var fall_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	# Clean up after lifetime expires
	get_tree().create_timer(lifetime).timeout.connect(func(): if is_instance_valid(self): queue_free())
	
	# Connect collision signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Apply gravity
	velocity.y -= fall_gravity * delta
	
	# Move bomb
	global_translate(velocity * delta)
	
	# Rotate towards movement
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)

func _on_area_entered(area: Area3D) -> void:
	# Don't hit yourself immediately
	if area.is_in_group("player_hitbox"): return
	explode()

func _on_body_entered(_body: Node3D) -> void:
	explode()

func explode() -> void:
	var explosion_scene = load("res://1_entities/3_objects/1_bullet/Explosion.tscn")
	if explosion_scene:
		var exp = explosion_scene.instantiate()
		get_parent().add_child(exp)
		exp.global_position = global_position
		if exp.has_method("setup"): 
			exp.setup(0.0) # Detonate instantly
	
	queue_free()

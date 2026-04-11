extends StaticBody3D

@export var min_fire_rate: float = 2.0 
@export var max_fire_rate: float = 4.0 
@export var rotation_speed: float = 5.0 
@export var range_limit: float = 1200.0 # Increased range for 1km altitude
@export var deviation_limit: float = 40.0 

var target: Node3D = null
var is_in_range: bool = false
var timer: float = 0.0
var current_cooldown: float = 3.0

@onready var turret = $Turret 
@onready var muzzle_flash = $Turret/Muzzle/MuzzleFlash
@onready var shoot_sound = $ShootSound
@onready var explosion_scene = preload("res://1_entities/3_objects/1_bullet/Explosion.tscn")

func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")
	current_cooldown = randf_range(min_fire_rate, max_fire_rate)
	timer = current_cooldown
	
	# Procedural Beep for shooting if no sound asset exists
	var beep = AudioStreamWAV.new()
	beep.format = AudioStreamWAV.FORMAT_8_BITS
	beep.mix_rate = 16000
	var data = PackedByteArray()
	for i in range(2400):
		data.append(127 if (i / 8) % 2 == 0 else -128)
	beep.data = data
	shoot_sound.stream = beep

func _process(delta: float) -> void:
	if not target: return
	
	var distance = global_position.distance_to(target.global_position)
	
	if distance <= range_limit:
		if not is_in_range:
			is_in_range = true
			if target.has_method("register_aa_in_range"): target.register_aa_in_range(true)
		
		# Rotate turret towards target
		var look_transform = turret.global_transform.looking_at(target.global_position, Vector3.UP)
		turret.global_transform = turret.global_transform.interpolate_with(look_transform, rotation_speed * delta)
		
		timer += delta
		if timer >= current_cooldown:
			fire(distance)
			timer = 0.0
			current_cooldown = randf_range(min_fire_rate, max_fire_rate)
	else:
		if is_in_range:
			is_in_range = false
			if target.has_method("register_aa_in_range"): target.register_aa_in_range(false)
		muzzle_flash.visible = false
		timer = current_cooldown

func fire(dist: float) -> void:
	muzzle_flash.visible = true
	shoot_sound.play()
	get_tree().create_timer(0.1).timeout.connect(func(): muzzle_flash.visible = false)
	
	# PREDICTIVE AIMING CALCULATION
	# Scale distance for shell travel time (0-1200 range -> ~1 to 4 seconds delay)
	var travel_time = clamp(dist / 300.0, 1.0, 4.0)
	
	# Use target's movement data (matched to new Airplane.gd names)
	var target_speed_ms = target.get("current_speed_kmh") / 3.6 if "current_speed_kmh" in target else 100.0
	var sim_pos = target.global_position
	var sim_basis = target.global_transform.basis
	var step_dt = travel_time / 10.0
	
	# Simple simulation of airplane trajectory for prediction
	var turn_data = target.get("current_turn_speed") if "current_turn_speed" in target else Vector2.ZERO
	for i in range(10):
		sim_basis = Basis(Vector3.UP, deg_to_rad(turn_data.x * step_dt)) * sim_basis
		sim_basis = sim_basis.rotated(sim_basis.x, deg_to_rad(turn_data.y * step_dt))
		sim_pos += -sim_basis.z * target_speed_ms * step_dt
	
	# Dynamic Deviation (Accuracy drops if more AA are active)
	var active_aa = target.get("active_aa_count") if "active_aa_count" in target else 1
	var deviation = remap(clamp(active_aa, 1, 30), 1, 30, 5.0, deviation_limit)
	
	var deviation_vec = Vector3(
		randf_range(-deviation, deviation),
		randf_range(-deviation, deviation),
		randf_range(-deviation, deviation)
	)
	var final_target = sim_pos + deviation_vec
	
	# Spawn explosion at predicted point
	var exp = explosion_scene.instantiate()
	get_parent().add_child(exp)
	exp.global_position = final_target
	if exp.has_method("setup"):
		exp.setup(travel_time)

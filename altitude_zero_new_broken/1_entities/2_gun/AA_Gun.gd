extends StaticBody3D

@export var min_fire_rate: float = 6.0
@export var max_fire_rate: float = 10.0
@export var rotation_speed: float = 2.5
@export var range_limit: float = 400.0
@export var deviation_limit: float = 25.0

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
	timer = randf_range(0.0, current_cooldown)

	var flak = AudioStreamWAV.new()
	flak.format = AudioStreamWAV.FORMAT_8_BITS
	flak.mix_rate = 11025
	var data = PackedByteArray()
	for i in range(4000):
		var noise = (randi() % 64 - 32)
		var thump = sin(float(i) * 0.2) * 64.0
		var envelope = 1.0 - float(i) / 4000.0
		var val = int((thump + noise) * envelope)
		data.append(clamp(val, -128, 127))
	flak.data = data
	if shoot_sound:
		shoot_sound.stream = flak
		shoot_sound.unit_size = 20.0
		shoot_sound.max_distance = 5000.0

@export var max_health: float = 80.0
var current_health: float = 80.0
var is_destroyed: bool = false

func take_damage(amount: float) -> void:
	if is_destroyed: return

	current_health -= amount
	if muzzle_flash:
		muzzle_flash.visible = true
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(muzzle_flash):
				muzzle_flash.visible = false
		)

	if current_health <= 0:
		destroy()

func destroy() -> void:
	is_destroyed = true
	if is_in_range and target:
		target.register_aa_in_range(false)

	var exp = explosion_scene.instantiate()
	get_parent().add_child(exp)
	exp.global_position = global_position
	exp.scale = Vector3(0.6, 0.6, 0.6)
	if exp.has_method("setup"): exp.setup(0.0)

	set_process(false)
	get_tree().create_timer(0.1).timeout.connect(queue_free)

func _process(delta: float) -> void:
	if not target: return

	var distance = global_position.distance_to(target.global_position)
	var cloud_altitude = 700.0
	var is_above_clouds = target.global_position.y > cloud_altitude

	if distance <= range_limit and not is_above_clouds:
		if not is_in_range:
			is_in_range = true
			if target.has_method("register_aa_in_range"): target.register_aa_in_range(true)

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

	var travel_time = 0.15

	var target_speed_ms = target.get("current_speed_kmh") / 3.6 if "current_speed_kmh" in target else 100.0
	var sim_pos = target.global_position
	var sim_basis = target.global_transform.basis
	var step_dt = travel_time / 10.0

	var turn_data = target.get("current_turn_speed") if "current_turn_speed" in target else Vector2.ZERO
	for i in range(10):
		sim_basis = Basis(Vector3.UP, deg_to_rad(turn_data.x * step_dt)) * sim_basis
		sim_basis = sim_basis.rotated(sim_basis.x, deg_to_rad(turn_data.y * step_dt))
		sim_pos += -sim_basis.z * target_speed_ms * step_dt

	var active_aa = target.get("active_aa_count") if "active_aa_count" in target else 1
	var deviation = remap(clamp(active_aa, 1, 30), 1, 30, 5.0, deviation_limit)

	var deviation_vec = Vector3(
		randf_range(-deviation, deviation),
		randf_range(-deviation, deviation),
		randf_range(-deviation, deviation)
	)
	var final_target = sim_pos + deviation_vec

	var exp = explosion_scene.instantiate()
	get_parent().add_child(exp)
	exp.global_position = final_target
	exp.scale = Vector3(0.15, 0.15, 0.15)
	if exp.has_method("setup"):
		exp.setup(travel_time)

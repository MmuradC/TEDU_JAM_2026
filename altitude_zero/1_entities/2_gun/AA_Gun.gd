extends StaticBody3D

@export var min_fire_rate: float = 2.0 
@export var max_fire_rate: float = 4.0 
@export var rotation_speed: float = 5.0 
@export var range_limit: float = 750.0 
@export var deviation_limit: float = 10.0 

@export var look_ahead_time: float = 0.5 # Increased prediction range

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
	
	# Realistic Procedural Flak Sound
	var flak = AudioStreamWAV.new()
	flak.format = AudioStreamWAV.FORMAT_8_BITS
	flak.mix_rate = 11025
	var data = PackedByteArray()
	for i in range(4000):
		# Mix low frequency thump with white noise decay
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

func _process(delta: float) -> void:
	if not is_instance_valid(target): return
	
	var distance = global_position.distance_to(target.global_position)
	var cloud_altitude = 165.0 # Synced with TutorialLevel
	var is_above_clouds = target.global_position.y > cloud_altitude
	
	if distance <= range_limit and not is_above_clouds:
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
		timer = 0.0 # Reset timer so it doesn't fire immediately upon re-entry

func fire(dist: float) -> void:
	muzzle_flash.visible = true
	shoot_sound.play()
	get_tree().create_timer(0.1).timeout.connect(func(): if is_instance_valid(muzzle_flash): muzzle_flash.visible = false)
	
	# PREDICTIVE AIMING CALCULATION
	# Use target's movement data with visual_multiplier (10.0) from Airplane.gd
	var visual_multiplier = 10.0
	var target_speed_ms = (target.get("current_speed_kmh") / 3.6) * visual_multiplier if "current_speed_kmh" in target else 100.0
	var sim_pos = target.global_position
	var sim_basis = target.global_transform.basis
	var step_dt = look_ahead_time / 10.0
	
	# Simple simulation of airplane trajectory for prediction
	var turn_data = target.get("current_turn_speed") if "current_turn_speed" in target else Vector2.ZERO
	for i in range(10):
		sim_basis = Basis(Vector3.UP, deg_to_rad(turn_data.x * step_dt)) * sim_basis
		sim_basis = sim_basis.rotated(sim_basis.x.normalized(), deg_to_rad(turn_data.y * step_dt))
		sim_pos += -sim_basis.z * target_speed_ms * step_dt
	
	# Dynamic Deviation (Accuracy drops if more AA are active to avoid "sniping" the player)
	var active_aa = target.get("active_aa_count") if "active_aa_count" in target else 1
	var deviation = lerp(2.0, deviation_limit, clamp(float(active_aa - 1) / 8.0, 0.0, 1.0))
	
	var deviation_vec = Vector3(
		randf_range(-deviation, deviation),
		randf_range(-deviation, deviation),
		randf_range(-deviation, deviation)
	)
	var final_target = sim_pos + deviation_vec
	
	# Shell visual timing
	var travel_time = clamp(dist / 600.0, look_ahead_time, 5.0)
	
	# Visual Tracer
	create_tracer(muzzle_flash.global_position, final_target, travel_time)
	
	# Spawn explosion at predicted point
	var exp = explosion_scene.instantiate()
	get_parent().add_child(exp)
	exp.global_position = final_target
	if exp.has_method("setup"):
		exp.setup(travel_time)

func create_tracer(start: Vector3, end: Vector3, time: float):
	var tracer = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.7, 0.1) # Bright tracer orange/yellow
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	get_tree().root.add_child(tracer)
	
	var duration = 0.0
	while duration < time:
		duration += get_process_delta_time()
		var t = duration / time
		var current_head = start.lerp(end, t)
		var trail_length = 15.0
		var current_tail = start.lerp(end, max(0.0, t - (trail_length / start.distance_to(end))))
		
		mesh.clear_surfaces()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
		mesh.surface_add_vertex(current_tail)
		mesh.surface_add_vertex(current_head)
		mesh.surface_end()
		
		# Safety check: if scene changes or gun is removed, abort
		if not is_inside_tree(): break
		await get_tree().process_frame
	
	if is_instance_valid(tracer):
		tracer.queue_free()

extends Node3D

# --- Movement Settings ---
@export var min_speed: float = 120.0
@export var max_speed: float = 700.0
@export var cruise_speed: float = 400.0
@export var sensitivity_x: float = 0.1
@export var sensitivity_y: float = 0.02
@export var acceleration_power: float = 0.4

# --- Steering Smoothing ---
@export var max_turn_speed: float = 60.0 
@export var smoothing_speed_x: float = 3.0
@export var smoothing_speed_y: float = 3.0

# --- Visual Animation Settings ---
@export var max_roll_angle: float = 45.0
@export var max_pitch_angle: float = 20.0
@export var animation_speed: float = 5.0

# --- Internal State ---
var current_turn_speed: Vector2 = Vector2.ZERO
var frame_mouse_input: Vector2 = Vector2.ZERO
var current_speed_kmh: float = 400.0
var active_aa_count: int = 0
var virtual_mouse_offset: Vector2 = Vector2.ZERO
var is_flashing: bool = false

# --- Health System ---
@export var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false

# --- Node References ---
@onready var speed_label = find_ui_node("SpeedLabel")
@onready var health_bar = find_ui_node("HealthBar")
@onready var hit_indicator = find_ui_node("HitIndicator")
@onready var aa_label = find_ui_node("AALabel")
@onready var mouse_crosshair = find_ui_node("MouseCrosshair")
@onready var plane_crosshair = find_ui_node("PlaneCrosshair")
@onready var ww2_viewfinder = find_ui_node("WW2Viewfinder")

@onready var airplane_model = $bf109
@onready var smoke_particles = get_node_or_null("SmokeParticles")
@onready var fire_particles = get_node_or_null("FireParticles")
@onready var nose_ray = get_node_or_null("NoseRayCast")
@onready var engine_sound = get_node_or_null("EngineSound")
@onready var camera = $Camera3D
@onready var tps_pos = $TPSPos
@onready var top_down_pos = $TopDownPos
@onready var ground = get_tree().root.find_child("Ground", true, false)

func find_ui_node(node_name: String) -> Node:
	var ui = get_tree().root.find_child("UI", true, false)
	if ui:
		return ui.find_child(node_name, true, false)
	return null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_speed_kmh = cruise_speed
	
	if engine_sound and not engine_sound.playing:
		engine_sound.play()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		frame_mouse_input += event.relative
		virtual_mouse_offset += event.relative

func _process(delta: float) -> void:
	handle_movement(delta)
	handle_steering(delta)
	handle_visuals(delta)
	handle_camera(delta)
	update_ui()

func handle_movement(delta: float) -> void:
	# DYNAMIC SPEED (Energy Management)
	var forward_vector = -global_transform.basis.z
	var pitch_factor = forward_vector.y # Up is positive, Down is negative
	
	# Target speed based on pitch inclination
	var target_speed = cruise_speed
	if pitch_factor > 0: # Climbing: bleed speed
		target_speed = lerp(cruise_speed, min_speed, pitch_factor)
	else: # Diving: gain speed from gravity
		target_speed = lerp(cruise_speed, max_speed, -pitch_factor)
	
	# Realistic acceleration rates
	var accel_rate = 150.0 if pitch_factor < 0 else 80.0
	current_speed_kmh = move_toward(current_speed_kmh, target_speed, accel_rate * delta)
	
	# Apply translation
	global_translate(forward_vector * (current_speed_kmh / 3.6) * delta)

	# CRASH DETECTION
	if nose_ray and nose_ray.is_colliding():
		var collider = nose_ray.get_collider()
		print("CRASHED INTO: ", collider.name)
		die()

	if ground:
		ground.global_position.x = global_position.x
		ground.global_position.z = global_position.z

func handle_steering(delta: float) -> void:
	# Smoothly interpolate mouse input to turn speed
	var target_yaw_speed = clamp(-frame_mouse_input.x * sensitivity_x / delta, -max_turn_speed, max_turn_speed)
	var target_pitch_speed = clamp(-frame_mouse_input.y * sensitivity_y / delta, -max_turn_speed, max_turn_speed)
	
	current_turn_speed.x = lerp(current_turn_speed.x, target_yaw_speed, smoothing_speed_x * delta)
	current_turn_speed.y = lerp(current_turn_speed.y, target_pitch_speed, smoothing_speed_y * delta)
	
	rotate_y(deg_to_rad(current_turn_speed.x * delta))
	rotate_object_local(Vector3.RIGHT, deg_to_rad(current_turn_speed.y * delta))
	frame_mouse_input = Vector2.ZERO

func handle_visuals(delta: float) -> void:
	# Update airplane model roll and pitch animations
	if airplane_model:
		var target_roll = clamp(current_turn_speed.x * -1.0, -max_roll_angle, max_roll_angle)
		var target_pitch = clamp(current_turn_speed.y * -1.0, -max_pitch_angle, max_pitch_angle)
		
		airplane_model.rotation.z = lerp_angle(airplane_model.rotation.z, deg_to_rad(target_roll), animation_speed * delta)
		airplane_model.rotation.x = lerp_angle(airplane_model.rotation.x, deg_to_rad(target_pitch), animation_speed * delta)

	# Update Crosshairs
	virtual_mouse_offset = virtual_mouse_offset.lerp(Vector2.ZERO, 4.0 * delta)
	var max_radius = 300.0
	if virtual_mouse_offset.length() > max_radius:
		virtual_mouse_offset = virtual_mouse_offset.normalized() * max_radius

	if mouse_crosshair:
		var viewport_center = get_viewport().size / 2
		mouse_crosshair.global_position = Vector2(viewport_center) + virtual_mouse_offset
		
		var intensity = virtual_mouse_offset.length() / max_radius
		var is_hard_turning = intensity > 0.8
		var target_color = Color(1, 1, 0) if not is_hard_turning else Color(1, 0, 0)
		var target_scale = Vector2.ONE if not is_hard_turning else Vector2(1.5, 1.5)
		
		mouse_crosshair.modulate = mouse_crosshair.modulate.lerp(target_color, 10.0 * delta)
		mouse_crosshair.scale = mouse_crosshair.scale.lerp(target_scale, 10.0 * delta)
		
	# Smoothly reset camera shake offsets
	if camera:
		camera.h_offset = lerp(camera.h_offset, 0.0, 5.0 * delta)
		camera.v_offset = lerp(camera.v_offset, 0.0, 5.0 * delta)

	if plane_crosshair and camera and airplane_model:
		var forward_3d = airplane_model.global_position + (-airplane_model.global_transform.basis.z * 1000.0)
		if camera.is_position_behind(forward_3d):
			plane_crosshair.visible = false
		else:
			plane_crosshair.visible = true
			plane_crosshair.global_position = camera.unproject_position(forward_3d)

func handle_camera(delta: float) -> void:
	if camera and tps_pos and top_down_pos:
		var is_top_down = Input.is_key_pressed(KEY_C)
		var target_transform = tps_pos.transform if not is_top_down else top_down_pos.transform
		camera.transform = camera.transform.interpolate_with(target_transform, 5.0 * delta)
		
		if ww2_viewfinder: ww2_viewfinder.visible = is_top_down
		if mouse_crosshair: mouse_crosshair.visible = not is_top_down
		if plane_crosshair: plane_crosshair.visible = not is_top_down

func update_ui() -> void:
	if speed_label:
		speed_label.text = "Speed: %d km/h" % int(current_speed_kmh)
	
	if health_bar:
		health_bar.value = (current_health / max_health) * 100.0
	
	# Update engine sound pitch based on speed
	if engine_sound:
		var speed_perc = (current_speed_kmh - min_speed) / (max_speed - min_speed)
		engine_sound.pitch_scale = lerp(0.7, 1.5, speed_perc)

	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func take_damage(amount: float) -> void:
	if is_dead: return
	
	current_health -= amount
	current_health = clamp(current_health, 0.0, max_health)
	
	# Visual Flash & Camera Shake
	has_been_hit()
	
	if camera:
		var shake_intensity = clamp(amount * 0.02, 0.1, 0.5)
		camera.h_offset = randf_range(-shake_intensity, shake_intensity)
		camera.v_offset = randf_range(-shake_intensity, shake_intensity)
	
	# Damage Phases
	if smoke_particles:
		smoke_particles.emitting = current_health <= 60.0 and current_health > 0
	
	if fire_particles:
		fire_particles.emitting = current_health <= 30.0 and current_health > 0
	
	if current_health <= 0:
		die()

func die() -> void:
	if is_dead: return
	is_dead = true
	
	if smoke_particles: smoke_particles.emitting = false
	if fire_particles: fire_particles.emitting = false
	
	if airplane_model:
		airplane_model.visible = false
	
	var explosion_scene = load("res://1_entities/3_objects/1_bullet/Explosion.tscn")
	if explosion_scene:
		var exp = explosion_scene.instantiate()
		get_parent().add_child(exp)
		exp.global_position = global_position
		if exp.has_method("setup"): exp.setup(0.1) 
	
	set_process(false)
	set_physics_process(false)
	
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

func has_been_hit() -> void:
	if hit_indicator and not is_flashing:
		is_flashing = true
		for i in range(5):
			hit_indicator.visible = true
			await get_tree().create_timer(0.1).timeout
			hit_indicator.visible = false
			await get_tree().create_timer(0.1).timeout
		is_flashing = false

func register_aa_in_range(is_inside: bool) -> void:
	if is_inside:
		active_aa_count += 1
	else:
		active_aa_count = max(0, active_aa_count - 1)
	
	if aa_label:
		if active_aa_count > 0:
			aa_label.text = "WARNING: %d ANTI-AIR LOCKING ON!" % active_aa_count
			aa_label.visible = true
		else:
			aa_label.visible = false

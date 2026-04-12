extends Node3D

# --- Movement Settings ---
@export var min_speed: float = 100.0
@export var max_speed: float = 370.0
@export var cruise_speed: float = 250.0
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
var current_speed_kmh: float = 250.0
var active_aa_count: int = 0
var virtual_mouse_offset: Vector2 = Vector2.ZERO
var is_flashing: bool = false

# --- Health System ---
@export var max_health: float = 80.0        # was 60.0 — takes more effort to destroy
var current_health: float = 80.0
var is_dead: bool = false

# --- Energy System ---
@export var max_energy: float = 100.0
var current_energy: float = 100.0
@export var energy_drain: float = 30.0
@export var energy_regen: float = 15.0

# --- Combat Settings ---
@export var bullet_scene: PackedScene = preload("res://1_entities/3_objects/1_bullet/Bullet.tscn")
@export var fire_rate: float = 0.1
var shoot_timer: float = 0.0
var is_boosting: bool = false
@export var boost_multiplier: float = 1.6

# --- Node References ---
var ui_node: Node = null
@onready var speed_label = find_ui_node("SpeedLabel")
@onready var speed_gauge = find_ui_node("SpeedGauge")
@onready var speed_arrow = find_ui_node("SpeedArrow")
@onready var attitude_label = find_ui_node("AttitudeLabel")
@onready var health_bar = find_ui_node("HealthBar")
@onready var energy_bar = find_ui_node("EnergyBar")
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
@onready var shoot_sound = get_node_or_null("ShootSound")
@onready var camera = $Camera3D
@onready var tps_pos = $TPSPos
@onready var top_down_pos = $TopDownPos
@onready var ground = get_tree().root.find_child("Ground", true, false)
@onready var terrain_node = get_tree().get_first_node_in_group("terrain")

func find_ui_node(node_name: String) -> Node:
	if not ui_node:
		ui_node = get_tree().root.find_child("UI", true, false)
	
	if ui_node:
		return ui_node.find_child(node_name, true, false)
	return null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_speed_kmh = cruise_speed
	current_energy = max_energy
	
	if engine_sound and not engine_sound.playing:
		engine_sound.play()
	
	# Procedural Shoot Sound
	if not shoot_sound:
		shoot_sound = AudioStreamPlayer3D.new()
		add_child(shoot_sound)
		shoot_sound.name = "ShootSound"
		var gunshot = AudioStreamWAV.new()
		gunshot.format = AudioStreamWAV.FORMAT_8_BITS
		gunshot.mix_rate = 16000
		var data = PackedByteArray()
		for i in range(2000):
			var val = (randi() % 64 - 32) * (1.0 - float(i)/2000.0)
			data.append(val)
		gunshot.data = data
		shoot_sound.stream = gunshot
		shoot_sound.unit_size = 10.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		frame_mouse_input += event.relative
		virtual_mouse_offset += event.relative
	
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	handle_movement(delta)
	handle_steering(delta)
	handle_combat(delta)
	handle_visuals(delta)
	handle_camera(delta)
	handle_audio(delta)
	update_ui()

func handle_audio(_delta: float) -> void:
	if engine_sound:
		var speed_perc = (current_speed_kmh - min_speed) / (max_speed - min_speed)
		engine_sound.pitch_scale = lerp(0.7, 1.5, speed_perc)

func handle_movement(delta: float) -> void:
	var forward_vector = -global_transform.basis.z
	var pitch_factor = forward_vector.y
	
	is_boosting = Input.is_key_pressed(KEY_SHIFT) and current_energy > 5.0
	
	if is_boosting:
		current_energy -= energy_drain * delta
	else:
		current_energy = move_toward(current_energy, max_energy, energy_regen * delta)
	
	current_energy = clamp(current_energy, 0.0, max_energy)
	
	var target_speed = cruise_speed
	if is_boosting:
		target_speed = max_speed * boost_multiplier
	elif pitch_factor > 0:
		target_speed = lerp(cruise_speed, min_speed, pitch_factor)
	else:
		target_speed = lerp(cruise_speed, max_speed, -pitch_factor)
	
	var accel_rate = 300.0 if is_boosting or pitch_factor < 0 else 80.0
	current_speed_kmh = move_toward(current_speed_kmh, target_speed, accel_rate * delta)
	
	global_translate(forward_vector * (current_speed_kmh / 3.6) * delta)

	# CRASH DETECTION
	if terrain_node and terrain_node.has_method("get_height_at_pos"):
		var check_points = [
			global_position,
			global_position + forward_vector * 5.0,
			global_position + global_transform.basis.x * 3.0,
			global_position - global_transform.basis.x * 3.0
		]
		for p in check_points:
			var terrain_h = terrain_node.get_height_at_pos(p)
			if p.y <= terrain_h + 0.5:
				die()
				break

	if nose_ray and nose_ray.is_colliding():
		die()

	if ground:
		ground.global_position.x = global_position.x
		ground.global_position.z = global_position.z

func handle_combat(delta: float) -> void:
	shoot_timer -= delta
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and shoot_timer <= 0:
		fire_bullet()
		shoot_timer = fire_rate

func fire_bullet() -> void:
	if not bullet_scene: return
	
	if shoot_sound:
		shoot_sound.play()
	
	var b = bullet_scene.instantiate()
	get_parent().add_child(b)
	b.global_transform = global_transform
	b.global_position += -global_transform.basis.z * 5.0
	
	var spread = 0.02
	b.rotate_x(randf_range(-spread, spread))
	b.rotate_y(randf_range(-spread, spread))
	
	if airplane_model:
		var flash = OmniLight3D.new()
		flash.light_color = Color(1, 0.8, 0.2)
		flash.light_energy = 5.0
		flash.omni_range = 10.0
		add_child(flash)
		flash.position = Vector3(0, 0, -2)
		get_tree().create_timer(0.05).timeout.connect(flash.queue_free)

func handle_steering(delta: float) -> void:
	var target_yaw_speed = clamp(-frame_mouse_input.x * sensitivity_x / delta, -max_turn_speed, max_turn_speed)
	var target_pitch_speed = clamp(-frame_mouse_input.y * sensitivity_y / delta, -max_turn_speed, max_turn_speed)
	
	current_turn_speed.x = lerp(current_turn_speed.x, target_yaw_speed, smoothing_speed_x * delta)
	current_turn_speed.y = lerp(current_turn_speed.y, target_pitch_speed, smoothing_speed_y * delta)
	
	rotate_y(deg_to_rad(current_turn_speed.x * delta))
	rotate_object_local(Vector3.RIGHT, deg_to_rad(current_turn_speed.y * delta))
	frame_mouse_input = Vector2.ZERO

func handle_visuals(delta: float) -> void:
	if airplane_model:
		var target_roll = clamp(current_turn_speed.x * -1.0, -max_roll_angle, max_roll_angle)
		var target_pitch = clamp(current_turn_speed.y * -1.0, -max_pitch_angle, max_pitch_angle)
		airplane_model.rotation.z = lerp_angle(airplane_model.rotation.z, deg_to_rad(target_roll), animation_speed * delta)
		airplane_model.rotation.x = lerp_angle(airplane_model.rotation.x, deg_to_rad(target_pitch), animation_speed * delta)

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
		
		# Dynamic FOV based on speed (70 at min, 90 at max)
		var speed_perc = (current_speed_kmh - min_speed) / (max_speed - min_speed)
		var target_fov = lerp(70.0, 95.0, clamp(speed_perc, 0.0, 1.0))
		camera.fov = lerp(camera.fov, target_fov, 2.0 * delta)
		
		if ww2_viewfinder: ww2_viewfinder.visible = is_top_down
		if mouse_crosshair: mouse_crosshair.visible = not is_top_down
		if plane_crosshair: plane_crosshair.visible = not is_top_down

func update_ui() -> void:
	if speed_label:
		speed_label.text = "SPEED: %d KM/H" % int(current_speed_kmh)
		if is_boosting:
			speed_label.text += " [BOOST]"
	
	if speed_arrow:
		# Map speed to gauge. User says visual goes to 400, but plane max is 370.
		# We assume 400 KM/H = 360 degrees.
		var visual_max = 400.0
		var speed_ratio = clamp(current_speed_kmh / visual_max, 0.0, 1.0)
		var target_rotation = speed_ratio * 360.0
		var current_rad = deg_to_rad(speed_arrow.rotation_degrees)
		var target_rad = deg_to_rad(target_rotation)
		speed_arrow.rotation_degrees = rad_to_deg(lerp_angle(current_rad, target_rad, 5.0 * get_process_delta_time()))

	if attitude_label:
		# Pitch in degrees (inverted for intuitive display: nose up is positive)
		var pitch = -global_transform.basis.get_euler().x
		attitude_label.text = "ATTITUDE: %d°" % int(rad_to_deg(pitch))
	
	if health_bar:
		health_bar.value = (current_health / max_health) * 100.0
		
	if energy_bar:
		energy_bar.value = (current_energy / max_energy) * 100.0
		var energy_color = Color(0.2, 0.6, 1.0) if not is_boosting else Color(1.0, 0.8, 0.2)
		energy_bar.modulate = energy_bar.modulate.lerp(energy_color, 5.0 * get_process_delta_time())

	# Warning System (Prioritize DANGER over WARNING)
	if aa_label:
		var terrain_h = get_terrain_height()
		var altitude = global_position.y - terrain_h
		var low_alt = false
		
		if altitude < 100.0:
			low_alt = true
			aa_label.text = "DANGER: LOW ALTITUDE! (%d M)" % int(altitude)
			aa_label.modulate = Color(1.0, 0.2, 0.2)
			aa_label.visible = true
		
		if not low_alt:
			if active_aa_count > 0:
				aa_label.text = "WARNING: %d ANTI-AIR LOCKING ON!" % active_aa_count
				aa_label.modulate = Color(1.0, 0.8, 0.2)
				aa_label.visible = true
			else:
				aa_label.visible = false

func get_terrain_height() -> float:
	# Prioritize TerraBrush (main terrain)
	var terrabrush = get_tree().get_first_node_in_group("terrabrush")
	if not terrabrush:
		terrabrush = get_tree().root.find_child("TerraBrush", true, false)
		
	if terrabrush and terrabrush.has_method("getHeightAtPosition"):
		return terrabrush.getHeightAtPosition(global_position.x, global_position.z, true)
	
	# Fallback to group
	if terrain_node and terrain_node.has_method("get_height_at_pos"):
		return terrain_node.get_height_at_pos(global_position)
	
	return 0.0

func take_damage(amount: float) -> void:
	if is_dead: return
	current_health -= amount
	current_health = clamp(current_health, 0.0, max_health)
	
	var level = get_tree().root.find_child("TutorialLevel", true, false)
	if level and level.has_method("show_dialog"):
		if current_health <= 30.0:
			level.show_dialog("Plane health critically low!")
		else:
			level.show_dialog("We took damage!")
	
	has_been_hit()
	if camera:
		var shake_intensity = clamp(amount * 0.02, 0.1, 0.5)
		camera.h_offset = randf_range(-shake_intensity, shake_intensity)
		camera.v_offset = randf_range(-shake_intensity, shake_intensity)
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
	if airplane_model: airplane_model.visible = false
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
		var level = get_tree().root.find_child("TutorialLevel", true, false)
		if level and level.has_method("show_dialog"):
			level.show_dialog("We have entered enemy anti-air guns range, be careful!")
	else:
		active_aa_count = max(0, active_aa_count - 1)
	
	if aa_label:
		if active_aa_count > 0:
			aa_label.text = "WARNING: %d ANTI-AIR LOCKING ON!" % active_aa_count
			aa_label.visible = true
		else:
			aa_label.visible = false

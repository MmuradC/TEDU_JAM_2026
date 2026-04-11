extends RigidBody3D

@export var engine_power: float = 350.0
@export var lift_coefficient: float = 1.2
@export var mouse_sensitivity: float = 0.0015
@export var turn_speed: float = 20.0
@export var cam_lerp_speed: float = 5.0
@export var high_altitude_threshold: float = 200.0

@onready var recon_ui = $CanvasLayer/AnalysisCanvas # UI yolun
@onready var status_label = $CanvasLayer/AnalysisCanvas/StatusLabel
@onready var photo_rect = $CanvasLayer/AnalysisCanvas/PhotoRect
@onready var result_filter = $CanvasLayer/AnalysisCanvas/ResultOverlay
@onready var thrust_point = $ThrustPoint
@onready var camera = $PlaneCameraControl/PlayerCamera
@onready var world_env = get_viewport().get_camera_3d().get_world_3d().fallback_environment

var current_base_in_range: Node3D = null
var photo_taken: bool = false
var is_base_captured: bool = false # F'ye basıldığı andaki durum
var analysis_timer: float = 10.0
var analysis_active: bool = false
var mouse_input = Vector2.ZERO
var standard_pos = Vector3(0, 5, 15)
var standard_rot = Vector3(deg_to_rad(-10), 0, 0)
var bombing_pos = Vector3(0, -3, 3)
var bombing_rot = Vector3(deg_to_rad(-90), 0, 0)
var boundary_timer: float = 5.0
var is_outside: bool = false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	linear_damp = 0.6
	angular_damp = 5.0

func _input(event):
	if event is InputEventMouseMotion:
		mouse_input.x += event.relative.x * mouse_sensitivity
		mouse_input.y += event.relative.y * mouse_sensitivity
	if event.is_action_pressed("take_photo"):
		take_photo()

func _physics_process(delta):
	var forward_speed = -global_transform.basis.z.dot(linear_velocity)
	
	if Input.is_action_pressed("ui_up"):
		apply_force(global_transform.basis * (Vector3.FORWARD * engine_power), global_transform.basis * thrust_point.position)

	apply_central_force(global_transform.basis.y * clamp(forward_speed, 0, 100) * lift_coefficient)

	var target_basis = Basis().rotated(Vector3.UP, -mouse_input.x).rotated(Vector3.RIGHT, -mouse_input.y)
	var torque = (target_basis * global_transform.basis.inverse()).get_euler() * turn_speed
	apply_torque(torque)

	if Input.is_key_pressed(KEY_D):
		camera.position = camera.position.lerp(bombing_pos, cam_lerp_speed * delta)
		camera.rotation.x = lerp_angle(camera.rotation.x, bombing_rot.x, cam_lerp_speed * delta)
	else:
		camera.position = camera.position.lerp(standard_pos, cam_lerp_speed * delta)
		camera.rotation.x = lerp_angle(camera.rotation.x, standard_rot.x, cam_lerp_speed * delta)
	
	if is_outside:
		boundary_timer -= delta
		if boundary_timer <= 0:
			get_tree().change_scene_to_file("res://3_ui/menus/GameOverMenu.tscn")
	else:
		boundary_timer = 5.0
	
	if photo_taken and global_position.y >= high_altitude_threshold:
		start_analysis(delta)

func take_photo():
	photo_taken = true
	is_base_captured = (current_base_in_range != null)
	
	recon_ui.show()
	photo_rect.self_modulate = Color.BLACK
	status_label.text = "Fotoğraf Çekildi!"
	result_filter.hide()

func start_analysis(delta):
	analysis_active = true
	status_label.text = "Fotoğraf Analiz Ediliyor..."
	analysis_timer -= delta
	
	if analysis_timer <= 0:
		finish_analysis()

func finish_analysis():
	analysis_active = false
	photo_taken = false
	analysis_timer = 10.0
	photo_rect.self_modulate = Color.WHITE # Fotoğraf "görünür" olur
	
	if is_base_captured:
		show_result(true, "Üs bulundu! Bombardıman uçaklarına haber veriliyor...", Color(0, 1, 0, 0.4))
		await get_tree().create_timer(3.0).timeout
		# start_bombing_cutscene()
	else:
		show_result(false, "Üs bulunamadı!", Color(1, 0, 0, 0.4))
		await get_tree().create_timer(3.0).timeout
		recon_ui.hide()

#func start_bombing_cutscene():
	## 1. Kamerayı üsse odakla
	## 2. Patlama efektini oluştur
	#var explosion = preload("res://ExplosionEffect.tscn").instantiate()
	#get_parent().add_child(explosion)
	#explosion.global_position = current_base_in_range.global_position
	#
	## 3. Üssü kaldır
	#current_base_in_range.queue_free()
	#recon_ui.hide()

func show_result(success: bool, msg: String, filter_color: Color):
	status_label.text = msg
	result_filter.color = filter_color
	result_filter.show()

func _on_cloud_area_body_entered(body):
	if body == self:
		var tween = create_tween()
		tween.tween_property(world_env, "volumetric_fog_density", 0.4, 1.5)

func _on_cloud_area_body_exited(body):
	if body == self:
		var tween = create_tween()
		tween.tween_property(world_env, "volumetric_fog_density", 0.0, 1.5)

func _on_map_boundary_body_exited(body):
	if body == self:
		is_outside = true

func _on_map_boundary_body_entered(body):
	if body == self:
		is_outside = false

func _on_base_area_body_entered(body):
	if body == self:
		current_base_in_range = body.get_parent()

func _on_base_area_body_exited(body):
	if body == self:
		current_base_in_range = null

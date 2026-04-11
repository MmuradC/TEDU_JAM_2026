extends Node3D

@export var min_hiz: float = 120.0
@export var max_hiz: float = 700.0
@export var cruise_hiz: float = 400.0
@export var hassasiyet_x: float = 0.1
@export var hassasiyet_y: float = 0.02
@export var ivme_gucu: float = 0.4

# Yumuşatılmış Kontrol Ayarları
@export var max_donus_hizi: float = 60.0 
@export var yumusama_hizi_x: float = 3.0
@export var yumusama_hizi_y: float = 3.0

var mevcut_donus_hizi: Vector2 = Vector2.ZERO
var kare_mouse_input: Vector2 = Vector2.ZERO

# Görsel Efekt Ayarları
@export var max_yatma_acisi: float = 45.0
@export var max_yunuslama_acisi: float = 20.0
@export var animasyon_hizi: float = 5.0
@export var duzelme_hizi: float = 3.0

var mevcut_hiz_kmh: float = 400.0
var hedef_yatma: float = 0.0
var hedef_yunuslama: float = 0.0

# AA Takip Sistemi
var active_aa_count: int = 0

@onready var speed_label = get_node("/root/TutorialLevel/UI/SpeedLabel")
@onready var hit_indicator = get_node("/root/TutorialLevel/UI/HitIndicator")
@onready var aa_label = get_node("/root/TutorialLevel/UI/AALabel")
@onready var ucak_modeli = $bf109
@onready var zemin = get_node("/root/TutorialLevel/Ground")
@onready var mouse_crosshair = get_node("/root/TutorialLevel/UI/MouseCrosshair")
@onready var plane_crosshair = get_node("/root/TutorialLevel/UI/PlaneCrosshair")
@onready var camera = $Camera3D
@onready var tps_pos = $TPSPos
@onready var top_down_pos = $TopDownPos

var virtual_mouse_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mevcut_hiz_kmh = cruise_hiz

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		kare_mouse_input += event.relative
		virtual_mouse_offset += event.relative

func _process(delta: float) -> void:
	# 1. Hız ve Hareket (CONSTANT SPEED)
	mevcut_hiz_kmh = cruise_hiz
	var ileri_vektoru = -global_transform.basis.z
	global_translate(ileri_vektoru * (mevcut_hiz_kmh / 3.6) * delta)

	if zemin:
		zemin.global_position.x = global_position.x
		zemin.global_position.z = global_position.z

	# Update Mouse Crosshair visual (War Thunder style leading)
	virtual_mouse_offset = virtual_mouse_offset.lerp(Vector2.ZERO, 4.0 * delta)

	# CIRCULAR CLAMPING
	var max_radius = 300.0
	if virtual_mouse_offset.length() > max_radius:
		virtual_mouse_offset = virtual_mouse_offset.normalized() * max_radius

	if mouse_crosshair:
		var viewport_center = get_viewport().size / 2
		mouse_crosshair.global_position = Vector2(viewport_center) + virtual_mouse_offset

		# "HARD" TURN EFFECT
		# Calculate intensity based on how close to the edge it is (0.0 to 1.0)
		var intensity = virtual_mouse_offset.length() / max_radius
		var is_hard_turning = intensity > 0.8

		# Change color to red and scale up when turning hard
		var target_color = Color(1, 1, 0) if not is_hard_turning else Color(1, 0, 0) # Yellow to Red
		var target_scale = Vector2.ONE if not is_hard_turning else Vector2(1.5, 1.5)

		mouse_crosshair.modulate = mouse_crosshair.modulate.lerp(target_color, 10.0 * delta)
		mouse_crosshair.scale = mouse_crosshair.scale.lerp(target_scale, 10.0 * delta)
	
	# 2. Camera View Switching (TPS to Top-Down)
	if camera and tps_pos and top_down_pos:
		var target_transform = tps_pos.transform
		if Input.is_key_pressed(KEY_C):
			target_transform = top_down_pos.transform
		
		camera.transform = camera.transform.interpolate_with(target_transform, 5.0 * delta)

	# 3. Update Plane Crosshair visual (follows true forward from model)
	if plane_crosshair and camera and ucak_modeli:
		var forward_3d = ucak_modeli.global_position + (-ucak_modeli.global_transform.basis.z * 1000.0)
		if camera.is_position_behind(forward_3d):
			plane_crosshair.visible = false
		else:
			plane_crosshair.visible = true
			var screen_pos = camera.unproject_position(forward_3d)
			plane_crosshair.global_position = screen_pos

	# 2. Yumuşatılmış Dönüş
	var hedef_yaw_hizi = clamp(-kare_mouse_input.x * hassasiyet_x / delta, -max_donus_hizi, max_donus_hizi)
	var hedef_pitch_hizi = clamp(-kare_mouse_input.y * hassasiyet_y / delta, -max_donus_hizi, max_donus_hizi)
	mevcut_donus_hizi.x = lerp(mevcut_donus_hizi.x, hedef_yaw_hizi, yumusama_hizi_x * delta)
	mevcut_donus_hizi.y = lerp(mevcut_donus_hizi.y, hedef_pitch_hizi, yumusama_hizi_y * delta)
	
	rotate_y(deg_to_rad(mevcut_donus_hizi.x * delta))
	rotate_object_local(Vector3.RIGHT, deg_to_rad(mevcut_donus_hizi.y * delta))
	kare_mouse_input = Vector2.ZERO

	# 3. Görsel Animasyonlar
	if ucak_modeli:
		hedef_yatma = mevcut_donus_hizi.x * -1.0 
		hedef_yunuslama = mevcut_donus_hizi.y * -1.0
		hedef_yatma = clamp(hedef_yatma, -max_yatma_acisi, max_yatma_acisi)
		hedef_yunuslama = clamp(hedef_yunuslama, -max_yunuslama_acisi, max_yunuslama_acisi)
		var rot = ucak_modeli.rotation
		rot.z = lerp_angle(rot.z, deg_to_rad(hedef_yatma), animasyon_hizi * delta)
		rot.x = lerp_angle(rot.x, deg_to_rad(hedef_yunuslama), animasyon_hizi * delta)
		ucak_modeli.rotation = rot

	if speed_label:
		speed_label.text = "Hız: %d km/h" % int(mevcut_hiz_kmh)

	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# DARBE ALMA VE YANIP SÖNME
var is_flashing: bool = false
func has_been_hit() -> void:
	if hit_indicator and not is_flashing:
		is_flashing = true
		for i in range(5):
			hit_indicator.visible = true
			await get_tree().create_timer(0.1).timeout
			hit_indicator.visible = false
			await get_tree().create_timer(0.1).timeout
		is_flashing = false

# AA SAYACI GÜNCELLEME
func register_aa_in_range(is_inside: bool) -> void:
	if is_inside:
		active_aa_count += 1
	else:
		active_aa_count = max(0, active_aa_count - 1)
	
	if aa_label:
		if active_aa_count > 0:
			aa_label.text = "%d ADET ANTI-AIR MENZİLİNDESİNİZ!" % active_aa_count
			aa_label.visible = true
		else:
			aa_label.visible = false

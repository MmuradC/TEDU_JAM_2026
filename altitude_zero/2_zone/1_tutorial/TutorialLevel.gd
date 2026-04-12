extends Node3D

@onready var fade_layer = $UI/FadeLayer
@onready var objective_label = $UI/ObjectiveLabel
@onready var photo_taken_label = $UI/PhotoTakenLabel
@onready var airplane = $AirplaneContainer
@onready var camera = $AirplaneContainer/Camera3D
@onready var plane_crosshair = $UI/PlaneCrosshair
@onready var boundary_warning_label = $UI/BoundaryWarningLabel
@onready var objective_column = $UI/ObjectiveColumn
@onready var shutter_sound = $ShutterSound

var bases_photographed = []
var total_bases = 3
var objective_completed = false

# Boundary & Altitude Settings
var boundary_center = Vector3(0, 0, -1500)
var boundary_size = Vector3(4000, 2500, 4000)
var outside_timer = 5.0
var is_outside = false
var cloud_altitude = 500.0

# Photo State: 0: None, 1: Pending Success, 2: Pending Failure
var photo_status = 0
var pending_base = null

func _ready():
	# Initial UI state
	fade_layer.color = Color.BLACK
	fade_layer.visible = true
	objective_label.visible = false
	photo_taken_label.visible = false
	
	# Procedural Camera Click Sound
	var click = AudioStreamWAV.new()
	click.format = AudioStreamWAV.FORMAT_8_BITS
	click.mix_rate = 22050
	var data = PackedByteArray()
	for i in range(1000):
		# Decaying high frequency noise
		var val = (randi() % 256 - 128) * (1.0 - float(i)/1000.0)
		data.append(val)
	click.data = data
	if shutter_sound: 
		shutter_sound.stream = click
	
	# Fade in from black
	var tween = create_tween()
	tween.tween_property(fade_layer, "color:a", 0.0, 2.0)
	tween.finished.connect(func(): fade_layer.visible = false)

func _process(delta):
	check_boundary(delta)
	check_reveal()
	update_objective_ui()

func check_reveal():
	if photo_status > 0 and airplane.global_position.y > cloud_altitude:
		if photo_status == 1:
			if pending_base and not pending_base in bases_photographed:
				bases_photographed.append(pending_base)
				show_temp_label("TRANSMISSION SUCCESS: ENEMY BASE CONFIRMED!")
			else:
				show_temp_label("TRANSMISSION SKIPPED: ALREADY PHOTOGRAPHED.")
		else:
			show_temp_label("TRANSMISSION FAILED: NO TARGET DETECTED.")
		
		photo_status = 0
		pending_base = null
		
		if bases_photographed.size() >= total_bases:
			complete_objective()

func update_objective_ui():
	if objective_column:
		var status_msg = ""
		if photo_status > 0:
			status_msg = "\n[STATUS: DATA PENDING TRANSMISSION...]"
		elif airplane.global_position.y > cloud_altitude:
			status_msg = "\n[STATUS: DESCEND TO PHOTOGRAPH]"
		else:
			status_msg = "\n[STATUS: SEARCHING TARGETS...]"
			
		objective_column.text = "OBJECTIVE:
- Take photos of 3 enemy bases.
- Must be below clouds (Y < 500) to photograph.
- Climb above clouds (Y > 500) to transmit.

Progress: %d/%d %s" % [bases_photographed.size(), total_bases, status_msg]

func show_temp_label(msg: String):
	photo_taken_label.text = msg
	photo_taken_label.visible = true
	var pt_tween = create_tween()
	pt_tween.tween_interval(3.0)
	pt_tween.finished.connect(func(): photo_taken_label.visible = false)

func check_boundary(delta):
	if not airplane: return
	
	var pos = airplane.global_position
	var half_size = boundary_size / 2.0
	
	var out_x = abs(pos.x - boundary_center.x) > half_size.x
	var out_y = pos.y < 0 or pos.y > boundary_size.y 
	var out_z = abs(pos.z - boundary_center.z) > half_size.z
	
	if out_x or out_y or out_z:
		if not is_outside:
			is_outside = true
			outside_timer = 5.0
			boundary_warning_label.visible = true
		
		outside_timer -= delta
		boundary_warning_label.text = "WARNING, RETURN TO YOUR OBJECTIVE IN %d SECONDS!" % ceil(outside_timer)
		
		if outside_timer <= 0:
			get_tree().reload_current_scene()
	else:
		if is_outside:
			is_outside = false
			boundary_warning_label.visible = false

func _unhandled_input(event):
	if objective_completed:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
			get_tree().reload_current_scene()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		take_photo()

func take_photo():
	if not Input.is_key_pressed(KEY_C):
		print("Photo denied: Must be in Top-Down view (C held).")
		return
		
	if airplane.global_position.y > cloud_altitude:
		show_temp_label("ERROR: DESCEND BELOW CLOUDS TO PHOTOGRAPH")
		return

	if photo_status > 0:
		show_temp_label("ERROR: PREVIOUS DATA PENDING TRANSMISSION")
		return

	# Flash effect & Sound
	var flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	$UI.add_child(flash)
	
	if shutter_sound: 
		shutter_sound.play()
	
	var t = create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.1)
	t.finished.connect(flash.queue_free)

	# Check if we hit a base
	var space_state = get_world_3d().direct_space_state
	var center = get_viewport().size / 2
	var ray_origin = camera.project_ray_origin(center)
	var ray_end = ray_origin + camera.project_ray_normal(center) * 10000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider.is_in_group("photograph_target"):
		photo_status = 1
		pending_base = result.collider
		show_temp_label("PHOTO TAKEN. CLIMB ABOVE CLOUDS TO TRANSMIT.")
	else:
		photo_status = 2
		show_temp_label("PHOTO TAKEN (EMPTY). CLIMB ABOVE CLOUDS TO TRANSMIT.")

func complete_objective():
	objective_completed = true
	objective_label.visible = true

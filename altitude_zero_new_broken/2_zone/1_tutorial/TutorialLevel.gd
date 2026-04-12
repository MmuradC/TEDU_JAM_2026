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

@onready var bases = $Bases.get_children()

var bases_photographed = []
var total_bases = 3
var objective_completed = false

# Boundary & Altitude Settings
var boundary_center = Vector3(256, 0, 256)
var boundary_size = Vector3(512, 1000, 512)
var outside_timer = 5.0
var is_outside = false
var cloud_altitude = 700.0

# Photo State: 0: None, 1: Pending Success, 2: Pending Failure
var photo_status = 0
var pending_base = null

@onready var minimap_container = $UI/MiniMapContainer
@onready var minimap_camera = $UI/MiniMapContainer/SubViewport/MiniMapCamera
@onready var minimap_subviewport = $UI/MiniMapContainer/SubViewport
@onready var base_marker_container = $UI/MiniMapContainer/MiniMapOverlay/BaseContainer
@onready var player_point = $UI/MiniMapContainer/MiniMapOverlay/PlayerPoint
@onready var dialog_frame = $UI/DialogFrame
@onready var dialog_text = $UI/DialogFrame/DialogText

var discovered_map: Image
var discovered_texture: ImageTexture
var fog_rect: ColorRect

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if fade_layer:
		fade_layer.visible = true
		fade_layer.color.a = 1.0
		var tween = create_tween()
		tween.tween_property(fade_layer, "color:a", 0.0, 2.0)
		tween.finished.connect(func(): fade_layer.visible = false)
	
	if player_point:
		player_point.color = Color(0.2, 0.5, 1.0) # Blue point
	
	init_minimap()
	place_bases_on_terrain()
	
	# Initial dialog
	show_dialog("Dive under clouds to explore the enemy territory!")

func init_minimap():
	# Create discovery fog of war
	discovered_map = Image.create(100, 100, false, Image.FORMAT_L8)
	discovered_map.fill(Color.BLACK)
	discovered_texture = ImageTexture.create_from_image(discovered_map)
	
	# Create a fog overlay for the minimap
	fog_rect = ColorRect.new()
	fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat = ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = "shader_type canvas_item;
		uniform sampler2D mask;
		void fragment() {
			float m = texture(mask, UV).r;
			COLOR = vec4(0.1, 0.1, 0.1, 1.0 - m);
		}"
	mat.set_shader_parameter("mask", discovered_texture)
	fog_rect.material = mat
	minimap_subviewport.add_child(fog_rect)
	
	# Spawn base markers (hidden initially)
	for base in $Bases.get_children():
		var marker = ColorRect.new()
		marker.size = Vector2(6, 6)
		marker.color = Color.RED
		marker.visible = false
		marker.set_meta("world_pos", base.global_position)
		base_marker_container.add_child(marker)

func place_bases_on_terrain():
	var terrabrush = get_tree().get_first_node_in_group("terrabrush")
	if not terrabrush:
		terrabrush = find_child("TerraBrush", true, false)
	
	if not terrabrush or not terrabrush.has_method("getHeightAtPosition"):
		return

	# Attempt to find flat spots for each base within [0, 512]
	for i in range(bases.size()):
		var base = bases[i]
		var found_flat = false
		var attempts = 0
		
		while not found_flat and attempts < 100:
			attempts += 1
			var test_pos = Vector2(
				randf_range(50, 462),
				randf_range(50, 462)
			)
			
			if is_area_flat(terrabrush, test_pos):
				var h = terrabrush.getHeightAtPosition(test_pos.x, test_pos.y, true)
				
				if not is_finite(h):
					continue
				
				base.global_position = Vector3(test_pos.x, h, test_pos.y)
				found_flat = true
				print("Placed ", base.name, " at ", base.global_position, " after ", attempts, " attempts.")

func is_area_flat(terrabrush: Node, pos: Vector2) -> bool:
	var h_center = terrabrush.getHeightAtPosition(pos.x, pos.y, true)
	var samples = [
		Vector2(pos.x + 10, pos.y),
		Vector2(pos.x - 10, pos.y),
		Vector2(pos.x, pos.y + 10),
		Vector2(pos.x, pos.y - 10)
	]
	
	for s in samples:
		var h = terrabrush.getHeightAtPosition(s.x, s.y, true)
		if abs(h - h_center) > 1.0: # Tolerance for flatness
			return false
	return true

func _process(delta):
	check_boundary(delta)
	check_reveal()
	update_objective_ui()
	update_minimap(delta)

func show_dialog(text: String, duration: float = 4.0):
	if not dialog_frame or not dialog_text: return
	dialog_text.text = text
	dialog_frame.visible = true
	
	# Stop previous tween if any
	if dialog_frame.has_meta("tween"):
		var prev_tween = dialog_frame.get_meta("tween")
		if prev_tween and prev_tween.is_valid():
			prev_tween.kill()
	
	var tween = create_tween()
	dialog_frame.set_meta("tween", tween)
	tween.tween_interval(duration)
	tween.finished.connect(func(): dialog_frame.visible = false)

func update_minimap(delta):
	if not airplane: return
	
	# Follow player position but static rotation (North up)
	minimap_camera.global_position = Vector3(airplane.global_position.x, 2000, airplane.global_position.z)
	minimap_camera.rotation.y = 0
	
	# Update discovery
	var map_size = boundary_size.x
	var ux = (airplane.global_position.x / map_size) * 100.0
	var uy = (airplane.global_position.z / map_size) * 100.0
	
	# Draw discovery circle on Image
	var radius = 5
	for i in range(-radius, radius):
		for j in range(-radius, radius):
			if Vector2(i,j).length() < radius:
				var px = clamp(int(ux + i), 0, 99)
				var py = clamp(int(uy + j), 0, 99)
				discovered_map.set_pixel(px, py, Color.WHITE)
	
	discovered_texture.update(discovered_map)
	
	# Update Base Markers
	var cam_size = minimap_camera.size
	for marker in base_marker_container.get_children():
		var world_pos = marker.get_meta("world_pos")
		
		# Check discovery (is pixel white?)
		var mx = clamp(int((world_pos.x / map_size) * 100.0), 0, 99)
		var mz = clamp(int((world_pos.z / map_size) * 100.0), 0, 99)
		if discovered_map.get_pixel(mx, mz).r > 0.5:
			marker.visible = true
			
		# Position marker on static minimap
		var rel_pos = world_pos - airplane.global_position
		var vec2_rel = Vector2(rel_pos.x, rel_pos.z)
		# No rotation transformation anymore for North-up map
		
		var gui_pos = (vec2_rel / cam_size) * 200.0 + Vector2(100, 100)
		marker.position = gui_pos - marker.size/2.0
		
		# Clip if outside minimap bounds
		marker.visible = marker.visible and (gui_pos.x >= 0 and gui_pos.x <= 200 and gui_pos.y >= 0 and gui_pos.y <= 200)

func check_reveal():
	if photo_status > 0 and airplane.global_position.y > cloud_altitude:
		if photo_status == 1:
			if pending_base and not pending_base in bases_photographed:
				bases_photographed.append(pending_base)
				show_dialog("Photo secured. Climb to a safe altitude to transmit data to the bombers.")
			else:
				show_temp_label("TRANSMISSION SKIPPED: ALREADY PHOTOGRAPHED.")
		else:
			show_temp_label("TRANSMISSION FAILED: NO TARGET DETECTED.")
		
		photo_status = 0
		pending_base = null
		
		if bases_photographed.size() >= total_bases:
			complete_objective()

func complete_objective():
	objective_completed = true
	objective_label.visible = true
	show_dialog("Mission completed, good job Kamerad!")

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
- TAKE PHOTOS OF 3 ENEMY BASES.
- MUST BE BELOW CLOUDS (Y < 700) TO PHOTOGRAPH.
- CLIMB ABOVE CLOUDS (Y > 700) TO TRANSMIT.

PROGRESS: %d/%d %s" % [bases_photographed.size(), total_bases, status_msg]

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

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		take_photo()

func take_photo():
	if not Input.is_key_pressed(KEY_C):
		show_temp_label("ERROR: MUST BE IN TOP-DOWN VIEW (HOLD 'C')")
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
	var center = get_viewport().get_visible_rect().size / 2.0
	var ray_origin = camera.project_ray_origin(center)
	var ray_end = ray_origin + camera.project_ray_normal(center) * 10000.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = true # Also check bodies (TerraBrush might use bodies)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		print("PHOTO RAY HIT: ", result.collider.name, " groups: ", result.collider.get_groups())
		var is_target = result.collider.is_in_group("photograph_target") or "hq" in result.collider.name.to_lower()
		
		if is_target:
			photo_status = 1
			pending_base = result.collider
			show_temp_label("PHOTO TAKEN. CLIMB ABOVE CLOUDS TO TRANSMIT.")
		else:
			photo_status = 2
			show_temp_label("PHOTO TAKEN (EMPTY). CLIMB ABOVE CLOUDS TO TRANSMIT.")
	else:
		print("PHOTO RAY MISSED EVERYTHING")
		photo_status = 2
		show_temp_label("PHOTO TAKEN (EMPTY). CLIMB ABOVE CLOUDS TO TRANSMIT.")

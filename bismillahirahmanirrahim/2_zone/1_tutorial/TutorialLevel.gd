extends Node3D

@onready var fade_layer = $UI/FadeLayer
@onready var objective_label = $UI/ObjectiveLabel
@onready var photo_taken_label = $UI/PhotoTakenLabel
@onready var airplane = $AirplaneContainer
@onready var camera = $AirplaneContainer/Camera3D
@onready var plane_crosshair = $UI/PlaneCrosshair
@onready var boundary_warning_label = $UI/BoundaryWarningLabel

var bases_photographed = []
var total_bases = 3
var objective_completed = false

# Boundary Settings
var boundary_center = Vector3(0, 0, -1500)
var boundary_size = Vector3(4000, 2500, 4000)
var outside_timer = 5.0
var is_outside = false

func _ready():
	# Initial UI state
	fade_layer.color = Color.BLACK
	fade_layer.visible = true
	objective_label.visible = false
	photo_taken_label.visible = false
	
	# Fade in from black
	var tween = create_tween()
	tween.tween_property(fade_layer, "color:a", 0.0, 2.0)
	tween.finished.connect(func(): fade_layer.visible = false)

func _process(delta):
	check_boundary(delta)

func check_boundary(delta):
	if not airplane: return
	
	var pos = airplane.global_position
	var half_size = boundary_size / 2.0
	
	var out_x = abs(pos.x - boundary_center.x) > half_size.x
	var out_y = pos.y < 0 or pos.y > boundary_size.y # Assuming ground is 0
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

	# Flash effect
	var flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	$UI.add_child(flash)
	var t = create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.1)
	t.finished.connect(flash.queue_free)

	# Show "Photo is taken." popup
	photo_taken_label.visible = true
	var pt_tween = create_tween()
	pt_tween.tween_interval(2.0)
	pt_tween.finished.connect(func(): photo_taken_label.visible = false)

	# Check if we hit a base
	var space_state = get_world_3d().direct_space_state
	# In top-down mode, use the exact center of the screen
	var center = get_viewport().size / 2
	var ray_origin = camera.project_ray_origin(center)
	var ray_end = ray_origin + camera.project_ray_normal(center) * 10000.0 # High altitude reach
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var result = space_state.intersect_ray(query)
	
	if result:
		print("Ray hit: ", result.collider.name, " in groups: ", result.collider.get_groups())
		if result.collider.is_in_group("photograph_target"):
			var base = result.collider
			if not base in bases_photographed:
				bases_photographed.append(base)
				print("Base photographed! Total: ", bases_photographed.size())
				
				if bases_photographed.size() >= total_bases:
					complete_objective()
	else:
		print("Photo taken, but no base detected.")

func complete_objective():
	objective_completed = true
	objective_label.visible = true

extends Node3D

@onready var fade_layer = $UI/FadeLayer
@onready var photo_frame = $UI/PhotoFrame
@onready var objective_label = $UI/ObjectiveLabel
@onready var airplane = $AirplaneContainer
@onready var camera = $AirplaneContainer/Camera3D
@onready var plane_crosshair = $UI/PlaneCrosshair

var bases_photographed = []
var total_bases = 3
var objective_completed = false

func _ready():
	# Initial UI state
	fade_layer.color = Color.BLACK
	fade_layer.visible = true
	objective_label.visible = false
	
	# Fade in from black
	var tween = create_tween()
	tween.tween_property(fade_layer, "color:a", 0.0, 2.0)
	tween.finished.connect(func(): fade_layer.visible = false)

func _unhandled_input(event):
	if objective_completed:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
			get_tree().reload_current_scene()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		take_photo()

func take_photo():
	# Flash effect
	var flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	$UI.add_child(flash)
	var t = create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.1)
	t.finished.connect(flash.queue_free)

	# Capture the screen
	await get_tree().process_frame
	var image = get_viewport().get_texture().get_image()
	var texture = ImageTexture.create_from_image(image)
	photo_frame.texture = texture
	
	# Check if we hit a base
	var space_state = get_world_3d().direct_space_state
	# Use the plane crosshair position for the raycast origin
	var aim_pos = plane_crosshair.global_position
	var ray_origin = camera.project_ray_origin(aim_pos)
	var ray_end = ray_origin + camera.project_ray_normal(aim_pos) * 5000.0 # Increased range
	
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

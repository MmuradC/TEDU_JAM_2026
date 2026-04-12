@tool
extends MeshInstance3D

@export var height_scale: float = 0.0:
	set(v):
		height_scale = v
		_sync_shader_params()

@export var map_size: float = 10000.0:
	set(v):
		map_size = v
		_sync_shader_params()

func _ready():
	_sync_shader_params()
	if not Engine.is_editor_hint():
		add_to_group("terrain")

func _sync_shader_params():
	var mat = get_surface_override_material(0)
	if not mat:
		mat = get_active_material(0)
	
	if mat and mat is ShaderMaterial:
		mat.set_shader_parameter("height_scale", 0.0)
		mat.set_shader_parameter("map_size", map_size)

func get_height_at_pos(_world_pos: Vector3) -> float:
	return global_position.y

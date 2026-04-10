extends RigidBody3D

@export var engine_power: float = 150.0  
@export var pitch_speed: float = 3.0     
@export var roll_speed: float = 3.0      

@onready var thrust_point = $ThrustPoint
@onready var ground_sensor = $GroundSensor

func _ready():
	gravity_scale = 0.5 

func _physics_process(delta):
	if Input.is_action_pressed("ui_up"):
		var local_force = Vector3.FORWARD * engine_power
		var global_force = global_transform.basis * local_force
		var global_pos_offset = global_transform.basis * thrust_point.position
		
		apply_force(global_force, global_pos_offset)

	var pitch_input = Input.get_axis("ui_down", "ui_up") 
	var roll_input = Input.get_axis("ui_right", "ui_left") 
	
	var local_torque = Vector3.ZERO
	local_torque.x = pitch_input * pitch_speed  
	local_torque.z = roll_input * roll_speed    
	
	var global_torque = global_transform.basis * local_torque
	
	apply_torque(global_torque)

	if ground_sensor.is_colliding():
		var hit_point = ground_sensor.get_collision_point()
		var distance = global_position.distance_to(hit_point)

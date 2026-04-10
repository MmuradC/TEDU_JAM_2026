extends RigidBody3D

@export var engine_power: float = 250.0
@export var lift_coefficient: float = 0.8
@export var pitch_speed: float = 4.0
@export var roll_speed: float = 10.0

@onready var thrust_point = $ThrustPoint

func _ready():
	gravity_scale = 1.0
	contact_monitor = true
	max_contacts_reported = 1

func _physics_process(delta):
	var forward_speed = -global_transform.basis.z.dot(linear_velocity)
	
	if Input.is_action_pressed("ui_up"):
		var global_force = global_transform.basis * (Vector3.FORWARD * engine_power)
		var global_pos_offset = global_transform.basis * thrust_point.position
		apply_force(global_force, global_pos_offset)

	var lift_magnitude = clamp(forward_speed, 0, 100) * lift_coefficient
	var lift_force = global_transform.basis.y * lift_magnitude
	apply_central_force(lift_force)

	var pitch_input = Input.get_axis("ui_down", "ui_up")
	var roll_input = Input.get_axis("ui_right", "ui_left")
	
	var local_torque = Vector3.ZERO
	local_torque.x = pitch_input * pitch_speed
	local_torque.z = roll_input * roll_speed
	
	apply_torque(global_transform.basis * local_torque)
	
	if forward_speed > 10:
		var banking_torque = -roll_input * forward_speed * 0.05
		apply_torque(global_transform.basis.y * banking_torque)

extends RigidBody3D

# Ayarlanabilir Değişkenler (Inspector panelinden değiştirebilirsin)
@export var engine_power: float = 150.0  # Motorun itiş gücü
@export var pitch_speed: float = 3.0     # Burnunu aşağı/yukarı eğme hızı
@export var roll_speed: float = 3.0      # Sağa/sola yatma hızı

# Düğümleri (Node) Koda Tanımlama
@onready var thrust_point = $ThrustPoint
@onready var ground_sensor = $GroundSensor

func _ready():
	gravity_scale = 0.5 

func _physics_process(delta):
	if Input.is_action_pressed("ui_up"):
		var force_direction = Vector3.FORWARD * engine_power
		apply_local_force(force_direction, thrust_point.position)

	var pitch_input = Input.get_axis("ui_down", "ui_up") 
	var roll_input = Input.get_axis("ui_right", "ui_left") 
	
	var torque = Vector3.ZERO
	torque.x = pitch_input * pitch_speed
	torque.z = roll_input * roll_speed
	
	apply_local_torque(torque)

	if ground_sensor.is_colliding():
		var hit_point = ground_sensor.get_collision_point()
		var distance = global_position.distance_to(hit_point)

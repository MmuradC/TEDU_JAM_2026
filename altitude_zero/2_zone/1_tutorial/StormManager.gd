extends Node

@export var sun_node: DirectionalLight3D
@export var flash_rect: ColorRect
@export var min_interval: float = 10.0
@export var max_interval: float = 30.0

var thunder_sound: AudioStreamPlayer
var timer: float = 0.0
var next_strike: float = 0.0

func _ready():
	# Setup procedural thunder sound
	thunder_sound = AudioStreamPlayer.new()
	add_child(thunder_sound)
	thunder_sound.volume_db = 0.0
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 11025
	var data = PackedByteArray()
	for i in range(22050): # 2 seconds
		# Low frequency rumble + noise
		var envelope = pow(1.0 - float(i)/22050.0, 2.0)
		var val = (randi() % 64 - 32) + (sin(float(i) * 0.1) * 64.0)
		data.append(int(clamp(val * envelope, -128, 127)))
	stream.data = data
	thunder_sound.stream = stream
	
	next_strike = randf_range(min_interval, max_interval)

func _process(delta):
	timer += delta
	if timer >= next_strike:
		strike()
		timer = 0.0
		next_strike = randf_range(min_interval, max_interval)

func strike():
	if not sun_node: return
	
	# Visual Flash (Light)
	var original_energy = sun_node.light_energy
	var t = create_tween()
	t.tween_property(sun_node, "light_energy", original_energy * 5.0, 0.05)
	t.tween_property(sun_node, "light_energy", original_energy, 0.2)
	
	# Visual Flash (Screen)
	if flash_rect:
		flash_rect.color.a = 0.5
		flash_rect.visible = true
		var t2 = create_tween()
		t2.tween_property(flash_rect, "color:a", 0.0, 0.3)
		t2.finished.connect(func(): if is_instance_valid(flash_rect): flash_rect.visible = false)
	
	# Sound (delayed slightly for realism)
	get_tree().create_timer(randf_range(0.1, 0.5)).timeout.connect(func():
		if is_instance_valid(thunder_sound): thunder_sound.play()
	)

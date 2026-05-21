import os

file_path = "altitude_zero/1_entities/1_airplane/Airplane.gd"
with open(file_path, "r") as f:
    content = f.read()

# 1. Visual Multiplier
content = content.replace(
    'var visual_multiplier = 1.0 # Adjusted to 1.0 for realistic scale',
    'var visual_multiplier = 2.5 # Adjusted from 1.0 to feel much faster'
)

# 2. Smoothing speed
content = content.replace('smoothing_speed_x: float = 4.0', 'smoothing_speed_x: float = 12.0')
content = content.replace('smoothing_speed_y: float = 4.0', 'smoothing_speed_y: float = 12.0')

# 3. Cam speed
content = content.replace(
    'var cam_speed = 3.0 if not is_top_down else 5.0',
    'var cam_speed = 15.0 if not is_top_down else 10.0'
)

# 4. Energy drain
content = content.replace('turn_intensity * 25.0 * delta', 'turn_intensity * 12.0 * delta')
content = content.replace('max_energy, 20.0 * delta', 'max_energy, 25.0 * delta')
content = content.replace('current_energy < 25.0', 'current_energy < 15.0')
content = content.replace('lerp(0.3, 1.0, current_energy / 25.0)', 'lerp(0.5, 1.0, current_energy / 15.0)')

# 5. Speed arrow
speed_arrow_old = """		# Mapping speed to a full circular gauge (0 to 400 km/h)
		var speed_perc = clamp(current_speed_kmh / 400.0, 0.0, 1.0)
		speed_arrow.rotation_degrees = speed_perc * 360.0"""
speed_arrow_new = """		# Mapping speed to a full circular gauge (0 to 400 km/h)
		var speed_perc = clamp(current_speed_kmh / 400.0, 0.0, 1.0)
		if "pivot_offset" in speed_arrow and speed_arrow.size != Vector2.ZERO:
			speed_arrow.pivot_offset = speed_arrow.size / 2.0
		if "rotation" in speed_arrow:
			speed_arrow.rotation = speed_perc * TAU
		else:
			speed_arrow.rotation_degrees = speed_perc * 360.0"""
content = content.replace(speed_arrow_old, speed_arrow_new)

# 6. Hit alarm
ready_old = """func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_speed_kmh = cruise_speed
	
	# Tune camera markers for a better "size" feel (Closer to the plane)"""
ready_new = """var hit_alarm_player: AudioStreamPlayer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_speed_kmh = cruise_speed
	
	hit_alarm_player = AudioStreamPlayer.new()
	add_child(hit_alarm_player)
	var alarm_stream = AudioStreamWAV.new()
	alarm_stream.format = AudioStreamWAV.FORMAT_8_BITS
	alarm_stream.mix_rate = 11025
	var data = PackedByteArray()
	for i in range(5000):
		var val = int(sin(float(i) * 0.1) * 127.0)
		data.append(clamp(val, -128, 127))
	alarm_stream.data = data
	hit_alarm_player.stream = alarm_stream
	hit_alarm_player.volume_db = 10.0 # Make it loud
	
	# Tune camera markers for a better "size" feel (Closer to the plane)"""
content = content.replace(ready_old, ready_new)

hit_old = """func has_been_hit() -> void:
	if hit_indicator and not is_flashing:"""
hit_new = """func has_been_hit() -> void:
	if hit_alarm_player: hit_alarm_player.play()
	if hit_indicator and not is_flashing:"""
content = content.replace(hit_old, hit_new)

with open(file_path, "w") as f:
    f.write(content)


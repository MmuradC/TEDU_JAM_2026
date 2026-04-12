extends Node3D

var delay_time: float = 0.0
var time_left: float = 0.0
var is_active: bool = false

@onready var target_marker = $TargetMarker
@onready var explosion_visual = $ExplosionVisual

var boom_player: AudioStreamPlayer3D

func _ready():
	boom_player = AudioStreamPlayer3D.new()
	add_child(boom_player)
	boom_player.unit_size = 10.0
	boom_player.max_distance = 1000.0

	var boom = AudioStreamWAV.new()
	boom.format = AudioStreamWAV.FORMAT_8_BITS
	boom.mix_rate = 8000
	var data = PackedByteArray()
	for i in range(8000):
		var noise = (randi() % 256 - 128)
		var envelope = pow(1.0 - float(i) / 8000.0, 3.0)
		data.append(int(noise * envelope))
	boom.data = data
	boom_player.stream = boom

func setup(delay: float) -> void:
	delay_time = delay
	time_left = delay
	is_active = true

	if target_marker:
		target_marker.visible = true
		var mat = target_marker.get_active_material(0).duplicate()
		target_marker.set_surface_override_material(0, mat)
		mat.albedo_color.a = 0.0

	if explosion_visual:
		explosion_visual.visible = false

func _process(delta: float) -> void:
	if not is_active: return

	time_left -= delta

	if target_marker and delay_time > 0:
		var progress = 1.0 - (time_left / delay_time)
		var mat = target_marker.get_active_material(0)
		mat.albedo_color.a = clamp(progress, 0.0, 1.0)
		mat.emission_energy_multiplier = progress * 5.0

	if time_left <= 0:
		explode()

func explode() -> void:
	is_active = false

	if target_marker: target_marker.visible = false
	if explosion_visual: explosion_visual.visible = true

	if boom_player:
		boom_player.play()

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var blast_radius = 10.0
		var max_damage = 20.0
		var distance = global_position.distance_to(player.global_position)

		if distance <= blast_radius:
			var damage_factor = pow(1.0 - (distance / blast_radius), 2.0)
			var damage = max_damage * damage_factor

			if player.has_method("take_damage"):
				player.take_damage(damage)
			elif player.has_method("has_been_hit"):
				player.has_been_hit()

	await get_tree().create_timer(1.0).timeout
	queue_free()

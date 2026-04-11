extends Node3D

var gecikme_suresi: float = 0.0
var kalan_sure: float = 0.0
var aktif: bool = false

@onready var marker = $TargetMarker
@onready var visual_sphere = $ExplosionVisual

func setup(delay: float) -> void:
	gecikme_suresi = delay
	kalan_sure = delay
	aktif = true
	
	if marker:
		marker.visible = true
		# Materyali her bomba için benzersiz yapalım ki birbirlerini etkilemesinler
		var mat = marker.get_active_material(0).duplicate()
		marker.set_surface_override_material(0, mat)
		# Başlangıçta tamamen şeffaf yap
		mat.albedo_color.a = 0.0
	
	if visual_sphere: 
		visual_sphere.visible = false

func _process(delta: float) -> void:
	if not aktif: return
	
	kalan_sure -= delta
	
	# Opacity (Alpha) hesapla: 0'dan 1'e doğru artsın
	if marker and gecikme_suresi > 0:
		var ilerleme = 1.0 - (kalan_sure / gecikme_suresi)
		var mat = marker.get_active_material(0)
		mat.albedo_color.a = clamp(ilerleme, 0.0, 1.0)
		# Işımayı da (emission) aynı oranda artıralım ki daha belirgin olsun
		mat.emission_energy_multiplier = ilerleme * 5.0
	
	if kalan_sure <= 0:
		patla()

func patla() -> void:
	aktif = false
	
	if marker: marker.visible = false
	if visual_sphere: visual_sphere.visible = true
	
	var ucak = get_tree().get_first_node_in_group("player")
	if ucak:
		var mesafe = global_position.distance_to(ucak.global_position)
		if mesafe <= 10.0: 
			if ucak.has_method("has_been_hit"):
				ucak.has_been_hit()
	
	await get_tree().create_timer(0.5).timeout
	queue_free()

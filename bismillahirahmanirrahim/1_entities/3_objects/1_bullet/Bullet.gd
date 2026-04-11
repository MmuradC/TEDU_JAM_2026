extends Area3D

@export var hiz: float = 150.0
@export var omur: float = 4.0

func _ready() -> void:
	# 4 saniye sonra mermiyi temizle
	get_tree().create_timer(omur).timeout.connect(queue_free)
	# Çarpışma sinyalini kodla bağlayalım
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	# Mermiyi ileri götür
	global_translate(-global_transform.basis.z * hiz * delta)

func _on_area_entered(area: Area3D) -> void:
	# Uçağın hitbox'ına çarptığını kontrol et
	var ucak = area.get_parent()
	if ucak and ucak.has_method("has_been_hit"):
		print("--- DARBE TESPİT EDİLDİ ---")
		ucak.has_been_hit()
	
	# Mermi herhangi bir alana girdiğinde yok olmalı
	queue_free()

extends StaticBody3D

@export var min_ates_hizi: float = 2.0 
@export var max_ates_hizi: float = 4.0 
@export var donus_hizi: float = 5.0 
@export var menzil: float = 800.0 # Menzil sınırı geri geldi
@export var sapma_miktari_limit: float = 40.0 # Max sapma

var hedef: Node3D = null
var su_an_menzilde_mi: bool = false
var zamanlayici: float = 0.0
var mevcut_bekleme_suresi: float = 3.0

@onready var turret = $Turret 
@onready var muzzle_flash = $Turret/Muzzle/MuzzleFlash
@onready var shoot_sound = $ShootSound
var explosion_scene = preload("res://Explosion.tscn")

func _ready() -> void:
	hedef = get_tree().get_first_node_in_group("player")
	mevcut_bekleme_suresi = randf_range(min_ates_hizi, max_ates_hizi)
	zamanlayici = mevcut_bekleme_suresi
	
	var beep = AudioStreamWAV.new()
	beep.format = AudioStreamWAV.FORMAT_8_BITS
	beep.mix_rate = 16000
	var data = PackedByteArray()
	for i in range(2400):
		data.append(127 if (i / 8) % 2 == 0 else -128)
	beep.data = data
	shoot_sound.stream = beep

func _process(delta: float) -> void:
	if not hedef: return
	
	var anlik_mesafe = global_position.distance_to(hedef.global_position)
	
	if anlik_mesafe <= menzil:
		if not su_an_menzilde_mi:
			su_an_menzilde_mi = true
			if hedef.has_method("register_aa_in_range"): hedef.register_aa_in_range(true)
		
		var hedef_transform = turret.global_transform.looking_at(hedef.global_position, Vector3.UP)
		turret.global_transform = turret.global_transform.interpolate_with(hedef_transform, donus_hizi * delta)
		
		zamanlayici += delta
		if zamanlayici >= mevcut_bekleme_suresi:
			ates_et(anlik_mesafe)
			zamanlayici = 0.0
			mevcut_bekleme_suresi = randf_range(min_ates_hizi, max_ates_hizi)
	else:
		if su_an_menzilde_mi:
			su_an_menzilde_mi = false
			if hedef.has_method("register_aa_in_range"): hedef.register_aa_in_range(false)
		muzzle_flash.visible = false
		zamanlayici = mevcut_bekleme_suresi

func ates_et(dist: float) -> void:
	muzzle_flash.visible = true
	shoot_sound.play()
	get_tree().create_timer(0.1).timeout.connect(func(): muzzle_flash.visible = false)
	
	# --- GERÇEK MESAFEYE BAĞLI HESAPLAMA ---
	# Mesafe ölçekle (0-800 arası -> 300-800 arası)
	var hesaplanan_mesafe = remap(clamp(dist, 0, 800), 0, 800, 300, 800)
	var a_saniyesi = hesaplanan_mesafe / 300.0
	
	var ucak_hizi_ms = hedef.mevcut_hiz_kmh / 3.6
	var sim_pos = hedef.global_position
	var sim_basis = hedef.global_transform.basis
	var adim_dt = a_saniyesi / 10.0
	
	for i in range(10):
		sim_basis = Basis(Vector3.UP, deg_to_rad(hedef.mevcut_donus_hizi.x * adim_dt)) * sim_basis
		sim_basis = sim_basis.rotated(sim_basis.x, deg_to_rad(hedef.mevcut_donus_hizi.y * adim_dt))
		sim_pos += -sim_basis.z * ucak_hizi_ms * adim_dt
	
	# Dinamik Sapma
	var aa_sayisi = hedef.active_aa_count
	var dinamik_sapma = remap(clamp(aa_sayisi, 1, 30), 1, 30, 0, sapma_miktari_limit)
	
	var sapma_vektoru = Vector3(
		randf_range(-dinamik_sapma, dinamik_sapma),
		randf_range(-dinamik_sapma, dinamik_sapma),
		randf_range(-dinamik_sapma, dinamik_sapma)
	)
	var final_nokta = sim_pos + sapma_vektoru
	
	var exp = explosion_scene.instantiate()
	get_parent().add_child(exp)
	exp.global_position = final_nokta
	exp.setup(a_saniyesi)

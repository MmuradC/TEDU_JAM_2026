extends Node3D

@export var min_hiz: float = 120.0
@export var max_hiz: float = 700.0
@export var cruise_hiz: float = 400.0
@export var hassasiyet_x: float = 0.1
@export var hassasiyet_y: float = 0.02
@export var ivme_gucu: float = 0.4

# Dönüş Kapasitesi Ayarları
@export var min_donus_hizi: float = 40.0  # 120 km/h hızdaki dönüş (Derece/Saniye)
@export var max_donus_hizi: float = 100.0 # 700 km/h hızdaki dönüş (Derece/Saniye)
@export var yumusama_hizi_x: float = 3.0
@export var yumusama_hizi_y: float = 3.0

var mevcut_donus_hizi: Vector2 = Vector2.ZERO
var kare_mouse_input: Vector2 = Vector2.ZERO

# Görsel Efekt Ayarları
@export var max_yatma_acisi: float = 45.0
@export var max_yunuslama_acisi: float = 20.0
@export var animasyon_hizi: float = 5.0
@export var duzelme_hizi: float = 3.0

var mevcut_hiz_kmh: float = 400.0
var hedef_yatma: float = 0.0
var hedef_yunuslama: float = 0.0

@onready var speed_label = get_node("../UI/SpeedLabel")
@onready var ucak_modeli = get_node("bf109")
@onready var zemin = get_node("../Ground")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mevcut_hiz_kmh = cruise_hiz

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		kare_mouse_input += event.relative
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_A:
			mevcut_hiz_kmh = 700.0
		if event.keycode == KEY_S:
			mevcut_hiz_kmh = 120.0

func _process(delta: float) -> void:
	# 1. Hız ve Hareket
	var ileri_vektoru = -global_transform.basis.z
	var egim = ileri_vektoru.y
	var hedef_hiz_kmh = lerp(cruise_hiz, min_hiz, egim) if egim > 0 else lerp(cruise_hiz, max_hiz, -egim)
	var fark = hedef_hiz_kmh - mevcut_hiz_kmh
	var ivme_faktor = clamp((max_hiz - mevcut_hiz_kmh) / (max_hiz - min_hiz) if fark > 0 else (mevcut_hiz_kmh - min_hiz) / (max_hiz - min_hiz), 0.05, 1.0)
	
	mevcut_hiz_kmh += fark * ivme_faktor * ivme_gucu * delta
	mevcut_hiz_kmh = clamp(mevcut_hiz_kmh, min_hiz, max_hiz)
	
	global_translate(ileri_vektoru * (mevcut_hiz_kmh / 3.6) * delta)

	if zemin:
		zemin.global_position.x = global_position.x
		zemin.global_position.z = global_position.z

	# 2. Hıza Bağlı Yumuşatılmış Dönüş
	# Hız oranına göre (0 ile 1 arası) dönüş hızını hesapla (remap mantığı)
	var t = (mevcut_hiz_kmh - min_hiz) / (max_hiz - min_hiz)
	var su_anki_donus_kapasitesi = lerp(min_donus_hizi, max_donus_hizi, t)
	
	var hedef_yaw_hizi = clamp(-kare_mouse_input.x * hassasiyet_x / delta, -su_anki_donus_kapasitesi, su_anki_donus_kapasitesi)
	var hedef_pitch_hizi = clamp(-kare_mouse_input.y * hassasiyet_y / delta, -su_anki_donus_kapasitesi, su_anki_donus_kapasitesi)
	
	mevcut_donus_hizi.x = lerp(mevcut_donus_hizi.x, hedef_yaw_hizi, yumusama_hizi_x * delta)
	mevcut_donus_hizi.y = lerp(mevcut_donus_hizi.y, hedef_pitch_hizi, yumusama_hizi_y * delta)
	
	rotate_y(deg_to_rad(mevcut_donus_hizi.x * delta))
	rotate_object_local(Vector3.RIGHT, deg_to_rad(mevcut_donus_hizi.y * delta))
	
	kare_mouse_input = Vector2.ZERO

	# 3. Görsel Animasyonlar
	if ucak_modeli:
		hedef_yatma = mevcut_donus_hizi.x * -1.0 
		hedef_yunuslama = mevcut_donus_hizi.y * -1.0
		hedef_yatma = clamp(hedef_yatma, -max_yatma_acisi, max_yatma_acisi)
		hedef_yunuslama = clamp(hedef_yunuslama, -max_yunuslama_acisi, max_yunuslama_acisi)
		var rot = ucak_modeli.rotation
		rot.z = lerp_angle(rot.z, deg_to_rad(hedef_yatma), animasyon_hizi * delta)
		rot.x = lerp_angle(rot.x, deg_to_rad(hedef_yunuslama), animasyon_hizi * delta)
		ucak_modeli.rotation = rot

	if speed_label:
		speed_label.text = "Hız: %d km/h" % int(mevcut_hiz_kmh)

	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

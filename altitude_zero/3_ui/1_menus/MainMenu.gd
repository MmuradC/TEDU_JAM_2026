extends Control

@onready var start_button = $CenterContainer/VBoxContainer/StartButton
@onready var options_button = $CenterContainer/VBoxContainer/OptionsButton
@onready var quit_button = $CenterContainer/VBoxContainer/QuitButton
@onready var options_menu = $OptionsMenu
@onready var music_player = $AudioStreamPlayer

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if options_menu:
		options_menu.visible = false
	if start_button:
		start_button.grab_focus()

	# Initialize Volume Slider
	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus != -1:
		var volume_db = AudioServer.get_bus_volume_db(master_bus)
		var slider = get_node_or_null("OptionsMenu/VBoxContainer/VolumeSlider")
		if slider:
			slider.value = db_to_linear(volume_db) * 100.0

	# Start background music
	if music_player and not music_player.playing:
		music_player.play()
	
	# Web compatibility: Ensure VideoStreamPlayer is handled
	var video_player = get_node_or_null("BackgroundGIF")
	if video_player and video_player is VideoStreamPlayer:
		if OS.get_name() == "Web":
			# Some browsers require user interaction before video/audio
			# We'll try to play, but it might only start after a click
			video_player.play()

func _on_start_button_pressed():
	var global = get_node_or_null("/root/GlobalState")
	if global:
		global.play_cutscene("res://3_ui/4_cutscene/beginning.ogv", "res://2_zone/1_tutorial/TutorialLevel.tscn")
	else:
		get_tree().change_scene_to_file("res://2_zone/1_tutorial/TutorialLevel.tscn")

func _on_options_button_pressed():
	options_menu.visible = true
	$CenterContainer.visible = false
	$Logo.visible = false

func _on_quit_button_pressed():
	get_tree().quit()

func _on_back_button_pressed():
	options_menu.visible = false
	$CenterContainer.visible = true
	$Logo.visible = true
	start_button.grab_focus()

func _on_volume_slider_value_changed(value: float) -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(value / 100.0))

func _on_graphics_option_selected(index: int) -> void:
	# 0: Low, 1: Med, 2: High, 3: Ultra
	match index:
		0: RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_DISABLED)
		1: RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_2X)
		2: RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X)
		3: RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_8X)

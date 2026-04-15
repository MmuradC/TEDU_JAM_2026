extends Node

@onready var video = $CutsceneVideo

func _ready():
	var global = get_node_or_null("/root/GlobalState")
	if video:
		video.finished.connect(_on_video_finished)
		if global and global.cutscene_video != "":
			video.stream = load(global.cutscene_video)
			video.play()
		else:
			# Fallback if GlobalState is missing or empty
			_on_video_finished()

func _on_video_finished():
	var global = get_node_or_null("/root/GlobalState")
	if global and global.cutscene_next_scene != "":
		get_tree().change_scene_to_file(global.cutscene_next_scene)
	else:
		get_tree().change_scene_to_file("res://3_ui/1_menus/MainMenu.tscn")

func _input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_on_video_finished()

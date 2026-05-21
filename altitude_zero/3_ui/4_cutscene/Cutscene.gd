extends Node

@onready var video = $CutsceneVideo
@onready var skip_progress = $UI/SkipProgressBar

var hold_time: float = 0.0
const REQUIRED_HOLD_TIME: float = 2.0

func _ready():
	var global = get_node_or_null("/root/GlobalState")
	if video:
		video.finished.connect(_on_video_finished)
		if global and global.cutscene_video != "":
			video.stream = load(global.cutscene_video)
			video.play()
		else:
			_on_video_finished()

func _process(delta):
	if Input.is_action_pressed("ui_accept"):
		hold_time += delta
		skip_progress.value = (hold_time / REQUIRED_HOLD_TIME) * 100.0
		if hold_time >= REQUIRED_HOLD_TIME:
			_on_video_finished()
	else:
		hold_time = max(0.0, hold_time - delta * 2.0)
		skip_progress.value = (hold_time / REQUIRED_HOLD_TIME) * 100.0

func _on_video_finished():
	var global = get_node_or_null("/root/GlobalState")
	if global and global.cutscene_next_scene != "":
		get_tree().change_scene_to_file(global.cutscene_next_scene)
	else:
		get_tree().change_scene_to_file("res://3_ui/1_menus/MainMenu.tscn")

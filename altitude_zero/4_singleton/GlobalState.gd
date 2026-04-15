extends Node

var cutscene_video: String = ""
var cutscene_next_scene: String = ""

func play_cutscene(video_path: String, next_scene: String):
	cutscene_video = video_path
	cutscene_next_scene = next_scene
	get_tree().change_scene_to_file("res://3_ui/4_cutscene/Cutscene.tscn")

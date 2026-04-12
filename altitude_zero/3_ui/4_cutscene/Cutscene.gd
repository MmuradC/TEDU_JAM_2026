extends Node

@onready var video = $VideoStreamPlayer

func _ready():
	video.stream = load("res://3_ui/1_menus/renderback.ogv")
	video.play()
	get_tree().quit()

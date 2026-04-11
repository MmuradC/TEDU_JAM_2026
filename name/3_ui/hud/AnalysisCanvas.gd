extends CanvasLayer

var boundary_countdown: float = 5.0
var out_of_bounds: bool = false

func _process(delta):
	if out_of_bounds:
		boundary_countdown -= delta
		$UI/WarningLabel.text = "ALANA DÖN: " + str(ceil(boundary_countdown))
		$UI/WarningLabel.show()
		
		if boundary_countdown <= 0:
			# Fade out efektini başlat ve sahne değiştir
			get_tree().change_scene_to_file("res://GameOverMenu.tscn")
	else:
		$UI/WarningLabel.hide()
		boundary_countdown = 5.0

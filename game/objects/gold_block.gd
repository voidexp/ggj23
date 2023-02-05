extends GridBlock

func _process(_delta):
	$Label.set_position(get_viewport().get_camera().unproject_position(to_global(Vector3.ZERO)))

func _on_health_changed(value):
	$Label.text = "%d" % value

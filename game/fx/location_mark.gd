extends Spatial

var color: Color setget _set_color

func _set_color(c:Color):
	color = c
	$SpotLight.light_color = c.lightened(0.5)
	$Particles.process_material.color = c

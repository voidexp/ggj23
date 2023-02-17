extends Spatial

export var color: Color = Color.azure setget _set_color

func _set_color(new_color):
	color = new_color
	$RootNode/group1/helmet.get_surface_material(0).albedo_color = color

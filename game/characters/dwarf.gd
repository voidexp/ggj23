extends Spatial

export var color: Color = Color.azure setget _set_color

func _set_color(new_color):
	color = new_color
	var helmet_mat = SpatialMaterial.new()
	helmet_mat.albedo_color = color
	$RootNode/helmet.set_surface_material(0, helmet_mat)

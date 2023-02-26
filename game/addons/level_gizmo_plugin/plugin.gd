tool
extends EditorPlugin

class GizmoPlugin extends EditorSpatialGizmoPlugin:

	func _init():
		create_material("primary", Color.steelblue)
		create_material("secondary", Color.cyan)
		create_material("tertiary", Color.coral)
		create_handle_material("handle")

	func create_gizmo(spatial):
		if spatial is Level:
			return LevelGizmo.new()
		return null

	func get_name():
		return "Level"

var gizmo_plugin = GizmoPlugin.new()

func _enter_tree():
	add_spatial_gizmo_plugin(gizmo_plugin)

func _exit_tree():
	remove_spatial_gizmo_plugin(gizmo_plugin)

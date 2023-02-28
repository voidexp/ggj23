tool
extends EditorPlugin

var plugin

func _enter_tree():
	plugin = load("res://addons/map_loader_plugin/map_loader.gd").new()
	add_import_plugin(plugin)


func _exit_tree():
	remove_import_plugin(plugin)
	plugin = null

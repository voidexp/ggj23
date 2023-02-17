tool
extends EditorPlugin

const PropertyEditor = preload("res://addons/power_up_inspector_plugin/property_editor.gd")

class InspectorPlugin extends EditorInspectorPlugin:

	func can_handle(object):
		return object is PowerUp

	func parse_property(object, type, path, hint, hint_text, usage):
		if type == TYPE_DICTIONARY:
			add_property_editor(path, PropertyEditor.new())
			return true
		return false

var plugin

func _enter_tree():
	plugin = InspectorPlugin.new()
	add_inspector_plugin(plugin)


func _exit_tree():
	remove_inspector_plugin(plugin)

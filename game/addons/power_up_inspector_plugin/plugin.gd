tool
extends EditorPlugin

const BoostsPropertyEditor = preload("res://addons/power_up_inspector_plugin/boosts_property_editor.gd")
const DurationPropertyEditor = preload("res://addons/power_up_inspector_plugin/duration_property_editor.gd")

class InspectorPlugin extends EditorInspectorPlugin:

	func can_handle(object):
		return object is PowerUp

	func parse_property(object, type, path, hint, hint_text, usage):
		if type == TYPE_DICTIONARY and path == "boosts":
			add_property_editor(path, BoostsPropertyEditor.new())
			return true
		elif type == TYPE_REAL and path == "duration":
			add_property_editor(path, DurationPropertyEditor.new())
			return true
		return false

var plugin

func _enter_tree():
	plugin = InspectorPlugin.new()
	add_inspector_plugin(plugin)


func _exit_tree():
	remove_inspector_plugin(plugin)

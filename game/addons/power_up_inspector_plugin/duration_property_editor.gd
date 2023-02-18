extends EditorProperty

var control = preload("res://addons/power_up_inspector_plugin/duration_control.tscn").instance()

func _init():
	add_child(control)

	control.connect("changed", self, "_value_changed")

func update_property():
	var duration = get_edited_object().get(get_edited_property())
	control.value = duration

func _value_changed():
	get_edited_object().set(get_edited_property(), control.value)
	emit_changed(get_edited_property(), control.value)

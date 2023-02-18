extends EditorProperty

var control = preload("res://addons/power_up_inspector_plugin/property_list_control.tscn").instance()

var button

var prop_names = Player.BOOSTABLE_PROPERTIES.keys()
var updating = false
var props = {}

func _init():
	add_child(control)
	set_bottom_editor(control)
	add_focusable(control)

	control.connect("value_changed", self, "_on_prop_value_change")
	control.connect("value_removed", self, "_on_prop_value_remove")
	button = control.get_node("Button")
	button.connect("button_down", self, "_populate_menu")
	button.get_popup().connect("id_pressed", self, "_add_property_entry")

func _populate_menu():
	var menu = button.get_popup()
	menu.clear()

	for id in range(len(prop_names)):
		var prop_name = prop_names[id]
		if prop_name in props:
			continue
		var label = prop_name.capitalize()
		menu.add_item(label, id)

func update_property():
	updating = true

	var new_props = get_edited_object().get(get_edited_property())
	for prop_name in new_props:
		var value = new_props[prop_name]
		if not prop_name in props:
			var id = prop_names.find_last(prop_name)
			_add_property_entry(id, value)
		else:
			props[prop_name] = value

	updating = false

func _add_property_entry(id, value=null):
	var prop_name = prop_names[id]
	var type = Player.BOOSTABLE_PROPERTIES[prop_name]

	if value == null:
		value = _get_default(type)

	control.add_entry(prop_name.capitalize(), id, Player.BOOSTABLE_PROPERTIES[prop_name], value)

	if not prop_name in props:
		props[prop_name] = value

	if not updating:
		emit_changed(get_edited_property(), props)

func _get_default(type):
	match type:
		TYPE_REAL:
			return 1.0
		TYPE_INT:
			return 1
		TYPE_BOOL:
			return false
		_:
			return null

func _on_prop_value_change(id, value):
	if not updating:
		var prop_name = prop_names[id]
		props[prop_name] = value
		emit_changed(get_edited_property(), props)

func _on_prop_value_remove(id):
	if not updating:
		var prop_name = prop_names[id]
		props.erase(prop_name)
		emit_changed(get_edited_property(), props, "", true)

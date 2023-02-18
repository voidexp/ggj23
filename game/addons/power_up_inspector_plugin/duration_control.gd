tool
extends VBoxContainer

signal changed

var value: float = -1.0 setget _set_value, _get_value

onready var _duration = get_node("Duration")
onready var _duration_edit = get_node("Duration/SpinBox")
onready var _type_button = get_node("Type")

enum {PERMANENT, ONE_SHOT, TEMPORARY}

func _on_type_changed(id):
	_set_value(_get_value())
	emit_signal("changed")

func _on_value_changed():
	emit_signal("changed")

func _set_value(v):
	value = v

	var type

	if value == -1.0:
		type = ONE_SHOT
		_duration.visible = false

	elif value == -2.0:
		type = PERMANENT
		_duration.visible = false

	else:
		type = TEMPORARY
		_duration_edit.value = value
		_duration.visible = true

	_type_button.select(type)

func _get_value():
	match _type_button.get_selected_id():
		ONE_SHOT:
			return -1.0
		PERMANENT:
			return -2.0
		TEMPORARY:
			return _duration_edit.value

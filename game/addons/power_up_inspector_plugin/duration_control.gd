tool
extends VBoxContainer

signal changed

var value = 1.0 setget _set_value, _get_value

onready var _duration = get_node("Duration")
onready var _duration_edit = get_node("Duration/SpinBox")
onready var _type_button = get_node("Type")

enum {ONE_SHOT, PERMANENT, DURATION}

func _on_type_changed(id):
	_set_value(_get_value())
	emit_signal("changed")

func _on_value_changed():
	emit_signal("changed")

func _set_value(v):
	print("set value %s" % v)
	value = v

	var type

	if value == -2:
		type = PERMANENT
		_duration.visible = false

	elif value == -1:
		type = ONE_SHOT
		_duration.visible = false

	else:
		type = DURATION
		_duration_edit.value = value
		_duration.visible = true

	_type_button.select(type)

func _get_value():
	match _type_button.get_selected_id():
		PERMANENT:
			return -2
		ONE_SHOT:
			return -1
		DURATION:
			return _duration_edit.value

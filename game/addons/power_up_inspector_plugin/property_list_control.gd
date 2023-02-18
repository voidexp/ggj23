tool
extends VBoxContainer

signal value_changed
signal value_removed

func _ready():
	$RealEntry.visible = false
	$BoolEntry.visible = false

func add_entry(label, id, type, value):
	var node
	match type:
		TYPE_REAL, TYPE_INT:
			node = $RealEntry.duplicate()
			var control = node.get_node("SpinBox")
			control.value = value
			control.connect("value_changed", self, "_handle_real_change", [id])
			control.rounded = type == TYPE_INT
			control.step = 1 if type == TYPE_INT else 0.1

		TYPE_BOOL:
			node = $BoolEntry.duplicate()
			var control = node.get_node("CheckBox")
			control.pressed = value
			control.connect("pressed", self, "_handle_bool_change", [id])

		_:
			push_error("Unsupported property type")
			return

	node.name = "%d" % id
	node.visible = true
	node.get_node("Label").text = label
	node.get_node("RemoveButton").connect("pressed", self, "_handle_remove", [id])

	add_child(node)

func _handle_real_change(value, id):
	var node = get_node("%d" % id)
	emit_signal("value_changed", id, value)

func _handle_bool_change(id):
	var node = get_node("%d" % id)
	var value = (node.get_node("CheckBox") as CheckBox).pressed
	emit_signal("value_changed", id, value)

func _handle_remove(id):
	var node = get_node("%d" % id)
	node.queue_free()
	emit_signal("value_removed", id)

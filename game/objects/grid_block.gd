extends StaticBody

class_name GridBlock


var row
var col

signal destroyed

# Called when the node enters the scene tree for the first time.
func _ready():
	name = '_'.join([name, str(row), str(col)])

func queue_free():

	emit_signal("destroyed", row, col)
	.queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

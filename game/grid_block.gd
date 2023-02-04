extends StaticBody

class_name GridBlock


var row_id
var col_id

signal destroyed

# Called when the node enters the scene tree for the first time.
func _ready():
	name = '_'.join([name, str(row_id), str(col_id)])

func queue_free():
	emit_signal("destroyed", row_id, col_id)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

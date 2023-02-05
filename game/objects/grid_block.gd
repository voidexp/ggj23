extends StaticBody

class_name GridBlock

var col
var row

signal destroyed

func queue_free():
	emit_signal("destroyed", col, row)
	.queue_free()

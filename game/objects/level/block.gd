extends StaticBody

class_name Block

var col
var row
var type
var collisions_enabled: bool setget __set_collisions_enabled

func get_shape() -> Shape:
	return $CollisionShape.shape

func _ready():
	$CollisionShape.disabled = true

func __set_collisions_enabled(v):
	collisions_enabled = v
	$CollisionShape.disabled = not v

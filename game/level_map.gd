extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export(PackedScene) var soil_brick
export(PackedScene) var rock_brick
export var size_x = 21
export var size_z = 21

var GROUND_THICKNESS = 0.1

# Called when the node enters the scene tree for the first time.
func _ready():
	__init_ground()
	__init_tiles()

func __init_tiles():
	assert(size_x % 2 == 1)
	var start_x = -size_x / 2
	var start_z = -size_z / 2
	var y_pos = GROUND_THICKNESS / 2
	
	for i in range(size_x):
		for j in range(size_z):
			var position = Vector3(start_x + i, y_pos, start_z + j)
			var brick_class = soil_brick if (i % 2 == 1) or (j % 2 == 1) else rock_brick
			var new_brick = brick_class.instance()

			add_child(new_brick)
			new_brick.translate(position)

func __init_ground():
	var ground_size = Vector3(size_x/2, GROUND_THICKNESS/2, size_z/2)
	$Ground/CollisionShape.shape.extents = ground_size

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

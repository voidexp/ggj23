extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	var player_positions = $LevelMap.get_player_positions()
	$Player1.transform.origin = player_positions[0]
	$Player2.transform.origin = player_positions[1]


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

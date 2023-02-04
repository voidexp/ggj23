extends Spatial


var p1_score = 999
var p2_score = 777


# Called when the node enters the scene tree for the first time.
func _ready():
	var player_positions = $Level.get_player_positions()
	$Player1.transform.origin = player_positions[0]
	$Player2.transform.origin = player_positions[1]


func _process(_delta):
	$UI.p1_score = p1_score
	$UI.p2_score = p2_score

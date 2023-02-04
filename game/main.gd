extends Spatial


var p1_score = 0
var p2_score = 0

var p1_path_state_active = false
var p2_path_state_active = false

export var score_per_second = 1


# Called when the node enters the scene tree for the first time.
func _ready():
	var player_positions = $Level.get_player_positions()
	$Player1.transform.origin = player_positions[0]
	$Player2.transform.origin = player_positions[1]
	$Level.connect("path_state_changed", self, "__on_path_state_changed")

func _process(_delta):
	var score_to_add = score_per_second * _delta
	if p1_path_state_active:
		p1_score += score_to_add

	if p2_path_state_active:
		p2_score += score_to_add

	$UI.p1_score = int(p1_score)
	$UI.p2_score = int(p2_score)

	assert(p1_score < 300)
	assert(p2_score < 300)

func __on_path_state_changed(player_id, is_active):
	if player_id == 1:
		p1_path_state_active = is_active
	elif player_id == 2:
		p2_path_state_active = is_active

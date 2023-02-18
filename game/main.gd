extends Spatial

export var score_per_second = 1
export var points_to_win = 100

var p1_score = 0
var p2_score = 0

var _is_game_running = false

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()  # init random seed

	var player_positions = $Level.get_player_positions()
	$Player1.transform.origin = player_positions[0]
	$Player2.transform.origin = player_positions[1]

	_is_game_running = true

func _process(_delta):
	if not _is_game_running:
		return

	var score_to_add = score_per_second * _delta
	var state = $Level.get_state()

	if 0 in state.linked_bases:
		p1_score += score_to_add

	if 1 in state.linked_bases:
		p2_score += score_to_add

	$Scenery.p1_score = int(p1_score)
	$Scenery.p2_score = int(p2_score)

	__check_win_conditions()

func __check_win_conditions():
	if p1_score >= points_to_win or p2_score >= points_to_win:
		$UI/Game.show_winner(1 if p1_score > p2_score else 2)
		_is_game_running = false

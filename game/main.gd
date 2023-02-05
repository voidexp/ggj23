extends Spatial

export var score_per_second = 1
export var points_to_win = 100

var p1_score = 0
var p2_score = 0

var p1_path_state_active = false
var p2_path_state_active = false

var _is_game_running = false

# Called when the node enters the scene tree for the first time.
func _ready():
	var player_positions = $Level.get_player_positions()
	$Player1.transform.origin = player_positions[0]
	$Player2.transform.origin = player_positions[1]
	$Level.connect("path_state_changed", self, "__on_path_state_changed")

	_is_game_running = true

func _process(_delta):
	if not _is_game_running:
		return

	var score_to_add = score_per_second * _delta
	if p1_path_state_active:
		p1_score += score_to_add

	if p2_path_state_active:
		p2_score += score_to_add

	$UI.p1_score = int(p1_score)
	$UI.p2_score = int(p2_score)

	__check_win_conditions()

func __check_win_conditions():
	if p1_score >= points_to_win or p2_score >= points_to_win:
		$UI.show_winner(1 if p1_score > p2_score else 2)
		_is_game_running = false

func __on_path_state_changed(state):
	if not _is_game_running:
		return

	p1_path_state_active = state.p1_linked
	p2_path_state_active = state.p2_linked

	# TODO: move to some better place, where all dreams go
	if state.gold:
		state.gold.get_node("Drainable").enabled = state.p1_linked or state.p2_linked

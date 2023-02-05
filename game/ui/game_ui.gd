extends Control


var p1_score: int setget __set_p1_score
var p2_score: int setget __set_p2_score

var _p1_score_tmpl = ""
var _p2_score_tmpl = ""
var _winner_text_tmpl = ""

var _p1_color
var _p2_color

func show_winner(player_id):
	var winner_color = _p1_color if player_id == 1 else _p2_color

	$Winner.visible = true
	$Winner.add_color_override("font_color", winner_color)
	$Winner.text = _winner_text_tmpl % player_id

func _ready():
	_p1_score_tmpl = $P1Score.text
	_p2_score_tmpl = $P2Score.text

	_p1_color = $P1Score.get_color("font_color")
	_p2_color = $P2Score.get_color("font_color")

	_winner_text_tmpl = $Winner.text
	$Winner.visible = false

func __set_p1_score(score):
	$P1Score.text = _p1_score_tmpl % score

func __set_p2_score(score):
	$P2Score.text = _p2_score_tmpl % score

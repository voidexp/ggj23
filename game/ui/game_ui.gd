extends Control


var p1_score: int setget __set_p1_score
var p2_score: int setget __set_p2_score

var _p1_score_tmpl = ""
var _p2_score_tmpl = ""

func _ready():
	_p1_score_tmpl = $P1Score.text
	_p2_score_tmpl = $P2Score.text

func __set_p1_score(score):
	$P1Score.text = _p1_score_tmpl % score

func __set_p2_score(score):
	$P2Score.text = _p2_score_tmpl % score

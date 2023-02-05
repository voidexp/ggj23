extends Spatial

var p1_score: int setget __set_p1_score
var p2_score: int setget __set_p2_score

func __set_p1_score(score):
	$Gate1.score = score

func __set_p2_score(score):
	$Gate2.score = score

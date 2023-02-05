extends CSGCombiner

export var score_color: Color

var score: int setget __set_score

var __score_tmpl = ""

func _ready():
	__score_tmpl = $Score.text
	$Score.modulate = score_color

func __set_score(value):
	$Score.text = __score_tmpl % value

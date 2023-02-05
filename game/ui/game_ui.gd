extends Control

var _winner_text_tmpl = ""

func show_winner(player_id):
	$Winner.visible = true
	$Winner.text = _winner_text_tmpl % player_id

func _ready():
	_winner_text_tmpl = $Winner.text
	$Winner.visible = false

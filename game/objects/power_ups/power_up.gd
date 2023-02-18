tool
extends Area

class_name PowerUp

signal on_pick_up

export var duration := -1.0
export(Player.Boost.Type) var boost_type = 0
export var boosts := {}

func _on_body_entered(body:Node):
	if body is Player:
		var boost = Player.Boost.new()
		boost.type = boost_type
		boost.values = boosts
		boost.duration = duration
		body.add_boost(boost)
		emit_signal("on_pick_up")
		_on_pick_up(body)

func _on_pick_up(p: Player) -> void:
	queue_free()

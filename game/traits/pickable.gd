extends "res://traits/trait.gd"


func handle_pick(player: Node, amount: int):
	print("%s picked about %d stone" % [player.name, amount])

	get_parent().queue_free()

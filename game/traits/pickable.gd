extends "res://traits/trait.gd"

const Level = preload("res://level_map.gd")
const Block = preload("res://objects/grid_block.gd")


func handle_pick(player: Node, amount: int):
	print("%s picked about %d stone" % [player.name, amount])

	var block = get_parent() as Block
	var level = block.get_parent() as Level
	level.clear_block(block.col, block.row)

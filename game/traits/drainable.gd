extends "res://traits/trait.gd"

onready var health = get_node("../Health")

export var drain_rate = 1.0
export var enabled = false

func _process(delta):
	if not enabled:
		return

	health.health -= delta * drain_rate
	if health.health < 0:
		health.health = 0

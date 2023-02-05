extends "res://components/component.gd"

export var health: float setget __set_health, __get_health

signal health_changed(value)

signal dead

var __health
var __dead = false

func __set_health(v):
	__health = v
	emit_signal("health_changed", __health)
	if not __dead and v <= 0:
		__dead = true
		emit_signal("dead")

func __get_health() -> float:
	return __health

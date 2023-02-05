extends "res://components/component.gd"

export var health: float setget __set_health, __get_health

signal health_changed(value)

var __health

func __set_health(v):
	__health = v
	emit_signal("health_changed", __health)
	if v <= 0:
		get_parent().queue_free()

func __get_health() -> float:
	return __health

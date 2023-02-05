extends Control

func _ready():
	get_viewport().connect("size_changed", self, "__resize")

func __resize():
	set_size(get_viewport_rect().size, true)

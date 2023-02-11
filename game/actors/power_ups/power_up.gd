tool
extends Area

class_name PowerUp

export var duration := 1.0

signal on_pick_up

var props := {}

func property_can_revert(property):
	return property in Player.Property

func property_get_revert(property):
	if property in Player.Property:
		return 1.0

func _init():
	for property in Player.Property:
		set(property, 1.0)

func _set(property, value):
	if property in Player.Property:
		props[property] = value
		return true

func _get(property):
	if property in Player.Property:
		return props[property]

func _on_body_entered(body:Node):
	if body is Player:
		emit_signal("on_pick_up")
		_on_pick_up(body)
		$AnimationPlayer.play("Disappear")

func _on_animation_finished(name:String):
	if name == "Disappear":
		queue_free()

func _get_property_list():
	var properties = []
	properties.append({
		name = "Boosts",
		type = TYPE_NIL,
		usage = PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	for key in Player.Property:
		properties.append({
			name = key,
			type = TYPE_REAL,
		})

	return properties

func _on_pick_up(p: Player) -> void:
	var boosts = {}
	for prop in props:
		boosts[prop] = props[prop]
	p.add_boost(duration, boosts)

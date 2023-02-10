extends Area

class_name PowerUp

signal on_pick_up

func _on_body_entered(body:Node):
	if body is Player:
		print("hey %s, pick me up!!!" % body)
		emit_signal("on_pick_up", body)
		$AnimationPlayer.play("Disappear")

func _on_animation_finished(name:String):
	if name == "Disappear":
		queue_free()

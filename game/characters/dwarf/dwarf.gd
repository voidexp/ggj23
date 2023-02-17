extends Spatial

export var color: Color = Color.azure setget _set_color

var _headlamp_on = true

func toggle_headlamp(enabled):
	if _headlamp_on != enabled:
		_headlamp_on = enabled

		if enabled:
			$HeadlampEffect/AnimationPlayer.play_backwards("Toggle")
		else:
			$HeadlampEffect/AnimationPlayer.play("Toggle")

func toggle_aura(enabled):
	$AuraEffect.emitting = enabled

func play_pick_animation():
	$RootNode/AnimationPlayer.play("pickaxe hit")

func _set_color(new_color):
	color = new_color
	$RootNode/group1/helmet.get_surface_material(0).albedo_color = color
	$AuraEffect.process_material.color = color

func _on_headlamp_animation_finished(anim_name:String):
	if anim_name == "Toggle" and _headlamp_on:
		$HeadlampEffect/AnimationPlayer.play("Pulse")

extends Block

onready var _anim: AnimationPlayer = get_node("AnimationPlayer")

func toggle(enabled:bool):
	if enabled:
		_anim.play("Toggle")
	else:
		_anim.play_backwards("Toggle")

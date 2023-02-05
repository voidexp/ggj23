extends Spatial

export var ghost: PackedScene
export var spawn_duration = 1.0

signal spawn_started
signal spawn_completed

func spawn():
	$Path/Follower.add_child(ghost.instance())
	$AnimationPlayer.play("Spawn", -1, 1.0 / spawn_duration)
	emit_signal("spawn_started")

func _ready():
	$AnimationPlayer.connect("animation_finished", self, "__on_animation_finished")

# func _process(_delta):
# 	if $AnimationPlayer.is_playing():
# 		emit_signal("spawn_progress_changed", $AnimationPlayer.current_animation_position)

func __on_animation_finished(__):
	emit_signal("spawn_completed")
	queue_free()

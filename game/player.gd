extends KinematicBody

export var color: Color
export var player_seat: int = 1
export var speed: int = 1

enum {UP, DOWN, LEFT, RIGHT}

var actions = []

func _ready():
	$Model.color = color


func _unhandled_input(event):
	if event.is_action_released("p%d_move_right" % player_seat):
		actions.erase(RIGHT)
	if event.is_action_released("p%d_move_left" % player_seat):
		actions.erase(LEFT)
	if event.is_action_released("p%d_move_up" % player_seat):
		actions.erase(UP)
	if event.is_action_released("p%d_move_down" % player_seat):
		actions.erase(DOWN)

	if event.is_action_pressed("p%d_move_down" % player_seat):
		actions.push_back(DOWN)
	if event.is_action_pressed("p%d_move_up" % player_seat):
		actions.push_back(UP)
	if event.is_action_pressed("p%d_move_left" % player_seat):
		actions.push_back(LEFT)
	if event.is_action_pressed("p%d_move_right" % player_seat):
		actions.push_back(RIGHT)


func _physics_process(step):
	var movement = Vector3.ZERO
	var last_action = actions.back()
	if last_action == UP:
		movement.z = -1
	elif last_action == DOWN:
		movement.z = 1
	elif last_action == LEFT:
		movement.x = -1
	elif last_action == RIGHT:
		movement.x = 1

	var offset = movement * speed * step
	if not test_move(transform, offset) and move_and_collide(movement * speed * step):
		# TODO: what else do we do on collision?
		pass

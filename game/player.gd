extends KinematicBody

const Trait = preload("res://traits/trait.gd")

export var color: Color
export var player_seat: int = 1
export var speed: int = 1

enum {UP, DOWN, LEFT, RIGHT}

var movements = []

func _ready():
	name = "Player%d" % player_seat

	$Model.color = color

func _unhandled_input(event):
	if event.is_action_released("p%d_move_right" % player_seat):
		movements.erase(RIGHT)
	if event.is_action_released("p%d_move_left" % player_seat):
		movements.erase(LEFT)
	if event.is_action_released("p%d_move_up" % player_seat):
		movements.erase(UP)
	if event.is_action_released("p%d_move_down" % player_seat):
		movements.erase(DOWN)

	if event.is_action_pressed("p%d_move_down" % player_seat):
		movements.push_back(DOWN)
	if event.is_action_pressed("p%d_move_up" % player_seat):
		movements.push_back(UP)
	if event.is_action_pressed("p%d_move_left" % player_seat):
		movements.push_back(LEFT)
	if event.is_action_pressed("p%d_move_right" % player_seat):
		movements.push_back(RIGHT)

	if event.is_action_pressed("p%d_action" % player_seat):
		__do_pick()

func _physics_process(step):
	var dir = Vector3.ZERO
	if not movements:
		return

	var last_action = movements.back()
	if last_action == UP:
		dir.z = -1
	elif last_action == DOWN:
		dir.z = 1
	elif last_action == LEFT:
		dir.x = -1
	elif last_action == RIGHT:
		dir.x = 1

	# Orient the player towards the moving direction
	var angle = Vector3.FORWARD.signed_angle_to(dir, Vector3.UP)
	transform.basis = Basis()
	rotate(Vector3.UP, angle)

	# Attempt to move, as long as we're not colliding
	var offset = dir * speed * step
	if not test_move(transform, offset) and move_and_collide(offset):
		# TODO: what else do we do on collision?
		pass

func __do_pick():
	var target = $RayCast.get_collider() as Spatial
	if not target:
		return

	for node in target.get_children():
		if node.is_in_group("traits"):
			var aspect = node as Trait
			aspect.handle_pick(self, 10)

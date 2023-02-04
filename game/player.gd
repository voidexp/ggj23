extends KinematicBody

const Trait = preload("res://traits/trait.gd")
const Map = preload("res://level_map.gd")

export var color: Color
export var player_seat: int = 1
export var speed: int = 1

export var pick_cooldown = 1.0
export var pick_limit = 3

export var roar_cooldown = 3.0
export var roar_expansion = 5.0
export var roar_radius = 3
export var roar_delay = 1.5

enum {UP, DOWN, LEFT, RIGHT}

var movements = []
var picks = pick_limit
var roaring = false
var roar = 0.0
var roar_cooldown_remaining = 0.0
var roar_pos
var map: Map = null

func _ready():
	name = "Player%d" % player_seat

	$Model.color = color
	$RoarDelay.wait_time = roar_delay

	map = get_node("/root/Game/Level")
	print(map)

	$AnimationPlayer.connect("animation_finished", self, "__exit_cooldown")

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

	if event.is_action_pressed("p%d_aux_action" % player_seat):
		__charge_roar()
	elif event.is_action_released("p%d_aux_action" % player_seat):
		__discharge_roar()

func _process(delta):
	__update_cooldown()
	__update_roar(delta)

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
	if __is_in_cooldown():
		return

	picks -= 1
	if picks == 0:
		__enter_cooldown()

	var target = $RayCast.get_collider() as Spatial
	if not target:
		return

	for node in target.get_children():
		if node.is_in_group("traits"):
			var aspect = node as Trait
			aspect.handle_pick(self, 10)

func __enter_cooldown():
	$AnimationPlayer.play("Cooldown", -1, 1 / pick_cooldown)

func __exit_cooldown(__unused=null):
	picks = pick_limit

func __is_in_cooldown():
	return $AnimationPlayer.is_playing()

func __update_cooldown():
	var overhead_pos = to_global(Vector3.UP)
	$Cooldown.set_position(get_viewport().get_camera().unproject_position(overhead_pos))
	if __is_in_cooldown():
		$Cooldown.visible = true
		$Cooldown.text = "%.1f" % stepify(
			($AnimationPlayer.current_animation_length - $AnimationPlayer.current_animation_position) * pick_cooldown,
			0.1)
	else:
		$Cooldown.text = "%d" % picks

func __charge_roar():
	if not __can_roar():
		return

	roaring = true
	$RoarSphere.visible = true

func __discharge_roar():
	if not roaring:
		return

	roar_pos = self.global_transform.origin
	$RoarSphere.visible = false
	$RoarDelay.start()

func __update_roar(delta):
	if not roaring:
		# update the cooldown
		roar_cooldown_remaining -= delta
		if roar_cooldown_remaining <= 0:
			roar_cooldown_remaining = 0
	else:
		# update the roar expansion
		roar = clamp(roar + delta * roar_expansion, 0, roar_radius)
		$RoarSphere.transform.basis = Basis().scaled(Vector3.ONE * (1 + roar))

func __can_roar() -> bool:
	return roar_cooldown_remaining == 0 and roaring == false

func _on_roar_delay_timeout():
	if not map:
		return

	var coord = map.world_to_coords(roar_pos)
	if not coord:
		return

	var curr_coord = map.world_to_coords(global_transform.origin)
	var occupied_tile_pos = map.coords_to_world(coord)
	var radius = 0.5 + (occupied_tile_pos - roar_pos).length() + roar
	var blocks = map.get_blocks_in_radius(coord, radius)
	for block_info in blocks:
		if block_info[0] == curr_coord:
			continue
		if block_info[1] == Map.BLOCK_TYPE.NONE:
			map.spawn_tile(block_info[0], Map.BLOCK_TYPE.SOIL)

	# remaining cooldown = basic cooldown + % of reached charge
	roar_cooldown_remaining = roar_cooldown + roar_cooldown * (roar / roar_radius)
	roaring = false
	roar = 0.0

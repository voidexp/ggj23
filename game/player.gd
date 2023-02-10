extends KinematicBody

class_name Player

const Trait = preload("res://traits/trait.gd")
const Map = preload("res://objects/level/map.gd")

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

enum {NOT_ROARING, ROAR_CHARGING, ROAR_DISCHARGING}

var movements = []
var picks = 0
var roaring = NOT_ROARING
var roar = 0.0
var roar_cooldown_remaining = 0.0
var roar_pos
var level = null
var snap_to = null

func _ready():
	name = "Player%d" % player_seat
	picks = pick_limit

	$Model.color = color
	$RoarDelay.wait_time = roar_delay

	level = get_node("/root/Game/Level")

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
	var dir

	if snap_to:
		dir = (snap_to - global_transform.origin).normalized()
	else:
		dir = Vector3.ZERO
		if not movements or roaring == ROAR_CHARGING:
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

		snap_to = __get_snap_target(dir)

	# Orient the player towards the moving direction
	var angle = Vector3.FORWARD.signed_angle_to(dir, Vector3.UP)
	transform.basis = Basis()
	rotate(Vector3.UP, angle)

	# Attempt to move, as long as we're not colliding and not overshooting the
	# snap target
	var snap_dist = INF if not snap_to else (global_transform.origin - snap_to).length()
	var offset = min(speed * step, snap_dist)
	var move_delta = dir * offset

	# TODO: maybe this whole movement logic could be simplified
	var collision = test_move(transform, move_delta)
	if not collision:
		collision = move_and_collide(move_delta) != null
		if snap_to and (global_transform.origin - snap_to).length() <= 0.001:
			transform.origin = snap_to
			snap_to = null
			collision = false
	if snap_to and collision:
		snap_to = null

func __get_snap_target(dir):
	if not level:
		# no level found, abort
		return null

	var pos = global_transform.origin
	var coord = level.world_to_coord(pos)
	if not coord:
		# not on level, abort
		return null

	# go over neighbors of the current tile and pick the one we're looking at
	var neighbors = level.get_neighbors(coord)
	for neighbor in neighbors:
		# 1. obtain world position of the tile
		var n_pos = level.coord_to_world(neighbor)
		# 2. compute the direction to it
		var n_dir = (n_pos - pos).normalized()
		# 3. perform dot product with desired movement direction
		var dot = n_dir.dot(dir)
		# 4. if dot is close to unit, then the directions match
		if abs(dot - 1.0) <= 0.1:
			return n_pos

func __do_pick():
	if __is_in_cooldown():
		return

	picks -= 1
	$Model/RootNode/AnimationPlayer.play("pickaxe hit")
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
	if roar_cooldown_remaining > 0 or roaring:
		return

	roaring = ROAR_CHARGING
	roar = 0.0
	$RoarSphere.visible = true

func __discharge_roar():
	if roaring != ROAR_CHARGING:
		return

	roaring = ROAR_DISCHARGING
	roar_pos = self.global_transform.origin
	$RoarSphere.visible = false
	$RoarDelay.start()

func __update_roar(delta):
	if not roaring:
		# update the cooldown
		roar_cooldown_remaining -= delta
		if roar_cooldown_remaining <= 0:
			roar_cooldown_remaining = 0
	elif roaring == ROAR_CHARGING:
		# expand the roar radius
		roar = clamp(roar + delta * roar_expansion, 0, roar_radius)
		$RoarSphere.transform.basis = Basis().scaled(Vector3.ONE * (1 + roar))

func _on_roar_delay_timeout():
	if not level:
		return

	var occupied_tile = level.world_to_coord(global_transform.origin)
	var tiles = level.get_tiles_in_radius(roar_pos, roar)
	for tile_info in tiles:  # tile_info = [coord, type]
		if tile_info[0] == occupied_tile:
			continue
		if tile_info[1] == Map.BLOCK_TYPE.NONE:
			level.spawn_soil(tile_info[0])

	# remaining cooldown = basic cooldown + % of reached charge
	roar_cooldown_remaining = roar_cooldown + roar_cooldown * (roar / roar_radius)
	roaring = NOT_ROARING

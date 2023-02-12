extends KinematicBody

class_name Player

const Trait = preload("res://traits/trait.gd")
const Map = preload("res://objects/level/map.gd")

export var color: Color
export var player_seat: int = 1
export var speed: float = 3.0
export var pick_speed := 1.0
export var roar_cooldown := 3.0
export var roar_expansion := 5.0
export var roar_radius := 3
export var roar_delay := 1.5

# Identifiers of properties that support boosting. These are to be used in
# power-ups.
enum Property {
	SPEED = 1,
	PICK_SPEED,
	ROAR_COOLDOWN,
	ROAR_RADIUS
}

# Internal map of boostable properties identifiers to actual names (the ones
# exported above).
const prop_names_map := {
	SPEED = "speed",
	PICK_SPEED = "pick_speed",
	ROAR_COOLDOWN = "roar_cooldown",
	ROAR_RADIUS = "roar_radius",
}

enum {UP, DOWN, LEFT, RIGHT}

enum {NOT_ROARING, ROAR_CHARGING, ROAR_DISCHARGING}

var movements = []
var roaring = NOT_ROARING
var roar = 0.0
var pick_cooldown_remaining = 0.0
var roar_cooldown_remaining = 0.0
var roar_pos
var level = null
var snap_to = null
var boosts := []

var computed_props: Dictionary
var defaults: Dictionary

class Boost extends Object:

	var multipliers: Dictionary
	var duration_remaining: float


func add_boost(duration:float, multipliers:Dictionary):
	var boost = Boost.new()
	boost.multipliers = multipliers
	boost.duration_remaining = duration
	boosts.push_back(boost)

func _ready():
	name = "Player%d" % player_seat

	# store the default values of exported properties
	defaults = {}
	for key in prop_names_map:
		defaults[key] = get(prop_names_map[key])

	$Model.color = color
	$RoarDelay.wait_time = roar_delay

	level = get_node("/root/Game/Level")


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
	__update_boosts(delta)
	__update_pick(delta)
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
	if pick_cooldown_remaining > 0:
		return

	pick_cooldown_remaining = 1.0 / pick_speed

	$Model/RootNode/AnimationPlayer.play("pickaxe hit")

	var target = $RayCast.get_collider() as Spatial
	if not target:
		return

	for node in target.get_children():
		if node.is_in_group("traits"):
			var aspect = node as Trait
			aspect.handle_pick(self, 10)

func __update_pick(delta):
	pick_cooldown_remaining -= delta
	if pick_cooldown_remaining < 0:
		pick_cooldown_remaining = 0

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
	$CandleFX/AnimationPlayer.play("Toggle")

func __update_roar(delta):
	if not roaring and roar_cooldown_remaining:
		# update the cooldown
		roar_cooldown_remaining -= delta
		if roar_cooldown_remaining < 0:
			roar_cooldown_remaining = 0
			$CandleFX/AnimationPlayer.play_backwards("Toggle")
	elif roaring == ROAR_CHARGING:
		# expand the roar radius
		roar = clamp(roar + delta * roar_expansion, 0, roar_radius)
		$RoarSphere.transform.basis = Basis().scaled(Vector3.ONE * (1 + roar))

func __update_boosts(delta):
	# reset properties to their defaults
	for key in prop_names_map:
		set(prop_names_map[key], defaults[key])

	# update boosters and apply them
	var expired = []
	for boost in boosts:
		boost.duration_remaining -= delta
		if boost.duration_remaining <= 0:
			expired.append(boost)

		for key in boost.multipliers:
			var prop_name = prop_names_map[key]
			var val = get(prop_name)
			set(prop_name, val * boost.multipliers[key])

	# remove expired boosters
	for boost in expired:
		boosts.erase(boost)

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

func _on_candle_animation_finished(anim_name:String):
	if anim_name == "Toggle" and not roaring and not roar_cooldown_remaining:
		$CandleFX/AnimationPlayer.play("Pulse")

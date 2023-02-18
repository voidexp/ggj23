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
export var detonator_max_distance := 5.0
export var detonator_radius := 3.0
export var detonator_counts := 0

# Scene to use as a mark for the ultimate positioning.
export var ultimate_placement_mark: PackedScene

# Identifiers of properties that support boosting. These will be available for
# boosting in power-ups.
const BOOSTABLE_PROPERTIES := {
	"speed": TYPE_REAL,
	"pick_speed": TYPE_REAL,
	"roar_cooldown": TYPE_REAL,
	"roar_expansion": TYPE_REAL,
	"roar_radius": TYPE_REAL,
	"roar_delay": TYPE_REAL,
	"detonator_max_distance": TYPE_REAL,
	"detonator_radius": TYPE_REAL,
	"detonator_counts": TYPE_INT,
}

enum {UP, DOWN, LEFT, RIGHT}

enum {NOT_ROARING, ROAR_CHARGING, ROAR_DISCHARGING}

enum {WAIT_NOTHING, WAIT_FOR_COORDS = 1}

var movements = []
var roaring = NOT_ROARING
var roar = 0.0
var pick_cooldown_remaining = 0.0
var roar_cooldown_remaining = 0.0
var roar_pos
var snap_to = null
var boosts := []

var defaults: Dictionary

var _waiting = WAIT_NOTHING

onready var level = get_node("/root/Game/Level")
onready var _mark = ultimate_placement_mark.instance()
onready var _model = get_node("Model")


class Boost extends Object:
	enum Type {MOD, SET, ADD}
	var type: int
	var values: Dictionary
	var duration: float


func _ready():
	add_child(_mark)

	# store the default values of boostable properties
	defaults = {}
	for prop in BOOSTABLE_PROPERTIES:
		defaults[prop] = get(prop)

	# colorize player attributes (mark, model, etc)
	_model.color = color
	_mark.color = color

	# hide the ultimate mark initially
	_mark.visible = false

func _unhandled_input(event):
	match _waiting:
		WAIT_NOTHING:
			__handle_normal_input(event)

		WAIT_FOR_COORDS:
			__handle_mark_placement_input(event)

func _process(delta):
	__update_boosts(delta)
	__update_pick(delta)
	__update_roar(delta)
	__update_ultimate(delta)

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

func add_boost(boost:Boost):
	boosts.push_back(boost)

func __handle_normal_input(event):
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

	if event.is_action_pressed("p%d_secondary_action" % player_seat):
		__charge_roar()
	elif event.is_action_released("p%d_secondary_action" % player_seat):
		__discharge_roar()

	if event.is_action_released("p%d_ultimate_action" % player_seat):
		__initiate_ultimate()

func __handle_mark_placement_input(event):
	var coord_offset = Vector2.ZERO

	if event.is_action_released("p%d_ultimate_action" % player_seat):
		__activate_ultimate()
		return

	if event.is_action_pressed("p%d_move_down" % player_seat):
		coord_offset.y += 1
	if event.is_action_pressed("p%d_move_up" % player_seat):
		coord_offset.y -= 1
	if event.is_action_pressed("p%d_move_left" % player_seat):
		coord_offset.x -= 1
	if event.is_action_pressed("p%d_move_right" % player_seat):
		coord_offset.x += 1

	if coord_offset.length() != 0.0:
		__reposition_mark(coord_offset)

func __get_snap_target(dir):
	var pos = global_transform.origin
	var coord = level.world_to_coord(pos)
	if not coord:
		# not on level, abort
		return null

	# go over neighbors of the current tile and find the one we're looking at
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

	# TODO: bind the exact moment of the axe "hitting" the block with the actual
	# .handle_pick() call; now animation and action are unrelated
	_model.play_pick_animation()

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
	$RoarDelay.start(roar_delay)
	_model.toggle_headlamp(false)

func __update_roar(delta):
	if not roaring and roar_cooldown_remaining:
		# update the cooldown
		roar_cooldown_remaining -= delta

		# turn the head lamp back on, if cooldown expired
		if roar_cooldown_remaining < 0:
			roar_cooldown_remaining = 0
			_model.toggle_headlamp(true)

	elif roaring == ROAR_CHARGING:
		# expand the roar sphere radius
		roar = clamp(roar + delta * roar_expansion, 0, roar_radius)
		$RoarSphere.transform.basis = Basis().scaled(Vector3.ONE * (1 + roar))

func __on_roar_delay_timeout():
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

func __update_boosts(delta):
	var expired = []
	var mod_boosts = {}
	var set_boosts = {}
	var add_boosts = {}

	# iterate over boosters and collect modifier/setter values
	for boost in boosts:
		var is_oneshot = false

		if boost.duration == -1.0:
			# one shot boosters are applied to object's properties directly and
			# popped right after
			is_oneshot = true
			expired.append(boost)
		elif boost.duration == -2.0:
			# permanent boosters are never removed
			pass
		else:
			# temporary boosters are removed once they expire
			boost.duration -= delta
			if boost.duration <= 0:
				expired.append(boost)

		match boost.type:
			# setter boosts override the base value
			# NOTE: if multiple setter boosts are changing the same property,
			# the last applied value will be used
			Boost.Type.SET:
				for prop_name in boost.values:
					if is_oneshot:
						set(prop_name, boost.values[prop_name])
					else:
						set_boosts[prop_name] = boost.values[prop_name]

			# adder boosts add to the base value
			# NOTE: multiple adder boosts perform algebraic additions, thus,
			# they apply commutatively
			Boost.Type.ADD:
				for prop_name in boost.values:
					if is_oneshot:
						set(prop_name, get(prop_name) + boost.values[prop_name])
					else:
						if not prop_name in mod_boosts:
							add_boosts[prop_name] = 0
						add_boosts[prop_name] += boost.values[prop_name]

			# modifier boosts act as multipliers of base value; 1.0 = 100%
			# NOTE: modifiers which affect the same property are stacked by
			# *multiplying* them
			Boost.Type.MOD:
				for prop_name in boost.values:
					if is_oneshot:
						set(prop_name, get(prop_name) * boost.values[prop_name])
					else:
						if not prop_name in mod_boosts:
							mod_boosts[prop_name] = 1
						mod_boosts[prop_name] *= boost.values[prop_name]

	# boost properties
	for prop_name in BOOSTABLE_PROPERTIES:
		if not prop_name in set_boosts and\
		   not prop_name in add_boosts and\
		   not prop_name in mod_boosts:

		   # skip resetting the value if it's not overridden by any booster:
		   # this allows to keep the decaying behavior for properties modified
		   # internally during the tick by other game logic
		   continue

		# start with current default value
		var value = defaults[prop_name]

		# override with SET boost
		if prop_name in set_boosts:
			value = set_boosts[prop_name]

		# apply the ADD boost, adjusted by elapsed time
		if prop_name in add_boosts:
			value += add_boosts[prop_name] * delta

		# apply the MOD boost
		if prop_name in mod_boosts:
			value *= mod_boosts[prop_name]

		set(prop_name, value)

	# remove expired boosters
	for boost in expired:
		boosts.erase(boost)

func __initiate_ultimate():
	if not detonator_counts:
		return

	_waiting = WAIT_FOR_COORDS

	# reset the mark
	_mark.visible = true
	_mark.transform.origin = Vector3.ZERO
	__reposition_mark(Vector2(0, 0))

func __update_ultimate(_delta):
	_model.toggle_aura(detonator_counts > 0)

func __activate_ultimate():
	_waiting = WAIT_NOTHING

	_mark.visible = false

	detonator_counts -= 1

	var pos = _mark.global_transform.origin
	var coord = level.world_to_coord(pos)
	var tiles = level.get_tiles_in_radius(pos, detonator_radius)
	for tile_info in tiles:  # tile_info = [coord, type]
		if tile_info[1] == Map.BLOCK_TYPE.NONE:
			level.spawn_soil(tile_info[0])
	level.spawn_soil(coord)

func __reposition_mark(offset:Vector2):
	var coord = level.world_to_coord(_mark.global_transform.origin)
	coord += offset

	var tile = level.get_map().get_tile(coord)
	if tile != -1:
		var pos = level.coord_to_world(coord)
		if pos.distance_to(global_transform.origin) <= detonator_max_distance:
			_mark.global_transform.origin = pos

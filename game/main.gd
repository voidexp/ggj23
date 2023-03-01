extends Spatial

const player_scene = preload("res://player.tscn")

export(Array, Color) var player_colors = [ Color.red, Color.blue, Color.magenta, Color.cyan, ]

export var score_per_second = 1
export var points_to_win = 100

var p1_score = 0
var p2_score = 0

onready var _is_game_running = true
onready var _base_positions = $Level.get_player_base_positions()

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()  # init random seed

func _process(_delta):
	if not _is_game_running:
		return

	var score_to_add = score_per_second * _delta
	var state = $Level.get_state()

	if 0 in state.linked_bases:
		p1_score += score_to_add

	if 1 in state.linked_bases:
		p2_score += score_to_add

	$Scenery.p1_score = int(p1_score)
	$Scenery.p2_score = int(p2_score)

	__check_win_conditions()

func _unhandled_input(event):
	if len(__get_players()) < 4:
		for i in range(4):
			var seat = i + 1
			if event.is_action_released("p%d_action" % seat) \
			   and not get_node_or_null("Player%d" % seat):
				print("Player%d enters the game..." % seat)
				__spawn_player(seat)

func __check_win_conditions():
	if p1_score >= points_to_win or p2_score >= points_to_win:
		$UI/Game.show_winner(1 if p1_score > p2_score else 2)
		_is_game_running = false

func __spawn_player(seat):
	# every even player goes to team 0, every odd to team 1
	var team = seat % 2

	# get the position of the player's team base
	var base_position = _base_positions[team]
	var base_neighbor_tiles = $Level.get_neighbors($Level.world_to_coord(base_position))

	# find a free nearby tile
	var spawn_position = null
	for coord in base_neighbor_tiles:
		var type = $Level.map.get_tile(coord)
		if type in [Map.BLOCK_TYPE.SOIL, Map.BLOCK_TYPE.NONE]:
			spawn_position = $Level.coord_to_world(coord)

			# if there's already a player in that tile, skip it
			for player in __get_players():
				if player.global_transform.origin.distance_to(spawn_position) <= 1:
					spawn_position = null
					break

			if spawn_position != null:
				break

	assert(spawn_position, "couldn't find a suitable position near %s to spawn a new player!" % base_position)

	# clear the tile on which the player is going to be spawned
	$Level.map.set_tile($Level.world_to_coord(spawn_position), Map.BLOCK_TYPE.NONE)

	# instantiate the player, customize her and reposition on the chosen tile
	var player = player_scene.instance()
	player.name = "Player%d" % seat
	player.player_seat = seat
	player.color = player_colors[seat - 1]
	add_child(player)
	player.global_transform.origin = spawn_position

func __get_players():
	return get_tree().get_nodes_in_group("players")

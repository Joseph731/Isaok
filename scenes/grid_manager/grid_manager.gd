extends Control
class_name GridManager

enum StoneType {EMPTY, BLACK, WHITE, FIFTH, BANNED}
enum GameState{SECOND, THIRD, FOURTH, FIFTH, CHOOSE, NORMAL}
enum GameOutcome{UNDECIDED, BLACK_WIN, WHITE_WIN, DRAW}

signal turn_switched(is_servers_turn: bool)
signal stone_placed(cell_global_position: Vector2, cell_size: Vector2, stone_type: StoneType)
signal second_move_finished
signal third_move_finished
signal fourth_move_finished
signal fifth_move_finished
signal choose_move_finished
signal game_outcome_decided(game_outcome: GameOutcome)

@export var position_marker: Marker2D
@export var center_cell_marker: Marker2D

const SECOND_SNAP = preload("uid://d0bpipi6pja87")

@onready var grid_container: GridContainer = $GridContainer
@onready var swap_stream_player: AudioStreamPlayer = $SwapStreamPlayer
@onready var rejected_player: AudioStreamPlayer = $RejectedPlayer

# Grid configuration
const GRID_SIZE: int = 15
const CELL_MIN_SIZE: Vector2 = Vector2(16, 16) # Width and Height of each cell in pixels
const DIRECTIONS = [
	Vector2i(1, 0),   # Horizontal (Right)
	Vector2i(0, 1),   # Vertical (Down)
	Vector2i(1, 1),   # Diagonal Down-Right (\)
	Vector2i(1, -1)   # Diagonal Up-Right (/)
]

var stone_grid: Array[Array] = []
var servers_stone: StoneType
var clients_stone: StoneType
var game_state: GameState = GameState.SECOND
var initial_fifth_moves_count: int = 0
var lone_fifth_move_coords: Vector2i
var fifth_moves_count: int = 0
var grid_symmetry_data: Dictionary
var stones_on_the_grid: int = 0
var have_swapped_before: bool = false

var _game_outcome: GameOutcome = GameOutcome.UNDECIDED
var game_outcome: GameOutcome:
	get:
		return _game_outcome
	set(value):
		_game_outcome = value
		game_outcome_decided.emit(game_outcome)

var _is_servers_turn: bool = true
var is_servers_turn: bool:
	get:
		return _is_servers_turn
	set(value):
		if _is_servers_turn != value:
			turn_switched.emit(value)
		_is_servers_turn = value

func _ready() -> void:
	position = position_marker.position
	setup_grid()
	
	if !is_multiplayer_authority():
		return
	
	if HostStats.host_just_won:
		is_servers_turn = false
	
	stone_grid.resize(GRID_SIZE)
	for y in range(GRID_SIZE):
		# Create the row and strictly enforce that it ONLY holds your Enum/ints
		var row: Array[int] = [] 
		row.resize(GRID_SIZE)
		row.fill(StoneType.EMPTY)
		
		# Shove the typed row into the main grid
		stone_grid[y] = row
		
	stone_grid[7][7] = StoneType.BLACK
	var cell_global_position: Vector2 = center_cell_marker.global_position
	stone_placed.emit.call_deferred(cell_global_position, CELL_MIN_SIZE, stone_grid[7][7])

func setup_grid() -> void:
	# Clear any existing children just in case
	for child in grid_container.get_children():
		child.queue_free()
	
	# Set the GridContainer columns dynamically
	grid_container.columns = GRID_SIZE
	
	# Generate the 15x15 grid
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			create_cell(x, y)

func create_cell(x: int, y: int) -> void:
	var cell := Button.new()
	
	# NEW: Makes the button background transparent, but it stays clickable
	cell.flat = true
	# Set size constraints so the grid doesn't collapse
	cell.custom_minimum_size = CELL_MIN_SIZE
	
	# Optional: Store coordinates in the button's name or metadata for easy tracking
	cell.name = "Cell_%d_%d" % [x, y]
	cell.set_meta("grid_pos", Vector2i(x, y))
	
	# Connect the press signal using a lambda function to pass coordinates
	cell.pressed.connect(func(): _on_cell_clicked(Vector2i(x, y), cell))
	
	grid_container.add_child(cell)

func _on_cell_clicked(coords: Vector2i, cell_node: Button) -> void:
	print("Clicked cell at coordinates: ", coords)
	place_stone.rpc_id(1, coords, cell_node.get_path())

@rpc("any_peer", "call_local", "reliable")
func place_stone(coords: Vector2i, cell_node_path: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		if !is_servers_turn:
			return
	else:
		if is_servers_turn:
			return
	if game_outcome != GameOutcome.UNDECIDED:
		return
	#check if coords is in 3x3 in center of board
	if game_state == GameState.SECOND && !coords_in_area(coords, Vector2i(6,6), 3):
		if multiplayer.get_remote_sender_id() == 1:
			play_rejected_sound.rpc_id(1)
		elif multiplayer.get_peers().size() > 0:
			play_rejected_sound.rpc_id(multiplayer.get_peers()[0])
		return
	#check if coords is in 5x5 in center of board
	if game_state == GameState.THIRD && !coords_in_area(coords, Vector2i(5,5), 5):
		if multiplayer.get_remote_sender_id() == 1:
			play_rejected_sound.rpc_id(1)
		elif multiplayer.get_peers().size() > 0:
			play_rejected_sound.rpc_id(multiplayer.get_peers()[0])
		return
	
	var stone_grid_pos: Vector2i
	stone_grid_pos.x = coords.y
	stone_grid_pos.y = coords.x
	
	var stone_type: StoneType
	if is_servers_turn:
		stone_type = servers_stone
	else:
		stone_type = clients_stone
	
	if game_state == GameState.SECOND:
		stone_type = StoneType.WHITE
	elif game_state == GameState.THIRD:
		stone_type = StoneType.BLACK
	elif game_state == GameState.FIFTH:
		stone_type = StoneType.FIFTH
	elif game_state == GameState.CHOOSE:
		stone_type = StoneType.BLACK
	
	var change_turns: bool = true
	if game_state == GameState.CHOOSE:
		change_turns = false
		if stone_grid[coords.y][coords.x] != StoneType.FIFTH:
			if multiplayer.get_remote_sender_id() == 1:
				play_rejected_sound.rpc_id(1)
			elif multiplayer.get_peers().size() > 0:
				play_rejected_sound.rpc_id(multiplayer.get_peers()[0])
			return
	else:
		if stone_grid[coords.y][coords.x] != StoneType.EMPTY:
			return
	
	stone_grid[coords.y][coords.x] = stone_type
	stones_on_the_grid += 1
	
	if game_state == GameState.FIFTH:
		if initial_fifth_moves_count == 1:
			lone_fifth_move_coords = coords
		if grid_symmetry_data["left_right"]:
			print("left right symmetry detected")
			if Vector2i(coords.y, coords.x) != Vector2i(coords.y, 2*7 - coords.x):
				stone_grid[coords.y][2*7 - coords.x] = StoneType.BANNED
				var cell_global_position: Vector2 = position_marker.global_position + Vector2(coords * 29)
				cell_global_position.x = 2 * center_cell_marker.global_position.x - cell_global_position.x
				stone_placed.emit(cell_global_position, CELL_MIN_SIZE, stone_grid[coords.y][2*7 - coords.x])
		elif grid_symmetry_data["top_bottom"]:
			print("top bottom symmetry detected")
			if Vector2i(coords.y, coords.x) != Vector2i(2*7 - coords.y, coords.x):
				stone_grid[2*7 - coords.y][coords.x] = StoneType.BANNED
				var cell_global_position: Vector2 = position_marker.global_position + Vector2(coords * 29)
				cell_global_position.y = 2 * center_cell_marker.global_position.y - cell_global_position.y
				stone_placed.emit(cell_global_position, CELL_MIN_SIZE, stone_grid[2*7 - coords.y][coords.x])
		elif grid_symmetry_data["main_diagonal"]:
			print("main symmetry detected")
			if Vector2i(coords.y, coords.x) != Vector2i(coords.x, coords.y):
				stone_grid[coords.x][coords.y] = StoneType.BANNED
				var cell_global_position: Vector2 = position_marker.global_position + Vector2(coords * 29)
				cell_global_position = Vector2(cell_global_position.y, cell_global_position.x)
				stone_placed.emit(cell_global_position, CELL_MIN_SIZE, stone_grid[coords.x][coords.y])
		elif grid_symmetry_data["anti_diagonal"]:
			print("anti symmetry detected")
			if Vector2i(coords.y, coords.x) != Vector2i(GRID_SIZE - 1 - coords.x, GRID_SIZE - 1 - coords.y):
				stone_grid[GRID_SIZE - 1 - coords.x][GRID_SIZE - 1 - coords.y] = StoneType.BANNED
				var cell_global_position: Vector2 = position_marker.global_position + Vector2(coords * 29)
				cell_global_position = Vector2(position_marker.global_position.y * 2 + 29 * (GRID_SIZE-1) - cell_global_position.y, position_marker.global_position.x * 2 + 29 * (GRID_SIZE-1) - cell_global_position.x)
				stone_placed.emit(cell_global_position, CELL_MIN_SIZE, stone_grid[GRID_SIZE - 1 - coords.x][GRID_SIZE - 1 - coords.y])
		
		
	if check_win(stone_grid_pos, stone_type):
		if stone_type == StoneType.BLACK:
			if check_black_overline(stone_grid_pos):
				print("Move rejected: Violates overline rule!")
				stone_grid[coords.y][coords.x] = StoneType.EMPTY # Undo the move
				stones_on_the_grid -= 1
				
				if multiplayer.get_remote_sender_id() == 1:
					play_rejected_sound.rpc_id(1)
				elif multiplayer.get_peers().size() > 0:
					play_rejected_sound.rpc_id(multiplayer.get_peers()[0])
				
				return
			else:
				print("Black Winner!")
				game_outcome = GameOutcome.BLACK_WIN
		else:
			print("White Winner!")
			game_outcome = GameOutcome.WHITE_WIN
	elif stone_type == StoneType.BLACK:
		if violates_three_and_three(stone_grid_pos, stone_type):
			print("Move rejected: Violates the Three-and-Three rule!")
			stone_grid[coords.y][coords.x] = StoneType.EMPTY # Undo the move
			stones_on_the_grid -= 1
			
			if multiplayer.get_remote_sender_id() == 1:
				play_rejected_sound.rpc_id(1)
			elif multiplayer.get_peers().size() > 0:
				play_rejected_sound.rpc_id(multiplayer.get_peers()[0])
			
			return
		
		if violates_four_and_four(stone_grid_pos, stone_type):
			print("Move rejected: Violates the Four-and-Four rule!")
			stone_grid[coords.y][coords.x] = StoneType.EMPTY # Undo the move
			stones_on_the_grid -= 1
			
			if multiplayer.get_remote_sender_id() == 1:
				play_rejected_sound.rpc_id(1)
			elif multiplayer.get_peers().size() > 0:
				play_rejected_sound.rpc_id(multiplayer.get_peers()[0])
			
			return
	
	if game_outcome == GameOutcome.UNDECIDED && stones_on_the_grid == GRID_SIZE * GRID_SIZE:
		print("Draw!")
		game_outcome = GameOutcome.DRAW
	
	stone_placed.emit(get_node(cell_node_path).global_position, CELL_MIN_SIZE, stone_grid[coords.y][coords.x])
	
	if game_state == GameState.FIFTH:
		fifth_moves_count -= 1
	if fifth_moves_count == 0:
		increment_game_state()
	
	if change_turns:
		change_turns = game_state != GameState.THIRD && game_state != GameState.FIFTH
	if change_turns:
		switch_whose_turn_it_is()

@rpc("authority", "call_local", "unreliable")
func play_rejected_sound() -> void:
	rejected_player.play()

func coords_in_area(coords: Vector2i, starting_pos: Vector2i, area_width_height: int) -> bool:
	for y in range(starting_pos.y, starting_pos.y + area_width_height):
		# Loop through 3 columns
		for x in range(starting_pos.x, starting_pos.x + area_width_height):
			if coords == Vector2i(x, y):
				return true
	return false

func check_win(start_pos: Vector2i, stone_type: StoneType) -> bool:
	for dir in DIRECTIONS:
		var count = 1 # Count the piece just placed
		
		# Check positive direction
		count += count_in_direction(start_pos, dir, stone_type)
		# Check negative direction
		count += count_in_direction(start_pos, -dir, stone_type)
		
		if count >= 5:
			return true
	return false

func check_black_overline(start_pos: Vector2i) -> bool:
	var overline_exists: bool = false
	for dir in DIRECTIONS:
		var count = 1 # Count the piece just placed
		
		# Check positive direction
		count += count_in_direction(start_pos, dir, StoneType.BLACK)
		# Check negative direction
		count += count_in_direction(start_pos, -dir, StoneType.BLACK)
		
		#if the move would win black the game with a 5 connection overlines don't matter
		if count == 5:
			return false
		if count > 5:
			overline_exists = true
	return overline_exists

func count_in_direction(start_pos: Vector2i, direction: Vector2i, stone_type: StoneType) -> int:
	var count = 0
	var current_pos = start_pos + direction
	
	# Loop while the coordinates are inside the grid AND match the player's ID
	while is_inside_grid(current_pos.x, current_pos.y) and stone_grid[current_pos.x][current_pos.y] == stone_type:
		count += 1
		current_pos += direction # Keep stepping in that direction
		
	return count

# Helper helper function to keep the while loop safe from crashes
func is_inside_grid(x: int, y: int) -> bool:
	return x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE

func violates_three_and_three(start_pos: Vector2i, stone_type: StoneType) -> bool:
	var open_three_count = 0
	
	# Check all 4 axes running through the placed stone
	for dir in DIRECTIONS:
		if is_open_three_on_axis(start_pos, dir, stone_type):
			open_three_count += 1
			
		# If we hit 2 or more open rows of three, it's a violation
		if open_three_count >= 2:
			return true
			
	return false

func is_open_three_on_axis(start_pos: Vector2i, direction: Vector2i, stone_type: StoneType) -> bool:
	# 1. Extract a 9-cell window centered around our new piece
	# Index 4 of this local array will be our newly placed stone.
	var line = []
	for i in range(-4, 5):
		var check_pos = start_pos + direction * i
		if is_inside_grid(check_pos.x, check_pos.y):
			line.append(stone_grid[check_pos.x][check_pos.y])
		else:
			line.append(-1) # -1 represents an out-of-bounds boundary block
	# FIX: If this axis ALREADY contains an open four, it is a four-row threat, 
	# NOT an open three. We return false immediately.
	if contains_open_four(line, stone_type):
		return false
	# 2. Simulate playing an additional stone on every empty slot ('0') in this window
	for j in range(9):
		if line[j] == StoneType.EMPTY:
			var test_line = line.duplicate()
			test_line[j] = stone_type # Hypothethical next move
			
			# 3. Check if this next move creates a perfect "Open Four"
			# A perfect Open Four pattern is strictly: [0, id, id, id, id, 0]
			if contains_open_four(test_line, stone_type): # Slide a 6-cell window across our 9-cell line
				return true
	return false

# Helper function to find a clean, unblocked open four profile (. 1 1 1 1 .)
func contains_open_four(line: Array, player_id: int) -> bool:
	for k in range(4): 
		if line[k] == 0 \
		and line[k+1] == player_id \
		and line[k+2] == player_id \
		and line[k+3] == player_id \
		and line[k+4] == player_id \
		and line[k+5] == 0:
			return true
	return false

func violates_four_and_four(start_pos: Vector2i, stone_type: StoneType) -> bool:
	var four_axis_count = 0
	
	# Check all 4 lines passing through our newly placed stone
	for dir in DIRECTIONS:
		if is_four_on_axis(start_pos, dir, stone_type):
			four_axis_count += 1
			
		# If this move created 2 or more separate rows of four, it's illegal
		if four_axis_count >= 2:
			return true
			
	return false

func is_four_on_axis(start_pos: Vector2i, direction: Vector2i, stone_type: StoneType) -> bool:
	# Extract a 9-cell line centered around our new piece (index 4 is our piece)
	var line = []
	for i in range(-4, 5):
		var check_pos = start_pos + direction * i
		if is_inside_grid(check_pos.x, check_pos.y):
			line.append(stone_grid[check_pos.x][check_pos.y])
		else:
			line.append(-1) # Out of bounds block
			
	# Simulate playing an additional stone on every empty slot ('0') in this window
	for j in range(9):
		if line[j] == StoneType.EMPTY:
			var test_line = line.duplicate()
			test_line[j] = stone_type # Hypothethical next move
			
			# If adding this single stone results in an unbroken 5-in-a-row,
			# then this axis natively contains a "Row of Four".
			if has_five_in_a_row(test_line, stone_type):
				return true 
				
	return false

func has_five_in_a_row(line: Array, stone_type: StoneType) -> bool:
	# A clean sliding window of size 5 to find an unbroken line
	for i in range(5):
		if line[i] == stone_type \
		and line[i+1] == stone_type \
		and line[i+2] == stone_type \
		and line[i+3] == stone_type \
		and line[i+4] == stone_type:
			return true
	return false

func set_servers_stone_type(stone_type: StoneType) -> void:
	if game_state != GameState.SECOND && servers_stone != stone_type:
		if have_swapped_before:
			swap_stream_player_to_oh_snap.rpc()
		play_swap_stream_player.rpc()
		have_swapped_before = true
		
	servers_stone = stone_type
	if servers_stone == StoneType.BLACK:
		clients_stone = StoneType.WHITE
	else:
		clients_stone = StoneType.BLACK
	
	if game_state == GameState.SECOND:
		is_servers_turn = servers_stone == StoneType.BLACK
	if game_state == GameState.FOURTH:
		is_servers_turn = servers_stone == StoneType.WHITE
	if game_state == GameState.FIFTH:
		is_servers_turn = servers_stone == StoneType.BLACK

@rpc("authority", "call_local", "unreliable")
func swap_stream_player_to_oh_snap() -> void:
	swap_stream_player.stream = SECOND_SNAP

@rpc("authority", "call_local", "unreliable")
func play_swap_stream_player() -> void:
	swap_stream_player.play()

func increment_game_state() -> void:
	# Get the maximum valid integer index (size - 1)
	var max_game_state = GameState.size() - 1
	# Clamp the value so it never exceeds the maximum
	if game_state == GameState.SECOND:
		second_move_finished.emit()
	
	if game_state == GameState.THIRD:
		third_move_finished.emit()
	
	if game_state == GameState.FOURTH:
		fourth_move_finished.emit()
		grid_symmetry_data = check_board_symmetry()
	
	if game_state == GameState.FIFTH:
		fifth_move_finished.emit()
		empty_stone_type_in_stone_grid(StoneType.BANNED)
		if initial_fifth_moves_count == 1:
			stone_grid[lone_fifth_move_coords.y][lone_fifth_move_coords.x] = StoneType.BLACK
			var cell_global_position: Vector2 = position_marker.global_position + Vector2(lone_fifth_move_coords * 29)
			stone_placed.emit(cell_global_position, CELL_MIN_SIZE, stone_grid[lone_fifth_move_coords.y][lone_fifth_move_coords.x])
	
	if game_state == GameState.CHOOSE:
		choose_move_finished.emit()
		empty_stone_type_in_stone_grid(StoneType.FIFTH)
		stones_on_the_grid = 5
	
	game_state = min(int(game_state) + 1, max_game_state) as GameState
	
	if game_state == GameState.CHOOSE && initial_fifth_moves_count == 1:
		increment_game_state()

func switch_whose_turn_it_is() -> void:
	if game_outcome == GameOutcome.UNDECIDED:
		is_servers_turn = !is_servers_turn

func set_fifth_moves_count(move_count: int) -> void:
	initial_fifth_moves_count = move_count
	fifth_moves_count = initial_fifth_moves_count

func empty_stone_type_in_stone_grid(stone_type: StoneType):
	for row in stone_grid.size():
		for column in stone_grid[row].size():
			if stone_grid[row][column] == stone_type:
				stone_grid[row][column] = StoneType.EMPTY

# Checks if the board has ANY type of line symmetry
func check_board_symmetry() -> Dictionary:
	return {
		"left_right": is_left_right_symmetrical(),
		"top_bottom": is_top_bottom_symmetrical(),
		"main_diagonal": is_main_diagonal_symmetrical(),
		"anti_diagonal": is_anti_diagonal_symmetrical()
	}

# Horizontal Symmetry (Left side mirrors Right side)
func is_left_right_symmetrical() -> bool:
	var total_rows = stone_grid.size()
	var total_cols = stone_grid[0].size()
	var max_col_idx = total_cols - 1
	
	# Only loop through the left half of the columns
	for row in range(total_rows):
		@warning_ignore("integer_division")
		for col in range(total_cols/2):
			if stone_grid[row][col] != stone_grid[row][max_col_idx - col]:
				return false # Mismatch found
	
	return true

# Top half mirrors Bottom half (Reflection across a horizontal center axis)
func is_top_bottom_symmetrical() -> bool:
	var total_rows = stone_grid.size()
	var total_cols = stone_grid[0].size()
	var max_row_idx = total_rows - 1
	
	# Loop through only half of the rows, but every column
	@warning_ignore("integer_division")
	for row in range(total_rows / 2):
		for col in range(total_cols):
			# The column stays the same, the row mirrors to the opposite side
			if stone_grid[row][col] != stone_grid[max_row_idx - row][col]:
				return false
	return true

# Main Diagonal Symmetry ("\")
func is_main_diagonal_symmetrical() -> bool:
	var total_rows = stone_grid.size()
	
	for row in range(total_rows):
		# Only loop through the triangle below the diagonal line (col < row)
		for col in range(row):
			# Swap the row and column indices to check the reflection
			if stone_grid[row][col] != stone_grid[col][row]:
				return false
	return true

# Anti-Diagonal Symmetry ("/")
func is_anti_diagonal_symmetrical() -> bool:
	var total_rows = stone_grid.size()
	var max_idx = total_rows - 1
	
	for row in range(total_rows):
		# Only loop through the triangle above the anti-diagonal line
		for col in range(max_idx - row):
			var mirror_row = max_idx - col
			var mirror_col = max_idx - row
			if stone_grid[row][col] != stone_grid[mirror_row][mirror_col]:
				return false
	return true

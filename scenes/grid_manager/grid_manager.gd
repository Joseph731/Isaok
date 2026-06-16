extends Control
class_name GridManager

enum StoneType {EMPTY, BLACK, WHITE}

signal stone_placed(cell: Button, stone_type: StoneType)

@export var position_marker: Marker2D
@export var center_cell_marker: Marker2D

@onready var grid_container: GridContainer = $GridContainer

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
var is_servers_turn: bool = true

func _ready() -> void:
	position = position_marker.position
	
	setup_grid()
	
	if !is_multiplayer_authority():
		return
	
	stone_grid.resize(GRID_SIZE)
	
	for y in range(GRID_SIZE):
		# Create the row and strictly enforce that it ONLY holds your Enum/ints
		var row: Array[int] = [] 
		row.resize(GRID_SIZE)
		row.fill(StoneType.EMPTY)
		
		# Shove the typed row into the main grid
		stone_grid[y] = row
		
	stone_grid[7][7] = StoneType.BLACK
	var cell = Button.new()
	cell.custom_minimum_size = CELL_MIN_SIZE
	cell.global_position = center_cell_marker.global_position
	stone_placed.emit.call_deferred(cell, stone_grid[7][7])

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
	var stone_grid_pos: Vector2i
	stone_grid_pos.x = coords.y
	stone_grid_pos.y = coords.x
	
	var stone_type: StoneType
	if is_servers_turn:
		stone_type = servers_stone
	else:
		stone_type = clients_stone
	
	if stone_grid[stone_grid_pos.x][stone_grid_pos.y] != StoneType.EMPTY:
		return
	
	if multiplayer.get_remote_sender_id() == 1:
		if is_servers_turn:
			stone_grid[stone_grid_pos.x][stone_grid_pos.y] = stone_type
		else:
			return
	else:
		if !is_servers_turn:
			stone_grid[stone_grid_pos.x][stone_grid_pos.y] = stone_type
		else:
			return
	
	if check_win(stone_grid_pos, stone_type):
		if stone_type == StoneType.BLACK:
			print("Black Winner!")
		else:
			print("White Winner!")
	else:
		if stone_type == StoneType.BLACK && violates_three_and_three(stone_grid_pos, stone_type):
			print("Move rejected: Violates the Three-and-Three rule!")
			stone_grid[stone_grid_pos.x][stone_grid_pos.y] = StoneType.EMPTY # Undo the move
			return
		if stone_type == StoneType.BLACK && violates_four_and_four(stone_grid_pos, stone_type):
			print("Move rejected: Violates the Four-and-Four rule!")
			stone_grid[stone_grid_pos.x][stone_grid_pos.y] = 0 # Rollback the move
			return
	
	stone_placed.emit(get_node(cell_node_path), stone_grid[stone_grid_pos.x][stone_grid_pos.y])
	is_servers_turn = !is_servers_turn

func check_win(start_pos: Vector2i, stone_type: StoneType) -> bool:
	for dir in DIRECTIONS:
		var count = 1 # Count the piece just placed
		
		# Check positive direction
		count += count_in_direction(start_pos, dir, stone_type)
		# Check negative direction
		count += count_in_direction(start_pos, -dir, stone_type)
		
		if stone_type == StoneType.BLACK && count == 5:
			return true
		elif stone_type == StoneType.WHITE && count >= 5:
			return true
	return false

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
			
	# 2. Simulate playing an additional stone on every empty slot ('0') in this window
	for j in range(9):
		if line[j] == 0:
			var test_line = line.duplicate()
			test_line[j] = stone_type # Hypothethical next move
			
			# 3. Check if this next move creates a perfect "Open Four"
			# A perfect Open Four pattern is strictly: [0, id, id, id, id, 0]
			for k in range(4): # Slide a 6-cell window across our 9-cell line
				if test_line[k] == 0 \
				and test_line[k+1] == stone_type \
				and test_line[k+2] == stone_type \
				and test_line[k+3] == stone_type \
				and test_line[k+4] == stone_type \
				and test_line[k+5] == 0:
					return true # An open three exists on this axis!
					
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
		if line[j] == 0:
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

func _on_stone_selection_prompt_stone_selected(stone_type: StoneType) -> void:
		servers_stone = stone_type
		if servers_stone == StoneType.BLACK:
			clients_stone = StoneType.WHITE
		else:
			clients_stone = StoneType.BLACK

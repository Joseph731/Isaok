extends Node
class_name UIManager

signal stone_selection_prompt_created(stone_selection_prompt: StoneSelectionPrompt)
signal fifth_moves_count_prompt_created(fifth_moves_count_prompt: FifthMovesCountPrompt)
signal game_over_prompt_created(game_over_prompt: GameOverPrompt)
signal pause_request_prompt_created(pause_request_prompt: PauseRequestPrompt)

@export var grid_manager: GridManager
@export var turn_timer_host: Timer
@export var turn_timer_challenger: Timer

@onready var stones: Node = $Stones
@onready var center_label: Label = $MarginContainer/CenterLabel
@onready var prompt_spawner: MultiplayerSpawner = $PromptSpawner
@onready var pause_request_prompt_spawner: MultiplayerSpawner = $PauseRequestPromptSpawner
@onready var turn_timer_label: Label = $MarginContainer/TurnTimerLabel
@onready var whose_turn_label: Label = $MarginContainer/WhoseTurnLabel
@onready var pass_button: Button = $PassButton
@onready var pause_request_prompts: CanvasLayer = $PauseRequestPrompts

const STONE: PackedScene = preload("uid://dyrih8v8f0hie")
const STONE_SELECTION_PROMPT: PackedScene = preload("uid://dly5k3xygv7tn")
const FIFTH_MOVES_COUNT_PROMPT: PackedScene = preload("uid://cghnoly1psgtq")
const GAME_OVER_PROMPT: PackedScene = preload("uid://cadoonsqj6px8")
const PAUSE_REQUEST_PROMPT: PackedScene = preload("uid://1gtjdwujhlyb")

var newest_stone: Stone
var fifth_stones: Array[Stone]
var banned_stones: Array[Stone]

func _ready() -> void:
	prompt_spawner.spawned.connect(_on_prompt_spawned)
	pause_request_prompt_spawner.spawned.connect(_on_pause_request_prompt_spawned)
	grid_manager.stone_placed.connect(_on_stone_placed)
	grid_manager.turn_switched.connect(_on_turn_switched)
	grid_manager.second_move_finished.connect(_on_second_move_finished)
	grid_manager.third_move_finished.connect(_on_third_move_finished)
	grid_manager.fourth_move_finished.connect(_on_fourth_move_finished)
	grid_manager.fifth_move_finished.connect(_on_fifth_move_finished)
	grid_manager.choose_move_finished.connect(_on_choose_move_finished)
	grid_manager.game_outcome_decided.connect(_on_game_outcome_decided)
	if is_multiplayer_authority():
		create_stone_selection_prompt(true)

func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		update_turn_timer_label()

func update_turn_timer_label():
	var turn_timer: Timer
	if !turn_timer_host.paused:
		turn_timer = turn_timer_host
		turn_timer_label.text = "Host's time: "
	elif !turn_timer_challenger.paused:
		turn_timer = turn_timer_challenger
		turn_timer_label.text = "Challenger's time: "
	else:
		return
	
	var total_seconds: int = int(ceilf(turn_timer.time_left))
	
	# Calculate hours, minutes, and seconds
	@warning_ignore("integer_division")
	var hours: int = total_seconds / 3600
	@warning_ignore("integer_division")
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	
	# Dynamically change the format based on whether hours exist
	if hours > 0:
		turn_timer_label.text += "%02d:%02d:%02d" % [hours, minutes, seconds]
	else:
		turn_timer_label.text += "%02d:%02d" % [minutes, seconds]

func _on_stone_placed(cell_global_position: Vector2, cell_size: Vector2, stone_type: GridManager.StoneType) -> void:
	var stone: Stone = STONE.instantiate()
	stone.global_position = cell_global_position + cell_size / 2
	if stone_type == GridManager.StoneType.BLACK:
		stone.texture_index = 0
	elif stone_type == GridManager.StoneType.WHITE:
		stone.texture_index = 1
	elif stone_type == GridManager.StoneType.FIFTH:
		stone.texture_index = 2
		fifth_stones.append(stone)
	elif stone_type == GridManager.StoneType.BANNED:
		stone.texture_index = 3
		banned_stones.append(stone)
	
	stones.add_child(stone, true)
	
	if newest_stone != null:
		newest_stone.animation_player.play("RESET")
	newest_stone = stone
	newest_stone.animation_player.play("recently_placed")

func _on_second_move_finished() -> void:
	center_label.text = "Place stone in center 5x5"

func _on_third_move_finished() -> void:
	center_label.text = ""
	if grid_manager.servers_stone == GridManager.StoneType.WHITE:
		create_stone_selection_prompt(true)
	else:
		create_stone_selection_prompt(false)

func create_stone_selection_prompt(is_for_server: bool) -> void:
	var stone_selection_prompt: StoneSelectionPrompt = STONE_SELECTION_PROMPT.instantiate()
	add_child(stone_selection_prompt)
	stone_selection_prompt_created.emit.call_deferred(stone_selection_prompt)
	stone_selection_prompt.is_for_server = is_for_server

func _on_fourth_move_finished() -> void:
	if grid_manager.servers_stone == GridManager.StoneType.WHITE:
		create_fifth_moves_count_prompt(true)
	else:
		create_fifth_moves_count_prompt(false)

func create_fifth_moves_count_prompt(is_for_server: bool) -> void:
	var fifth_moves_count_prompt: FifthMovesCountPrompt = FIFTH_MOVES_COUNT_PROMPT.instantiate()
	add_child(fifth_moves_count_prompt)
	fifth_moves_count_prompt_created.emit(fifth_moves_count_prompt)
	fifth_moves_count_prompt.fifth_moves_count_selected.connect(_on_fifth_moves_count_selected)
	fifth_moves_count_prompt.is_for_server = is_for_server

func _on_fifth_moves_count_selected(moves_count: int, _fifth_moves_count_prompt: FifthMovesCountPrompt) -> void:
	handle_fifth_moves_count_selected.rpc_id(1, moves_count)

@rpc("any_peer", "call_local", "reliable")
func handle_fifth_moves_count_selected(moves_count: int) -> void:
	set_fifth_moves_count_text(moves_count)
	create_stone_selection_prompt(!multiplayer.is_server())

func set_fifth_moves_count_text(moves_count: int) -> void:
	center_label.text = "There will be " + str(moves_count) + " fifth moves"

func _on_fifth_move_finished() -> void:
	for banned_stone in banned_stones:
		banned_stone.queue_free()
	banned_stones.clear()
	center_label.text = "Choose black's fifth move"

func _on_choose_move_finished() -> void:
	for fifth_stone in fifth_stones:
		fifth_stone.queue_free()
	fifth_stones.clear()
	center_label.text = ""
	pass_button.visible = true

func _on_prompt_spawned(prompt: Node) -> void:
	if multiplayer.is_server():
		return
	if prompt is StoneSelectionPrompt:
		stone_selection_prompt_created.emit(prompt)
	if prompt is FifthMovesCountPrompt:
		fifth_moves_count_prompt_created.emit(prompt)
		prompt.fifth_moves_count_selected.connect(_on_fifth_moves_count_selected)
	if prompt is GameOverPrompt:
		game_over_prompt_created.emit(prompt)

func _on_pause_request_prompt_spawned(pause_request_prompt: Node) -> void:
	pause_request_prompt_created.emit(pause_request_prompt)

func _on_turn_switched(is_servers_turn: bool) -> void:
		if (is_servers_turn && grid_manager.servers_stone == GridManager.StoneType.WHITE) || (!is_servers_turn && grid_manager.clients_stone == GridManager.StoneType.WHITE):
			whose_turn_label.text = "White's turn"
		else:
			whose_turn_label.text = "Black's turn"

func _on_game_outcome_decided(game_outcome: GridManager.GameOutcome) -> void:
	match game_outcome:
		GridManager.GameOutcome.BLACK_WIN:
			center_label.text = "Black Wins!"
			if grid_manager.servers_stone == grid_manager.StoneType.BLACK:
				create_game_over_prompt(true, "Victory")
				create_game_over_prompt(false, "Defeat")
			else:
				create_game_over_prompt(true, "Defeat")
				create_game_over_prompt(false, "Victory")
		GridManager.GameOutcome.WHITE_WIN:
			center_label.text = "White Wins!"
			if grid_manager.servers_stone == grid_manager.StoneType.WHITE:
				create_game_over_prompt(true, "Victory")
				create_game_over_prompt(false, "Defeat")
			else:
				create_game_over_prompt(true, "Defeat")
				create_game_over_prompt(false, "Victory")
		GridManager.GameOutcome.DRAW:
			center_label.text = "Draw!"
			create_game_over_prompt(true, "Tie")
			create_game_over_prompt(false, "Tie")
			
	whose_turn_label.text = ""
	turn_timer_label.text = ""
	pass_button.visible = false

func create_game_over_prompt(is_for_server: bool, label_text: String) -> void:
	var game_over_prompt: GameOverPrompt = GAME_OVER_PROMPT.instantiate()
	add_child(game_over_prompt, true)
	game_over_prompt_created.emit(game_over_prompt)
	game_over_prompt.is_for_server = is_for_server
	game_over_prompt.label.text = label_text

func create_pause_request_prompt(is_for_server: bool) -> void:
	if pause_request_prompts.get_child_count() > 0:
		return
	var pause_request_prompt: PauseRequestPrompt = PAUSE_REQUEST_PROMPT.instantiate()
	pause_request_prompts.add_child(pause_request_prompt)
	pause_request_prompt_created.emit(pause_request_prompt)
	pause_request_prompt.is_for_server = is_for_server

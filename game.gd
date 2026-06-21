extends Node

const MAIN_MENU_SCENE_PATH: String = "res://scenes/menus/main_menu/main_menu.tscn"

@onready var grid_manager: GridManager = $GridManager
@onready var ui_manager: UIManager = $UIManager
@onready var network_manager: NetworkManager = $NetworkManager
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var turn_timer_host: Timer = $TurnTimerHost
@onready var turn_timer_challenger: Timer = $TurnTimerChallenger

func _ready() -> void:
	turn_timer_host.paused = true
	turn_timer_challenger.paused = true
	turn_timer_host.timeout.connect(_on_host_time_out)
	turn_timer_challenger.timeout.connect(_on_challenger_time_out)
	pause_menu.quit_requested.connect(network_manager.end_game)
	ui_manager.stone_selection_prompt_created.connect(_on_stone_selection_prompt_created)
	ui_manager.fifth_moves_count_prompt_created.connect(_on_fifth_moves_count_prompt_created)
	grid_manager.turn_switched.connect(_on_turn_switched)

func _on_stone_selection_prompt_created(stone_selection_prompt: StoneSelectionPrompt) -> void:
	stone_selection_prompt.stone_selected.connect(_on_stone_selection_prompt_stone_selected)

func _on_stone_selection_prompt_stone_selected(stone_type: GridManager.StoneType, stone_selection_prompt: StoneSelectionPrompt) -> void:
	if grid_manager.game_state == GridManager.GameState.SECOND:
		if stone_selection_prompt.is_for_server:
			if stone_type == grid_manager.StoneType.WHITE:
				turn_timer_host.start(turn_timer_host.time_left - 30)
			else:
				turn_timer_host.paused = false
		else:
			if stone_type == grid_manager.StoneType.WHITE:
				turn_timer_challenger.start(turn_timer_challenger.time_left - 30)
			else:
				turn_timer_challenger.paused = false
	
	grid_manager.set_peers_stone_types.rpc_id(1, stone_type)
	queue_free_a_node.rpc_id(1, stone_selection_prompt.get_path())

func _on_fifth_moves_count_prompt_created(fifth_moves_count_prompt: FifthMovesCountPrompt) -> void:
	fifth_moves_count_prompt.fifth_moves_count_selected.connect(_on_fifth_moves_count_prompt_count_selected)

func _on_fifth_moves_count_prompt_count_selected(moves_count: int, fifth_moves_count_prompt: FifthMovesCountPrompt) -> void:
	grid_manager.switch_whose_turn_it_is.rpc_id(1)
	grid_manager.set_fifth_moves_count.rpc_id(1, moves_count)
	queue_free_a_node.rpc_id(1, fifth_moves_count_prompt.get_path())

@rpc("any_peer", "call_local", "reliable")
func queue_free_a_node(node_path: String):
	get_node(node_path).queue_free()

func _on_host_time_out() -> void:
	print("Challenger wins!")

func _on_challenger_time_out() -> void:
	print("Host wins!")

func _on_turn_switched(is_servers_turn: bool) -> void:
	if is_servers_turn:
		turn_timer_challenger.start(turn_timer_challenger.time_left + 30)
		turn_timer_challenger.paused = true
		turn_timer_host.paused = false
	else:
		turn_timer_host.start(turn_timer_host.time_left + 30)
		turn_timer_host.paused = true
		turn_timer_challenger.paused = false

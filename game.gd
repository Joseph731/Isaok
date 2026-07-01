extends Node

const MAIN_MENU_SCENE_PATH: String = "res://scenes/menus/main_menu/main_menu.tscn"
const KAHOOT_MUSIC = preload("uid://d2nyr17by2e02")
const WIN = preload("uid://seuy6pfpjqut")
const LOSE = preload("uid://dwntwhjhmp11k")
const DRAW = preload("uid://wao6vpt50ohd")

@onready var grid_manager: GridManager = $GridManager
@onready var ui_manager: UIManager = $UIManager
@onready var network_manager: NetworkManager = $NetworkManager
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var turn_timer_host: Timer = $TurnTimerHost
@onready var turn_timer_challenger: Timer = $TurnTimerChallenger
@onready var pause_panel: PanelContainer = $PausePanel
@onready var garrosh_player: AudioStreamPlayer = $GarroshPlayer
@onready var stone_plop_player: AudioStreamPlayer = $StonePlopPlayer
@onready var game_over_player: AudioStreamPlayer = $GameOverPlayer
@onready var pause_menu_button: Button = $PauseMenuButton
@onready var timers_to_protect: Array[Timer] = [
	turn_timer_host,
	turn_timer_challenger
]

var consecutive_passes: int = 0
var last_frame_time_msec: int = 0

func _ready() -> void:
	MusicPlayer.stream = KAHOOT_MUSIC
	
	last_frame_time_msec = Time.get_ticks_msec()
	
	turn_timer_host.paused = true
	turn_timer_challenger.paused = true
	
	if is_multiplayer_authority():
		pause_panel.visible = false
	
	pause_menu_button.pressed.connect(pause_menu.pause)
	turn_timer_host.timeout.connect(_on_host_time_out)
	turn_timer_challenger.timeout.connect(_on_challenger_time_out)
	pause_menu.quit_requested.connect(network_manager.end_game)
	pause_menu.pause_button.pressed.connect(_on_pause_requested)
	pause_menu.rematch_button.pressed.connect(_on_rematch_requested)
	ui_manager.stone_selection_prompt_created.connect(_on_stone_selection_prompt_created)
	ui_manager.fifth_moves_count_prompt_created.connect(_on_fifth_moves_count_prompt_created)
	ui_manager.game_over_prompt_created.connect(_on_game_over_prompt_created)
	ui_manager.pause_request_prompt_created.connect(_on_pause_request_prompt_created)
	ui_manager.pass_button.pressed.connect(_on_pass_button_pressed)
	grid_manager.turn_switched.connect(_on_turn_switched)
	grid_manager.game_outcome_decided.connect(_on_game_outcome_decided)
	grid_manager.stone_placed.connect(_on_stone_placed)

func _process(delta: float) -> void:
	if is_multiplayer_authority() && grid_manager.game_outcome == grid_manager.GameOutcome.UNDECIDED:
		if turn_timer_host.time_left < 30 || turn_timer_challenger.time_left < 30:
			if !MusicPlayer.playing:
				MusicPlayer.play_music_player.rpc()
				if turn_timer_host.time_left < 30:
					play_garrosh_sound.rpc_id(1)
				elif multiplayer.get_peers().size() > 0:
					play_garrosh_sound.rpc_id(multiplayer.get_peers()[0])
		elif MusicPlayer.playing:
			MusicPlayer.stop_music_player.rpc()
		
		var current_time_msec = Time.get_ticks_msec()
		# Calculate how much real-world time actually passed since the last frame
		var real_delta_seconds = (current_time_msec - last_frame_time_msec) / 1000.0
		
		# Threshold: If the gap is greater than 1.0 second, the browser tab was asleep
		if real_delta_seconds > 1.0:
			# Godot is already going to subtract the standard frame 'delta' right now,
			# so the 'extra' time lost that Godot doesn't know about is:
			var extra_time_lost = real_delta_seconds - delta
			
			print("Browser tab woke up! Catching up timers by: ", extra_time_lost, " seconds.")
			_catch_up_timer_nodes(extra_time_lost)
		
		# Always update the timestamp for the next frame
		last_frame_time_msec = current_time_msec

func _catch_up_timer_nodes(seconds_lost: float) -> void:
	for timer in timers_to_protect:
		# Skip if the timer isn't currently active
		if timer.paused:
			continue
		
		# Calculate what the new time_left should be
		var new_time_left = timer.time_left - seconds_lost
		
		if new_time_left > 0:
			# If there's still time left, restart it with the corrected time
			timer.start(new_time_left)
		else:
			# If the timer should have finished while the browser was closed,
			# trigger its timeout signal immediately!
			timer.emit_signal("timeout")
			timer.stop()

@rpc("authority", "call_local", "unreliable")
func play_garrosh_sound() -> void:
	garrosh_player.play()

func _on_stone_selection_prompt_created(stone_selection_prompt: StoneSelectionPrompt) -> void:
	grid_manager.input_blocking_prompt_is_up = true
	stone_selection_prompt.stone_selected.connect(_on_stone_selection_prompt_stone_selected)

func _on_stone_selection_prompt_stone_selected(stone_type: GridManager.StoneType, stone_selection_prompt: StoneSelectionPrompt) -> void:
	handle_stone_selection_prompt_stone_selected.rpc_id(1, stone_type, stone_selection_prompt.get_path())

@rpc("any_peer", "call_local", "reliable")
func handle_stone_selection_prompt_stone_selected(stone_type: GridManager.StoneType, stone_selection_prompt_path: String) -> void:
	if grid_manager.game_is_paused || !grid_manager.input_blocking_prompt_is_up:
		return
	var stone_selection_prompt: StoneSelectionPrompt = get_node(stone_selection_prompt_path)
	if stone_selection_prompt == null:
		return
	
	if grid_manager.game_outcome != GridManager.GameOutcome.UNDECIDED:
		stone_selection_prompt.queue_free()
		grid_manager.input_blocking_prompt_is_up = false
		return
	
	if grid_manager.game_state == GridManager.GameState.SECOND && stone_type == grid_manager.StoneType.BLACK:
		if stone_selection_prompt.is_for_server:
			turn_timer_host.paused = false
		else:
			turn_timer_challenger.paused = false
	
	if stone_selection_prompt.is_for_server:
		grid_manager.set_servers_stone_type(stone_type)
	else:
		if stone_type == GridManager.StoneType.BLACK:
			grid_manager.set_servers_stone_type(GridManager.StoneType.WHITE)
		else:
			grid_manager.set_servers_stone_type(GridManager.StoneType.BLACK)
	
	stone_selection_prompt.queue_free()
	grid_manager.input_blocking_prompt_is_up = false

func _on_fifth_moves_count_prompt_created(fifth_moves_count_prompt: FifthMovesCountPrompt) -> void:
	grid_manager.input_blocking_prompt_is_up = true
	fifth_moves_count_prompt.fifth_moves_count_selected.connect(_on_fifth_moves_count_prompt_count_selected)

func _on_fifth_moves_count_prompt_count_selected(moves_count: int, fifth_moves_count_prompt: FifthMovesCountPrompt) -> void:
	handle_fifth_moves_count_prompt_count_selected.rpc_id(1, moves_count, fifth_moves_count_prompt.get_path())

@rpc("any_peer", "call_local", "reliable")
func handle_fifth_moves_count_prompt_count_selected(moves_count: int, fifth_moves_count_prompt_path: String) -> void:
	if grid_manager.game_is_paused || !grid_manager.input_blocking_prompt_is_up:
		return
	var fifth_moves_count_prompt: FifthMovesCountPrompt = get_node(fifth_moves_count_prompt_path)
	if fifth_moves_count_prompt == null:
		return
	fifth_moves_count_prompt.queue_free()
	grid_manager.input_blocking_prompt_is_up = false
	
	if grid_manager.game_outcome != GridManager.GameOutcome.UNDECIDED:
		return
	grid_manager.switch_whose_turn_it_is()
	grid_manager.set_fifth_moves_count(moves_count)

func _on_game_over_prompt_created(game_over_prompt: GameOverPrompt) -> void:
	game_over_prompt.background_button.pressed.connect(_on_game_over_prompt_background_button_pressed.bind(game_over_prompt))
	game_over_prompt.rematch_selected.connect(_on_rematch_requested)
	game_over_prompt.quit_to_main_menu_selected.connect(network_manager.end_game)

func _on_game_over_prompt_background_button_pressed(game_over_prompt: GameOverPrompt):
	handle_game_over_prompt_background_button_pressed.rpc_id(1, game_over_prompt.get_path())

@rpc("any_peer", "call_local", "reliable")
func handle_game_over_prompt_background_button_pressed(game_over_prompt_path: String) -> void:
	var game_over_prompt: GameOverPrompt = get_node(game_over_prompt_path)
	if game_over_prompt == null:
		return
	game_over_prompt.queue_free()

func _on_host_time_out() -> void:
	print("Challenger wins!")
	if grid_manager.clients_stone == grid_manager.StoneType.BLACK:
		grid_manager.game_outcome = GridManager.GameOutcome.BLACK_WIN
	else:
		grid_manager.game_outcome = GridManager.GameOutcome.WHITE_WIN

func _on_challenger_time_out() -> void:
	print("Host wins!")
	if grid_manager.servers_stone == grid_manager.StoneType.BLACK:
		grid_manager.game_outcome = GridManager.GameOutcome.BLACK_WIN
	else:
		grid_manager.game_outcome = GridManager.GameOutcome.WHITE_WIN

func _on_turn_switched(is_servers_turn: bool) -> void:
	if is_servers_turn:
		if grid_manager.game_state != GridManager.GameState.SECOND:
			turn_timer_challenger.start(turn_timer_challenger.time_left + 30)
		turn_timer_challenger.paused = true
		turn_timer_host.paused = false
	else:
		if grid_manager.game_state != GridManager.GameState.SECOND:
			turn_timer_host.start(turn_timer_host.time_left + 30)
		turn_timer_host.paused = true
		turn_timer_challenger.paused = false

func _on_game_outcome_decided(game_outcome: GridManager.GameOutcome) -> void:
	turn_timer_host.paused = true
	turn_timer_challenger.paused = true
	pause_menu.rematch_button.visible = true
	
	if game_outcome == GridManager.GameOutcome.BLACK_WIN:
		if grid_manager.servers_stone == GridManager.StoneType.BLACK:
			HostStats.host_wins += 1
			HostStats.host_just_won = true
		else:
			HostStats.host_loses += 1
			HostStats.host_just_won = false
	elif game_outcome == GridManager.GameOutcome.WHITE_WIN:
		if grid_manager.servers_stone == GridManager.StoneType.WHITE:
			HostStats.host_wins += 1
			HostStats.host_just_won = true
		else:
			HostStats.host_loses += 1
			HostStats.host_just_won = false
	else:
		HostStats.host_ties += 1
		HostStats.host_just_won = false
	pause_menu.update_host_stats_labels()
	
	if game_outcome == GridManager.GameOutcome.DRAW:
		set_game_over_player.rpc(GameOverPrompt.GameOverOutcome.TIE)
	elif HostStats.host_just_won:
		set_game_over_player.rpc_id(1, GameOverPrompt.GameOverOutcome.VICTORY)
		if multiplayer.get_peers().size() > 0:
			set_game_over_player.rpc_id(multiplayer.get_peers()[0], GameOverPrompt.GameOverOutcome.DEFEAT)
	else:
		set_game_over_player.rpc_id(1, GameOverPrompt.GameOverOutcome.DEFEAT)
		if multiplayer.get_peers().size() > 0:
			set_game_over_player.rpc_id(multiplayer.get_peers()[0], GameOverPrompt.GameOverOutcome.VICTORY)
	play_game_over_sound.rpc()

@rpc("authority", "call_local", "unreliable")
func set_game_over_player(game_over_outcome: GameOverPrompt.GameOverOutcome) -> void:
	if game_over_outcome == GameOverPrompt.GameOverOutcome.VICTORY:
		game_over_player.stream = WIN
	elif game_over_outcome == GameOverPrompt.GameOverOutcome.DEFEAT:
		game_over_player.stream = LOSE
	else:
		game_over_player.stream = DRAW

@rpc("authority", "call_local", "unreliable")
func play_game_over_sound() -> void:
	game_over_player.play()

func _on_pass_button_pressed() -> void:
	handle_pass_button_pressed.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func handle_pass_button_pressed():
	if grid_manager.game_is_paused || grid_manager.game_outcome != GridManager.GameOutcome.UNDECIDED || grid_manager.game_state != GridManager.GameState.NORMAL:
		return
	if !((multiplayer.get_remote_sender_id() == 1 && grid_manager.is_servers_turn) || (multiplayer.get_remote_sender_id() != 1 && !grid_manager.is_servers_turn)):
		return
	increment_consecutivie_passes()
	grid_manager.switch_whose_turn_it_is()

func _on_stone_placed(_cell_global_position: Vector2, _cell_size: Vector2, _stone_type: GridManager.StoneType) -> void:
	if consecutive_passes > 0:
		reset_consecutive_passes()
	play_stone_plop.rpc()

@rpc("authority", "call_local", "unreliable")
func play_stone_plop() -> void:
	stone_plop_player.play()

func increment_consecutivie_passes() -> void:
	consecutive_passes += 1
	ui_manager.center_label.text = "Passing will draw the game!"
	if consecutive_passes > 1:
		grid_manager.game_outcome = grid_manager.GameOutcome.DRAW

func reset_consecutive_passes() -> void:
	ui_manager.center_label.text = ""
	consecutive_passes = 0

func _on_pause_requested() -> void:
	handle_pause_request.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func handle_pause_request() -> void:
	if multiplayer.get_remote_sender_id() == 1:
		ui_manager.create_pause_request_prompt(false)
	else:
		ui_manager.create_pause_request_prompt(true)

func _on_rematch_requested() -> void:
	handle_rematch_request.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func handle_rematch_request() -> void:
	if grid_manager.game_is_paused || grid_manager.game_outcome == grid_manager.GameOutcome.UNDECIDED:
		return
	#ADDED TO TRIGGER ABOVE RETURN TO FIX CRASH BUG ON REMATCH
	grid_manager.game_is_paused = true
	get_tree().reload_current_scene()

func _on_pause_request_prompt_created(pause_request_prompt: PauseRequestPrompt) -> void:
	pause_request_prompt.answered.connect(_on_pause_request_prompt_answered)
	if pause_panel.visible:
		pause_request_prompt.change_to_unpause_version()

func _on_pause_request_prompt_answered(answer_is_yes: bool, pause_request_prompt: PauseRequestPrompt) -> void:
	handle_pause_request_prompt_answered.rpc_id(1, answer_is_yes, pause_request_prompt.get_path())

@rpc("any_peer", "call_local", "reliable")
func handle_pause_request_prompt_answered(answer_is_yes: bool, pause_request_prompt_path: String) -> void:
	var pause_request_prompt: PauseRequestPrompt = get_node(pause_request_prompt_path)
	if pause_request_prompt == null:
		return
	pause_request_prompt.queue_free()
	if answer_is_yes:
		pause_game()

func pause_game() -> void:
	pause_panel.visible = !pause_panel.visible
	if pause_panel.visible:
		pause_menu.pause_button.text = "Request Unpause"
		grid_manager.game_is_paused = true
		pause_menu.rematch_button.visible = false
		turn_timer_host.paused = true
		turn_timer_challenger.paused = true
	else:
		pause_menu.pause_button.text = "Request Pause"
		grid_manager.game_is_paused = false
		if grid_manager.game_outcome != GridManager.GameOutcome.UNDECIDED:
			pause_menu.rematch_button.visible = true
		#Servers stone is only 0 when the game hasn't started yet
		if grid_manager.servers_stone != 0 && grid_manager.game_outcome == GridManager.GameOutcome.UNDECIDED:
			if grid_manager.is_servers_turn:
				turn_timer_host.paused = false
			else:
				turn_timer_challenger.paused = false

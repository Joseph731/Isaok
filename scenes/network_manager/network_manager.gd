extends Node
class_name NetworkManager

const MAIN_MENU_SCENE_PATH: String = "res://scenes/menus/main_menu/main_menu.tscn"

func _ready() -> void:
	MultiplayerConfig.connection_failed.connect(_on_network_connection_failed)
	MultiplayerConfig.host_disconnected.connect(_on_host_disconnected)
	#if is_multiplayer_authority():
		#multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		#multiplayer.peer_connected.connect(_on_peer_connected)

func end_game() -> void:
	get_tree().paused = false
	MultiplayerConfig.clean_disconnect_and_reset()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_network_connection_failed(reason: String):
	print("Failed to connect because: ", reason)
	
	# Optional: If you have a global UI notification manager, pass the reason:
	# NotificationManager.show_error(reason)
	
	# Boot the player straight back to the main menu scene
	end_game()

func _on_host_disconnected() -> void:
	print("host disconnected")
	end_game()

#func _on_peer_connected(_peer_id: int) -> void:
	## 3. Close the server to any future connections
	#var peer = multiplayer.multiplayer_peer
	#if peer is ENetMultiplayerPeer:
		#peer.refuse_new_connections = true
		#print("Server is now CLOSED to new players.")
#
#func _on_peer_disconnected(_peer_id: int):
	#var peer = multiplayer.multiplayer_peer
	#if peer is ENetMultiplayerPeer:
		#peer.refuse_new_connections = false
		#print("Server is now OPEN to new players.")

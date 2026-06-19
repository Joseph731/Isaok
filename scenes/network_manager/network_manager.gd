extends Node
class_name NetworkManager

const MAIN_MENU_SCENE_PATH: String = "res://scenes/menus/main_menu/main_menu.tscn"

func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if is_multiplayer_authority():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.peer_connected.connect(_on_peer_connected)

func end_game():
	get_tree().paused = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_server_disconnected():
	end_game()

func _on_peer_connected(_peer_id: int) -> void:
	# 3. Close the server to any future connections
	var peer = multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.refuse_new_connections = true
		print("Server is now CLOSED to new players.")

func _on_peer_disconnected(_peer_id: int):
	var peer = multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.refuse_new_connections = false
		print("Server is now OPEN to new players.")

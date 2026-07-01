extends Node

signal connection_failed(reason: String) # <-- ADD THIS
signal host_disconnected

var signaling_peer: WebSocketPeer = WebSocketPeer.new()
var rtc_peer: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()

const SIGNAL_URL = "wss://my-godot-signaling.onrender.com"
var current_room: String = ""
var is_host: bool = false
var is_connecting = false # <-- ADD THIS to track if we are in the loading phase

var game_scene: PackedScene = preload("uid://c08fg1xiroqwb")

func _ready():
	set_process(false)
	rtc_peer.peer_connected.connect(_on_rtc_peer_connected)
	rtc_peer.peer_disconnected.connect(_on_rtc_peer_disconnected)

func _process(_delta):
	signaling_peer.poll()
	var state = signaling_peer.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		while signaling_peer.get_available_packet_count() > 0:
			var packet = signaling_peer.get_packet().get_string_from_utf8()
			var message = JSON.parse_string(packet)
			if message:
				_handle_signaling_message(message)
	elif state == WebSocketPeer.STATE_CLOSED:
		set_process(false)
		# FAILURE POINT 1: Server went offline or dropped during handshake
		if is_connecting:
			is_connecting = false
			connection_failed.emit("Signaling server disconnected unexpectedly.")
			clean_disconnect_and_reset()

# ==========================================
# PUBLIC CLEANUP METHOD (Call this when leaving a game!)
# ==========================================
func clean_disconnect_and_reset():
	print("Cleaning network state and returning to fresh menu state...")
	is_connecting = false # Reset tracking
	# 1. Inform the signaling server we are leaving this room assignment
	if signaling_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var leave_msg = {"type": "leave"}
		signaling_peer.send_text(JSON.stringify(leave_msg))
		# Give the socket a frame to push out the packet before closing
		await get_tree().process_frame 
	
	# 2. Shutdown signaling channel completely
	signaling_peer.close()
	set_process(false)
	
	# 3. Wipe out the WebRTC peer entirely to dissolve the local mesh structure
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	rtc_peer.close()
	
	# Instantiate a fresh, pristine instance for the next match sequence
	rtc_peer = WebRTCMultiplayerPeer.new()
	if not rtc_peer.peer_connected.is_connected(_on_rtc_peer_connected):
		rtc_peer.peer_connected.connect(_on_rtc_peer_connected)
	if not rtc_peer.peer_disconnected.is_connected(_on_rtc_peer_disconnected):
		rtc_peer.peer_disconnected.connect(_on_rtc_peer_disconnected)
	
	# 4. Clear state variables
	current_room = ""
	is_host = false

# ==========================================
# HOST INITIALIZATION
# ==========================================
func start_hosting(room_id: String):
	# Safe guard: ensure old connections are fully cleared before spinning up a new match
	if multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
		await clean_disconnect_and_reset()

	is_host = true
	current_room = room_id
	signaling_peer.connect_to_url(SIGNAL_URL)
	set_process(true)
	
	rtc_peer.create_mesh(1)
	multiplayer.multiplayer_peer = rtc_peer
	print("Host initialized WebRTC mesh. Waiting for signaling server...")
	
	while signaling_peer.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		signaling_peer.poll()
		await get_tree().process_frame
		
	if signaling_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var message = {"type": "host", "room": current_room}
		signaling_peer.send_text(JSON.stringify(message))
		print("Sent 'host' request for room: ", current_room)

# ==========================================
# CLIENT INITIALIZATION
# ==========================================
func start_joining(room_id: String):
	if multiplayer.multiplayer_peer is not OfflineMultiplayerPeer:
		await clean_disconnect_and_reset()

	is_host = false
	current_room = room_id
	is_connecting = true
	
	get_tree().change_scene_to_packed(game_scene)
	
	signaling_peer.connect_to_url(SIGNAL_URL)
	set_process(true)
	
	var client_id = randi() % 10000 + 2
	rtc_peer.create_mesh(client_id) 
	multiplayer.multiplayer_peer = rtc_peer
	print("Client initialized WebRTC mesh with ID: ", client_id)
	
	while signaling_peer.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		signaling_peer.poll()
		await get_tree().process_frame
		
	if signaling_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var message = {
			"type": "join",
			"room": current_room,
			"peer_id": multiplayer.get_unique_id()
		}
		signaling_peer.send_text(JSON.stringify(message))
		print("Sent 'join' request for room: ", current_room)

# ==========================================
# SIGNALING LOGIC
# ==========================================
func _handle_signaling_message(message: Dictionary):
	match message.type:
		"error":
			print("Signaling Error: ", message.message)
			if is_connecting:
				is_connecting = false
				connection_failed.emit(message.message) # Pass the server's reason to the UI
			# Fallback: clean state if we fail to connect/join
			clean_disconnect_and_reset()
			
		"client_joined":
			if is_host:
				var client_id = int(message.peer_id)
				print("A client wants to join with true ID: ", client_id)
				_create_peer_connection(client_id)

		"client_left":
			if is_host:
				print("The client disconnected from the match.")
				# Clean up peer mesh slot inside Godot if client leaves early
				# (Allows a new client to use this room without restarting the host instance)
				for peer_id in rtc_peer.get_peers():
					if peer_id != 1:
						print("Removing dead client connection from mesh slot: ", peer_id)
						rtc_peer.remove_peer(peer_id)

		"signal":
			var payload = message.data
			var target_peer_id = int(payload.peer_id)
			
			if not rtc_peer.has_peer(target_peer_id):
				_create_peer_connection(target_peer_id)
				
			var connection: WebRTCPeerConnection = rtc_peer.get_peer(target_peer_id).connection
			
			if payload.has("type") and payload.type == "offer":
				connection.set_remote_description("offer", payload.sdp)
			elif payload.has("type") and payload.type == "answer":
				connection.set_remote_description("answer", payload.sdp)
			elif payload.has("candidate"):
				connection.add_ice_candidate(payload.media, payload.index, payload.candidate)

# ==========================================
# WEBRTC CORE HANDSHAKES
# ==========================================
func _create_peer_connection(target_id: int):
	var connection = WebRTCPeerConnection.new()
	connection.initialize({
		"iceServers": [{ "urls": ["stun:stun.l.google.com:19302"] }]
	})
	
	connection.session_description_created.connect(func(type, sdp):
		connection.set_local_description(type, sdp)
		var msg = {
			"type": "signal",
			"room": current_room,
			"data": { "peer_id": multiplayer.get_unique_id(), "type": type, "sdp": sdp }
		}
		if signaling_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			signaling_peer.send_text(JSON.stringify(msg))
	)
	
	connection.ice_candidate_created.connect(func(media, index, name_val):
		var msg = {
			"type": "signal",
			"room": current_room,
			"data": { "peer_id": multiplayer.get_unique_id(), "media": media, "index": index, "candidate": name_val }
		}
		if signaling_peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			signaling_peer.send_text(JSON.stringify(msg))
	)
	
	rtc_peer.add_peer(connection, target_id)
	
	if is_host:
		connection.create_offer()

func _on_rtc_peer_connected(id: int):
	print("WebRTC handshake completed! Peer: ", id)
	is_connecting = false

func _on_rtc_peer_disconnected(id: int):
	print("WebRTC direct tunnel lost connection with peer: ", id)
	# Safely clear them from Godot's internal multiplayer tracking slots
	if rtc_peer.has_peer(id):
		rtc_peer.remove_peer(id)
		
	if !is_host:
		host_disconnected.emit()
	
	# ALERT YOUR UI HERE: e.g., emit a signal so your game knows to pause or return to menu
	# connection_lost.emit()

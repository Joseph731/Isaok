extends AudioStreamPlayer

@rpc ("authority", "call_local", "unreliable")
func play_music_player():
	play()

@rpc ("authority", "call_local", "unreliable")
func stop_music_player():
	stop()

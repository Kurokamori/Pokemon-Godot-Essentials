extends Node
## Registered as `AudioManger` handles background music, ambience, jingles, and sound effects

## Emitted when a music-effect jingle finishes and the BGM resumes.
signal jingle_finished()

const SE_VOICE_COUNT: int = 8

var _bgm_player: AudioStreamPlayer = null
var _bgs_player: AudioStreamPlayer = null
var _me_player: AudioStreamPlayer = null
var _se_players: Array[AudioStreamPlayer] = []
var _next_se_voice: int = 0

var _current_bgm_name: String = ""
var _current_bgs_name: String = ""
var _bgm_volume_scale: float = 1.0
var _bgs_volume_scale: float = 1.0
var _bgm_saved_position: float = 0.0
var _bgm_saved_name: String = ""
var _bgm_tween: Tween = null
var _position_stack: Array[Dictionary] = []

var _memorized: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_player = _make_player("BGMPlayer")
	_bgs_player = _make_player("BGSPlayer")
	_me_player = _make_player("MEPlayer")
	_me_player.finished.connect(_on_me_finished)
	for i: int in range(SE_VOICE_COUNT):
		_se_players.append(_make_player("SEPlayer%d" % i))

func _make_player(player_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	add_child(player)
	return player

 # === BGM ===

## Plays a background track by its name.
## Replaying a track by default does nothing, allowing two maps to declare the same bgm without restarting a playing one
func play_bgm(track_name: String, volume: float = 1.0, pitch: float = 1.0, restart_if_same: bool = false) -> void:
	if track_name.is_empty():
		stop_bgm()
		return
	if not restart_if_same and _current_bgm_name == track_name and _bgm_player.playing:
		_bgm_volume_scale = volume
		_apply_bgm_volume()
		return
	var stream: AudioStream = Assets.audio(AssetIndex.CATEGORY_BGM, track_name)
	if stream == null:
		return
	_set_stream_looping(stream, true)
	_kill_bgm_tween()
	
	# This is the place where we record jukebox playability since it's the one consistent touchstone of all bgm
	if GameState != null and GameState.player != null:
		GameState.player.note_heard_track(track_name)
	_current_bgm_name = track_name
	_bgm_volume_scale = volume
	_bgm_player.stream = stream
	_bgm_player.pitch_scale = pitch
	_apply_bgm_volume()
	_bgm_player.play()
	
## Fades the current track out over [param seconds] and stops it.
func fade_out_bgm(seconds: float = -1.0) -> void:
	if not _bgm_player.playing:
		return
	var duration: float = seconds if seconds >= 0.0 else GameSettings.data.bgm_fade_seconds
	if duration <= 0.0:
		stop_bgm()
		return
	_kill_bgm_tween()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", -60.0, duration)
	_bgm_tween.tween_callback(stop_bgm)

func stop_bgm() -> void:
	_kill_bgm_tween()
	_bgm_player.stop()
	_current_bgm_name = ""

func pause_bgm() -> void:
	_bgm_player.stream_paused = true

func resume_bgm() -> void:
	_bgm_player.stream_paused = false

func current_bgm() -> String:
	return _current_bgm_name

## Retains the location of the current track and postion so it can be returned to later
## This lets us enter battles/menus and then return to the correct position
func push_bgm_position() -> void:
	_position_stack.append({
		"name": _current_bgm_name,
		"position": _bgm_player.get_playback_position() if _bgm_player.playing else 0.0,
		"volume": _bgm_volume_scale,
	})
	
## Matches [method push_bgm_position] to restore the track that was saved
func pop_bgm_position(resume_at_saved_position: bool = true) -> void:
	if _position_stack.is_empty():
		return
	var entry: Dictionary = _position_stack.pop_back()
	var track_name: String = entry["name"]
	if track_name.is_empty():
		stop_bgm()
		return
	play_bgm(track_name, entry["volume"], 1.0, true)
	if resume_at_saved_position:
		_bgm_player.seek(entry["position"])
		
## Matches [method push_bgm_postion] and forgets the track without playing it
func drop_bgm_position() -> void:
	if not _position_stack.is_empty():
		_position_stack.pop_back()

## === BGS ===

func play_bgs(track_name: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	if track_name.is_empty():
		stop_bgs()
		return
	if _current_bgs_name == track_name and _bgs_player.playing:
		_bgs_volume_scale = volume
		_apply_bgs_volume()
		return
	var stream: AudioStream = Assets.audio(AssetIndex.CATEGORY_BGS, track_name)
	if stream == null:
		return
	_set_stream_looping(stream, true)
	_current_bgs_name = track_name
	_bgs_volume_scale = volume
	_bgs_player.stream = stream
	_bgs_player.pitch_scale = pitch
	_apply_bgs_volume()
	_bgs_player.play()


func stop_bgs() -> void:
	_bgs_player.stop()
	_current_bgs_name = ""


func current_bgs() -> String:
	return _current_bgs_name
	
# === Memorization and Restoration ===

## Notes the music and ambience plying now, this is a slot not a stack
##
## [method push_bgm_postion] is the other side of the same coin but kept seperate on purpose:
## that one is the engine's and it is what a battle or menu uses; this one belongs to the events
func memorize_bgm_bgs() -> void:
	_memorized = {
		"bgm": _current_bgm_name,
		"bgm_position": _bgm_player.get_playback_position() if _bgm_player.playing else 0.0,
		"bgm_volume": _bgm_volume_scale,
		"bgs": _current_bgs_name,
		"bgs_position": _bgs_player.get_playback_position() if _bgs_player.playing else 0.0,
		"bgs_volume": _bgs_volume_scale,
	}
	
## Plays back the retained [method memorize_bgm_bgs] from where it had got to
## Restoring before anything has been memoriezed does nothing, rather than silencing whatever is playing
func restore_bgm_bgs() -> void:
	if _memorized.is_empty():
		return
	var bgm_name: String = String(_memorized["bgm"])
	if bgm_name.is_empty():
		stop_bgm()
	else:
		play_bgm(bgm_name, float(_memorized["bgm_volume"]), 1.0, true)
		_bgm_player.seek(float(_memorized["bgm_position"]))
	var bgs_name: String = String(_memorized["bgs"])
	if bgs_name.is_empty():
		stop_bgs()
		return
		
	# Forced to restart
	stop_bgs()
	play_bgs(bgs_name, float(_memorized["bgs_volume"]))
	_bgs_player.seek(float(_memorized["bgs_position"]))
	
## Returns `true` once something has been memorized this session
func has_memorized_audio() -> bool:
	return not _memorized.is_empty()
	
# === ME ===

## Plays a jingle, silencing the BGM until it finishes.
func play_me(track_name: String, volume: float = 1.0) -> void:
	if track_name.is_empty():
		return
	var stream: AudioStream = Assets.audio(AssetIndex.CATEGORY_ME, track_name)
	if stream == null:
		return
	_set_stream_looping(stream, false)
	_bgm_saved_name = _current_bgm_name
	_bgm_saved_position = _bgm_player.get_playback_position() if _bgm_player.playing else 0.0
	_bgm_player.stream_paused = true
	_me_player.stream = stream
	_me_player.volume_db = linear_to_db(clampf(volume * _bgm_master(), 0.0001, 1.0))
	_me_player.play()

## `true` while a jingle is playing.
func is_me_playing() -> bool:
	return _me_player.playing

func _on_me_finished() -> void:
	if _bgm_saved_name.is_empty():
		jingle_finished.emit()
		return
	_bgm_player.stream_paused = false
	_bgm_saved_name = ""
	jingle_finished.emit()

# === SE ===

## Plays a one-shot sound effect on the next available voice
func play_se(sound_name: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	if sound_name.is_empty():
		return
	var stream: AudioStream = Assets.audio(AssetIndex.CATEGORY_SE, sound_name)
	if stream == null:
		return
	_set_stream_looping(stream, false)
	var player: AudioStreamPlayer = _pick_se_voice()
	player.stream = stream
	player.volume_db = linear_to_db(clampf(volume * _se_master(), 0.0001, 1.0))
	player.pitch_scale = pitch
	player.play()
	
## Plays a Pokemon's cry
## It is pitched and volume scaled by how hurt it is
func play_cry(species_id: StringName, form: int = 0, pitch: float = 1.0, volume: float = 1.0) -> void:
	var candidates: Array[String] = []
	if form > 0:
		candidates.append("%s_%d Cry" % [species_id, form])
		candidates.append("%s_%d" % [species_id, form])
	candidates.append("%s Cry" % species_id)
	candidates.append(String(species_id))
	for candidate: String in candidates:
		if Assets.exists(AssetIndex.CATEGORY_SE, candidate):
			play_se(candidate, volume, pitch)
			return

func stop_all_se() -> void:
	for player: AudioStreamPlayer in _se_players:
		player.stop()
		
## Reapplies the Player's chosen master volumes to whatever is already playing
## This allows changes made in options effects the current playing track
## A track actively fading is left alone, since the fade owns its own volume until it finishes
func refresh_volumes() -> void:
	if _bgm_tween == null or not _bgm_tween.is_valid():
		_apply_bgm_volume()
	_apply_bgs_volume()
	
func stop_all() -> void:
	stop_bgm()
	stop_bgs()
	_me_player.stop()
	stop_all_se()

func _pick_se_voice() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _se_players:
		if not player.playing:
			return player
	var reused: AudioStreamPlayer = _se_players[_next_se_voice]
	_next_se_voice = (_next_se_voice + 1) % _se_players.size()
	return reused

func _apply_bgm_volume() -> void:
	_bgm_player.volume_db = linear_to_db(clampf(_bgm_volume_scale * _bgm_master(), 0.0001, 1.0))

func _apply_bgs_volume() -> void:
	_bgs_player.volume_db = linear_to_db(clampf(_bgs_volume_scale * _bgm_master(), 0.0001, 1.0))

## Whatever the player's settings, which music, and ambience and jingles are all under.
func _bgm_master() -> float:
	return GameSettings.data.default_bgm_volume if GameSettings.data != null else 1.0

func _se_master() -> float:
	return GameSettings.data.default_se_volume if GameSettings.data != null else 1.0

func _kill_bgm_tween() -> void:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = null

## The music stream may carry its own loop flag, this forces it to match the how the track is being used.
func _set_stream_looping(stream: AudioStream, should_loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = should_loop
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = should_loop

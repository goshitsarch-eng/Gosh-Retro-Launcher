extends Node
## Autoload "Sounds": retro synthesized effects (port of utils/sounds.ts). Honors settings.soundEnabled.
## Names: startup_chime, window_open, window_close, menu_click, dialog_open, error_beep, button_click
## (the camelCase names of the old SoundPlayer - startupChime, windowOpen, ... - are accepted too).
##
## Resource model (the Electron build fixed an idle CPU/memory leak, so this stays minimal):
## effects are rendered lazily, once, into cached AudioStreamWAV resources (a few KB each); a small
## pool of AudioStreamPlayer nodes plays them. Nothing generates audio while idle: finished
## players drop their stream reference, and the pool shrinks back to zero nodes after a short
## grace period of silence.

const POOL_MAX := 6
const IDLE_FREE_SECONDS := 5.0

var _streams := {}               ## effect id -> AudioStreamWAV
var _pool: Array[AudioStreamPlayer] = []
var _idle_timer: Timer
var plays := 0                   ## number of accepted play() calls (test/diagnostic counter)
var force_playback := false      ## tests: drive real players even under the headless dummy audio driver


func enabled() -> bool:
	return bool(ProgramStore.settings.get("soundEnabled", true))


## Starts an effect (fire and forget). No-op when sound is disabled or the name is unknown.
func play(sound_name: String) -> void:
	if not enabled():
		return
	var key := SoundSynth.normalize_name(sound_name)
	if not SoundSynth.has_effect(key):
		return
	var stream := stream_for(key)
	if stream == null:
		return
	plays += 1
	if _is_headless():
		return
	var player := _acquire_player()
	if player == null:
		return
	player.stream = stream
	player.play()
	_restart_idle_timer()


## Cached AudioStreamWAV for an effect (rendered on first use).
func stream_for(sound_name: String) -> AudioStreamWAV:
	var key := SoundSynth.normalize_name(sound_name)
	if not SoundSynth.has_effect(key):
		return null
	if not _streams.has(key):
		_streams[key] = SoundSynth.make_stream(SoundSynth.render(key))
	return _streams[key]


func stop_all() -> void:
	for p in _pool:
		if is_instance_valid(p):
			p.stop()
			p.stream = null


func playing_count() -> int:
	var n := 0
	for p in _pool:
		if is_instance_valid(p) and p.playing:
			n += 1
	return n


func pool_size() -> int:
	return _pool.size()


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless" and not force_playback


func _acquire_player() -> AudioStreamPlayer:
	for p in _pool:
		if is_instance_valid(p) and not p.playing:
			return p
	if _pool.size() < POOL_MAX:
		var np := AudioStreamPlayer.new()
		np.bus = "Master"
		np.finished.connect(_on_player_finished.bind(np))
		add_child(np)
		_pool.append(np)
		return np
	# All voices busy: steal the one that has been playing longest (the UI beeps are short).
	var oldest: AudioStreamPlayer = _pool[0]
	for p2 in _pool:
		if p2.get_playback_position() > oldest.get_playback_position():
			oldest = p2
	oldest.stop()
	return oldest


func _on_player_finished(player: AudioStreamPlayer) -> void:
	player.stream = null


func _restart_idle_timer() -> void:
	if _idle_timer == null:
		_idle_timer = Timer.new()
		_idle_timer.one_shot = true
		_idle_timer.timeout.connect(_free_idle_players)
		add_child(_idle_timer)
	_idle_timer.start(IDLE_FREE_SECONDS)


func _free_idle_players() -> void:
	if playing_count() > 0:
		_idle_timer.start(IDLE_FREE_SECONDS)
		return
	for p in _pool:
		if is_instance_valid(p):
			p.queue_free()
	_pool.clear()


func _exit_tree() -> void:
	stop_all()

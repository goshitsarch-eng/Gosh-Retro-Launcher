class_name SingleInstance
extends Node
## Single-instance lock over loopback TCP (replacement for app.requestSingleInstanceLock).
##
## The first instance listens on 127.0.0.1:<port>. A second instance connects, sends
## "SHOW\t<profile>\n" and quits when the first answers "OK\t<profile>\n"; the first instance emits
## `show_requested` (main.gd restores + focuses the window). Properties:
##  * no lock file: the OS releases the port when the process dies, so crashes never leave stale state;
##  * the port is derived from the user-data directory, so different profiles (PM_USER_DATA) can
##    run side by side, exactly like Electron's per-userData lock;
##  * a foreign program squatting on the port (connects but never answers correctly) is detected by
##    the handshake and skipped (next port), so the app still starts.

signal show_requested

enum Result { PRIMARY, SECONDARY, UNAVAILABLE }

const BASE_PORT := 47100
const PORT_SPAN := 800
const PORT_TRIES := 6
const HOST := "127.0.0.1"
const MAGIC_REQUEST := "SHOW"
const MAGIC_REPLY := "OK"
const CONNECT_TIMEOUT_MS := 400
const REPLY_TIMEOUT_MS := 600
const POLL_INTERVAL := 0.2
const MAX_LINE := 512

var profile := ""
var port := 0
var _server: TCPServer
var _clients: Array = []  ## [{peer: StreamPeerTCP, buf: PackedByteArray, started: int}]
var _timer: Timer


## Deterministic candidate ports for a profile directory.
static func candidate_ports(profile_dir: String, base: int = BASE_PORT, span: int = PORT_SPAN, tries: int = PORT_TRIES) -> Array:
	var h := profile_dir.hash()
	var start := base + int(absi(h) % span)
	var out := []
	for i in tries:
		out.append(base + ((start - base + i) % span))
	return out


static func request_line(profile_dir: String) -> String:
	return "%s\t%s\n" % [MAGIC_REQUEST, profile_dir.replace("\n", " ").replace("\t", " ")]


static func reply_line(profile_dir: String) -> String:
	return "%s\t%s\n" % [MAGIC_REPLY, profile_dir.replace("\n", " ").replace("\t", " ")]


## Server side: handles one complete request line, returns the reply line or "" when it is not a
## valid request for this profile.
static func handle_request(line: String, profile_dir: String) -> String:
	var parts := line.strip_edges(false, true).split("\t", true, 1)
	if parts.size() != 2 or parts[0] != MAGIC_REQUEST:
		return ""
	if parts[1] != profile_dir.replace("\n", " ").replace("\t", " "):
		return ""
	return reply_line(profile_dir)


## Client side: is `line` the first instance's confirmation?
static func is_valid_reply(line: String, profile_dir: String) -> bool:
	return line.strip_edges(false, true) == reply_line(profile_dir).strip_edges(false, true)


## Tries to become the primary instance (listening) or tell an existing one to show itself.
## Coroutine (frame-friendly, so a same-process server can answer in tests): `await` it.
## `tree` supplies process frames.
func acquire(profile_dir: String, tree: SceneTree, ports: Array = []) -> Result:
	profile = profile_dir
	var list := ports if not ports.is_empty() else candidate_ports(profile_dir)
	for p in list:
		var answer := await _probe(int(p), tree)
		match answer:
			"ours":
				port = int(p)
				return Result.SECONDARY
			"free":
				var server := TCPServer.new()
				if server.listen(int(p), HOST) == OK:
					_server = server
					port = int(p)
					_start_polling()
					return Result.PRIMARY
				# Lost a race or the port is blocked: try the next candidate.
			_:
				pass  # foreign listener (different profile / other program): next port
	return Result.UNAVAILABLE


## "ours" (an instance of this profile answered), "free" (nobody listening), "foreign".
func _probe(p: int, tree: SceneTree) -> String:
	var peer := StreamPeerTCP.new()
	if peer.connect_to_host(HOST, p) != OK:
		return "free"
	var deadline := Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	while true:
		peer.poll()
		var st := peer.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED:
			break
		if st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
			return "free"
		if Time.get_ticks_msec() > deadline:
			peer.disconnect_from_host()
			return "foreign"
		await tree.process_frame
	peer.put_data(request_line(profile).to_utf8_buffer())
	var buf := PackedByteArray()
	var reply_deadline := Time.get_ticks_msec() + REPLY_TIMEOUT_MS
	while Time.get_ticks_msec() < reply_deadline:
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		var avail := peer.get_available_bytes()
		if avail > 0:
			var chunk := peer.get_data(avail)
			if chunk[0] == OK:
				buf.append_array(chunk[1])
			if buf.has(10) or buf.size() > MAX_LINE:
				break
		await tree.process_frame
	peer.disconnect_from_host()
	return "ours" if is_valid_reply(buf.get_string_from_utf8(), profile) else "foreign"


func _start_polling() -> void:
	_timer = Timer.new()
	_timer.wait_time = POLL_INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(poll)
	add_child(_timer)


## Accepts pending connections and answers complete request lines. Called by the internal timer;
## tests call it directly.
func poll() -> void:
	if _server == null:
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if peer != null:
			_clients.append({"peer": peer, "buf": PackedByteArray(), "started": Time.get_ticks_msec()})
	var keep := []
	for c in _clients:
		var peer2: StreamPeerTCP = c.peer
		peer2.poll()
		var done := false
		if peer2.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			var avail := peer2.get_available_bytes()
			if avail > 0:
				var chunk := peer2.get_data(avail)
				if chunk[0] == OK:
					var merged: PackedByteArray = c.buf
					merged.append_array(chunk[1])
					c.buf = merged
			if PackedByteArray(c.buf).has(10):
				var line := PackedByteArray(c.buf).get_string_from_utf8().split("\n")[0]
				var reply := handle_request(line, profile)
				if reply != "":
					peer2.put_data(reply.to_utf8_buffer())
					show_requested.emit()
				done = true
			elif PackedByteArray(c.buf).size() > MAX_LINE or Time.get_ticks_msec() - int(c.started) > 2000:
				done = true
		else:
			done = true
		if done:
			peer2.poll()
			peer2.disconnect_from_host()
		else:
			keep.append(c)
	_clients = keep


func release() -> void:
	if _timer:
		_timer.stop()
	for c in _clients:
		c.peer.disconnect_from_host()
	_clients.clear()
	if _server:
		_server.stop()
		_server = null


func is_primary() -> bool:
	return _server != null and _server.is_listening()


func _exit_tree() -> void:
	release()

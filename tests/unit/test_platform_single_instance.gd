extends TestCase
## Single-instance lock: protocol functions and real loopback handshakes.

var _shows := 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _free_port() -> int:
	for p in range(52000, 52400):
		var s := TCPServer.new()
		if s.listen(p, "127.0.0.1") == OK:
			s.stop()
			return p
	return 0


func _make(profile_dir: String) -> SingleInstance:
	var si := SingleInstance.new()
	_tree().root.add_child(si)
	si.show_requested.connect(func() -> void: _shows += 1)
	return si


func test_candidate_ports_are_deterministic_and_in_range() -> void:
	var a := SingleInstance.candidate_ports("/home/u/.config/program-manager")
	expect_eq(a, SingleInstance.candidate_ports("/home/u/.config/program-manager"))
	expect_eq(a.size(), SingleInstance.PORT_TRIES)
	var seen := {}
	for p in a:
		expect(p >= SingleInstance.BASE_PORT and p < SingleInstance.BASE_PORT + SingleInstance.PORT_SPAN)
		seen[p] = true
	expect_eq(seen.size(), a.size(), "distinct fallbacks")
	expect(SingleInstance.candidate_ports("profile-A") != SingleInstance.candidate_ports("profile-B"))
	# Wraps inside the span near the top end.
	var wrapped := SingleInstance.candidate_ports("x", 100, 5, 4)
	for p in wrapped:
		expect(p >= 100 and p < 105)
	expect_eq(wrapped.size(), 4)


func test_protocol_lines() -> void:
	var req := SingleInstance.request_line("/p")
	expect_eq(req, "SHOW\t/p\n")
	expect_eq(SingleInstance.handle_request("SHOW\t/p", "/p"), "OK\t/p\n")
	expect_eq(SingleInstance.handle_request("SHOW\t/p\r", "/p"), "OK\t/p\n")
	expect_eq(SingleInstance.handle_request("SHOW\t/other", "/p"), "", "other profile")
	expect_eq(SingleInstance.handle_request("GET / HTTP/1.1", "/p"), "", "foreign protocol")
	expect_eq(SingleInstance.handle_request("", "/p"), "")
	expect(SingleInstance.is_valid_reply("OK\t/p\n", "/p"))
	expect(not SingleInstance.is_valid_reply("OK\t/q\n", "/p"))
	expect(not SingleInstance.is_valid_reply("", "/p"))
	expect(not SingleInstance.is_valid_reply("HTTP/1.1 400 Bad Request", "/p"))
	# Control characters in profile names cannot break framing.
	expect(not SingleInstance.request_line("a\nb\tc").substr(0, SingleInstance.request_line("a\nb\tc").length() - 1).contains("\n"))


func test_second_instance_signals_first_and_stale_state_is_impossible() -> void:
	var port := _free_port()
	expect(port > 0)
	_shows = 0
	var first := _make("prof")
	var r1: int = await first.acquire("prof", _tree(), [port])
	expect_eq(r1, SingleInstance.Result.PRIMARY)
	expect(first.is_primary())
	var second := _make("prof")
	var r2: int = await second.acquire("prof", _tree(), [port])
	expect_eq(r2, SingleInstance.Result.SECONDARY)
	expect(not second.is_primary())
	expect_eq(_shows, 1, "first instance was asked to show its window")
	# Crash safety: releasing (or dying) frees the port; a new instance simply becomes primary.
	first.release()
	var third := _make("prof")
	var r3: int = await third.acquire("prof", _tree(), [port])
	expect_eq(r3, SingleInstance.Result.PRIMARY, "no stale lock after the owner went away")
	third.release()
	for n in [first, second, third]:
		n.queue_free()


func test_other_profile_or_foreign_listener_falls_through_to_next_port() -> void:
	var p1 := _free_port()
	var holder := _make("A")
	await holder.acquire("A", _tree(), [p1])
	var p2 := p1 + 1
	var other := _make("B")
	var r: int = await other.acquire("B", _tree(), [p1, p2])
	expect_eq(r, SingleInstance.Result.PRIMARY, "different profile uses the next candidate port")
	expect_eq(other.port, p2)
	# A silent foreign program on the port is skipped after the handshake times out.
	var squatter := TCPServer.new()
	var p3 := p2 + 1
	expect_eq(squatter.listen(p3, "127.0.0.1"), OK)
	var third := _make("C")
	var r3: int = await third.acquire("C", _tree(), [p3, p3 + 1])
	expect_eq(r3, SingleInstance.Result.PRIMARY)
	expect_eq(third.port, p3 + 1)
	squatter.stop()
	# Nothing available at all: run without the lock instead of refusing to start.
	var blocker := TCPServer.new()
	expect_eq(blocker.listen(p3 + 5, "127.0.0.1"), OK)
	var fourth := _make("D")
	var r4: int = await fourth.acquire("D", _tree(), [p3 + 5])
	expect_eq(r4, SingleInstance.Result.UNAVAILABLE)
	blocker.stop()
	for n in [holder, other, third, fourth]:
		n.release()
		n.queue_free()

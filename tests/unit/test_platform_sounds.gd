extends TestCase
## Sound synthesis (port of utils/sounds.ts parameters) and the Sounds autoload.

func _max_abs(s: PackedFloat32Array, from: int = 0, to: int = -1) -> float:
	var end := s.size() if to < 0 else mini(to, s.size())
	var m := 0.0
	for i in range(from, end):
		m = maxf(m, absf(s[i]))
	return m


func _sign_changes(s: PackedFloat32Array) -> int:
	var n := 0
	for i in range(1, s.size()):
		if (s[i - 1] < 0.0) != (s[i] < 0.0):
			n += 1
	return n


func test_effect_table_matches_sounds_ts() -> void:
	expect_eq(SoundSynth.effect_names().size(), 7)
	for n in ["startup_chime", "window_open", "window_close", "menu_click", "dialog_open", "error_beep", "button_click"]:
		expect(SoundSynth.has_effect(n), n)
	for alias in ["startupChime", "windowOpen", "windowClose", "menuClick", "dialogOpen", "errorBeep", "buttonClick"]:
		expect(SoundSynth.has_effect(alias), alias)
	expect(not SoundSynth.has_effect("nope"))
	var chime: Array = SoundSynth.EFFECTS.startup_chime
	expect_eq(chime.size(), 4)
	expect_eq([chime[0].freq, chime[1].freq, chime[2].freq, chime[3].freq], [523.0, 659.0, 784.0, 1047.0])
	expect_eq([chime[0].delay, chime[1].delay, chime[2].delay, chime[3].delay], [0.0, 0.1, 0.2, 0.3])
	expect_eq(chime[3].volume, 0.08)
	expect_eq(SoundSynth.EFFECTS.window_open[0].ramp_to, 500.0)
	expect_eq(SoundSynth.EFFECTS.window_close[0].ramp_to, 300.0)
	expect_eq(SoundSynth.EFFECTS.menu_click[0].duration, 0.03)
	expect_eq(SoundSynth.EFFECTS.button_click[0].freq, 1000.0)
	expect_eq(SoundSynth.EFFECTS.error_beep[1].delay, 0.15)


func test_durations_and_sample_counts() -> void:
	expect_near(SoundSynth.effect_duration("startup_chime"), 0.6)
	expect_near(SoundSynth.effect_duration("dialog_open"), 0.16)
	expect_near(SoundSynth.effect_duration("error_beep"), 0.25)
	expect_near(SoundSynth.effect_duration("menu_click"), 0.03)
	expect_eq(SoundSynth.render("startup_chime").size(), ceili(0.6 * SoundSynth.SAMPLE_RATE))
	expect_eq(SoundSynth.render("window_open").size(), 4410)
	expect_eq(SoundSynth.render("button_click").size(), 882)
	expect_eq(SoundSynth.render("nope").size(), 0)
	expect_eq(SoundSynth.render("menuClick").size(), SoundSynth.render("menu_click").size())
	expect_eq(SoundSynth.render("window_open", 22050).size(), 2205)


func test_rendering_is_deterministic() -> void:
	for n in SoundSynth.effect_names():
		var a := SoundSynth.render(n)
		var b := SoundSynth.render(n)
		expect_eq(a.to_byte_array().hex_encode(), b.to_byte_array().hex_encode(), n)
		expect(_max_abs(a) > 0.0, n + " is not silent")


func test_exponential_gain_envelope() -> void:
	expect_near(SoundSynth.gain_at(0.06, 0.1, 0.0), 0.06, 1e-9)
	expect_near(SoundSynth.gain_at(0.06, 0.1, 0.1), 0.001, 1e-9)
	expect_near(SoundSynth.gain_at(0.06, 0.1, 0.05), 0.06 * sqrt(0.001 / 0.06), 1e-9)
	var prev := 1.0
	for i in 11:
		var g := SoundSynth.gain_at(0.08, 0.3, 0.03 * i)
		expect(g < prev, "monotonic decay")
		prev = g


func test_linear_frequency_ramp() -> void:
	expect_near(SoundSynth.freq_at(300.0, 500.0, 0.1, 0.0), 300.0)
	expect_near(SoundSynth.freq_at(300.0, 500.0, 0.1, 0.05), 400.0)
	expect_near(SoundSynth.freq_at(300.0, 500.0, 0.1, 0.1), 500.0)
	expect_near(SoundSynth.freq_at(500.0, 300.0, 0.1, 0.075), 350.0)
	expect_near(SoundSynth.freq_at(800.0, -1.0, 0.03, 0.02), 800.0, 1e-9, "no ramp")


func test_tone_envelope_and_pitch() -> void:
	# 1 kHz sine, 0.2 s, volume 0.5: starts near full volume, ends at -60 dB of it.
	var s := SoundSynth.tone(1000.0, 0.2, "sine", 0.5)
	expect_eq(s.size(), 8820)
	expect(_max_abs(s, 0, 200) > 0.45 and _max_abs(s, 0, 200) <= 0.5, "attack near volume")
	expect(_max_abs(s, s.size() - 100) < 0.0012, "tail decays to the 0.001 end gain")
	expect(_max_abs(s, 0, 441) > _max_abs(s, 4410, 4851), "envelope is decreasing")
	expect(absi(_sign_changes(s) - 400) <= 2, "1 kHz over 0.2s = 400 half cycles")
	# 800 Hz square click: 0.03s -> 48 half cycles (band-limiting adds no extra zero crossings)
	var sq := SoundSynth.render("menu_click")
	expect(absi(_sign_changes(sq) - 48) <= 2, "square half cycles: %d" % _sign_changes(sq))
	expect_near(_max_abs(sq, 0, 100), 0.05, 0.006, "menu click volume 0.05")


func test_square_is_band_limited_and_bounded() -> void:
	var s := SoundSynth.tone(1000.0, 0.05, "square", 1.0)
	expect(_max_abs(s) <= 1.3, "polyblep overshoot is small")
	# Mostly flat tops: most samples are close to +/- envelope value.
	var flat := 0
	for i in range(0, 441):
		if absf(absf(s[i]) - SoundSynth.gain_at(1.0, 0.05, i / 44100.0)) < 0.05:
			flat += 1
	expect(flat > 400, "flat tops (%d/441)" % flat)


func test_overlapping_tones_sum_without_clipping() -> void:
	var chime := SoundSynth.render("startup_chime")
	expect(_max_abs(chime) <= 1.0)
	# Additive mix: samples in the overlap equal the sum of the individual tones.
	var t1 := SoundSynth.tone(523.0, 0.15, "square", 0.06)
	var t2 := SoundSynth.tone(659.0, 0.15, "square", 0.06)
	var off := int(roundf(0.1 * 44100.0))
	var worst := 0.0
	for i in range(off, t1.size()):
		worst = maxf(worst, absf(chime[i] - (t1[i] + t2[i - off])))
	expect(worst < 1e-5, "tones are mixed additively (max diff %f)" % worst)
	# 4th tone starts at 0.3 s with the larger volume 0.08.
	var start := int(0.3 * 44100.0)
	expect(_max_abs(chime, start, start + 200) > 0.07)


func test_pcm16_and_stream() -> void:
	var pcm := SoundSynth.to_pcm16(PackedFloat32Array([0.0, 1.0, -1.0, 1.5, -1.5, 0.5]))
	expect_eq(pcm.size(), 12)
	expect_eq(pcm.decode_s16(0), 0)
	expect_eq(pcm.decode_s16(2), 32767)
	expect_eq(pcm.decode_s16(4), -32767)
	expect_eq(pcm.decode_s16(6), 32767, "clamped")
	expect_eq(pcm.decode_s16(8), -32768, "clamped")
	expect_eq(pcm.decode_s16(10), 16384)
	var stream := SoundSynth.make_stream(SoundSynth.render("window_close"))
	expect_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
	expect_eq(stream.mix_rate, 44100)
	expect(not stream.stereo)
	expect_eq(stream.data.size(), 4410 * 2)
	expect_near(stream.get_length(), 0.1, 0.002)


func test_sounds_autoload_honors_setting_and_caches() -> void:
	var original: Variant = ProgramStore.settings.get("soundEnabled", true)
	ProgramStore.settings["soundEnabled"] = false
	var before: int = Sounds.plays
	Sounds.play("menu_click")
	expect_eq(Sounds.plays, before, "disabled: nothing accepted")
	ProgramStore.settings["soundEnabled"] = true
	Sounds.play("menu_click")
	Sounds.play("buttonClick")
	Sounds.play("does_not_exist")
	expect_eq(Sounds.plays, before + 2)
	expect(Sounds.stream_for("menu_click") == Sounds.stream_for("menuClick"), "rendered once, cached")
	expect(Sounds.stream_for("nope") == null)
	ProgramStore.settings["soundEnabled"] = original


func test_sound_pool_is_bounded_and_shrinks() -> void:
	var original: Variant = ProgramStore.settings.get("soundEnabled", true)
	ProgramStore.settings["soundEnabled"] = true
	Sounds.force_playback = true
	for i in 12:
		Sounds.play("startup_chime")
	expect(Sounds.pool_size() >= 1 and Sounds.pool_size() <= Sounds.POOL_MAX, "pool bounded: %d" % Sounds.pool_size())
	Sounds.stop_all()
	expect_eq(Sounds.playing_count(), 0)
	Sounds.force_playback = false
	Sounds._free_idle_players()
	expect_eq(Sounds.pool_size(), 0, "idle players are released")
	ProgramStore.settings["soundEnabled"] = original

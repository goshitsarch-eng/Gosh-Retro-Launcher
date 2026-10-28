class_name SoundSynth
extends RefCounted
## Offline renderer for the retro UI effects of src/renderer/src/utils/sounds.ts.
##
## The Web Audio version scheduled an OscillatorNode + GainNode per tone:
##   osc.type = square | sine; osc.frequency = freq (optionally a linear ramp to `rampTo` over
##   `duration`); gain = setValueAtTime(volume) then exponentialRampToValueAtTime(0.001, +duration);
##   osc.start(t0); osc.stop(t0 + duration).
## Here every effect is rendered once into a mono 16-bit PCM buffer (cached as AudioStreamWAV by the
## `Sounds` autoload), so nothing keeps running between sounds.

const SAMPLE_RATE := 44100
const END_GAIN := 0.001
const TAU_F := TAU

## Effect tables copied from sounds.ts (frequencies Hz, durations/delays seconds, linear volumes).
## Single tones use delay 0 and optional `ramp_to`; defaults: type "square", volume 0.06 for
## sequences / 0.08 for single tones (playTone's default), exactly as in the TS helpers.
const EFFECTS := {
	# C5 - E5 - G5 - C6 arpeggio
	"startup_chime": [
		{"freq": 523.0, "duration": 0.15, "delay": 0.0},
		{"freq": 659.0, "duration": 0.15, "delay": 0.1},
		{"freq": 784.0, "duration": 0.15, "delay": 0.2},
		{"freq": 1047.0, "duration": 0.3, "delay": 0.3, "volume": 0.08},
	],
	"window_open": [{"freq": 300.0, "duration": 0.1, "ramp_to": 500.0, "volume": 0.06, "single": true}],
	"window_close": [{"freq": 500.0, "duration": 0.1, "ramp_to": 300.0, "volume": 0.06, "single": true}],
	"menu_click": [{"freq": 800.0, "duration": 0.03, "volume": 0.05, "single": true}],
	"dialog_open": [
		{"freq": 600.0, "duration": 0.08, "delay": 0.0},
		{"freq": 800.0, "duration": 0.1, "delay": 0.06},
	],
	"error_beep": [
		{"freq": 200.0, "duration": 0.1, "delay": 0.0},
		{"freq": 200.0, "duration": 0.1, "delay": 0.15},
	],
	"button_click": [{"freq": 1000.0, "duration": 0.02, "volume": 0.04, "single": true}],
}

## camelCase names of the TS SoundPlayer -> effect ids.
const ALIASES := {
	"startupChime": "startup_chime",
	"windowOpen": "window_open",
	"windowClose": "window_close",
	"menuClick": "menu_click",
	"dialogOpen": "dialog_open",
	"errorBeep": "error_beep",
	"buttonClick": "button_click",
}


static func effect_names() -> Array:
	return EFFECTS.keys()


static func normalize_name(sound_name: String) -> String:
	return ALIASES.get(sound_name, sound_name)


static func has_effect(sound_name: String) -> bool:
	return EFFECTS.has(normalize_name(sound_name))


## Total length in seconds of an effect (latest tone end).
static func effect_duration(sound_name: String) -> float:
	var end := 0.0
	for t in EFFECTS.get(normalize_name(sound_name), []):
		end = maxf(end, float(t.get("delay", 0.0)) + float(t.duration))
	return end


## Gain envelope value at time t into a tone (exponential ramp volume -> 0.001 over duration).
static func gain_at(volume: float, duration: float, t: float) -> float:
	if duration <= 0.0:
		return END_GAIN
	return volume * pow(END_GAIN / volume, clampf(t / duration, 0.0, 1.0))


## Frequency at time t (linear ramp when ramp_to >= 0).
static func freq_at(freq: float, ramp_to: float, duration: float, t: float) -> float:
	if ramp_to < 0.0 or duration <= 0.0:
		return freq
	return freq + (ramp_to - freq) * clampf(t / duration, 0.0, 1.0)


## PolyBLEP residual that band-limits the square wave step discontinuities.
static func _poly_blep(t: float, dt: float) -> float:
	if t < dt:
		var x := t / dt
		return x + x - x * x - 1.0
	if t > 1.0 - dt:
		var y := (t - 1.0) / dt
		return y * y + y + y + 1.0
	return 0.0


## One tone as float samples in [-1, 1] (length = round(duration * rate)).
## type: "square" (band-limited like Web Audio's) or "sine". ramp_to < 0 means no frequency ramp.
static func tone(freq: float, duration: float, type: String = "square", volume: float = 0.08,
		ramp_to: float = -1.0, rate: int = SAMPLE_RATE) -> PackedFloat32Array:
	var count := int(roundf(duration * rate))
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0  # cycles
	var dt_s := 1.0 / float(rate)
	for i in count:
		var t := float(i) * dt_s
		var f := freq_at(freq, ramp_to, duration, t)
		var inc := f * dt_s
		var s: float
		if type == "sine":
			s = sin(phase * TAU_F)
		else:
			s = 1.0 if phase < 0.5 else -1.0
			s += _poly_blep(phase, inc)
			s -= _poly_blep(fmod(phase + 0.5, 1.0), inc)
		out[i] = s * gain_at(volume, duration, t)
		phase += inc
		if phase >= 1.0:
			phase -= 1.0
	return out


## Mixes {freq, duration, delay?, type?, volume?, ramp_to?} tones additively (Web Audio sums nodes).
static func mix(tones: Array, rate: int = SAMPLE_RATE) -> PackedFloat32Array:
	var total := 0.0
	for t in tones:
		total = maxf(total, float(t.get("delay", 0.0)) + float(t.duration))
	var out := PackedFloat32Array()
	out.resize(int(ceilf(total * rate)))
	for t in tones:
		var single: bool = t.get("single", false)
		var volume := float(t.get("volume", 0.08 if single else 0.06))
		var samples := tone(float(t.freq), float(t.duration), String(t.get("type", "square")),
				volume, float(t.get("ramp_to", -1.0)), rate)
		var start := int(roundf(float(t.get("delay", 0.0)) * rate))
		for i in samples.size():
			if start + i < out.size():
				out[start + i] += samples[i]
	return out


## Samples of a named effect (cached by the caller). Empty for unknown names.
static func render(sound_name: String, rate: int = SAMPLE_RATE) -> PackedFloat32Array:
	var key := normalize_name(sound_name)
	if not EFFECTS.has(key):
		return PackedFloat32Array()
	return mix(EFFECTS[key], rate)


## Little-endian signed 16-bit PCM (clamped).
static func to_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampi(int(roundf(samples[i] * 32767.0)), -32768, 32767)
		out.encode_s16(i * 2, v)
	return out


static func make_stream(samples: PackedFloat32Array, rate: int = SAMPLE_RATE) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = to_pcm16(samples)
	return stream

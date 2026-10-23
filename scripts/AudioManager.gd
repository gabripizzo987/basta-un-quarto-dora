extends Node

# ── Music ─────────────────────────────────────────────────────────────────────
var _music: AudioStreamPlayer
var _music_vol := 0.65

var _music_paths := {
	"menu":       "res://audio/music/menu.ogg",
	"acceptance": "res://audio/music/acceptance.ogg",
	"emocromo":   "res://audio/music/emocromo.ogg",
	"final":      "res://audio/music/final.ogg",
}

# ── SFX pool ──────────────────────────────────────────────────────────────────
const _POOL := 10
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_vol := 0.85
var _cache: Dictionary = {}

func _ready() -> void:
	_music = AudioStreamPlayer.new()
	add_child(_music)

	for i in _POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)

	_prebuild()

func _prebuild() -> void:
	_cache["btn_click"]      = _tone(780,  0.055, 0.38, "square")
	_cache["btn_hover"]      = _tone(560,  0.035, 0.12, "sine")
	_cache["correct"]        = _arpeggio([523.0, 659.0, 784.0], 0.55, 0.5)
	_cache["wrong"]          = _sweep(320.0, 170.0, 0.38, 0.5)
	_cache["page_turn"]      = _noise(0.07, 0.22)
	_cache["drag_start"]     = _tone(480,  0.07,  0.28, "sine")
	_cache["drag_drop"]      = _tone(230,  0.13,  0.45, "sine")
	_cache["room_complete"]  = _arpeggio([523.0, 659.0, 784.0, 1047.0], 0.85, 0.55)
	_cache["error_popup"]    = _sweep(420.0, 240.0, 0.32, 0.48)
	_cache["heartbeat"]      = _heartbeat()
	_cache["manual_open"]    = _arpeggio([392.0, 523.0, 659.0], 0.28, 0.22)
	_cache["manual_page"]    = _noise(0.038, 0.15)
	_cache["manual_close"]   = _sweep(520.0, 290.0, 0.20, 0.20)
	_cache["needle_miss"]    = _sweep(240.0, 95.0,  0.22, 0.22)

# ── Public API ────────────────────────────────────────────────────────────────

var _current_track: String = ""
var _music_proc: Dictionary = {}

func play_music(track: String, fade: float = 1.2) -> void:
	if track == _current_track and _music.playing:
		return
	var stream: AudioStream = null
	# Try real audio file first
	var path: String = _music_paths.get(track, "")
	if not path.is_empty() and ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded != null:
			if loaded is AudioStreamOggVorbis:
				loaded.loop = true
			stream = loaded
	# Fall back to procedural generation
	if stream == null:
		if not _music_proc.has(track):
			_music_proc[track] = _build_music_track(track)
		stream = _music_proc.get(track)
	if stream == null:
		return
	_current_track = track
	_music.stream = stream
	_music.volume_db = -80.0
	_music.play()
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", linear_to_db(_music_vol), fade)

func stop_music(fade: float = 1.0) -> void:
	if not _music.playing:
		return
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -80.0, fade)
	await tw.finished
	_music.stop()

func set_music_volume(v: float) -> void:
	_music_vol = v
	if _music.playing:
		_music.volume_db = linear_to_db(v)

func set_sfx_volume(v: float) -> void:
	_sfx_vol = v

func play_sfx(name: String) -> void:
	var stream: AudioStreamWAV = _cache.get(name)
	if stream == null:
		return
	for p in _sfx:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(_sfx_vol)
			p.play()
			return
	_sfx[0].stream = stream
	_sfx[0].volume_db = linear_to_db(_sfx_vol)
	_sfx[0].play()

# ── Procedural generators ─────────────────────────────────────────────────────

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 44100
	w.stereo = false
	w.data = data
	return w

func _tone(freq: float, dur: float, vol: float, wave: String) -> AudioStreamWAV:
	var n := int(44100 * dur)
	var d := PackedByteArray(); d.resize(n * 2)
	for i in n:
		var t := float(i) / 44100.0
		var env: float = 1.0 - clamp((t - dur * 0.55) / (dur * 0.45), 0.0, 1.0)
		var s: float
		match wave:
			"square": s = 1.0 if sin(TAU * freq * t) >= 0 else -1.0
			"saw":    s = fmod(freq * t, 1.0) * 2.0 - 1.0
			_:        s = sin(TAU * freq * t)
		d.encode_s16(i * 2, clamp(int(s * env * vol * 32767), -32768, 32767))
	return _wav(d)

func _arpeggio(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(44100 * dur)
	var d := PackedByteArray(); d.resize(n * 2)
	var step := dur / freqs.size()
	for i in n:
		var t := float(i) / 44100.0
		var env: float = 1.0 - clamp((t - dur * 0.5) / (dur * 0.5), 0.0, 1.0)
		var idx: int = clamp(int(t / step), 0, freqs.size() - 1)
		var local_t := fmod(t, step) / step
		var note_env := sin(local_t * PI)
		var s := sin(TAU * float(freqs[idx]) * t) * note_env
		d.encode_s16(i * 2, clamp(int(s * env * vol * 32767), -32768, 32767))
	return _wav(d)

func _sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(44100 * dur)
	var d := PackedByteArray(); d.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / 44100.0
		var env: float = 1.0 - clamp((t - dur * 0.45) / (dur * 0.55), 0.0, 1.0)
		var freq : float = lerp(f0, f1, t / dur)
		phase += TAU * freq / 44100.0
		d.encode_s16(i * 2, clamp(int(sin(phase) * env * vol * 32767), -32768, 32767))
	return _wav(d)

func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var n := int(44100 * dur)
	var d := PackedByteArray(); d.resize(n * 2)
	for i in n:
		var t := float(i) / 44100.0
		var env: float = 1.0 - clamp((t - dur * 0.35) / (dur * 0.65), 0.0, 1.0)
		var s := randf_range(-1.0, 1.0)
		d.encode_s16(i * 2, clamp(int(s * env * vol * 32767), -32768, 32767))
	return _wav(d)

func _heartbeat() -> AudioStreamWAV:
	var dur := 0.35
	var n := int(44100 * dur)
	var d := PackedByteArray(); d.resize(n * 2)
	for i in n:
		var t := float(i) / 44100.0
		var beat1 := exp(-t * 30.0) * sin(TAU * 80.0 * t)
		var beat2 := exp(-(t - 0.12) * 30.0) * sin(TAU * 60.0 * (t - 0.12)) if t > 0.12 else 0.0
		d.encode_s16(i * 2, clamp(int((beat1 + beat2) * 0.6 * 32767), -32768, 32767))
	return _wav(d)

# ── Procedural chiptune music ─────────────────────────────────────────────────
# Step-sequencer at 11025 Hz (plenty for chip-style audio).
# Each track is 16 eighth-note steps (2 bars) generated on first use, then cached.
# The final 80 ms fade-to-zero + opening fade-in guarantee a click-free loop.

func _build_music_track(track: String) -> AudioStreamWAV:
	match track:
		# ── Main menu: D minor, dramatic, 120 BPM — 8 bars ───────────────────
		"menu":
			return _gen_chiptune(120.0,
				# A: opening statement
				[74, 0,72,70, 69, 0,67,65,  67, 0,69,72, 70, 0,69, 0,
				# B: rising tension
				 74, 0,76,74, 72, 0,70,72,  74,76, 0,77, 76, 0,74, 0,
				# C: mid-section contrast (lower, darker)
				 69,70,72, 0, 74, 0,72,70,  65, 0,67,69, 70, 0,72, 0,
				# D: climax and descent back
				 77, 0,76,74, 72,70,69, 0,  72,74, 0,76, 74, 0,69, 0],
				[38, 0,45, 0, 43, 0,45, 0,  38, 0,45, 0, 41, 0,45, 0,
				 38, 0,45, 0, 40, 0,45, 0,  43, 0,45, 0, 38, 0,43, 0,
				 43, 0,48, 0, 38, 0,43, 0,  41, 0,48, 0, 43, 0,41, 0,
				 38, 0,45, 0, 43, 0,45, 0,  40, 0,43, 0, 38, 0,45, 0],
				[50, 53, 57])   # Dm
		# ── Acceptance room: C major, warm, 92 BPM — 8 bars ──────────────────
		"acceptance":
			return _gen_chiptune(92.0,
				# A: warm theme
				[64,67, 0,72, 71, 0,69,67,  65, 0,64, 0, 62,64,60, 0,
				# B: higher register, hopeful
				 72, 0,74,72, 71, 0,69,67,  69,71, 0,72, 74, 0,72, 0,
				# C: bridge — steps down gently
				 60,62,64, 0, 65, 0,67,65,  64, 0,62,60, 62, 0,60, 0,
				# D: return with extra flourish
				 67, 0,69,71, 72,71,69, 0,  67, 0,65,64, 60, 0, 0, 0],
				[36, 0,43, 0, 41, 0,43, 0,  36, 0,45, 0, 41, 0,43, 0,
				 36, 0,43, 0, 43, 0,45, 0,  36, 0,43, 0, 41, 0,45, 0,
				 36, 0,43, 0, 41, 0,43, 0,  45, 0,43, 0, 43, 0,41, 0,
				 36, 0,43, 0, 41, 0,43, 0,  36, 0,43, 0, 36, 0,43, 0],
				[48, 52, 55])   # Cmaj
		# ── Emocromo room: A minor, focused, 108 BPM — 8 bars ────────────────
		"emocromo":
			return _gen_chiptune(108.0,
				# A: focused opening
				[69, 0,72, 0, 76,74,72, 0,  71, 0,69,67, 64, 0,69, 0,
				# B: more urgent, pushing up
				 72, 0,74,72, 76, 0,77,76,  74, 0,72,71, 69, 0,72, 0,
				# C: tension peak
				 76,77, 0,76, 74, 0,72,71,  69, 0,71,72, 74, 0,76, 0,
				# D: resolution and descent
				 77, 0,76,74, 72,71,69, 0,  71, 0,72,69, 64, 0, 0, 0],
				[45, 0,40, 0, 45, 0,43, 0,  45, 0,40, 0, 41, 0,40, 0,
				 45, 0,40, 0, 43, 0,40, 0,  45, 0,40, 0, 43, 0,45, 0,
				 45, 0,40, 0, 41, 0,40, 0,  45, 0,43, 0, 45, 0,43, 0,
				 45, 0,40, 0, 43, 0,40, 0,  45, 0,40, 0, 45, 0,40, 0],
				[57, 60, 64])   # Am
		# ── Final room: G major, uplifting, 114 BPM — 8 bars ─────────────────
		"final":
			return _gen_chiptune(114.0,
				# A: triumphant theme
				[67,71, 0,74, 79, 0,74,71,  67, 0,69,71, 72, 0,74, 0,
				# B: soaring higher
				 76, 0,74,72, 71, 0,72,74,  76, 0,79,76, 74, 0,76, 0,
				# C: lyrical mid-section
				 79, 0,76,74, 72,71, 0,72,  74, 0,76,74, 71, 0,72, 0,
				# D: grand finale run
				 74,76, 0,79, 81, 0,79,76,  74, 0,72,71, 67, 0, 0, 0],
				[43, 0,50, 0, 45, 0,50, 0,  43, 0,50, 0, 41, 0,50, 0,
				 43, 0,50, 0, 43, 0,50, 0,  45, 0,50, 0, 43, 0,50, 0,
				 43, 0,50, 0, 41, 0,50, 0,  43, 0,50, 0, 45, 0,50, 0,
				 43, 0,50, 0, 45, 0,50, 0,  43, 0,50, 0, 43, 0,50, 0],
				[55, 59, 62])   # Gmaj
	return null

# melody / bass: MIDI note numbers, 0 = rest.  chord: MIDI notes for arpeggio.
func _gen_chiptune(bpm: float, melody: Array, bass: Array, chord: Array) -> AudioStreamWAV:
	var sr       := 11025
	var steps    := melody.size()
	var step_sec := 60.0 / bpm / 2.0          # 8th-note duration
	var loop_sec := step_sec * steps
	var n        := int(sr * loop_sec)
	var d        := PackedByteArray()
	d.resize(n * 2)
	var csz: int = chord.size()

	for i in n:
		var t:    float = float(i) / float(sr)
		var sidx: int   = int(t / step_sec) % steps
		var spos: float = fmod(t, step_sec) / step_sec   # 0..1 within step

		var s: float = 0.0

		# ── Melody: triangle wave (smooth, sweet pixel sound) ─────────────────
		var mhz: float = _midi_hz(melody[sidx])
		if mhz > 0.0:
			var env: float = _chip_env(spos)
			s += _tri(mhz, t) * env * 0.30
			# Gentle vibrato on the second half of each held note
			if spos > 0.55:
				var vib: float = sin(TAU * 5.5 * t) * 0.0035
				s += _tri(mhz * (1.0 + vib), t) * env * 0.07

		# ── Arpeggio: square wave cycling through chord tones ─────────────────
		if csz > 0:
			var cidx: int   = int(spos * csz) % csz
			var ahz:  float = _midi_hz(chord[cidx])
			if ahz > 0.0:
				# Slight duty-cycle variation per chord step adds movement
				var duty: float = 0.25 + float(cidx) * 0.05
				s += _sq(ahz, t, duty) * 0.11

		# ── Bass: square wave with envelope ──────────────────────────────────
		var bhz: float = _midi_hz(bass[sidx])
		if bhz > 0.0:
			var env: float = _chip_env(spos)
			s += _sq(bhz, t, 0.45) * env * 0.24
			# Octave-up hint for body
			s += _sq(bhz * 2.0, t, 0.45) * env * 0.07

		# ── Kick: pitch-drop sine on beats 1 & 3 ─────────────────────────────
		if (sidx == 0 or sidx == steps / 2) and spos < 0.20:
			var kenv:  float = 1.0 - spos / 0.20
			var kfreq: float = lerp(170.0, 42.0, spos / 0.20)
			s += sin(TAU * kfreq * t) * kenv * 0.28

		# ── Hi-hat: noise burst on off-beats ──────────────────────────────────
		if sidx % 2 == 1 and spos < 0.065:
			s += randf_range(-1.0, 1.0) * (1.0 - spos / 0.065) * 0.065

		d.encode_s16(i * 2, clamp(int(s * 32767), -32768, 32767))

	# Echo delay (dotted-16th at the given BPM) for spatial depth
	_apply_echo(d, int(sr * step_sec * 0.5), 0.28)

	# Fade in first 50 ms and fade out last 80 ms → click-free loop
	var fi := int(sr * 0.05)
	for i in fi:
		var v := d.decode_s16(i * 2)
		d.encode_s16(i * 2, int(v * float(i) / float(fi)))
	var fo := int(sr * 0.08)
	for i in fo:
		var idx := n - fo + i
		var v   := d.decode_s16(idx * 2)
		d.encode_s16(idx * 2, int(v * (1.0 - float(i) / float(fo))))

	var w := AudioStreamWAV.new()
	w.format     = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate   = sr
	w.stereo     = false
	w.data       = d
	w.loop_mode  = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end   = n
	return w

# ── Oscillator helpers ────────────────────────────────────────────────────────

func _midi_hz(note: int) -> float:
	if note <= 0:
		return 0.0
	return 440.0 * pow(2.0, float(note - 69) / 12.0)

func _sq(freq: float, t: float, duty: float) -> float:
	return 1.0 if fmod(freq * t, 1.0) < duty else -1.0

func _tri(freq: float, t: float) -> float:
	var p: float = fmod(freq * t, 1.0)
	return 1.0 - 2.0 * abs(2.0 * p - 1.0)

# Attack 0→4% of step, hold, release 80→100%
func _chip_env(pos: float) -> float:
	var a: float = minf(pos / 0.04, 1.0)
	var r: float = 1.0 - clampf((pos - 0.80) / 0.20, 0.0, 1.0)
	return a * r

# Simple comb-filter echo applied in-place to a PackedByteArray of s16 samples
func _apply_echo(d: PackedByteArray, delay: int, decay: float) -> void:
	for i in d.size() / 2:
		if i < delay:
			continue
		var cur:  int = d.decode_s16(i * 2)
		var prev: int = d.decode_s16((i - delay) * 2)
		d.encode_s16(i * 2, clamp(cur + int(float(prev) * decay), -32768, 32767))

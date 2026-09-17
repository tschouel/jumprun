class_name SlidingPathWaveVisual
extends Node2D

@export var path: Path2D

@export_group("Vibration (um den Player herum)")
@export var amplitude: float = 6.0
@export var frequency: float = 45.0
@export var spatial_frequency: float = 0.08
@export var envelope_width: float = 140.0
## Wie SCHNELL die Vibration abklingt, nachdem der Spieler den Pfad
## KOMPLETT verlassen hat (pro Sekunde). Kleiner = laenger sichtbares
## Nachklingen.
@export_range(0.1, 10.0, 0.1) var fade_decay: float = 1.5
## Wie schnell die Vibration abklingt, WAEHREND der Spieler springt (noch
## auf dem Pfad, aber in der Luft) - deutlich schneller als fade_decay,
## aber kein hartes Abschneiden: die Saite schwingt beim Absprung noch
## ganz kurz nach, bevor sie stumm wird. Groesser = kuerzeres Nachschwingen.
@export_range(1.0, 40.0, 0.5) var jump_mute_decay: float = 12.0

@export_group("Optik")
@export var line_width: float = 3.0
@export var line_color: Color = Color.BLACK
@export var segments: int = 80
## Deaktiviere Antialiasing, wenn der Renderer einen 1px Halbpixel-Versatz erzeugt:
@export var antialiased: bool = false

@export_group("Ausgeblendeter Abschnitt (Ramp-Test)")
## Optional: RampTestSequencer, dessen Testfenster-Bereich NIE gezeichnet
## wird - unabhaengig davon, ob der Spieler dort gerade rutscht oder nicht.
## Leer lassen, wenn kein Abschnitt dauerhaft ausgeblendet werden soll.
@export var hidden_segment_source: RampTestSequencer

## Notenwerte fuer den Anzupf-Zyklus - gleiche Bedeutung wie bei
## BowRotator/VibratingString: Bruchteil eines game Taktes (4/4).
enum NoteValue { GANZE, HALBE, VIERTEL, ACHTEL, SECHZEHNTEL }
const NOTE_FRACTIONS: Array[float] = [1.0, 0.5, 0.25, 0.125, 0.0625]

@export_group("Anzupf-Punkte (Marker2D)")
## Marker2D-Positionen entlang des Pfades, an denen zusaetzlich zur
## spielerbezogenen Vibration ein periodisches "Anzupfen" gezeichnet wird -
## z.B. genau dort, wo deine Hand-/Finger-Animation die Saite beruehrt.
## Jeder Marker wird einmalig auf den naechstgelegenen Punkt der Pfadkurve
## projiziert (muss also nicht exakt AUF der Kurve liegen).
@export var pluck_points: Array[Marker2D] = []
## Rhythmus, in dem ALLE pluck_points gemeinsam angezupft werden (z.B.
## Viertel bei 90 bpm = alle 60/90*1 = 0.667s ein gemeinsamer Zupf-Impuls).
@export var pluck_note_value: NoteValue = NoteValue.VIERTEL
@export var pluck_bpm: float = 90.0
## Verschiebt NUR den Ausloese-Zeitpunkt des Zupfers relativ zum eigentlichen
## Taktschlag, in Sekunden - die Zykluslaenge (pluck_note_value/pluck_bpm)
## selbst bleibt dabei unangetastet, es verschiebt sich nur WANN innerhalb
## des Zyklus ausgeloest wird. NEGATIV = frueher (der Zupf kommt schon VOR
## dem Beat), POSITIV = spaeter (der Zupf kommt NACH dem Beat).
@export_range(-1.0, 1.0, 0.01, "or_greater", "or_less") var pluck_predelay: float = 0.0
@export var pluck_amplitude: float = 6.0
## Standard-/Fallback-Zupf-Radius (Breite des Ausschlagbereichs um jeden
## Punkt) - gilt fuer alle pluck_points, die in pluck_radii KEINEN eigenen
## Wert haben (siehe unten).
@export var pluck_envelope_width: float = 60.0
## Optional: individueller Zupf-Radius PRO Punkt in pluck_points, an
## GLEICHER Index-Position (z.B. pluck_radii[0] gilt fuer pluck_points[0]).
## Ein Eintrag <= 0, oder wenn dieses Array kuerzer als pluck_points ist,
## faellt fuer den jeweiligen Punkt automatisch auf pluck_envelope_width
## zurueck - trag hier also nur die Punkte ein, die einen ABWEICHENDEN
## Radius brauchen, der Rest bleibt leer/0.
@export var pluck_radii: Array[float] = []
## Wie schnell der Anzupf-Ausschlag nach jedem Impuls wieder abklingt (pro
## Sekunde) - i.d.R. deutlich schneller als fade_decay, da ein Zupfer ein
## kurzer Impuls ist, kein laengeres Nachklingen wie beim Pfad-Verlassen.
@export_range(0.1, 20.0, 0.1) var pluck_fade_decay: float = 6.0

var _player: CharacterBody2D = null
var _time: float = 0.0
var _fade_strength: float = 0.0
var _last_player_t: float = 0.5

var _pluck_offsets_t: Array[float] = []
var _pluck_cycle_elapsed: float = 0.0
var _pluck_strength: float = 0.0


func _ready() -> void:
	if not path:
		path = get_parent() as Path2D
	if path and path.curve:
		path.curve.changed.connect(_on_curve_changed)
	_refresh_pluck_offsets()
	set_process(true)


func _on_curve_changed() -> void:
	_refresh_pluck_offsets()
	queue_redraw()


## Projiziert jeden pluck_points-Marker einmalig auf seine naechstgelegene
## Kurvenposition (als t-Wert 0..1 entlang des Pfades) - wird in _ready()
## sowie jedes Mal, wenn sich die Pfadkurve aendert, neu berechnet.
func _refresh_pluck_offsets() -> void:
	_pluck_offsets_t.clear()
	if not path or not path.curve or path.curve.point_count < 2:
		return
	var total_length: float = path.curve.get_baked_length()
	if total_length <= 0.0:
		return
	for marker in pluck_points:
		if not marker:
			continue
		var local_pos: Vector2 = path.to_local(marker.global_position)
		var offset_dist: float = path.curve.get_closest_offset(local_pos)
		_pluck_offsets_t.append(clamp(offset_dist / total_length, 0.0, 1.0))


func _pluck_cycle_duration() -> float:
	if pluck_bpm <= 0.0 or pluck_points.is_empty():
		return 0.0
	return NOTE_FRACTIONS[pluck_note_value] * 4.0 * (60.0 / pluck_bpm)


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	var attached: bool = _is_player_attached_to_this_path()
	if attached:
		if _is_player_grounded_on_path():
			_fade_strength = 1.0
		else:
			_fade_strength = max(_fade_strength - jump_mute_decay * delta, 0.0)
	else:
		_fade_strength = max(_fade_strength - fade_decay * delta, 0.0)

	# Anzupf-Zyklus - laeuft unabhaengig vom Spieler immer im Hintergrund.
	var cycle_duration: float = _pluck_cycle_duration()
	if cycle_duration > 0.0:
		_pluck_cycle_elapsed += delta
		var trigger_offset: float = max(cycle_duration + pluck_predelay, 0.01)
		while _pluck_cycle_elapsed >= trigger_offset:
			_pluck_cycle_elapsed -= cycle_duration
			_pluck_strength = 1.0
	_pluck_strength = max(_pluck_strength - pluck_fade_decay * delta, 0.0)

	queue_redraw()


func _draw() -> void:
	if not path or not path.curve or path.curve.point_count < 2:
		return

	var total_length: float = path.curve.get_baked_length()
	if total_length <= 0.0:
		return

	if _is_player_attached_to_this_path():
		var player_pos_in_path: Vector2 = path.to_local(_player.global_position)
		var offset_along: float = path.curve.get_closest_offset(player_pos_in_path)
		_last_player_t = clamp(offset_along / total_length, 0.0, 1.0)

	var half_width_t: float = (envelope_width * 0.5) / total_length

	var hidden_ranges: Array[Vector2] = []
	if hidden_segment_source:
		hidden_ranges = hidden_segment_source.get_hidden_ranges()

	var current_run := PackedVector2Array()

	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var current_dist: float = t * total_length

		var is_hidden: bool = false
		for r in hidden_ranges:
			if current_dist >= r.x and current_dist <= r.y:
				is_hidden = true
				break

		if is_hidden:
			if current_run.size() > 1:
				draw_polyline(current_run, line_color, line_width, antialiased)
			current_run = PackedVector2Array()
			continue

		var local_pt: Vector2 = path.curve.sample_baked(current_dist, true)
		var global_pt: Vector2 = path.to_global(local_pt)

		var total_offset: float = 0.0

		if _fade_strength > 0.0:
			var envelope: float = _vibration_envelope(t, _last_player_t, half_width_t)
			if envelope > 0.0:
				var wave: float = sin((current_dist * spatial_frequency) - (_time * frequency * TAU))
				total_offset += amplitude * envelope * wave * _fade_strength

		if _pluck_strength > 0.0:
			for pi in range(_pluck_offsets_t.size()):
				var marker_t: float = _pluck_offsets_t[pi]
				var this_radius: float = pluck_envelope_width
				if pi < pluck_radii.size() and pluck_radii[pi] > 0.0:
					this_radius = pluck_radii[pi]
				var this_half_width_t: float = (this_radius * 0.5) / total_length
				var penv: float = _vibration_envelope(t, marker_t, this_half_width_t)
				if penv > 0.0:
					var pwave: float = sin((current_dist * spatial_frequency) - (_time * frequency * TAU))
					total_offset += pluck_amplitude * penv * pwave * _pluck_strength

		if total_offset != 0.0:
			var eps: float = max(total_length * 0.001, 0.5)
			var d0: float = clamp(current_dist - eps, 0.0, total_length)
			var d1: float = clamp(current_dist + eps, 0.0, total_length)
			var global_tangent: Vector2 = path.to_global(path.curve.sample_baked(d1)) - path.to_global(path.curve.sample_baked(d0))
			var perpendicular: Vector2 = global_tangent.normalized().orthogonal() if global_tangent.length() > 0.0001 else Vector2.UP
			global_pt += perpendicular * total_offset

		current_run.append(to_local(global_pt))

	if current_run.size() > 1:
		draw_polyline(current_run, line_color, line_width, antialiased)


func _is_player_attached_to_this_path() -> bool:
	if not is_instance_valid(_player):
		return false
	if not ("is_on_path" in _player) or not _player.is_on_path:
		return false
	var parent_path_follow := _player.get_parent() as PathFollow2D
	if not parent_path_follow:
		return false
	return parent_path_follow.get_parent() == path


func _is_player_grounded_on_path() -> bool:
	if not is_instance_valid(_player) or not _player.has_meta("path_movement_module"):
		return true
	var path_movement: Object = _player.get_meta("path_movement_module")
	if not is_instance_valid(path_movement):
		return true
	var jumping_value = path_movement.get("_is_jumping")
	if jumping_value == null:
		return true
	return not bool(jumping_value)


func _vibration_envelope(t: float, center_t: float, half_width_t: float) -> float:
	var d: float = abs(t - center_t)
	if half_width_t <= 0.0001 or d >= half_width_t:
		return 0.0
	return cos((d / half_width_t) * (PI * 0.5))

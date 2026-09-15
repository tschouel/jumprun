@tool
class_name RampTestSequencer
extends Node2D
## Wird als Kind-Node eines Path2D platziert (Geschwister von
## SlidingObstacleSequencer). Definiert MEHRERE aufeinanderfolgende
## Ramp-Test-Stationen auf derselben Kurve (siehe RampTestEntry.gd) - pro
## Station: a) das Tempo mit slowdown_factor multipliziert (nach einer
## optionalen Originaltempo-Warmup-Phase, siehe warmup_fraction), b) die
## Pfad-Linie bleibt fuer diesen Abschnitt DAUERHAFT unsichtbar (siehe
## SlidingPathWaveVisual.hidden_segment_source), c) ein Tastentest laeuft
## (Taste pro Station frei waehlbar, mit Pie-Timer-Countdown).
##
## Die Stationen werden IN REIHENFOLGE des tests-Arrays nacheinander
## abgearbeitet. Erfolg bei einer Station = kurzer Jubel-Hopser (siehe
## PathMovement.trigger_success_hop), dann normales Weiterrutschen bis zur
## naechsten Station. Fehlschlag bei IRGENDEINER Station (falsche Taste
## oder Timeout) = der Spieler faellt (siehe PathRampMovement.gd), dann
## Fade+Respawn ueber die Zone, die den Player attached hat (player-Meta
## "sliding_zone") - die GESAMTE Sequenz muss fehlerfrei durchlaufen werden.
##
## EDITOR-VORSCHAU: @tool macht dieses Skript auch im Editor aktiv - es
## zeichnet pro Station drei Marker (Start/Zeitlupen-Beginn/Ende) direkt
## auf der Kurve, damit man die Rampen-Grafik an den richtigen Stellen
## zeichnen kann, OHNE das Spiel zu starten.

@export var path: Path2D
## Die Ramp-Test-Stationen IN REIHENFOLGE entlang der Kurve. Fuer eine
## einzelne Ramp einfach ein Element, fuer mehrere hintereinander
## entsprechend mehr Elemente hinzufuegen.
@export var tests: Array[RampTestEntry] = []
## 0.5 = halbes Tempo waehrend der Zeitlupen-Phase jeder Station.
@export var slowdown_factor: float = 0.5
## Anteil jedes Testfensters (0.0-1.0), der noch im ORIGINALTEMPO
## durchlaufen wird, BEVOR Zeitlupe + Tastenabfrage beginnen - gilt fuer
## ALLE Stationen gleichermassen.
@export_range(0.0, 0.9, 0.01) var warmup_fraction: float = 0.33
## CanvasLayer-Instanz mit Tasten-/Pie-Timer-Anzeige (RampTimerUI.gd).
@export var timer_ui: RampTimerUI
## Wie lange der Spieler bei Fehlschlag faellt, bevor Fade+Respawn kommt.
@export var fail_fall_duration: float = 2.0
## Fallback-Geschwindigkeit fuer die Distanz-Umrechnung, falls kein
## SlidingObstacleSequencer als Geschwister-Node gefunden wird.
@export var reference_speed_fallback: float = 400.0

@export_group("Editor-Vorschau")
@export var show_editor_markers: bool = true
@export var marker_color: Color = Color(1.0, 0.2, 0.2, 0.9)
@export var marker_radius: float = 10.0

var _current_index: int = 0
var _failed: bool = false
var _passed_all: bool = false
var _key_listening: bool = false
var _current_player: CharacterBody2D = null


func _ready() -> void:
	if not path:
		path = get_parent() as Path2D


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or not show_editor_markers:
		return
	if not path or not path.curve:
		return

	var curve_len: float = path.curve.get_baked_length()
	if curve_len <= 0.0:
		return

	for entry in tests:
		if not entry or not entry.timing:
			continue

		var start_dist: float = clampf(_get_entry_start_distance(entry), 0.0, curve_len)
		var window_dist: float = _get_entry_window_distance(entry)
		var end_dist: float = clampf(start_dist + window_dist, 0.0, curve_len)
		var slow_dist: float = clampf(start_dist + (window_dist * warmup_fraction), 0.0, curve_len)

		var start_local: Vector2 = path.curve.sample_baked(start_dist, true)
		var end_local: Vector2 = path.curve.sample_baked(end_dist, true)
		var slow_local: Vector2 = path.curve.sample_baked(slow_dist, true)
		var start_pt: Vector2 = to_local(path.to_global(start_local))
		var end_pt: Vector2 = to_local(path.to_global(end_local))
		var slow_pt: Vector2 = to_local(path.to_global(slow_local))

		draw_line(start_pt, end_pt, marker_color, 3.0)
		draw_circle(start_pt, marker_radius, marker_color)
		draw_circle(slow_pt, marker_radius * 0.8, Color(1.0, 0.85, 0.1, 0.9))
		draw_circle(end_pt, marker_radius, marker_color.lightened(0.4))


func process_test(player: CharacterBody2D, path_follow: PathFollow2D, delta: float) -> float:
	if _failed or _passed_all or tests.is_empty():
		return 1.0

	_current_player = player

	if _current_index >= tests.size():
		_passed_all = true
		return 1.0

	var entry: RampTestEntry = tests[_current_index]
	if not entry or not entry.timing:
		_current_index += 1
		return 1.0

	var current_distance: float = path_follow.progress
	var start_dist: float = _get_entry_start_distance(entry)
	var window_dist: float = _get_entry_window_distance(entry)
	var end_dist: float = start_dist + window_dist
	var slow_phase_start_dist: float = start_dist + (window_dist * warmup_fraction)

	if current_distance < start_dist:
		return 1.0

	if current_distance >= end_dist:
		_trigger_fail(player)
		return 1.0

	if current_distance < slow_phase_start_dist:
		return 1.0

	if not _key_listening:
		_key_listening = true
		if timer_ui:
			timer_ui.show_prompt(OS.get_keycode_string(entry.required_key), player)

	if timer_ui:
		var slow_phase_dist: float = end_dist - slow_phase_start_dist
		var remaining_ratio: float = clampf((end_dist - current_distance) / slow_phase_dist, 0.0, 1.0) if slow_phase_dist > 0.0 else 0.0
		timer_ui.update_progress(remaining_ratio)

	return slowdown_factor


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not _key_listening or _failed or _passed_all:
		return
	if not (event is InputEventKey and event.pressed and not event.is_echo()):
		return
	if _current_index >= tests.size():
		return
	var entry: RampTestEntry = tests[_current_index]
	if not entry:
		return

	if event.physical_keycode == entry.required_key:
		_trigger_success()
	else:
		_trigger_fail(_current_player)


func _trigger_success() -> void:
	_key_listening = false
	if timer_ui:
		timer_ui.hide_prompt()

	if _current_player and _current_player.has_meta("path_movement_module"):
		var path_movement = _current_player.get_meta("path_movement_module")
		if path_movement and path_movement.has_method("trigger_success_hop"):
			path_movement.trigger_success_hop()

	_current_index += 1
	if _current_index >= tests.size():
		_passed_all = true


func _trigger_fail(player: CharacterBody2D) -> void:
	if _failed:
		return
	_failed = true
	_key_listening = false
	if timer_ui:
		timer_ui.hide_prompt()

	if not player.has_meta("sliding_zone"):
		push_warning("RampTestSequencer: Spieler hat keine 'sliding_zone' Meta - kann Respawn nicht ausloesen.")
		return
	var zone = player.get_meta("sliding_zone")
	if not zone:
		return

	var fall_velocity: Vector2 = Vector2(player.forward_speed, 0.0)

	if player.has_meta("path_ramp_movement_module"):
		var ramp_module = player.get_meta("path_ramp_movement_module")
		if ramp_module and ramp_module.has_method("begin_fail_fall"):
			ramp_module.begin_fail_fall(zone, player, fail_fall_duration, fall_velocity)


func reset_test() -> void:
	_current_index = 0
	_failed = false
	_passed_all = false
	_key_listening = false
	if timer_ui:
		timer_ui.hide_prompt()


func force_fail_if_unresolved(player: CharacterBody2D) -> bool:
	if _failed or _passed_all:
		return false
	_trigger_fail(player)
	return true


func _get_entry_start_distance(entry: RampTestEntry) -> float:
	if not entry or not entry.timing:
		return 0.0
	return entry.timing.get_start_time_seconds() * _get_reference_speed()


func _get_entry_window_distance(entry: RampTestEntry) -> float:
	if not entry or not entry.timing:
		return 0.0
	return entry.timing.get_window_duration_seconds() * _get_reference_speed()


func get_hidden_ranges() -> Array[Vector2]:
	var ranges: Array[Vector2] = []
	for entry in tests:
		if not entry or not entry.timing:
			continue
		var start_dist: float = _get_entry_start_distance(entry)
		ranges.append(Vector2(start_dist, start_dist + _get_entry_window_distance(entry)))
	return ranges


func _get_reference_speed() -> float:
	if path:
		for child in path.get_children():
			if child is SlidingObstacleSequencer:
				return child.slide_speed
	return reference_speed_fallback

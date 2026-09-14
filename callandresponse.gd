extends Node
class_name CallAndResponse
## Call-and-Response-System: sammelt die vom Spieler gezupften Toene (ueber
## register_note(), von aussen z.B. aus gopichand.gd bei jedem Zupfen
## aufgerufen) und prueft sie je nach "stage" auf Korrektheit. Bei Erfolg
## wird success_target (z.B. eine TuningKeySequence-Instanz/
## butterflytuningpeg.gd, ODER LevelStringDisplay.gd) per start_tuning()
## ausgeloest - JEDE erfolgreiche Stufe loest success_target aus.
##
## FINALE NACH DER LETZTEN STUFE (final_target, final_stage_number):
## ZUSAETZLICH zu success_target wird final_target.start_tuning()
## aufgerufen, aber NUR wenn genau final_stage_number (Standard 3) gerade
## erfolgreich abgeschlossen wurde.
##
## AKTUELL IN DIAGNOSE: print()-Aufrufe in _succeed(), um zu pruefen ob/wie
## final_target erreicht und aufgerufen wird. Nach der Diagnose wieder
## entfernen.
##
## AUTOMATISCHER STUFEN-AUFSTIEG: Nach Erfolg wird "stage" selbst
## automatisch um 1 erhoeht (siehe advance_stage_on_success).
##
## STUFE 1 - TON KOPIEREN, STUFE 2/3 - RHYTHMUS: siehe vorherige
## Kommentare/Versionen dieser Datei fuer Details.
##
## SETUP: siehe vorherige Versionen - unveraendert.

signal stage_passed(stage: int)
signal stage_failed(stage: int, reason: String)

@export_group("Ausloeser")
@export var interaction_zone: Area2D
@export var toggle_key: Key = KEY_F

@export_group("Aufgabe")
@export var stage: int = 1
@export var string_node: Node
@export var expected_tension_level: int = 0
@export var require_correct_pitch: bool = true

@export_group("Rhythmus (Stufe 2)")
@export var bpm: float = 100.0
@export var rhythm_pattern: Array[float] = [1.0, 0.5]
@export_range(0.01, 1.0, 0.01) var tolerance_percent: float = 0.25

@export_group("Rhythmus (Stufe 3, eigenstaendig)")
@export var stage3_expected_tension_level: int = 0
@export var stage3_bpm: float = 120.0
@export var stage3_rhythm_pattern: Array[float] = [0.5, 0.5, 1.0]
@export_range(0.01, 1.0, 0.01) var stage3_tolerance_percent: float = 0.25

@export_group("Stufen-Aufstieg")
@export var advance_stage_on_success: bool = true
@export var stage_intro_texts: Array[String] = ["", "", "Now try the rhythm: quarter - eighth - eighth", "Now try this new rhythm at a different tempo"]

@export_group("Rueckmeldung")
@export var feedback_label: Label
@export var feedback_display_time: float = 1.8
@export var too_slow_text: String = "too slow"
@export var rhythm_text: String = "rhythm not right"
@export var wrong_pitch_text: String = "wrong note"
@export var success_text: String = "nice!"
@export var success_color: Color = Color.WHITE
@export var intro_color: Color = Color.WHITE
@export var fail_color: Color = Color(1.0, 0.4, 0.4)
@export var auto_retry_on_fail: bool = true

@export_group("Erfolg")
@export var success_target: Node
@export var final_target: Node
@export var final_stage_number: int = 3

var _player_in_zone: bool = false
var _response_active: bool = false
var _note_times: Array[float] = []
var _note_pitches: Array[int] = []

func _ready() -> void:
	print("[CallAndResponse DIAGNOSE] _ready() - final_target=", final_target, " final_stage_number=", final_stage_number, " success_target=", success_target)
	if feedback_label:
		feedback_label.visible = false
	if interaction_zone:
		interaction_zone.body_entered.connect(_on_zone_body_entered)
		interaction_zone.body_exited.connect(_on_zone_body_exited)

func _on_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = true

func _on_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = false
		if _response_active:
			cancel_challenge()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_zone:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == toggle_key:
		if _response_active:
			cancel_challenge()
		else:
			start_challenge()

func start_challenge() -> void:
	_response_active = true
	_note_times.clear()
	_note_pitches.clear()

func cancel_challenge() -> void:
	_response_active = false
	_note_times.clear()
	_note_pitches.clear()

func register_note(tension_level: int) -> void:
	if not _response_active:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	_note_times.append(now)
	_note_pitches.append(tension_level)
	match stage:
		1:
			_evaluate_stage1()
		2:
			_evaluate_rhythm_stage(expected_tension_level, bpm, rhythm_pattern, tolerance_percent)
		3:
			_evaluate_rhythm_stage(stage3_expected_tension_level, stage3_bpm, stage3_rhythm_pattern, stage3_tolerance_percent)
		_:
			pass

func _evaluate_stage1() -> void:
	var pitch: int = _note_pitches[0]
	_response_active = false
	if pitch == expected_tension_level:
		_succeed()
	else:
		_fail(wrong_pitch_text)

func _evaluate_rhythm_stage(expected_pitch: int, stage_bpm: float, pattern: Array[float], tolerance: float) -> void:
	var expected_note_count: int = pattern.size() + 1
	var count: int = _note_pitches.size()

	if require_correct_pitch:
		var last_pitch: int = _note_pitches[count - 1]
		if last_pitch != expected_pitch:
			_response_active = false
			_fail(wrong_pitch_text)
			return

	if count < expected_note_count:
		return

	_response_active = false

	if stage_bpm <= 0.0:
		_fail(rhythm_text)
		return

	var seconds_per_beat: float = 60.0 / stage_bpm
	var ratios: Array[float] = []
	for i in range(pattern.size()):
		var expected_gap: float = pattern[i] * seconds_per_beat
		var actual_gap: float = _note_times[i + 1] - _note_times[i]
		if expected_gap <= 0.0001:
			_fail(rhythm_text)
			return
		ratios.append(actual_gap / expected_gap)

	var mean_ratio: float = 0.0
	for r in ratios:
		mean_ratio += r
	mean_ratio /= float(ratios.size())

	for r in ratios:
		var deviation: float = (r / mean_ratio) - 1.0
		if abs(deviation) > tolerance:
			_fail(rhythm_text)
			return

	if mean_ratio > 1.0 + tolerance:
		_fail(too_slow_text)
	else:
		_succeed()

func _succeed() -> void:
	var completed_stage: int = stage
	print("[CallAndResponse DIAGNOSE] _succeed() aufgerufen! completed_stage=", completed_stage, " final_stage_number=", final_stage_number, " final_target=", final_target)

	if success_target and success_target.has_method("start_tuning"):
		success_target.start_tuning()

	if completed_stage == final_stage_number:
		print("[CallAndResponse DIAGNOSE]   final_stage_number erreicht!")
		if final_target and final_target.has_method("start_tuning"):
			print("[CallAndResponse DIAGNOSE]   -> final_target.start_tuning() wird JETZT aufgerufen!")
			final_target.start_tuning()
		elif not final_target:
			print("[CallAndResponse DIAGNOSE]   ACHTUNG: final_target ist NICHT gesetzt (null)!")
		else:
			print("[CallAndResponse DIAGNOSE]   ACHTUNG: final_target hat KEINE start_tuning-Methode! Typ: ", final_target)
	else:
		print("[CallAndResponse DIAGNOSE]   completed_stage (", completed_stage, ") != final_stage_number (", final_stage_number, "), kein Finale ausgeloest")

	stage_passed.emit(completed_stage)

	var next_stage: int = stage + 1 if advance_stage_on_success else stage
	var intro_text: String = ""
	if advance_stage_on_success and next_stage < stage_intro_texts.size():
		intro_text = stage_intro_texts[next_stage]

	if intro_text != "":
		_show_feedback(success_text, success_color)
		get_tree().create_timer(feedback_display_time).timeout.connect(
			func() -> void:
				_show_feedback(intro_text, intro_color)
		)
	else:
		_show_feedback(success_text, success_color)

	if advance_stage_on_success:
		stage = next_stage
		_response_active = true
		_note_times.clear()
		_note_pitches.clear()

func _fail(reason: String) -> void:
	_show_feedback(reason, fail_color)
	stage_failed.emit(stage, reason)
	if auto_retry_on_fail:
		_response_active = true
		_note_times.clear()
		_note_pitches.clear()

func _show_feedback(text: String, color: Color) -> void:
	if not feedback_label:
		return
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_label.visible = true
	get_tree().create_timer(feedback_display_time).timeout.connect(
		func() -> void:
			if feedback_label and feedback_label.text == text:
				feedback_label.visible = false
	)

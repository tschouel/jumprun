extends Node2D
class_name MusicString
## Eine durchhaengende Saite (wie eine Geigensaite), die ueber einen
## externen TensionTrigger.gd (Area2D beim Stimmschluessel) bis zu
## max_tension mal nachgespannt (request_tension_increase) oder wieder
## gelockert (request_tension_decrease) werden kann. Je hoeher die Spannung,
## desto weniger haengt die Saite durch UND desto staerker federt sie, wenn
## der Spieler reinfaellt. Ist max_tension erreicht und wird trotzdem
## request_tension_increase() aufgerufen, spielt der Stimmschluessel eine
## eigene "schon ganz gespannt"-Animation ab, statt dass irgendwas reisst
## (keine Reissmechanik mehr in diesem Skript - dafuer gibt es StringWall.gd).
##
## Die Vibration nach einem Bounce geht vom tatsaechlichen Aufprallpunkt aus
## (Spielerposition auf die Saite projiziert) und klingt zu beiden Enden hin
## ab. Je hoeher die Spannung, desto HOEHER die Vibrationsfrequenz und desto
## NIEDRIGER die Amplitude - eine straffere Saite schwingt schneller, aber
## mit weniger Ausschlag.
##
## MEHRFACH-BOUNCE: Da die Vibration die Kollisionsform (bounce_collision)
## jeden Frame neu zeichnet (siehe _rebuild_visual_and_collision), verlaesst
## der Spieler die Area nach einem Bounce oft nie wirklich vollstaendig -
## das rein einmalige body_entered-Signal wuerde daher beim naechsten Fallen
## nicht erneut feuern. Geloest ueber _bodies_falling_ready: ein Koerper darf
## erst wieder bouncen, nachdem er zwischenzeitlich sichtbar gestiegen ist
## (velocity.y < 0) - geprueft jeden Physik-Frame ueber
## get_overlapping_bodies(), nicht nur beim einmaligen body_entered.
##
## WICHTIG zu Positionen: die Kurve wird intern komplett in GLOBALEN
## Koordinaten berechnet (ausgehend von anchor_left.global_position und
## anchor_right.global_position) und erst beim Zeichnen/Kollision-Setzen in
## das jeweilige lokale Koordinatensystem des Ziel-Nodes umgerechnet
## (to_local). Dadurch spielt es KEINE Rolle, an welcher Position im
## Szenenbaum StringLine, BounceArea/CollisionPolygon2D oder
## SolidBlock/CollisionPolygon2D relativ zu MusicString liegen.
##
## SETUP:
## 1. AnchorLeft und AnchorRight (Marker2D) auf die zwei Befestigungspunkte
##    ziehen. AnchorRight = Seite mit dem Stimmschluessel.
## 2. StringLine (Line2D) als Kind, als Scene Unique Name (%) markieren.
## 3. TuningPeg (AnimatedSprite2D) als Kind, als Scene Unique Name markieren.
##    Zwei Animationen ohne Loop noetig: eine normale Dreh-Animation
##    (tuning_peg_animation, z.B. "turn") und eine fuer den Fall, dass schon
##    voll gespannt ist und man trotzdem weiter drehen will
##    (tuning_peg_max_animation, z.B. "turn_stuck" - z.B. ein kurzes
##    Rattern/Anschlagen statt einer vollen Umdrehung).
## 4. BounceArea (Area2D) + CollisionPolygon2D als Kind, beide als Scene
##    Unique Name markieren. Polygon-Punkte werden automatisch gesetzt.
## 5. SolidBlock (StaticBody2D) + CollisionPolygon2D als Kind, beide als
##    Scene Unique Name markieren. Verhindert, dass der Spieler unter die
##    durchhaengende Saite gelangt.
## 6. Einen TensionTrigger-Node (eigenes Skript, siehe TensionTrigger.gd)
##    irgendwo beim Stimmschluessel platzieren und "String Node" im
##    Inspector auf diesen MusicString-Node zeigen lassen (oder automatische
##    Erkennung nutzen, siehe TensionTrigger.gd).

signal tension_changed(new_level: int)

@export_group("Spannung")
@export var max_tension: int = 4
@export var start_tension: int = 0
## Wie lange das sichtbare Nachspannen/Lockern (Durchhang-Aenderung) dauert.
@export var tension_animation_duration: float = 0.5

@export_group("Durchhang (Line2D-Kurve)")
## Wie stark die Saite bei Spannung 0 durchhaengt (in Pixeln).
@export var max_sag: float = 70.0
## Wie stark sie bei voller Spannung (max_tension) noch minimal durchhaengt.
@export var min_sag: float = 8.0
## Aufloesung der Kurve - mehr Punkte = glatter, aber etwas teurer.
@export var line_segments: int = 24
## "Dicke" der Bounce-Zone um die Kurve herum (Kollisions-Toleranz).
@export var bounce_thickness: float = 24.0
## Wie weit der feste Sperr-Block UNTER der Bounce-Zone nach unten reicht.
@export var solid_block_depth: float = 1200.0

@export_group("Federkraft")
## Sprungkraft bei Spannung 0 (schwaechster Bounce).
@export var bounce_velocity_base: float = 500.0
## Zusaetzliche Sprungkraft PRO Spannungsstufe.
@export var bounce_velocity_per_tension: float = 250.0

@export_group("Vibration bei Bounce")
## Basis-Amplitude bei Spannung 0. Wird pro Spannungsstufe reduziert (siehe
## vibration_amplitude_decrease_per_tension).
@export var vibration_amplitude: float = 18.0
## Basis-Frequenz bei Spannung 0. Wird pro Spannungsstufe erhoeht (siehe
## vibration_frequency_increase_per_tension).
@export var vibration_frequency: float = 6.0
## Wie schnell die Vibration abklingt - hoeher = schneller ruhig.
@export var vibration_decay: float = 5.0
## Faktor, um wie viel die Frequenz PRO Spannungsstufe steigt (0.5 = +50%
## Frequenz pro Stufe, bei max_tension=4 also bis zu +200%).
@export var vibration_frequency_increase_per_tension: float = 0.5
## Faktor, um wie viel die Amplitude PRO Spannungsstufe sinkt (0.15 = -15%
## Amplitude pro Stufe).
@export var vibration_amplitude_decrease_per_tension: float = 0.15
## Untere Grenze, wie stark die Amplitude durch obigen Faktor maximal
## schrumpfen darf (relativ zur Basis-Amplitude - 0.3 = nie unter 30%).
@export_range(0.0, 1.0, 0.01) var vibration_amplitude_min_factor: float = 0.3
## Mindestabstand (in t, 0..1) des Aufprallpunkts von den beiden Enden -
## verhindert eine "geknickte" Huellkurve, falls der Spieler ganz am Rand
## der Saite aufkommt.
@export_range(0.01, 0.49, 0.01) var vibration_edge_margin: float = 0.05

@export_group("Stimmschluessel")
## Name der normalen Dreh-Animation (Loop AUS).
@export var tuning_peg_animation: String = "turn"
## Name der Animation, die abgespielt wird, wenn man versucht ueber
## max_tension hinaus anzuspannen (Loop AUS). Rein optisches Feedback, es
## passiert danach nichts weiter (kein Reissen in diesem Skript).
@export var tuning_peg_max_animation: String = "turn_stuck"

@export_group("Optik (Line2D)")
@export var smooth_line_rendering: bool = true

@onready var anchor_left: Marker2D = $AnchorLeft
@onready var anchor_right: Marker2D = $AnchorRight
@onready var string_line: Line2D = %StringLine
@onready var bounce_area: Area2D = %BounceArea
@onready var bounce_collision: CollisionPolygon2D = %BounceArea/CollisionPolygon2D
@onready var solid_block: StaticBody2D = %SolidBlock
@onready var solid_block_collision: CollisionPolygon2D = %SolidBlock/CollisionPolygon2D
@onready var tuning_peg: AnimatedSprite2D = %TuningPeg

enum PendingAction { NONE, INCREASE, DECREASE, MAX_FEEDBACK }

var tension_level: int = 0
var _is_turning: bool = false
var _pending_action: PendingAction = PendingAction.NONE
var _active_anim_name: String = ""
var _display_sag: float = 0.0
var _sag_tween: Tween
var _vibration_time: float = -1.0  # -1 = keine Vibration aktiv
var _vibration_center_t: float = 0.5
## body -> true, solange dieser Koerper gerade "bounce-bereit" ist (siehe
## Erklaerung oben im Klassenkommentar zu MEHRFACH-BOUNCE).
var _bodies_falling_ready: Dictionary = {}

func _ready() -> void:
	tension_level = clampi(start_tension, 0, max_tension)
	_display_sag = _target_sag()
	if smooth_line_rendering:
		_style_line(string_line)
	_rebuild_visual_and_collision()
	bounce_area.body_entered.connect(_on_bounce_area_body_entered)
	bounce_area.body_exited.connect(_on_bounce_area_body_exited)
	tuning_peg.animation_finished.connect(_on_tuning_peg_animation_finished)

## Rein optische Zeicheneinstellungen fuer ein Line2D: Antialiasing an,
## runde Gelenke/Enden statt eckiger. Behebt das treppige Aussehen bei
## schraegen Linien, hat keinerlei Einfluss auf Physik/Kollision/Verhalten.
func _style_line(line: Line2D) -> void:
	if not line:
		return
	line.antialiased = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND

## Von einem TensionTrigger.gd aufgerufen, wenn der Spieler in der Zone die
## Anspann-Taste drueckt. Startet NUR die Dreh-Animation - die eigentliche
## Aenderung passiert erst, wenn die Animation fertig durchgelaufen ist
## (siehe _on_tuning_peg_animation_finished). Ist bereits max_tension
## erreicht, spielt stattdessen tuning_peg_max_animation ab (reines
## Feedback, die Spannung aendert sich dabei NICHT). Gibt true zurueck, wenn
## tatsaechlich eine Animation gestartet wurde.
func request_tension_increase() -> bool:
	if _is_turning:
		return false  # Verhindert Spammen/Ueberschneiden waehrend die Animation laeuft
	_is_turning = true
	if tension_level >= max_tension:
		_pending_action = PendingAction.MAX_FEEDBACK
		_active_anim_name = tuning_peg_max_animation
		tuning_peg.play(tuning_peg_max_animation)
	else:
		_pending_action = PendingAction.INCREASE
		_active_anim_name = tuning_peg_animation
		tuning_peg.play(tuning_peg_animation)
	return true

## Von einem TensionTrigger.gd aufgerufen, wenn der Spieler in der Zone die
## Lockern-Taste drueckt. Spielt die normale Dreh-Animation RUECKWAERTS ab
## (play_backwards() - speed_scale = -1.0 ist in Godot 4 unzuverlaessig).
## Bei Spannung 0 passiert nichts (gibt false zurueck).
func request_tension_decrease() -> bool:
	if _is_turning:
		return false
	if tension_level <= 0:
		return false
	_is_turning = true
	_pending_action = PendingAction.DECREASE
	_active_anim_name = tuning_peg_animation
	tuning_peg.play_backwards(tuning_peg_animation)
	return true

func _on_tuning_peg_animation_finished() -> void:
	# Filtert versehentliche Ready-Signale von anderen Animationen ab (z.B.
	# einer Idle-Animation mit Loop aus).
	if tuning_peg.animation != _active_anim_name:
		return
	_is_turning = false
	var action: PendingAction = _pending_action
	_pending_action = PendingAction.NONE
	if action == PendingAction.INCREASE:
		tension_level = clampi(tension_level + 1, 0, max_tension)
		tension_changed.emit(tension_level)
		_animate_sag_to(_target_sag())
	elif action == PendingAction.DECREASE:
		tension_level = clampi(tension_level - 1, 0, max_tension)
		tension_changed.emit(tension_level)
		_animate_sag_to(_target_sag())
	# MAX_FEEDBACK: keine Aenderung, war nur Optik.

func _target_sag() -> float:
	var t: float = float(tension_level) / float(max_tension)
	return lerp(max_sag, min_sag, t)

## Kurvenform: parabelfoermiger Durchhang, 0 an beiden Enden, Maximum in der Mitte.
func _sag_shape(t: float) -> float:
	return 4.0 * t * (1.0 - t)

## Huellkurve fuer die Vibration: 1.0 genau am Aufprallpunkt
## (_vibration_center_t), faellt zu BEIDEN Enden (t=0 und t=1) sanft auf 0 ab.
func _vibration_envelope(t: float) -> float:
	var center: float = _vibration_center_t
	if t <= center:
		var denom: float = center
		return sin((t / denom) * (PI * 0.5)) if denom > 0.0001 else 1.0
	else:
		var denom: float = 1.0 - center
		return sin(((1.0 - t) / denom) * (PI * 0.5)) if denom > 0.0001 else 0.0

## Effektive Vibrationsfrequenz/-amplitude fuer die aktuelle Spannungsstufe:
## Frequenz steigt, Amplitude sinkt mit hoeherer Spannung.
func _effective_vibration_frequency() -> float:
	return vibration_frequency * (1.0 + float(tension_level) * vibration_frequency_increase_per_tension)

func _effective_vibration_amplitude() -> float:
	var factor: float = max(1.0 - float(tension_level) * vibration_amplitude_decrease_per_tension, vibration_amplitude_min_factor)
	return vibration_amplitude * factor

## Aktueller Punkt auf der Kurve in GLOBALEN Koordinaten (Weltposition),
## inklusive Durchhang UND (falls gerade aktiv) der abklingenden
## Nachschwing-Vibration.
func _curve_point_global(t: float) -> Vector2:
	var base: Vector2 = anchor_left.global_position.lerp(anchor_right.global_position, t)
	base.y += _display_sag * _sag_shape(t)
	if _vibration_time >= 0.0:
		var amp: float = _effective_vibration_amplitude() * exp(-vibration_decay * _vibration_time)
		var freq: float = _effective_vibration_frequency()
		base.y += amp * _vibration_envelope(t) * sin(_vibration_time * freq * TAU)
	return base

## Projiziert eine globale Position auf die Saitenlinie (AnchorLeft ->
## AnchorRight) und gibt den Anteil t (0..1) zurueck, wo sie am naechsten liegt.
func _project_impact_t(global_pos: Vector2) -> float:
	var from: Vector2 = anchor_left.global_position
	var to: Vector2 = anchor_right.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return 0.5
	var t: float = (global_pos - from).dot(dir / length) / length
	return clamp(t, vibration_edge_margin, 1.0 - vibration_edge_margin)

## Startet die abklingende Nachschwing-Vibration, zentriert um impact_t
## (0..1 entlang der Saite).
func _start_vibration(impact_t: float = 0.5) -> void:
	_vibration_center_t = clamp(impact_t, vibration_edge_margin, 1.0 - vibration_edge_margin)
	_vibration_time = 0.0

func _process(delta: float) -> void:
	if _vibration_time >= 0.0:
		_vibration_time += delta
		var amp: float = _effective_vibration_amplitude() * exp(-vibration_decay * _vibration_time)
		if amp < 0.5:
			_vibration_time = -1.0
		_rebuild_visual_and_collision()

## Prueft jeden Physik-Frame ALLE Koerper, die die BounceArea gerade
## ueberlappen (nicht nur beim einmaligen body_entered) - das faengt den
## Fall ab, dass die vibrationsbedingt staendig neu gezeichnete
## Kollisionsform den Spieler nach einem Bounce nie wirklich austreten
## laesst, bevor er erneut faellt. Ein Koerper, der sichtbar steigt
## (velocity.y < 0), wird als "wieder bounce-bereit" markiert.
func _physics_process(_delta: float) -> void:
	for body in bounce_area.get_overlapping_bodies():
		if not (body is CharacterBody2D):
			continue
		if body.velocity.y < 0.0:
			_bodies_falling_ready[body] = true
		_try_bounce(body)

func _animate_sag_to(target_sag: float, duration: float = tension_animation_duration) -> void:
	if _sag_tween and _sag_tween.is_valid():
		_sag_tween.kill()
	_sag_tween = create_tween()
	_sag_tween.tween_method(_set_display_sag, _display_sag, target_sag, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_display_sag(value: float) -> void:
	_display_sag = value
	_rebuild_visual_and_collision()

## Berechnet die Kurve einmal in globalen Koordinaten und rechnet sie dann
## fuer JEDEN Ziel-Node einzeln in dessen lokales Koordinatensystem um -
## dadurch ist es egal, ob diese Nodes bei (0,0) relativ zu MusicString
## sitzen oder irgendwo anders.
func _rebuild_visual_and_collision() -> void:
	var top_points: Array[Vector2] = []
	var bottom_points: Array[Vector2] = []
	string_line.clear_points()
	for i in range(line_segments + 1):
		var t: float = float(i) / float(line_segments)
		var p_global: Vector2 = _curve_point_global(t)
		string_line.add_point(string_line.to_local(p_global))
		top_points.append(bounce_collision.to_local(p_global + Vector2(0.0, -bounce_thickness)))
		bottom_points.append(bounce_collision.to_local(p_global + Vector2(0.0, bounce_thickness)))
	var bounce_bottom: Array[Vector2] = bottom_points.duplicate()
	bounce_bottom.reverse()
	bounce_collision.polygon = PackedVector2Array(top_points + bounce_bottom)

	var block_top_points: Array[Vector2] = []
	var block_bottom_points: Array[Vector2] = []
	for i in range(line_segments + 1):
		var t: float = float(i) / float(line_segments)
		var p_global: Vector2 = _curve_point_global(t)
		block_top_points.append(solid_block_collision.to_local(p_global + Vector2(0.0, bounce_thickness)))
		block_bottom_points.append(solid_block_collision.to_local(p_global + Vector2(0.0, solid_block_depth)))
	block_bottom_points.reverse()
	solid_block_collision.polygon = PackedVector2Array(block_top_points + block_bottom_points)

func _bounce_strength() -> float:
	return bounce_velocity_base + tension_level * bounce_velocity_per_tension

## Erstmaliges Betreten der BounceArea - markiert den Koerper sofort als
## bounce-bereit und versucht direkt einen Bounce (fuer den Fall, dass er
## bereits faellt, wenn er reinkommt).
func _on_bounce_area_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	_bodies_falling_ready[body] = true
	_try_bounce(body)

## Aufraeumen, sobald ein Koerper die Area tatsaechlich komplett verlaesst -
## verhindert, dass das Dictionary unbegrenzt waechst.
func _on_bounce_area_body_exited(body: Node2D) -> void:
	_bodies_falling_ready.erase(body)

## Zentrale Bounce-Logik, aus zwei Stellen aufgerufen: einmal beim
## erstmaligen Betreten (body_entered) UND einmal jeden Physik-Frame fuer
## Koerper, die die Area ueberlappen (_physics_process). Bouncet nur, wenn
## der Koerper tatsaechlich FAELLT (velocity.y > 0) UND gerade als
## bounce-bereit markiert ist - direkt nach einem Bounce wird die
## Bereitschaft entzogen, bis der Koerper zwischenzeitlich wieder sichtbar
## gestiegen ist (siehe _physics_process).
func _try_bounce(body: CharacterBody2D) -> void:
	if not _bodies_falling_ready.get(body, false):
		return
	if body.velocity.y > 0.0:
		body.velocity.y = -_bounce_strength()
		_start_vibration(_project_impact_t(body.global_position))
		_bodies_falling_ready[body] = false

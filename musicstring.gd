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
## VIBRATION IST NUR VISUELL, NIEMALS PHYSISCH:
## Es gibt zwei getrennte Kurvenfunktionen. _curve_point_global(t) liefert
## die STABILE, strukturelle Kurve (reiner Durchhang, KEINE Vibration) -
## das ist die "physische Wahrheit" der Saite und wird fuer SolidBlock,
## BounceArea-Erkennungszone und den Bounce-Crossing-Test verwendet.
## _curve_visual_point_global(t) liefert zusaetzlich die abklingende
## Nachschwing-Vibration oben drauf - NUR fuer die sichtbare Line2D gedacht.
## Kollisions-Polygone werden NICHT jeden Vibrations-Frame neu gebaut,
## sondern nur bei tatsaechlicher Spannungsaenderung (siehe
## _rebuild_collision vs. _rebuild_line_visual weiter unten).
##
## SICHERHEITS-CLAMP GEGEN VISUELLES "DURCH DEN BODEN VIBRIEREN":
## Die effektive Vibrationsamplitude wird automatisch auf
## bounce_thickness * vibration_max_amplitude_ratio gedeckelt (siehe
## _effective_vibration_amplitude). WICHTIG (offener Punkt, siehe unten):
## bei bounce_thickness=24 gab es trotz komplett entkoppelter Kollision
## noch sporadisch fehlschlagende Bounces, die erst bei bounce_thickness=20
## zuverlaessig verschwanden. Der exakte Mechanismus dahinter (vermutlich
## Kollisionsgroesse von Footcoll/Headcoll oder move_and_slide's
## safe_margin in Kombination mit der Blockdicke) ist noch nicht final
## geklaert - aktuell rein empirisch auf bounce_thickness=20 eingestellt.
## Falls das Problem bei kuenftigen Aenderungen wieder auftaucht, lohnt es
## sich, das sauber zu Ende zu diagnostizieren statt nur den Wert zu
## verschieben.
##
## Die Vibration nach einem Bounce geht vom tatsaechlichen Aufprallpunkt aus
## (Spielerposition auf die Saite projiziert) und klingt zu beiden Enden hin
## ab. Je hoeher die Spannung, desto HOEHER die Vibrationsfrequenz und desto
## NIEDRIGER die Amplitude - eine straffere Saite schwingt schneller, aber
## mit weniger Ausschlag.
##
## BOUNCE-ERKENNUNG (Crossing-Test statt reinem Area-Overlap):
## Ein reiner "ist der Koerper gerade in der Area drin"-Check reicht bei
## hohen Fallgeschwindigkeiten/grosser World Scale NICHT aus - Area2D prueft
## Ueberlappung nur diskret pro Physik-Frame (kein Continuous Collision
## Detection). Faellt ein Koerper schneller, als die Zonen-Dicke pro Frame
## durchquert wird, kann er die BounceArea in einem einzigen Frame komplett
## durchtunneln, ohne dass body_entered/body_exited JEMALS feuert.
##
## Loesung: Statt (nur) auf Area-Overlap zu vertrauen, wird pro getracktem
## Koerper die globale Y-Position vom LETZTEN Physik-Frame gespeichert
## (_tracked_bodies_last_y). Jeden Frame wird geprueft, ob der Koerper
## zwischen letztem und jetzigem Frame die STABILE (nicht-vibrierende)
## Kurvenhoehe an seiner X-Position von OBEN nach UNTEN durchquert hat
## (last_y <= curve_y UND current_y >= curve_y).
##
## Die (unsichtbare, nie blockierende) BounceArea dient dabei nur noch dazu,
## grob zu wissen, WELCHE Koerper ueberhaupt relevant sind (Start/Stop des
## Trackings) - ihre Groesse (detection_margin) darf daher grosszuegig sein,
## ohne optische oder physische Nachteile, da Area2D sowieso nie blockiert.
## Das eigentliche feste Blockieren (damit der Spieler nicht unter die Saite
## rutscht) macht weiterhin ausschliesslich SolidBlock, dessen Position
## unabhaengig von bounce_thickness bestimmt wird.
##
## WICHTIG zu Positionen: die Kurve wird intern komplett in GLOBALEN
## Koordinaten berechnet (ausgehend von anchor_left.global_position und
## anchor_right.global_position) und erst beim Zeichnen/Kollision-Setzen in
## das jeweilige lokale Koordinatensystem des Ziel-Nodes umgerechnet
## (to_local). Dadurch spielt es KEINE Rolle, an welcher Position im
## Szenenbaum StringLine, BounceArea/CollisionPolygon2D oder
## SolidBlock/CollisionPolygon2D relativ zu MusicString liegen (Rotation und
## Skalierung dieser Nodes muessen aber bei 0 bzw. 1,1 bleiben, sonst werden
## die umgerechneten Punkte verzerrt).
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
##    Unique Name markieren. Polygon-Punkte werden automatisch gesetzt
##    (Groesse ueber detection_margin/detection_horizontal_margin steuern).
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
@export var max_sag: float = 600.0
## Wie stark sie bei voller Spannung (max_tension) noch minimal durchhaengt.
@export var min_sag: float = 8.0
## Aufloesung der Kurve - mehr Punkte = glatter, aber etwas teurer.
@export var line_segments: int = 24
## Wie weit der feste Sperr-Block (SolidBlock) UNTERHALB der (stabilen,
## nicht-vibrierenden) Kurve beginnt - bestimmt die "physische" Dicke der
## Saite. Beeinflusst NICHT die Bounce-Erkennung (siehe detection_margin),
## begrenzt aber automatisch die sichtbare Vibrationsamplitude (siehe
## vibration_max_amplitude_ratio). Aktuell empirisch auf 20 gesetzt (siehe
## Klassenkommentar oben, offener Punkt).
@export var bounce_thickness: float = 20.0
## Wie weit der feste Sperr-Block UNTER der Kurve nach unten reicht.
@export var solid_block_depth: float = 500.0

@export_group("Bounce-Erkennung")
## Groesse der (unsichtbaren, nicht-blockierenden) Trigger-Zone um die Kurve
## herum, in der Koerper ueberhaupt "beobachtet"/getrackt werden. Rein
## technischer Wert fuer verlaessliche Erkennung bei hohen
## Fallgeschwindigkeiten/grosser World Scale - hat KEINEN Einfluss auf
## Optik oder tatsaechliche physische Kollision (Area2D blockiert nie).
## Faustregel: grosszuegig waehlen, es gibt keinen Nachteil durch "zu
## gross" (z.B. 150-300px je nach max. Fallgeschwindigkeit).
@export var detection_margin: float = 150.0
## Zusaetzliche horizontale Toleranz ueber die Anker hinaus (in Pixeln), in
## der ein Bounce noch erkannt wird - falls der Koerper knapp seitlich der
## Saiten-Enden auftrifft.
@export var detection_horizontal_margin: float = 32.0

@export_group("Federkraft")
## Sprungkraft bei Spannung 0 (schwaechster Bounce).
@export var bounce_velocity_base: float = 400.0
## Zusaetzliche Sprungkraft PRO Spannungsstufe.
@export var bounce_velocity_per_tension: float = 350.0

@export_group("Vibration bei Bounce")
## Basis-Amplitude bei Spannung 0. Wird pro Spannungsstufe reduziert (siehe
## vibration_amplitude_decrease_per_tension) und zusaetzlich automatisch
## auf bounce_thickness * vibration_max_amplitude_ratio gedeckelt - rein
## visuell, beliebig hoch waehlbar, ohne die Kollision je zu beeinflussen.
@export var vibration_amplitude: float = 18.0
## Basis-Frequenz bei Spannung 0. Wird pro Spannungsstufe erhoeht (siehe
## vibration_frequency_increase_per_tension).
@export var vibration_frequency: float = 12.0
## Wie schnell die Vibration abklingt - hoeher = schneller ruhig.
@export var vibration_decay: float = 1.0
## Faktor, um wie viel die Frequenz PRO Spannungsstufe steigt (0.5 = +50%
## Frequenz pro Stufe, bei max_tension=4 also bis zu +200%).
@export var vibration_frequency_increase_per_tension: float = 0.5
## Faktor, um wie viel die Amplitude PRO Spannungsstufe sinkt (0.15 = -15%
## Amplitude pro Stufe).
@export var vibration_amplitude_decrease_per_tension: float = 0.15
## Untere Grenze, wie stark die Amplitude durch obigen Faktor maximal
## schrumpfen darf (relativ zur Basis-Amplitude - 0.3 = nie unter 30%).
@export_range(0.0, 1.0, 0.01) var vibration_amplitude_min_factor: float = 0.3
## SICHERHEITS-CLAMP (rein optisch): die effektive Vibrationsamplitude wird
## nie groesser als bounce_thickness * dieser Faktor. Verhindert, dass die
## sichtbare Linie bei hoch gewaehlter vibration_amplitude optisch durch
## den (unsichtbaren, aber felsenfesten) SolidBlock schlaegt.
@export_range(0.0, 1.0, 0.01) var vibration_max_amplitude_ratio: float = 0.85
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

## Koerper, die aktuell innerhalb der grosszuegigen Erkennungszone getrackt
## werden -> ihre globale Y-Position vom LETZTEN Physik-Frame. Grundlage
## fuer den Crossing-Test in _check_crossing(). Eintraege werden bei
## body_entered angelegt und bei body_exited wieder entfernt.
var _tracked_bodies_last_y: Dictionary = {}

func _ready() -> void:
	tension_level = clampi(start_tension, 0, max_tension)
	_display_sag = _target_sag()
	if smooth_line_rendering:
		_style_line(string_line)
	_rebuild_collision()
	_rebuild_line_visual()
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

func _animate_sag_to(target_sag: float, duration: float = tension_animation_duration) -> void:
	if _sag_tween and _sag_tween.is_valid():
		_sag_tween.kill()
	_sag_tween = create_tween()
	_sag_tween.tween_method(_set_display_sag, _display_sag, target_sag, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Wird waehrend der Spann-/Lockerungs-Animation jeden Tween-Schritt
## aufgerufen - hier AENDERT sich die stabile Kurve wirklich, deshalb
## werden hier (und nur hier, bzw. beim initialen _ready) Line UND
## Kollision gemeinsam neu gebaut.
func _set_display_sag(value: float) -> void:
	_display_sag = value
	_rebuild_collision()
	_rebuild_line_visual()

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

## Effektive Basis-Amplitude (vor Zeit-Abklingen), inkl. Spannungsreduktion
## UND dem Sicherheits-Clamp gegen bounce_thickness.
func _effective_vibration_amplitude() -> float:
	var factor: float = max(1.0 - float(tension_level) * vibration_amplitude_decrease_per_tension, vibration_amplitude_min_factor)
	var raw_amplitude: float = vibration_amplitude * factor
	var visual_cap: float = bounce_thickness * vibration_max_amplitude_ratio
	return min(raw_amplitude, visual_cap)

## STABILER (strukturell/physischer) Punkt auf der Kurve in GLOBALEN
## Koordinaten - reiner Durchhang, OHNE Vibration. Das ist die "physische
## Wahrheit" der Saite: wird fuer SolidBlock, BounceArea-Erkennungszone und
## den Bounce-Crossing-Test verwendet. Aendert sich NUR, wenn sich
## _display_sag aendert (Spannungswechsel) - NICHT waehrend der Vibration.
func _curve_point_global(t: float) -> Vector2:
	var base: Vector2 = anchor_left.global_position.lerp(anchor_right.global_position, t)
	base.y += _display_sag * _sag_shape(t)
	return base

## Wie _curve_point_global(), aber zusaetzlich MIT der abklingenden
## Nachschwing-Vibration addiert. Ausschliesslich fuer die sichtbare
## Line2D gedacht - hat absichtlich keinerlei Einfluss auf Kollision oder
## Bounce-Erkennung.
func _curve_visual_point_global(t: float) -> Vector2:
	var base: Vector2 = _curve_point_global(t)
	if _vibration_time >= 0.0:
		var amp: float = _effective_vibration_amplitude() * exp(-vibration_decay * _vibration_time)
		var freq: float = _effective_vibration_frequency()
		base.y += amp * _vibration_envelope(t) * sin(_vibration_time * freq * TAU)
	return base

## Berechnet den Kurven-Anteil t (0..1 entlang AnchorLeft->AnchorRight) fuer
## eine gegebene globale Position, OHNE ihn auf 0..1 zu begrenzen. Wird
## sowohl fuer den Bounce-Crossing-Test (Grenzen-Pruefung) als auch fuer die
## Vibrationszentrierung genutzt (dort danach geklemmt).
func _raw_t(global_pos: Vector2) -> float:
	var from: Vector2 = anchor_left.global_position
	var to: Vector2 = anchor_right.global_position
	var dir: Vector2 = to - from
	var length: float = dir.length()
	if length <= 0.0:
		return 0.5
	return (global_pos - from).dot(dir / length) / length

## Startet die abklingende Nachschwing-Vibration, zentriert um impact_t
## (0..1 entlang der Saite). Betrifft NUR die Line2D-Optik - keine
## Kollision wird dadurch neu gebaut.
func _start_vibration(impact_t: float = 0.5) -> void:
	_vibration_center_t = clamp(impact_t, vibration_edge_margin, 1.0 - vibration_edge_margin)
	_vibration_time = 0.0

## Waehrend der Vibration wird HIER NUR die sichtbare Line2D aktualisiert -
## bewusst NICHT die Kollisions-Polygone. Das verhindert, dass
## BounceArea/SolidBlock waehrend der Vibration unnoetig staendig neu
## gebacken werden.
func _process(delta: float) -> void:
	if _vibration_time >= 0.0:
		_vibration_time += delta
		var amp: float = _effective_vibration_amplitude() * exp(-vibration_decay * _vibration_time)
		if amp < 0.5:
			_vibration_time = -1.0
		_rebuild_line_visual()

## Prueft jeden Physik-Frame ALLE aktuell getrackten Koerper darauf, ob sie
## zwischen letztem und jetzigem Frame die (stabile, nicht-vibrierende)
## Kurve von oben nach unten durchquert haben (siehe Klassenkommentar oben
## zu BOUNCE-ERKENNUNG).
func _physics_process(_delta: float) -> void:
	for body in _tracked_bodies_last_y.keys():
		if not is_instance_valid(body):
			_tracked_bodies_last_y.erase(body)
			continue
		_check_crossing(body)

## Vergleicht die Y-Position des Koerpers vom letzten Frame mit der
## jetzigen gegen die tatsaechliche (stabile) Kurvenhoehe an seiner
## X-Position. Ein Bounce wird ausgeloest, wenn er dabei von OBEN nach UNTEN
## durch die Kurve "gesprungen" ist - unabhaengig davon, wie gross der
## Sprung zwischen den Frames war, und unabhaengig von der rein optischen
## Vibration.
func _check_crossing(body: CharacterBody2D) -> void:
	var last_y: float = _tracked_bodies_last_y[body]
	var current_pos: Vector2 = body.global_position
	var current_y: float = current_pos.y

	var raw_t: float = _raw_t(current_pos)
	var anchor_length: float = (anchor_right.global_position - anchor_left.global_position).length()
	var margin_t: float = (detection_horizontal_margin / anchor_length) if anchor_length > 0.0 else 0.0

	# Position IMMER fuer den naechsten Frame merken, auch wenn's diesmal
	# nicht zum Bounce kommt.
	_tracked_bodies_last_y[body] = current_y

	if raw_t < -margin_t or raw_t > 1.0 + margin_t:
		return  # Seitlich zu weit ausserhalb der Saite - kein Bounce-Kandidat.

	var t: float = clamp(raw_t, 0.0, 1.0)
	var curve_y: float = _curve_point_global(t).y  # stabil, ohne Vibration

	if last_y <= curve_y and current_y >= curve_y:
		_do_bounce(body, t)

func _bounce_strength() -> float:
	return bounce_velocity_base + tension_level * bounce_velocity_per_tension

func _do_bounce(body: CharacterBody2D, impact_t: float) -> void:
	body.velocity.y = -_bounce_strength()
	_start_vibration(impact_t)

## Legt einen neu in die (grosszuegige) Erkennungszone eintretenden Koerper
## zum Tracking an, mit seiner aktuellen Y-Position als Startwert fuer den
## naechsten Crossing-Vergleich.
func _on_bounce_area_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return
	_tracked_bodies_last_y[body] = body.global_position.y

## Aufraeumen, sobald ein Koerper die Erkennungszone wieder komplett
## verlaesst - verhindert, dass das Dictionary unbegrenzt waechst.
func _on_bounce_area_body_exited(body: Node2D) -> void:
	_tracked_bodies_last_y.erase(body)

## Baut NUR die sichtbare Line2D neu auf, mit der VISUELLEN (vibrierenden)
## Kurve. Wird jeden Frame waehrend der Vibration aufgerufen - beruehrt
## keinerlei Kollisions-Polygone.
func _rebuild_line_visual() -> void:
	string_line.clear_points()
	for i in range(line_segments + 1):
		var t: float = float(i) / float(line_segments)
		var p_visual_global: Vector2 = _curve_visual_point_global(t)
		string_line.add_point(string_line.to_local(p_visual_global))

## Baut die Kollisions-Polygone (BounceArea-Erkennungszone + SolidBlock)
## anhand der STABILEN (nicht-vibrierenden) Kurve neu. Wird NUR aufgerufen,
## wenn sich die stabile Kurve tatsaechlich aendert (initial in _ready und
## bei Spannungsaenderung in _set_display_sag) - explizit NICHT jeden
## Vibrations-Frame, um staendiges Neu-Backen der Collision Shapes (und
## dadurch ausgeloeste body_exited/entered-Signale) zu vermeiden.
func _rebuild_collision() -> void:
	var top_points: Array[Vector2] = []
	var bottom_points: Array[Vector2] = []
	var block_top_points: Array[Vector2] = []
	var block_bottom_points: Array[Vector2] = []
	for i in range(line_segments + 1):
		var t: float = float(i) / float(line_segments)
		var p_stable_global: Vector2 = _curve_point_global(t)
		top_points.append(bounce_collision.to_local(p_stable_global + Vector2(0.0, -detection_margin)))
		bottom_points.append(bounce_collision.to_local(p_stable_global + Vector2(0.0, detection_margin)))
		block_top_points.append(solid_block_collision.to_local(p_stable_global + Vector2(0.0, bounce_thickness)))
		block_bottom_points.append(solid_block_collision.to_local(p_stable_global + Vector2(0.0, solid_block_depth)))
	var bounce_bottom: Array[Vector2] = bottom_points.duplicate()
	bounce_bottom.reverse()
	bounce_collision.polygon = PackedVector2Array(top_points + bounce_bottom)
	block_bottom_points.reverse()
	solid_block_collision.polygon = PackedVector2Array(block_top_points + block_bottom_points)

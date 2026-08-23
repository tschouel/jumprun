extends Node2D
class_name MusicString
## Eine durchhaengende Saite (wie eine Geigensaite), die der Spieler am
## Stimmschluessel-Ende bis zu 4x nachspannen kann (Taste E, ueber
## TensionTrigger.gd). Je hoeher die Spannung, desto weniger haengt die
## Saite durch UND desto staerker federt sie, wenn der Spieler reinfaellt.
## Ein 5. Versuch, obwohl schon voll gespannt (max_tension erreicht), laesst
## die Saite reissen - danach federt sie nicht mehr und laesst sich nicht
## mehr spannen.
##
## SETUP:
## 1. AnchorLeft und AnchorRight (Marker2D) im Editor auf die zwei
##    Befestigungspunkte der Saite ziehen (gleiche Hoehe oder leicht
##    unterschiedlich, beides geht). AnchorRight = Seite mit dem Stimmschluessel.
## 2. StringLine (Line2D) irgendwo als Kind anlegen, als Scene Unique Name
##    markieren (%). Breite/Farbe/Textur im Line2D-Inspector wie gewuenscht
##    einstellen - der Code setzt nur die "points".
## 3. TuningPeg = euer bereits animierter Stimmschluessel-Sprite
##    (AnimatedSprite2D), als Kind, als Scene Unique Name markieren. Die
##    Animation, die einmal komplett durchlaeuft (eine Umdrehung), muss im
##    SpriteFrames-Panel "Loop" AUSGESCHALTET haben - sonst feuert das
##    "animation_finished"-Signal nie und die Spannung wuerde nie erhoeht.
##    Den Namen der Animation unten bei "Tuning Peg Animation" eintragen,
##    falls er nicht "turn" heisst.
## 4. BounceArea (Area2D) als Kind anlegen, CollisionPolygon2D als dessen
##    Kind, beide als Scene Unique Name markieren. Die Polygon-Punkte werden
##    automatisch vom Skript gesetzt, im Editor braucht ihr da nichts
##    einzuzeichnen.
## 5. TensionTrigger (Area2D + CollisionShape2D) irgendwo beim Stimmschluessel
##    platzieren, TensionTrigger.gd draufziehen, "String Node" im Inspector
##    auf diesen MusicString-Node zeigen lassen (siehe TensionTrigger.gd).
## 6. OPTIONAL, fuer die "Seil reisst"-Optik: StringLineRight (ein weiteres
##    Line2D-Kind) anlegen, als Scene Unique Name markieren, Breite/Farbe wie
##    StringLine einstellen, Sichtbarkeit (Visible) im Editor erstmal AUS
##    lassen - wird nur beim Reissen eingeblendet. Die Saite loest sich am
##    AnchorLeft und baumelt danach nur noch vom Stimmschluessel-Ende
##    (AnchorRight) nach unten - genau wie eine echte Saite, die sich nur am
##    losen Ende aus der Halterung reisst. Ohne diesen Node funktioniert das
##    Reissen trotzdem (Saite verschwindet einfach), nur ohne das
##    herabhaengende Ende.
## 7. SolidBlock (StaticBody2D) als Kind anlegen, CollisionPolygon2D als
##    dessen Kind, beide als Scene Unique Name markieren. Das ist die feste
##    Sperre UNTER der Bounce-Zone, die verhindert, dass der Spieler jemals
##    unter die durchhaengende Saite gelangt - die Polygon-Punkte werden
##    genau wie bei BounceArea automatisch vom Skript gesetzt.

signal tension_changed(new_level: int)
signal string_broke

@export_group("Spannung")
@export var max_tension: int = 4
@export var start_tension: int = 0
## Wie lange das sichtbare Nachspannen (Durchhang-Aenderung) dauert.
@export var tension_animation_duration: float = 0.5

@export_group("Durchhang (Line2D-Kurve)")
## Wie stark die Saite bei Spannung 0 durchhaengt (in Pixeln).
@export var max_sag: float = 70.0
## Wie stark sie bei voller Spannung (max_tension) noch minimal durchhaengt.
## Nie ganz 0 setzen, sonst wirkt die Saite unnatuerlich kerzengerade.
@export var min_sag: float = 8.0
## Aufloesung der Kurve - mehr Punkte = glatter, aber etwas teurer.
@export var line_segments: int = 24
## "Dicke" der Bounce-Zone um die Kurve herum (Kollisions-Toleranz).
@export var bounce_thickness: float = 24.0
## Wie weit der feste Sperr-Block UNTER der Bounce-Zone nach unten reicht -
## muss nur gross genug sein, dass der Spieler ihn nie "von unten umgehen"
## kann (z.B. tiefer als jeder erreichbare Punkt im Level darunter).
@export var solid_block_depth: float = 1200.0

@export_group("Federkraft")
## Sprungkraft bei Spannung 0 (schwaechster Bounce).
@export var bounce_velocity_base: float = 500.0
## Zusaetzliche Sprungkraft PRO Spannungsstufe.
@export var bounce_velocity_per_tension: float = 250.0

@export_group("Vibration bei Bounce")
## Wie stark die Saite direkt nach dem Abfedern sichtbar nachschwingt.
@export var vibration_amplitude: float = 18.0
## Schwingungen pro Sekunde.
@export var vibration_frequency: float = 6.0
## Wie schnell die Vibration abklingt - hoeher = schneller ruhig.
@export var vibration_decay: float = 5.0

@export_group("Stimmschluessel")
## Name der Animation im SpriteFrames-Panel von TuningPeg, die eine
## Umdrehung zeigt. Muss "Loop" AUSGESCHALTET haben.
@export var tuning_peg_animation: String = "turn"

@export_group("Bruch - Baumelndes Seilende (Seil-Physik)")
## Wie viele Segmente das baumelnde Seilstueck hat - mehr = weicher/
## glatter, aber etwas teurer. Die Gesamtlaenge ergibt sich automatisch
## aus der tatsaechlichen Kurvenlaenge im Moment des Reissens.
@export var break_rope_segments: int = 14
## Fallbeschleunigung des losen Endes (px/s^2) - hoehere Werte lassen es
## schneller/schwerer nach unten fallen.
@export var break_gravity: float = 1400.0
## Geschwindigkeits-Erhaltung pro Simulationsschritt (0-1). Naeher an 1 =
## schwingt spuerbar laenger nach, wie ein leichtes Seil; kleinere Werte
## beruhigen sich schneller.
@export var break_damping: float = 0.985
## Wie stark das lose Ende beim Reissen zur Seite ausschlaegt (Peitschen-
## Effekt durch die ploetzlich freiwerdende Spannung).
@export var break_snap_strength: float = 60.0
## Zeitraffer fuer die gesamte Baumel-Simulation: 1.0 = normal, 2.0 = doppelt
## so schnell/kurz (Fall UND Nachschwingen), 0.5 = halb so schnell. Aendert
## nur das Tempo, nicht das Aussehen der Bewegung.
@export var break_time_scale: float = 1.0

@onready var anchor_left: Marker2D = $AnchorLeft
@onready var anchor_right: Marker2D = $AnchorRight
@onready var string_line: Line2D = %StringLine
@onready var bounce_area: Area2D = %BounceArea
@onready var bounce_collision: CollisionPolygon2D = %BounceArea/CollisionPolygon2D
@onready var solid_block: StaticBody2D = %SolidBlock
@onready var solid_block_collision: CollisionPolygon2D = %SolidBlock/CollisionPolygon2D
@onready var tuning_peg: AnimatedSprite2D = %TuningPeg
# Optional - siehe Setup-Punkt 6 oben. Bleiben null, falls nicht angelegt.
@onready var string_line_left: Line2D = get_node_or_null("%StringLineLeft")
@onready var string_line_right: Line2D = get_node_or_null("%StringLineRight")

enum PendingAction { NONE, TENSION, BREAK }

var tension_level: int = 0
var is_broken: bool = false
var _is_turning: bool = false
var _pending_action: PendingAction = PendingAction.NONE
var _display_sag: float = 0.0
var _sag_tween: Tween
var _vibration_time: float = -1.0  # -1 = keine Vibration aktiv
var _rope_points: PackedVector2Array = PackedVector2Array()       # simulierte Punkte des losen Endes
var _rope_prev_points: PackedVector2Array = PackedVector2Array()  # Positionen vom letzten Schritt (fuer Verlet-Integration)
var _rope_segment_length: float = 0.0
var _rope_active: bool = false  # true, solange die Seil-Simulation noch laeuft (pausiert sich selbst, sobald sie zur Ruhe kommt)

func _ready() -> void:
	tension_level = clampi(start_tension, 0, max_tension)
	_display_sag = _target_sag()
	_rebuild_visual_and_collision()
	bounce_area.body_entered.connect(_on_bounce_area_body_entered)
	tuning_peg.animation_finished.connect(_on_tuning_peg_animation_finished)
	if string_line_left:
		string_line_left.visible = false
	if string_line_right:
		string_line_right.visible = false

## Von TensionTrigger.gd aufgerufen, wenn der Spieler am Stimmschluessel E
## drueckt. Startet NUR die Dreh-Animation - die eigentliche Aenderung
## (Nachspannen ODER Reissen, falls schon voll gespannt) passiert erst, wenn
## die Animation fertig durchgelaufen ist (siehe
## _on_tuning_peg_animation_finished). Gibt true zurueck, wenn die Animation
## tatsaechlich gestartet wurde (fuer Sound/Feedback am Trigger).
func request_tension_increase() -> bool:
	if is_broken:
		return false
	if _is_turning:
		return false  # Verhindert Spammen/Ueberschneiden waehrend die Animation laeuft
	_is_turning = true
	if tension_level >= max_tension:
		# Schon voll gespannt - dieser Versuch ueberdreht sie und sie reisst.
		_pending_action = PendingAction.BREAK
	else:
		_pending_action = PendingAction.TENSION
	tuning_peg.play(tuning_peg_animation)
	return true

func _on_tuning_peg_animation_finished() -> void:
	# Falls TuningPeg noch andere Animationen abspielt (z.B. eine Idle-
	# Animation mit Loop aus), hier sicherheitshalber filtern:
	if tuning_peg.animation != tuning_peg_animation:
		return
	_is_turning = false
	var action: PendingAction = _pending_action
	_pending_action = PendingAction.NONE
	if action == PendingAction.BREAK:
		_break_string()
	elif action == PendingAction.TENSION:
		tension_level = clampi(tension_level + 1, 0, max_tension)
		tension_changed.emit(tension_level)
		_animate_sag_to(_target_sag())

func _target_sag() -> float:
	var t: float = float(tension_level) / float(max_tension)
	return lerp(max_sag, min_sag, t)

## Kurvenform: parabelfoermiger Durchhang, 0 an beiden Enden, Maximum in der Mitte.
## (Optisch fast nicht von einer echten Kettenlinie/Catenary zu unterscheiden,
## aber viel einfacher zu berechnen.)
func _sag_shape(t: float) -> float:
	return 4.0 * t * (1.0 - t)

## Aktueller Punkt auf der Kurve, inklusive Durchhang UND (falls gerade aktiv)
## der abklingenden Nachschwing-Vibration. Wird von der Line2D-Optik UND
## beiden Kollisionsformen (BounceArea, SolidBlock) gemeinsam genutzt, damit
## alles immer exakt zur sichtbaren Kurve passt.
func _curve_point(t: float) -> Vector2:
	var base: Vector2 = anchor_left.position.lerp(anchor_right.position, t)
	base.y += _display_sag * _sag_shape(t)
	if _vibration_time >= 0.0:
		var amp: float = vibration_amplitude * exp(-vibration_decay * _vibration_time)
		# sin(t*PI): 0 an beiden Ankern, Bauch in der Mitte (stehende Welle).
		base.y += amp * sin(t * PI) * sin(_vibration_time * vibration_frequency * TAU)
	return base

## Startet die abklingende Nachschwing-Vibration (z.B. direkt nach einem Bounce).
func _start_vibration() -> void:
	_vibration_time = 0.0

func _process(delta: float) -> void:
	if _vibration_time >= 0.0:
		_vibration_time += delta
		var amp: float = vibration_amplitude * exp(-vibration_decay * _vibration_time)
		if amp < 0.5:
			_vibration_time = -1.0  # Vibration beendet
		_rebuild_visual_and_collision()
	if _rope_active:
		_step_rope_simulation(delta)

## Animiert _display_sag fliessend von seinem aktuellen Wert zum Zielwert,
## und zeichnet die Kurve+Kollision bei jedem Zwischenschritt neu - dadurch
## wirkt das Nachspannen wie ein weiches Straffziehen statt eines harten Sprungs.
func _animate_sag_to(target_sag: float, duration: float = tension_animation_duration) -> void:
	if _sag_tween and _sag_tween.is_valid():
		_sag_tween.kill()
	_sag_tween = create_tween()
	_sag_tween.tween_method(_set_display_sag, _display_sag, target_sag, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _set_display_sag(value: float) -> void:
	_display_sag = value
	_rebuild_visual_and_collision()

func _rebuild_visual_and_collision() -> void:
	var top_points: Array[Vector2] = []
	var bottom_points: Array[Vector2] = []
	var block_bottom_points: Array[Vector2] = []
	string_line.clear_points()
	for i in range(line_segments + 1):
		var t: float = float(i) / float(line_segments)
		var p: Vector2 = _curve_point(t)
		string_line.add_point(p)
		top_points.append(p + Vector2(0.0, -bounce_thickness))
		bottom_points.append(p + Vector2(0.0, bounce_thickness))
		block_bottom_points.append(p + Vector2(0.0, solid_block_depth))
	var bounce_bottom: Array[Vector2] = bottom_points.duplicate()
	bounce_bottom.reverse()
	bounce_collision.polygon = PackedVector2Array(top_points + bounce_bottom)

	# SolidBlock: gleiche Kurve als Oberkante (auf Hoehe der Bounce-Zone-
	# Unterkante), reicht aber viel weiter nach unten - das verhindert, dass
	# der Spieler jemals unter die durchhaengende Saite gelangen kann.
	block_bottom_points.reverse()
	solid_block_collision.polygon = PackedVector2Array(bottom_points + block_bottom_points)

func _bounce_strength() -> float:
	return bounce_velocity_base + tension_level * bounce_velocity_per_tension

func _on_bounce_area_body_entered(body: Node2D) -> void:
	if is_broken:
		return
	if not (body is CharacterBody2D):
		return
	# Nur federn, wenn der Spieler tatsaechlich FAELLT (nicht wenn er von
	# unten reinspringt oder seitlich reinlaeuft) - sonst wuerde die Saite
	# auch bei jeder seitlichen Beruehrung katapultieren.
	if body.velocity.y > 0.0:
		body.velocity.y = -_bounce_strength()
		_start_vibration()

## Laesst die Saite reissen: Feder-Funktion und weiteres Spannen werden
## deaktiviert, die Kurve verschwindet, und (falls angelegt) baumelt
## StringLineRight als einzelnes loses Ende vom Stimmschluessel (AnchorRight)
## nach unten - die Saite loest sich also nur am AnchorLeft, genau wie eine
## echte Saite, die aus ihrer Halterung reisst. Das lose Ende wird als
## kleine Verlet-Seilsimulation animiert (siehe _step_rope_simulation) statt
## als starre, parametrisch gebogene Form - dadurch faellt/schwingt es wie
## ein echtes, biegsames Seilstueck statt wie ein steifer Bogen.
func _break_string() -> void:
	if is_broken:
		return
	is_broken = true
	bounce_area.monitoring = false
	bounce_collision.set_deferred("disabled", true)
	solid_block_collision.set_deferred("disabled", true)
	string_broke.emit()

	string_line.visible = false
	if string_line_left:
		string_line_left.visible = false

	if string_line_right:
		string_line_right.visible = true
		_start_rope_simulation()

## Initialisiert die Verlet-Seilsimulation fuer das lose Ende: uebernimmt
## die tatsaechliche Kurvenform (inkl. aktuellem Durchhang/Vibration) im
## Moment des Reissens als Startform, leitet die feste Segmentlaenge aus
## deren echter Kurvenlaenge ab (das Seil streckt/schrumpft also nicht
## ploetzlich), und gibt der losen Spitze einen initialen "Peitschen"-Schwung.
func _start_rope_simulation() -> void:
	var point_count: int = break_rope_segments + 1
	var last: int = break_rope_segments
	_rope_points = PackedVector2Array()
	_rope_prev_points = PackedVector2Array()
	_rope_points.resize(point_count)
	_rope_prev_points.resize(point_count)

	for i in range(point_count):
		var t: float = float(i) / float(break_rope_segments)
		_rope_points[i] = _curve_point(t)  # Index 0 = loses Ende (ehem. AnchorLeft), Index "last" = AnchorRight (fix)

	var total_length: float = 0.0
	for i in range(last):
		total_length += _rope_points[i].distance_to(_rope_points[i + 1])
	_rope_segment_length = total_length / float(last)

	# Peitschen-Effekt: initiale Geschwindigkeit (ueber die Verlet-"Vorher"-
	# Position simuliert), staerker an der losen Spitze, klingt Richtung
	# des fixen Stimmschluessel-Endes auf 0 ab.
	var snap_dir: Vector2 = Vector2(1.0, -0.4).normalized()
	if anchor_left.position.x > anchor_right.position.x:
		snap_dir.x = -snap_dir.x
	for i in range(point_count):
		var t_from_tip: float = 1.0 - float(i) / float(last)
		var kick: Vector2 = snap_dir * break_snap_strength * t_from_tip
		_rope_prev_points[i] = _rope_points[i] - kick

	_rope_active = true
	_apply_rope_constraints()
	string_line_right.points = _rope_points

## Ein Simulationsschritt Verlet-Integration: jeder freie Punkt bekommt
## Schwerkraft + eine gedaempfte Fortsetzung seiner letzten Bewegung
## (= Geschwindigkeit), danach werden die Abstaende zu den Nachbarpunkten
## ueber mehrere Iterationen wieder auf die feste Segmentlaenge gezwungen
## (_apply_rope_constraints). Das ist derselbe Grundansatz wie bei Seil-/
## Ketten-Physik in vielen Spielen: kein starrer Koerper, der als Ganzes
## rotiert, sondern echte, sich gegenseitig ziehende Glieder - dadurch
## laufen Wellen/Verzoegerungen entlang des Seils statt einer einheitlichen
## Starr-Drehung. Der letzte Punkt bleibt jeden Schritt am Stimmschluessel
## (AnchorRight) fixiert.
func _step_rope_simulation(delta: float) -> void:
	# break_time_scale steckt hier: ein groesserer effektiver Zeitschritt laesst
	# die GESAMTE Simulation (Fall + Nachschwingen) schneller/kuerzer ablaufen,
	# ohne wie/warum sie sich bewegt zu veraendern - reines Zeitraffer.
	var sim_delta: float = delta * break_time_scale
	var last: int = _rope_points.size() - 1
	var max_speed: float = 0.0
	for i in range(_rope_points.size()):
		if i == last:
			_rope_points[i] = anchor_right.position
			_rope_prev_points[i] = anchor_right.position
			continue
		var current: Vector2 = _rope_points[i]
		var velocity: Vector2 = (current - _rope_prev_points[i]) * break_damping
		var next: Vector2 = current + velocity + Vector2(0.0, break_gravity) * sim_delta * sim_delta
		_rope_prev_points[i] = current
		_rope_points[i] = next
		max_speed = max(max_speed, velocity.length())

	_apply_rope_constraints()
	string_line_right.points = _rope_points

	if max_speed < 0.3:
		_rope_active = false  # zur Ruhe gekommen - Simulation pausiert sich selbst (spart Leistung)

## Zieht alle benachbarten Punktpaare wieder auf _rope_segment_length
## zusammen (mehrere Iterationen fuer ein stabileres, weniger "gummiges"
## Ergebnis). Der letzte Punkt (Stimmschluessel-Ende) wird dabei nie bewegt.
func _apply_rope_constraints() -> void:
	var last: int = _rope_points.size() - 1
	for _iteration in range(8):
		for i in range(last):
			var p1: Vector2 = _rope_points[i]
			var p2: Vector2 = _rope_points[i + 1]
			var delta_vec: Vector2 = p2 - p1
			var dist: float = delta_vec.length()
			if dist < 0.0001:
				continue
			var diff: float = (dist - _rope_segment_length) / dist
			var correction: Vector2 = delta_vec * 0.5 * diff
			p1 += correction
			if i + 1 != last:
				p2 -= correction
			_rope_points[i] = p1
			_rope_points[i + 1] = p2

@tool
class_name SlidingObstacleSequencer
extends Node2D

## @tool (wichtig): dadurch werden die Hindernisse auch direkt im Editor
## gespawnt und positioniert - nicht erst beim Spielstart. So kannst du den
## Aufbau eines Levels direkt an den musikalischen Timings (steps) ausrichten
## und siehst sofort im 2D-Viewport, wo jedes Hindernis tatsaechlich landet.
##
## WICHTIG: SlidingObstacleStep.gd (die Resource-Klasse fuer die Elemente in
## steps) MUSS ebenfalls @tool sein! Ohne das laedt Godot sie im Editor nur
## als Platzhalter-Instanz (Felder sichtbar, aber keine Methoden aufrufbar)
## - jeder Aufruf von step.get_duration_seconds() wuerde dann sofort mit
## "Attempt to call a method on a placeholder instance" abstuerzen, bevor
## ueberhaupt ein Hindernis gespawnt wird. Das war die eigentliche Ursache,
## falls hier mal wieder gar nichts im Editor erscheint.
##
## Die im Editor gespawnten Hindernis-Instanzen werden NICHT in die Szene
## eingebrannt (kein owner gesetzt) - dadurch tauchen sie im Scene-DOCK
## (links, die Baum-Ansicht) NICHT auf, obwohl sie wirklich im Baum stecken
## und ganz normal im 2D-VIEWPORT gerendert werden (Godots Scene-Dock zeigt
## nur Nodes mit gesetztem owner). Falls du also nach dem Spawnen nichts im
## Scene-Dock siehst: normal, einfach im Viewport zur Kurve hinschauen/
## reinzoomen. Beim Speichern der Szene werden sie nicht mitgespeichert und
## bei jeder relevanten Aenderung automatisch neu erzeugt. Ihre eigenen
## (nicht-@tool) Skripte laufen im Editor ganz normal NICHT - du siehst nur
## die reine Platzierung/Optik, keine Gameplay-Logik.
##
## MARKER-STEPS: jeder Step in steps hat sein eigenes step_type (siehe
## SlidingObstacleStep.gd) - OBSTACLE (Standard) spawnt wie gewohnt eine
## Szene, MARKER spawnt gar nichts und zeigt stattdessen NUR im Editor einen
## roten Streifen quer zur Kurve an dieser Stelle (siehe marker_color/
## marker_length/marker_width unten). Praktisch, um ein Musikstueck erstmal
## komplett timingmaessig durchzuplanen/-zumarkieren, bevor du fuer jede
## Stelle schon eine fertige Hindernis-Szene gebaut hast.

@export var path: Path2D:
	set(value):
		_disconnect_curve_signal()
		path = value
		_connect_curve_signal()
		_request_respawn()

@export var slide_speed: float = 400.0:
	set(value):
		slide_speed = value
		_request_respawn()

@export var steps: Array[SlidingObstacleStep] = []:
	set(value):
		_disconnect_step_signals()
		steps = value
		_connect_step_signals()
		_request_respawn()

## Verschiebt jedes gespawnte Hindernis senkrecht (im rechten Winkel) zur
## Kurve, statt es direkt AUF der Linie zu platzieren - negative Werte
## verschieben "nach oben" relativ zur Bewegungsrichtung, positive Werte
## "nach unten". Falls die Richtung falsch rum ist (Hindernis wandert nach
## unten statt oben), einfach das Vorzeichen umdrehen.
@export var perpendicular_offset: float = 0.0:
	set(value):
		perpendicular_offset = value
		_request_respawn()

## Manueller Refresh-Knopf: kurz anhaken und wieder aus (springt sofort
## selbst zurueck auf "aus") loest ein sofortiges Neuspawnen aus. Nuetzlich
## als Rueckfalloption, falls eine Aenderung mal nicht automatisch ein
## Neuspawnen ausloest.
@export var force_refresh: bool = false:
	set(value):
		force_refresh = false
		notify_property_list_changed()
		_request_respawn()

@export_group("Marker-Anzeige (nur Editor)")
## Farbe des Streifens fuer step_type = MARKER-Eintraege (siehe
## SlidingObstacleStep.gd). Wird NUR im Editor gezeichnet (_draw() prueft
## Engine.is_editor_hint()) - im fertigen Spiel unsichtbar, rein eine
## Level-Design-Hilfe.
@export var marker_color: Color = Color(1.0, 0.0, 0.0, 0.9)
## Laenge des Streifens quer zur Kurve, in Pixeln.
@export var marker_length: float = 80.0
@export var marker_width: float = 4.0

var _spawned: Array[Node2D] = []
var _marker_segments: Array[PackedVector2Array] = []


func _ready() -> void:
	if not path:
		path = get_parent() as Path2D
	_connect_curve_signal()
	_connect_step_signals()
	_spawn_obstacles()


func _connect_curve_signal() -> void:
	if path and path.curve and not path.curve.changed.is_connected(_on_curve_changed):
		path.curve.changed.connect(_on_curve_changed)


func _disconnect_curve_signal() -> void:
	if path and path.curve and path.curve.changed.is_connected(_on_curve_changed):
		path.curve.changed.disconnect(_on_curve_changed)


func _on_curve_changed() -> void:
	_request_respawn()


## Jeder SlidingObstacleStep ist selbst eine Resource - editierst du z.B.
## seinen Notenwert oder obstacle_scene direkt im aufgeklappten Inspector,
## feuert das sein eingebautes changed-Signal, worauf wir hier neu spawnen.
func _connect_step_signals() -> void:
	for step in steps:
		if step and not step.changed.is_connected(_on_step_changed):
			step.changed.connect(_on_step_changed)


func _disconnect_step_signals() -> void:
	for step in steps:
		if step and step.changed.is_connected(_on_step_changed):
			step.changed.disconnect(_on_step_changed)


func _on_step_changed() -> void:
	_request_respawn()


func _request_respawn() -> void:
	if not is_inside_tree():
		return
	_spawn_obstacles()


func _spawn_obstacles() -> void:
	if not is_inside_tree():
		return
	if not path or not path.curve:
		push_error("SlidingObstacleSequencer: path oder path.curve fehlt!")
		return

	for child in _spawned:
		if is_instance_valid(child):
			child.queue_free()
	_spawned.clear()
	_marker_segments.clear()

	var cumulative_distance: float = 0.0
	var curve_length: float = path.curve.get_baked_length()

	for step in steps:
		if not step:
			continue

		cumulative_distance += slide_speed * step.get_duration_seconds()

		# MARKER-Steps spawnen NICHTS (obstacle_scene wird komplett
		# ignoriert) - stattdessen wird nur ein Streifen fuer _draw()
		# vorbereitet (siehe SlidingObstacleStep.gd fuer den Sinn dahinter).
		if step.step_type == SlidingObstacleStep.StepType.MARKER:
			var marker_angle: float = _get_tangent_angle(cumulative_distance, curve_length)
			var marker_local_pos: Vector2 = path.curve.sample_baked(cumulative_distance, true)
			_add_marker_segment(marker_local_pos, marker_angle)
			continue

		if not step.obstacle_scene:
			continue

		var obstacle := step.obstacle_scene.instantiate() as Node2D
		if not obstacle:
			push_warning("SlidingObstacleSequencer: obstacle_scene ist kein Node2D")
			continue

		var tangent_angle: float = _get_tangent_angle(cumulative_distance, curve_length)
		var local_pos: Vector2 = path.curve.sample_baked(cumulative_distance, true)

		# Senkrecht zur Kurve verschieben (Tangente um 90 Grad gedreht),
		# damit das Hindernis optisch "ueber" statt "auf" der Linie sitzt -
		# funktioniert unabhaengig von der Neigung der Kurve an dieser Stelle.
		if perpendicular_offset != 0.0:
			var normal: Vector2 = Vector2.RIGHT.rotated(tangent_angle).rotated(-PI / 2.0)
			local_pos += normal * perpendicular_offset

		obstacle.position = local_pos
		obstacle.rotation = tangent_angle

		# invisible-Flag: nur das Zeichnen wird unterdrueckt (visible = false
		# auf dem Root-Node wirkt sich auf saemtliche Kind-Sprites/Animationen
		# aus) - die Collision/das Skript im Innern der Szene laeuft davon
		# vollkommen unbeeindruckt weiter, Godots Physik interessiert sich
		# nicht fuer visible. So kannst du dieses Hindernis rein als
		# unsichtbaren Kollisionskoerper hinter einem eigenen
		# AnimatedSprite2D einsetzen, ohne extra ein neues Skript zu bauen.
		if step.invisible:
			obstacle.visible = false

		# call_deferred statt direktem add_child(): beim Spielstart sind
		# alle Nodes der Szene gleichzeitig mitten im eigenen Aufbau - ruft
		# _ready() hier direkt add_child() auf path auf, kann das mit
		# "Parent node is busy setting up children" fehlschlagen. Deferred
		# wartet stattdessen bis path fertig eingerichtet ist, bevor das
		# Hindernis tatsaechlich eingehaengt wird - position/rotation/
		# visible sind zu dem Zeitpunkt schon gesetzt, das wirkt sich also
		# nicht auf sie aus.
		path.add_child.call_deferred(obstacle)
		_spawned.append(obstacle)

	queue_redraw()


## Berechnet einen Streifen (2 Punkte) quer zur Kurve an local_pos/angle,
## in GLOBALEN Koordinaten ueber path umgerechnet und dann in dieses Node's
## EIGENES lokales Koordinatensystem konvertiert (to_local) - funktioniert
## dadurch unabhaengig davon, ob dieser Sequencer-Node selbst exakt an
## Position (0,0) von path sitzt oder nicht. Wird nur zum Zeichnen benutzt
## (siehe _draw()), erzeugt keinerlei echten Node.
func _add_marker_segment(local_pos: Vector2, tangent_angle: float) -> void:
	var normal: Vector2 = Vector2.RIGHT.rotated(tangent_angle).rotated(-PI / 2.0)
	var global_center: Vector2 = path.to_global(local_pos)
	var half_length: float = marker_length * 0.5
	var p1: Vector2 = to_local(global_center + normal * half_length)
	var p2: Vector2 = to_local(global_center - normal * half_length)
	_marker_segments.append(PackedVector2Array([p1, p2]))


## Zeichnet die Marker-Streifen - AUSSCHLIESSLICH im Editor (Engine.
## is_editor_hint()), im fertigen Spiel passiert hier gar nichts. Wird durch
## queue_redraw() am Ende von _spawn_obstacles() ausgeloest, jedes Mal wenn
## sich steps/path/etc. aendern.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	for segment in _marker_segments:
		draw_line(segment[0], segment[1], marker_color, marker_width)


## Berechnet den Winkel der Kurve an einer Distanz, indem zwei nahe Punkte
## auf der Kurve abgetastet und deren Differenzvektor genutzt wird - analog
## zu dem, was PathFollow2D intern für seine eigene Rotation macht.
func _get_tangent_angle(distance: float, curve_length: float) -> float:
	var epsilon: float = 4.0
	var d1: float = clamp(distance - epsilon, 0.0, curve_length)
	var d2: float = clamp(distance + epsilon, 0.0, curve_length)
	var p1: Vector2 = path.curve.sample_baked(d1, true)
	var p2: Vector2 = path.curve.sample_baked(d2, true)
	return (p2 - p1).angle()

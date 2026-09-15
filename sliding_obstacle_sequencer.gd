class_name SlidingObstacleSequencer
extends Node2D

@export var path: Path2D
@export var slide_speed: float = 400.0
@export var steps: Array[SlidingObstacleStep] = []
## Verschiebt jedes gespawnte Hindernis senkrecht (im rechten Winkel) zur
## Kurve, statt es direkt AUF der Linie zu platzieren - negative Werte
## verschieben "nach oben" relativ zur Bewegungsrichtung, positive Werte
## "nach unten". Falls die Richtung falsch rum ist (Hindernis wandert nach
## unten statt oben), einfach das Vorzeichen umdrehen.
@export var perpendicular_offset: float = 0.0

var _spawned: Array[Node2D] = []


func _ready() -> void:
	if not path:
		path = get_parent() as Path2D
	call_deferred("_spawn_obstacles")


func _spawn_obstacles() -> void:
	if not path or not path.curve:
		push_error("SlidingObstacleSequencer: path oder path.curve fehlt!")
		return

	for child in _spawned:
		if is_instance_valid(child):
			child.queue_free()
	_spawned.clear()

	var cumulative_distance: float = 0.0
	var curve_length: float = path.curve.get_baked_length()

	for step in steps:
		if not step:
			continue

		cumulative_distance += slide_speed * step.get_duration_seconds()

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

		path.add_child(obstacle)
		obstacle.position = local_pos
		obstacle.rotation = tangent_angle
		_spawned.append(obstacle)


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

class_name SlidingPathWaveVisual
extends Node2D

@export var path: Path2D

@export_group("Vibration (um den Player herum)")
@export var amplitude: float = 6.0
@export var frequency: float = 45.0
@export var spatial_frequency: float = 0.08
@export var envelope_width: float = 140.0
## Wie SCHNELL die Vibration abklingt, nachdem der Spieler den Pfad
## verlassen hat (pro Sekunde). Kleiner = laenger sichtbares Nachklingen.
@export_range(0.1, 10.0, 0.1) var fade_decay: float = 1.5

@export_group("Optik")
@export var line_width: float = 3.0
@export var line_color: Color = Color.BLACK
@export var segments: int = 80
## Deaktiviere Antialiasing, wenn der Renderer einen 1px Halbpixel-Versatz erzeugt:
@export var antialiased: bool = false

var _player: CharacterBody2D = null
var _time: float = 0.0
var _fade_strength: float = 0.0
var _last_player_t: float = 0.5


func _ready() -> void:
	if not path:
		path = get_parent() as Path2D
	if path and path.curve:
		path.curve.changed.connect(queue_redraw)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if _is_player_on_this_path():
		_fade_strength = 1.0
	else:
		_fade_strength = max(_fade_strength - fade_decay * delta, 0.0)

	queue_redraw()


func _draw() -> void:
	if not path or not path.curve or path.curve.point_count < 2:
		return

	var total_length: float = path.curve.get_baked_length()
	if total_length <= 0.0:
		return

	# NEU: die Basislinie wird jetzt IMMER gezeichnet, unabhaengig von
	# _fade_strength. Vorher gab es hier "if _fade_strength <= 0.0: return",
	# wodurch die Linie komplett unsichtbar war, solange der Spieler nicht
	# auf dem Pfad ist. Die Vibration/Wave bleibt an _fade_strength > 0
	# gekoppelt, die Basislinie ist aber ab jetzt immer da.
	if _is_player_on_this_path():
		var player_pos_in_path: Vector2 = path.to_local(_player.global_position)
		var offset_along: float = path.curve.get_closest_offset(player_pos_in_path)
		_last_player_t = clamp(offset_along / total_length, 0.0, 1.0)

	var half_width_t: float = (envelope_width * 0.5) / total_length

	var points := PackedVector2Array()
	points.resize(segments + 1)

	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var current_dist: float = t * total_length
		# Punkt in Path2D-lokalen Koordinaten, dann explizit ueber
		# global_position in GLOBALE Koordinaten und zurueck in den lokalen
		# Zeichen-Raum DIESES Nodes umgerechnet - umgeht
		# draw_set_transform_matrix komplett, dadurch unempfindlich gegen
		# Transform-Diskrepanzen zwischen diesem Node und dem Path2D.
		var local_pt: Vector2 = path.curve.sample_baked(current_dist)
		var global_pt: Vector2 = path.to_global(local_pt)

		if _fade_strength > 0.0:
			var envelope: float = _vibration_envelope(t, _last_player_t, half_width_t)
			if envelope > 0.0:
				var eps: float = max(total_length * 0.001, 0.5)
				var d0: float = clamp(current_dist - eps, 0.0, total_length)
				var d1: float = clamp(current_dist + eps, 0.0, total_length)
				var global_tangent: Vector2 = path.to_global(path.curve.sample_baked(d1)) - path.to_global(path.curve.sample_baked(d0))
				var perpendicular: Vector2 = global_tangent.normalized().orthogonal() if global_tangent.length() > 0.0001 else Vector2.UP
				var wave: float = sin((current_dist * spatial_frequency) - (_time * frequency * TAU))
				global_pt += perpendicular * (amplitude * envelope * wave * _fade_strength)

		points[i] = to_local(global_pt)

	draw_polyline(points, line_color, line_width, antialiased)


func _is_player_on_this_path() -> bool:
	if not is_instance_valid(_player):
		return false
	if not ("is_on_path" in _player) or not _player.is_on_path:
		return false
	var parent_path_follow := _player.get_parent() as PathFollow2D
	if not parent_path_follow:
		return false
	return parent_path_follow.get_parent() == path


func _vibration_envelope(t: float, center_t: float, half_width_t: float) -> float:
	var d: float = abs(t - center_t)
	if half_width_t <= 0.0001 or d >= half_width_t:
		return 0.0
	return cos((d / half_width_t) * (PI * 0.5))

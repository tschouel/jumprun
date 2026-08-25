extends Node2D
class_name BubbleMachine

## Spawnt in unregelmäßigen Abständen Bubble-Instanzen an der Position des
## "Muendung"-Markers (Marker2D-Kind dieser Node), mit zufälliger Streuung
## in Position, Größe, Steig-Geschwindigkeit, Wobble und Richtung.

@export var bubble_scene: PackedScene = preload("res://bubble.tscn")

@export_group("Timing")
@export var spawn_interval_min: float = 0.35
@export var spawn_interval_max: float = 0.7
@export var autostart: bool = true

@export_group("Position & Richtung")
@export var spawn_position_jitter: float = 6.0
@export var direction: Vector2 = Vector2.UP
@export var direction_jitter_degrees: float = 12.0

@export_group("Blasen-Variation")
@export var radius_min: float = 6.0
@export var radius_max: float = 14.0
@export var rise_speed_min: float = 50.0
@export var rise_speed_max: float = 90.0
@export var wobble_amplitude_min: float = 10.0
@export var wobble_amplitude_max: float = 24.0
@export var wobble_frequency_min: float = 0.8
@export var wobble_frequency_max: float = 1.6

## Optional: Parent-Node, unter der die Blasen erzeugt werden sollen
## (z.B. damit sie nicht mitwandern, falls die Maschine sich bewegt/dreht).
## Leer lassen = aktuelle Szene wird verwendet.
@export var bubbles_parent_path: NodePath

var _time_to_next_spawn: float = 0.0
@onready var muendung: Node2D = $Muendung


func _ready() -> void:
	_reset_spawn_timer()
	set_process(autostart)


func _process(delta: float) -> void:
	_time_to_next_spawn -= delta
	if _time_to_next_spawn <= 0.0:
		spawn_bubble()
		_reset_spawn_timer()


func _reset_spawn_timer() -> void:
	_time_to_next_spawn = randf_range(spawn_interval_min, spawn_interval_max)


func spawn_bubble() -> void:
	var bubble = bubble_scene.instantiate()

	bubble.radius = randf_range(radius_min, radius_max)
	bubble.rise_speed = randf_range(rise_speed_min, rise_speed_max)
	bubble.wobble_amplitude = randf_range(wobble_amplitude_min, wobble_amplitude_max)
	bubble.wobble_frequency = randf_range(wobble_frequency_min, wobble_frequency_max)
	bubble.initial_direction = direction.rotated(deg_to_rad(randf_range(-direction_jitter_degrees, direction_jitter_degrees)))

	var target_parent: Node = get_node_or_null(bubbles_parent_path)
	if target_parent == null:
		target_parent = get_tree().current_scene
	target_parent.add_child(bubble)

	var jitter := Vector2(
		randf_range(-spawn_position_jitter, spawn_position_jitter),
		randf_range(-spawn_position_jitter, spawn_position_jitter)
	)
	bubble.launch(muendung.global_position + jitter)

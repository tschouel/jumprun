class_name Fader
extends Node2D

@export_group("Fader-Aufbau")
@export var start_point: Node2D
@export var end_point: Node2D
@export var handle: Node2D
@export var interaction_zone: Area2D

@export_group("Steuerung")
@export var toggle_key: Key = KEY_E
@export var left_action: String = "ui_left"
@export var right_action: String = "ui_right"

@export_group("Spieler-Kopplung")
@export var player: CharacterBody2D
@export var freeze_player_while_grabbing: bool = true

## Wird ausgelöst, sobald sich der Fader-Wert ändert. new_value liegt zwischen 0.0 und 1.0.
signal value_changed(new_value: float)

var value: float = 0.0:
	get:
		return value

var _is_grabbing: bool = false
var _player_in_zone: bool = false
var _total_distance: float = 1.0
var _ground_module: Node = null

func _ready() -> void:
	add_to_group("fader")
	_init_value_from_handle_position()

	if start_point and end_point:
		_total_distance = start_point.global_position.distance_to(end_point.global_position)
		if _total_distance <= 0.0:
			_total_distance = 1.0

	if player:
		_ground_module = player.get_node_or_null("GroundMovement")

	if interaction_zone:
		interaction_zone.body_entered.connect(func(b):
			if b.is_in_group("player"):
				_player_in_zone = true
		)
		interaction_zone.body_exited.connect(func(b):
			if b.is_in_group("player"):
				_player_in_zone = false
				_release_grab()
		)

## Öffentlicher Zugriff auf den aktuellen Wert (0.0 bis 1.0), z.B. für Musik-Skripte.
func get_value() -> float:
	return value

func _init_value_from_handle_position() -> void:
	if handle and start_point and end_point:
		var total: Vector2 = end_point.global_position - start_point.global_position
		var current: Vector2 = handle.global_position - start_point.global_position
		var length: float = total.length()
		if length > 0.0:
			value = clamp(current.dot(total.normalized()) / length, 0.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_zone:
		return
	if event is InputEventKey and event.physical_keycode == toggle_key:
		if event.pressed and not event.echo:
			_start_grab()
		elif not event.pressed:
			_release_grab()

func _start_grab() -> void:
	if _is_grabbing:
		return
	_is_grabbing = true
	if freeze_player_while_grabbing and player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO

func _release_grab() -> void:
	if not _is_grabbing:
		return
	_is_grabbing = false
	if freeze_player_while_grabbing and player:
		player.set_physics_process(true)

func _process(delta: float) -> void:
	if not _is_grabbing:
		return

	var input := Input.get_axis(left_action, right_action)
	if input == 0.0:
		return

	var speed: float = _ground_module.speed if _ground_module else 350.0
	var value_speed: float = speed / _total_distance

	var new_value: float = clamp(value + input * value_speed * delta, 0.0, 1.0)
	if is_equal_approx(new_value, value):
		return
	value = new_value
	_update_handle_position()
	value_changed.emit(value)

func _update_handle_position() -> void:
	if handle and start_point and end_point:
		handle.global_position = start_point.global_position.lerp(end_point.global_position, value)

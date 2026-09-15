class_name PathRampMovement
extends Node
## Steuert NUR die kurze "faellt und hat keine Hoehe"-Sequenz nach einem
## fehlgeschlagenen Ramp-Test (siehe RampTestSequencer.gd): der Spieler
## faellt fail_fall_duration Sekunden lang unter normaler Schwerkraft
## (ohne Lift), dann Fade to Black + Respawn ueber die Zone
## (zone.respawn_after_obstacle_hit()).
##
## Wird als eigener Node "PathRampMovement" (Geschwister von PathMovement/
## PathBassMovement) im Player eingehaengt.

var player: CharacterBody2D

enum State { INACTIVE, FALLING }
var _state: int = State.INACTIVE

var _zone: Node = null
var _velocity: Vector2 = Vector2.ZERO
var _fall_timer_remaining: float = 0.0

@export_group("Fall-Tuning")
## Multipliziert die normale Spieler-Schwerkraft NUR waehrend dieses
## Falls - unabhaengig von normalen Spruengen. 1.0 = normale Schwerkraft,
## 2.0 = doppelt so schnell fallend, usw.
@export var fall_gravity_multiplier: float = 1.0
## Zusaetzliche sofortige Abwaerts-Geschwindigkeit beim Start des Falls
## (in Einheiten/Sekunde). 0 = kein Extra-Schubs, faellt nur durch
## Schwerkraft an.
@export var initial_downward_boost: float = 0.0


func setup(p_player: CharacterBody2D) -> void:
	player = p_player
	if player:
		player.set_meta("path_ramp_movement_module", self)


## Wird von RampTestSequencer._trigger_fail() aufgerufen. zone muss
## get_previous_parent() (Rueckgabe: Node) und respawn_after_obstacle_hit()
## bereitstellen (siehe SlidingZone.gd).
func begin_fail_fall(zone: Node, p_player: CharacterBody2D, fall_duration: float, initial_velocity: Vector2) -> void:
	player = p_player
	_zone = zone
	_velocity = initial_velocity + Vector2(0.0, initial_downward_boost)
	_fall_timer_remaining = fall_duration

	# Spieler vom Pfad loesen, Weltposition beibehalten - analog zu
	# detach_from_path(), aber mit anschliessendem Fall statt normalem
	# Weiterlaufen.
	var end_transform: Transform2D = player.global_transform
	player.is_on_path = false

	var current_pf := player.get_parent() as PathFollow2D
	if current_pf and current_pf.is_ancestor_of(player):
		current_pf.remove_child(player)

	var target_parent: Node = null
	if zone.has_method("get_previous_parent"):
		target_parent = zone.get_previous_parent()
	if target_parent:
		target_parent.add_child(player)
		player.global_transform = end_transform

	player.keep_upright = true
	player.reset_physics_interpolation()
	player.is_ramp_launch_active = true
	_state = State.FALLING


func process_movement(delta: float) -> void:
	if _state != State.FALLING:
		return

	_velocity.y += player.gravity * fall_gravity_multiplier * delta
	player.global_position += _velocity * delta

	_fall_timer_remaining -= delta
	if _fall_timer_remaining <= 0.0:
		_trigger_respawn()


func _trigger_respawn() -> void:
	_state = State.INACTIVE
	player.is_ramp_launch_active = false
	if _zone and _zone.has_method("respawn_after_obstacle_hit"):
		_zone.respawn_after_obstacle_hit(player)
	_zone = null

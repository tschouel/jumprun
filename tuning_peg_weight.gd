class_name TuningPeg_weight
extends Node2D

## Stimmschluessel-Variante fuer ein Gewicht, das per Seil gehalten wird.
## Gleicher Engage-Ablauf wie bei TuningPeg: Spieler steht in
## interaction_zone, druecken engage_key (Standard F) "greift" den Peg
## (blockiert nur die Spielerbewegung, keine Armanimation). Danach dreht
## toggle_key (Standard E) den Peg ein Stueck weiter - jeder erfolgreiche
## Dreh-Tastendruck loest turn_animation_name aus, ausserdem die
## Handgreif-Animation (falls hand_grip gesetzt). Ist value schon bei 1.0
## angekommen (und das Seil wurde noch nicht ausgeloest), spielt stattdessen
## stuck_animation_name (reines Feedback, value aendert sich dabei nicht) -
## Handgreif-Animation laeuft trotzdem, wie beim echten Dreh-Versuch.
##
## Erreicht value den release_threshold, wird das Gewicht automatisch
## freigegeben (weight.freeze = false) - danach ist die Peg-Interaktion durch
## (kein Engage/Turn mehr moeglich). Das Seil-Visual verschwindet dabei nicht
## sofort, sondern rollt sich innerhalb von rope_unroll_duration vom
## Startpunkt ueber den Mittelpunkt zum Endpunkt ab (der sichtbare Rest folgt
## dabei weiter live rope_end_point, faellt das Gewicht also mit, "reisst"
## das Seil entsprechend mit).
##
## Setup: sprite (AnimatedSprite2D, mit turn_animation_name/
## stuck_animation_name als Kind anlegen), interaction_zone (Area2D +
## CollisionShape2D als Kind), optional hand_grip (Marker2D/Node2D am
## Griffpunkt), weight (RigidBody2D) sowie rope_start_point/rope_middle_point/
## rope_end_point/rope_line fuer das Seil-Visual - alles als Kinder dieser
## Szene. rope_middle_point ist ein einfacher Marker2D, mit dem sich der
## Seildurchhang von Hand positionieren laesst (die Linie verlaeuft als zwei
## gerade Stuecke start->middle->end). player wird pro Instanz im Inspector
## zugewiesen.

signal engaged
signal disengaged
signal value_changed(new_value: float)
signal weight_released

@export_group("Peg-Aufbau")
@export var sprite: AnimatedSprite2D
@export var interaction_zone: Area2D
@export var turn_animation_name: String = "turn"
@export var stuck_animation_name: String = "stuck"
@export_range(0.0, 1.0) var turn_step: float = 0.25

@export_group("Steuerung")
@export var engage_key: Key = KEY_F
@export var toggle_key: Key = KEY_E

@export_group("Spieler-Kopplung")
@export var player: CharacterBody2D
@export var freeze_player_while_engaged: bool = true

@export_group("Arm-Animation")
@export var hand_grip: Node2D

@export_group("Kamera")
@export var camera_offset_x: float = 0.0
@export var camera_offset_y: float = 0.0
@export var camera_zoom_enabled: bool = false
@export var camera_zoom_target: Vector2 = Vector2(0.6, 0.6)
@export var camera_transition_duration: float = 0.0
@export var camera_transition_curve: Curve

@export_group("Seil & Gewicht")
@export var weight: RigidBody2D
@export_range(0.0, 1.0) var release_threshold: float = 1.0

@export_group("Seil-Visual")
@export var rope_start_point: Node2D
@export var rope_middle_point: Node2D
@export var rope_end_point: Node2D
@export var rope_line: Line2D
@export var rope_segments: int = 16
@export var rope_unroll_duration: float = 0.6

var value: float = 0.0

var _player_in_zone: bool = false
var _is_engaged: bool = false
var _is_turning: bool = false
var _active_anim_name: String = ""
var _rope_released: bool = false
var _ground_movement: Node = null
var _unroll_tween: Tween

func _ready() -> void:
	if player:
		_ground_movement = player.get_node_or_null("GroundMovement")

	if interaction_zone:
		interaction_zone.body_entered.connect(_on_zone_body_entered)
		interaction_zone.body_exited.connect(_on_zone_body_exited)

	if weight:
		weight.freeze = true

	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)

	_update_rope_visual()

func _process(_delta: float) -> void:
	if not _rope_released:
		_update_rope_visual()

func is_at_max() -> bool:
	return value >= 1.0

## Liefert Start-/Mittel-/Endpunkt des Seils in lokalen Koordinaten von
## rope_line (und haengt rope_line dabei an rope_start_point an). Wird sowohl
## fuers normale Zeichnen als auch fuers Abroll-Feedback benutzt, damit beide
## immer denselben Verlauf ergeben.
func _get_rope_anchors() -> Array:
	rope_line.global_position = rope_start_point.global_position
	var start_local: Vector2 = Vector2.ZERO
	var end_local: Vector2 = rope_line.to_local(rope_end_point.global_position)
	var middle_local: Vector2
	if rope_middle_point:
		middle_local = rope_line.to_local(rope_middle_point.global_position)
	else:
		middle_local = start_local.lerp(end_local, 0.5)
	return [start_local, middle_local, end_local]

## Position auf dem Seilverlauf bei Parameter t (0 = Start, 0.5 = Mittelpunkt,
## 1 = Ende) - zwei gerade Stuecke start->middle und middle->end.
func _rope_point_at(t: float, start_local: Vector2, middle_local: Vector2, end_local: Vector2) -> Vector2:
	if t <= 0.5:
		return start_local.lerp(middle_local, t / 0.5)
	else:
		return middle_local.lerp(end_local, (t - 0.5) / 0.5)

func _update_rope_visual() -> void:
	if not (rope_line and rope_start_point and rope_end_point):
		return

	var anchors: Array = _get_rope_anchors()
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(rope_segments + 1):
		var t: float = float(i) / float(rope_segments)
		points.append(_rope_point_at(t, anchors[0], anchors[1], anchors[2]))

	rope_line.points = points

func _on_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = true

func _on_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = false
		if _is_engaged:
			_disengage()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_zone:
		return
	if _rope_released:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.physical_keycode == engage_key:
		if _is_engaged:
			_disengage()
		else:
			_engage()
		return

	if not _is_engaged:
		return

	if event.physical_keycode == toggle_key:
		_request_turn()

func _engage() -> void:
	_is_engaged = true
	engaged.emit()
	if freeze_player_while_engaged and player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	_apply_camera_offset(true)
	_apply_camera_zoom(true)

func _disengage() -> void:
	_is_engaged = false
	disengaged.emit()
	if freeze_player_while_engaged and player:
		player.set_physics_process(true)
	_apply_camera_offset(false)
	_apply_camera_zoom(false)

func _request_turn() -> void:
	if _is_turning:
		return
	var at_limit: bool = is_at_max()
	_is_turning = true
	_active_anim_name = stuck_animation_name if at_limit else turn_animation_name

	if hand_grip and player:
		var arm: Node = player.get_node_or_null("%SimpleArm")
		if arm and arm.has_method("reach_and_retract"):
			arm.reach_and_retract(hand_grip)

	if sprite:
		sprite.play(_active_anim_name)
	else:
		_on_animation_finished()

func _on_animation_finished() -> void:
	if sprite and sprite.animation != _active_anim_name:
		return
	_is_turning = false

	if _active_anim_name == stuck_animation_name:
		return

	value = clampf(value + turn_step, 0.0, 1.0)
	value_changed.emit(value)

	if not _rope_released and value >= release_threshold:
		_release_weight()

func _release_weight() -> void:
	_rope_released = true
	if _is_engaged:
		_disengage()
	if weight:
		weight.freeze = false
	weight_released.emit()
	_start_rope_unroll()

## Laesst das Seil-Visual statt einem harten "visible = false" innerhalb von
## rope_unroll_duration vom Start- zum Endpunkt hin abrollen/verschwinden.
## Der sichtbare Rest folgt dabei weiter live rope_end_point (haengt also am
## fallenden Gewicht, falls rope_end_point daran haengt).
func _start_rope_unroll() -> void:
	if not rope_line:
		return
	if rope_unroll_duration <= 0.0:
		rope_line.visible = false
		return
	if _unroll_tween:
		_unroll_tween.kill()
	_unroll_tween = create_tween()
	_unroll_tween.tween_method(_apply_rope_unroll, 0.0, 1.0, rope_unroll_duration)
	_unroll_tween.tween_callback(func() -> void: rope_line.visible = false)

func _apply_rope_unroll(progress: float) -> void:
	if not (rope_line and rope_start_point and rope_end_point):
		return

	var anchors: Array = _get_rope_anchors()
	var steps: int = maxi(1, int(round(rope_segments * (1.0 - progress))))
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = progress + (1.0 - progress) * (float(i) / float(steps))
		points.append(_rope_point_at(t, anchors[0], anchors[1], anchors[2]))

	rope_line.points = points

func _apply_camera_offset(activate: bool) -> void:
	if camera_offset_x == 0.0 and camera_offset_y == 0.0:
		return
	if not _ground_movement:
		return
	if activate:
		if _ground_movement.has_method("set_camera_offset_override"):
			_ground_movement.set_camera_offset_override(Vector2(camera_offset_x, camera_offset_y), camera_transition_duration, camera_transition_curve)
	else:
		if _ground_movement.has_method("clear_camera_offset_override"):
			_ground_movement.clear_camera_offset_override(camera_transition_duration, camera_transition_curve)

func _apply_camera_zoom(activate: bool) -> void:
	if not camera_zoom_enabled:
		return
	if not _ground_movement:
		return
	if activate:
		if _ground_movement.has_method("set_camera_zoom_override"):
			_ground_movement.set_camera_zoom_override(camera_zoom_target, camera_transition_duration, camera_transition_curve)
	else:
		if _ground_movement.has_method("clear_camera_zoom_override"):
			_ground_movement.clear_camera_zoom_override(camera_transition_duration, camera_transition_curve)

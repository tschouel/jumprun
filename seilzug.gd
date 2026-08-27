extends Node2D

@export_group("Steuerungstasten (Trigger)")
@export var right_trigger: Area2D   # Motor nach rechts (Magnet runter)
@export var left_trigger: Area2D    # Motor nach links (Magnet/Objekt hoch)
@export var pause_trigger: Area2D   # hält die Bewegung an, solange aktiv

@export_group("Seilzug")
@export var path: Path2D
@export var magnet: Node2D
@export var magnet_area: Area2D
@export var rope: Line2D
@export var anchor: Node2D
@export var motor_speed: float = 0.3  # Anteil des Wegs pro Sekunde (0..1)

@export_group("Objekt")
@export var object_to_lift: Node2D
@export var object_anim_player: AnimationPlayer
@export var object_anim_name: String = "open"

enum Active { NONE, RIGHT, LEFT, PAUSE }

var _attached := false
var _t := 0.0
var _path_length := 0.0
var _attach_offset := Vector2.ZERO
var _locked := false

func _ready() -> void:
	if magnet_area:
		magnet_area.area_entered.connect(_on_magnet_area_entered)
	if path and path.curve:
		_path_length = path.curve.get_baked_length()

	_update_magnet_position()
	_update_rope()

func _get_active_trigger() -> int:
	# Priorität bei Überschneidung: rechts > links > pause
	if right_trigger and _player_on(right_trigger):
		return Active.RIGHT
	if left_trigger and _player_on(left_trigger):
		return Active.LEFT
	if pause_trigger and _player_on(pause_trigger):
		return Active.PAUSE
	return Active.NONE

func _player_on(area: Area2D) -> bool:
	for body in area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false

func _process(delta: float) -> void:
	if _locked:
		return

	var active := _get_active_trigger()

	if active == Active.PAUSE or active == Active.NONE:
		return

	var input := 1.0 if active == Active.RIGHT else -1.0

	var was_t := _t
	_t = clamp(_t + input * motor_speed * delta, 0.0, 1.0)
	if _t == was_t:
		return

	_update_magnet_position()

	if _attached and object_to_lift:
		object_to_lift.global_position = magnet.global_position + _attach_offset
		if _t <= 0.0:
			_on_object_reached_top()

	_update_rope()

func _update_magnet_position() -> void:
	if path and path.curve and magnet:
		var offset := _t * _path_length
		magnet.global_position = path.to_global(path.curve.sample_baked(offset))

func _update_rope() -> void:
	if rope and anchor and magnet:
		rope.global_position = anchor.global_position
		rope.points = [Vector2.ZERO, rope.to_local(magnet.global_position)]

func _on_magnet_area_entered(area: Area2D) -> void:
	if _attached:
		return
	if not area.is_in_group("object_magnet"):
		return
	_attached = true
	if object_to_lift:
		_attach_offset = object_to_lift.global_position - magnet.global_position

func _on_object_reached_top() -> void:
	_locked = true
	if object_anim_player:
		object_anim_player.play(object_anim_name)

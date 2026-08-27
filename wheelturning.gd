extends Node2D

@export_group("Rädchen")
@export var visual: Node2D                  # das sich drehende Sprite/Rädchen (leer lassen = dreht sich selbst)
@export var rotation_speed: float = 90.0     # Grad pro Sekunde

@export_group("Fader-Bedingung")
@export var fader: Fader
@export_range(0.0, 1.0) var min_value: float = 0.0
@export_range(0.0, 1.0) var max_value: float = 1.0

@export_group("Trigger")
@export var clockwise_trigger: Area2D
@export var counter_clockwise_trigger: Area2D
@export var stop_trigger: Area2D

@export_group("Timing")
@export var pre_delay: float = 0.0

@export_group("Stop durch Animation")
@export var stop_anim_player: AnimationPlayer
@export var stop_animation_name: String = ""   # leer = jede abgeschlossene Animation stoppt

enum Direction { NONE = 0, CW = 1, CCW = -1 }

var _direction: int = Direction.NONE
var _delay_id: int = 0   # Generation-Counter, um veraltete verzögerte Starts zu verwerfen

func _ready() -> void:
	_connect_trigger(clockwise_trigger, func(): _request_direction(Direction.CW))
	_connect_trigger(counter_clockwise_trigger, func(): _request_direction(Direction.CCW))
	_connect_trigger(stop_trigger, func(): _stop_immediately())

	if stop_anim_player:
		stop_anim_player.animation_finished.connect(_on_stop_animation_finished)

func _connect_trigger(area: Area2D, callback: Callable) -> void:
	if not area:
		return
	area.body_entered.connect(func(b):
		if b.is_in_group("player"):
			callback.call()
	)

func _request_direction(dir: int) -> void:
	_delay_id += 1
	var this_id := _delay_id

	if pre_delay > 0.0:
		await get_tree().create_timer(pre_delay).timeout
		if this_id != _delay_id:
			return  # zwischenzeitlich wurde gestoppt oder neu getriggert -> verworfen

	_direction = dir

func _stop_immediately() -> void:
	_delay_id += 1  # invalidiert einen eventuell laufenden verzögerten Start
	_direction = Direction.NONE

func _on_stop_animation_finished(anim_name: String) -> void:
	if stop_animation_name == "" or anim_name == stop_animation_name:
		_stop_immediately()

func _process(delta: float) -> void:
	if _direction == Direction.NONE:
		return
	if not _fader_in_range():
		return

	var target: Node2D = visual if visual else self
	target.rotation_degrees += _direction * rotation_speed * delta

func _fader_in_range() -> bool:
	if not fader:
		return true
	return fader.value >= min_value and fader.value <= max_value

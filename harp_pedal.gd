extends Node2D

@export var step_size: float = 20.0
@export var min_station: int = 0
@export var max_station: int = 2
@export var start_station: int = 1
@export var move_duration: float = 0.15

@onready var body: AnimatableBody2D = $AnimatableBody2D
@onready var top_sensor: Area2D = $AnimatableBody2D/TopSensor
@onready var bottom_sensor: Area2D = $AnimatableBody2D/BottomSensor

var current_station: int
var base_position_y: float
var tween: Tween

func _ready() -> void:
	base_position_y = body.position.y
	current_station = start_station
	top_sensor.body_entered.connect(_on_top_sensor_body_entered)
	bottom_sensor.body_entered.connect(_on_bottom_sensor_body_entered)

func _on_top_sensor_body_entered(entered_body: Node2D) -> void:
	if not entered_body.is_in_group("player"):
		return
	move_station(-1)

func _on_bottom_sensor_body_entered(entered_body: Node2D) -> void:
	if not entered_body.is_in_group("player"):
		return
	move_station(1)

func move_station(delta: int) -> void:
	var target_station := clampi(current_station + delta, min_station, max_station)
	if target_station == current_station:
		return
	current_station = target_station
	var target_y := base_position_y - float(current_station - start_station) * step_size
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(body, "position:y", target_y, move_duration)

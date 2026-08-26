extends Area2D

signal sustain_changed(pressed: bool)

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var trigger: Area2D = %SustainPedalTrigger

var is_pressed: bool = false

func _ready() -> void:
	trigger.body_entered.connect(_on_trigger_body_entered)
	trigger.body_exited.connect(_on_trigger_body_exited)

func _on_trigger_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	print("SustainPedal global_position: ", global_position)
	print("Player global_position VOR Animation: ", body.global_position)
	is_pressed = true
	sustain_changed.emit(true)
	anim_player.play("sustainpedal")
	print("Player global_position NACH play(): ", body.global_position)

func _on_trigger_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	is_pressed = false
	sustain_changed.emit(false)
	anim_player.play_backwards("sustainpedal")

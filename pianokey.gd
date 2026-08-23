extends Area2D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var trigger: Area2D = %TasteTrigger

func _ready() -> void:
	trigger.body_entered.connect(_on_trigger_body_entered)

func _on_trigger_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	anim_player.play("taste_bewegung")

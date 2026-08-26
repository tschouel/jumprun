extends Area2D

@export var anim_player: AnimationPlayer
@export var animation_name: String = "taste_bewegung"
@export var trigger: Area2D

func _ready() -> void:
	if not anim_player:
		anim_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not trigger:
		trigger = get_node_or_null("%TasteTrigger") as Area2D
	if trigger:
		trigger.body_entered.connect(_on_trigger_body_entered)

func _on_trigger_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if anim_player:
		anim_player.play(animation_name)

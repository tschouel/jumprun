extends AnimatedSprite2D

@export_group("Trigger 1 -> Animation 1 -> Animation 2 (Loop)")
@export var trigger_1: Area2D
@export var animation_1: String = ""
@export var animation_2: String = ""

@export_group("Trigger 2 -> Animation 3")
@export var trigger_2: Area2D
@export var animation_3: String = ""

func _ready() -> void:
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)
	if trigger_1:
		trigger_1.body_entered.connect(_on_trigger_1_body_entered)
	if trigger_2:
		trigger_2.body_entered.connect(_on_trigger_2_body_entered)

func _on_trigger_1_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if animation_1 != "":
		play(animation_1)

func _on_trigger_2_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if animation_3 != "":
		play(animation_3)

func _on_animation_finished() -> void:
	if animation == animation_1 and animation_2 != "":
		play(animation_2)

class_name FlyingZone
extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and "is_flying_active" in body:
		body.is_flying_active = true
		# Schaltet direkt das Flug-Sprite im Player aktiv
		if body.has_method("show_only_sprite") and "flying_sprite" in body:
			body.show_only_sprite(body.flying_sprite)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and "is_flying_active" in body:
		body.is_flying_active = false
		# Stellt beim Verlassen wieder das normale Geh-Sprite her
		if body.has_method("show_only_sprite") and "walking_sprite" in body:
			body.show_only_sprite(body.walking_sprite)

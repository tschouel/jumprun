extends Area2D

@export var path_follow: PathFollow2D   # -> WindPathFollow

var is_active: bool = false


func _ready() -> void:
	monitoring = false   # Inaktiv, bis das Ventil gedrückt wurde
	body_entered.connect(_on_body_entered)


func activate() -> void:
	is_active = true
	monitoring = true


func _on_body_entered(body: Node2D) -> void:
	if is_active and body is CharacterBody2D and path_follow:
		path_follow.attach_player(body)

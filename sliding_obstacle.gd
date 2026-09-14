extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var player := body as CharacterBody2D
	if not player.has_meta("path_movement_module"):
		return

	var path_movement = player.get_meta("path_movement_module")
	if path_movement and path_movement.has_method("on_obstacle_hit"):
		path_movement.on_obstacle_hit()

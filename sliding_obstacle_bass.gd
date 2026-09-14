extends Area2D
## Eigenständige Kopie von SlidingObstacle.gd, spezifisch für die
## Kontrabass-Saiten. Ruft path_bass_movement_module statt
## path_movement_module auf, damit dein bestehendes SlidingObstacle.gd
## (und die alte PathMovement.gd) komplett unangetastet bleiben.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	var player := body as CharacterBody2D
	if not player.has_meta("path_bass_movement_module"):
		return

	var path_bass_movement = player.get_meta("path_bass_movement_module")
	if path_bass_movement and path_bass_movement.has_method("on_obstacle_hit"):
		path_bass_movement.on_obstacle_hit()

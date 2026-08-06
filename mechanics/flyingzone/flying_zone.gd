extends Area2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var active_player: CharacterBody2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if active_player != null or not is_instance_valid(body):
		return

	var player = body as CharacterBody2D
	if not player:
		return

	active_player = player
	
	if "is_flying_active" in active_player:
		active_player.is_flying_active = true

func _on_body_exited(body: Node2D) -> void:
	if is_instance_valid(body) and body == active_player:
		if is_instance_valid(active_player) and "is_flying_active" in active_player:
			active_player.is_flying_active = false

		active_player = null

extends Area2D

func _ready() -> void:
	print("Spike bereit.")

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		print("Player getroffen!")
		call_deferred("_play_sound")

func _play_sound() -> void:
	FmodServer.play_one_shot("event:/Crash")
	print("Crash-Sound via One-Shot gestartet!")

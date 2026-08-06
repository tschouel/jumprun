extends Area2D

# Hier ziehst du im Inspektor deinen FmodEventEmitter2D rein
@export var music_emitter: FmodEventEmitter2D

var triggered: bool = false

func _on_body_entered(body: Node2D) -> void:
	if not triggered and (body.is_in_group("player") or "player" in body.name.to_lower()):
		triggered = true
		if music_emitter:
			music_emitter.play()
			print("FMOD Event gestartet über Emitter: ", music_emitter.name)
		else:
			push_warning("Kein Music Emitter im MusicTrigger zugewiesen!")

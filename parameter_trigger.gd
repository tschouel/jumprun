extends Area2D

@export var music_emitter: FmodEventEmitter2D
@export var parameter_name: String = "Fall"
@export var target_value: float = 0.0
@export var trigger_ui_change: bool = true # Hier steuerst du, ob die UI reagieren soll!

var triggered: bool = false

func _on_body_entered(body: Node2D) -> void:
	if not triggered and (body.is_in_group("player") or "player" in body.name.to_lower()):
		triggered = true
		
		# 1. UI Bildwechsel unabhängig vom target_value auslösen
		if trigger_ui_change:
			var singer_ui = get_tree().root.find_child("SingerUI", true, false)
			if singer_ui:
				singer_ui.trigger_miss_expression()
		
		# 2. FMOD Parameter abgesichert setzen
		if music_emitter:
			await get_tree().process_frame
			music_emitter.set_parameter(parameter_name, target_value)
			print("FMOD Parameter '", parameter_name, "' auf ", target_value, " gesetzt!")

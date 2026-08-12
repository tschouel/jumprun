class_name FermataBlock
extends Area2D

@export_group("FMOD Sound Einstellungen")
## Der Name des FMOD-Parameters (z. B. "Chord", "Progression", "Impuls")
@export var fmod_parameter_name: String = "Chord"
## Der Wert, der beim Betreten gesendet wird
@export var fmod_parameter_value: float = 1.0
## Der Wert, auf den zurückgesetzt wird (z. B. 0.0)
@export var reset_value: float = 0.0

@export_group("Trigger Verhalten")
## Wenn aktiv, löst der Block nur ein einziges Mal aus und deaktiviert sich danach komplett
@export var one_shot: bool = true

@export_group("FMOD Emitter (Optional)")
@export var fmod_emitter: FmodEventEmitter2D

var _triggered: bool = false
var _has_been_used: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if _has_been_used:
		return
		
	if body is CharacterBody2D and not _triggered:
		_triggered = true
		
		if one_shot:
			_has_been_used = true
			set_deferred("monitoring", false)
			
			# Signale hart trennen, damit nichts nachfeuern kann
			if body_entered.is_connected(_on_body_entered):
				body_entered.disconnect(_on_body_entered)
			if body_exited.is_connected(_on_body_exited):
				body_exited.disconnect(_on_body_exited)
			
			# 1. Impuls senden (z. B. 1.0)
			_send_parameter(body, fmod_parameter_value)
			
			# 2. Kurzer Timer für Impuls-Reset bei One-Shot (z. B. auf 0.0)
			await get_tree().create_timer(0.1).timeout
			_send_parameter(body, reset_value)
		else:
			# Normaler Modus (kein One-Shot)
			_send_parameter(body, fmod_parameter_value)


func _on_body_exited(body: Node2D) -> void:
	if _has_been_used or one_shot:
		return
		
	if body is CharacterBody2D:
		_triggered = false
		_send_parameter(body, reset_value)


func _send_parameter(player: CharacterBody2D, value: float) -> void:
	print("[FERMATE BLOCK] Parameter ", fmod_parameter_name, " -> ", value)
	
	if fmod_emitter:
		fmod_emitter.set_parameter(fmod_parameter_name, value)
	elif player and player.get("music_emitter") and player.music_emitter:
		player.music_emitter.set_parameter(fmod_parameter_name, value)

	if ClassDB.class_exists("FmodServer"):
		FmodServer.set_global_parameter_by_name(fmod_parameter_name, value)

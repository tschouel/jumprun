class_name FermataZone
extends Area2D

@export_group("Trigger Einstellungen")
## Wenn aktiv, wirkt die Fermate-Zone nur beim ersten Mal (deaktiviert sich danach komplett)
@export var one_shot: bool = false

var _has_been_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if _has_been_triggered:
		return

	if body is CharacterBody2D and "is_fermata_active" in body:
		body.is_fermata_active = true
		print("[FERMATA ZONE] Betreten: Handsteuerung AKTIV")


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and "is_fermata_active" in body:
		body.is_fermata_active = false
		print("[FERMATA ZONE] Verlassen: Auto-Scroll AKTIV")

		if one_shot:
			_has_been_triggered = true
			set_deferred("monitoring", false)
			if body_entered.is_connected(_on_body_entered):
				body_entered.disconnect(_on_body_entered)
			if body_exited.is_connected(_on_body_exited):
				body_exited.disconnect(_on_body_exited)

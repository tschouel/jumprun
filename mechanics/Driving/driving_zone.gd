class_name DrivingZone
extends Area2D

@export_group("Rhythmus & Tempo")
@export var bpm: float = 120.0
@export var units_per_bar: float = 200.0

@export_group("Boost Einstellungen für diese Zone")
## Aktiviert/Deaktiviert den E-Boost für diese Zone
@export var enable_boost: bool = true
## Die Stärke des Speed-Schubs nach vorne
@export var boost_force: float = 350.0
## Dauer der FastCarBoost-Animation in Sekunden
@export var boost_duration: float = 1.5

var _is_player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if _is_player_inside:
		return
		
	if body is CharacterBody2D:
		_is_player_inside = true
		
		# 1. Zonen-Tempo im Player setzen
		if body.has_method("set_zone_tempo"):
			body.set_zone_tempo(bpm, units_per_bar)
		else:
			if "bpm" in body:
				body.bpm = bpm
			if "units_per_bar" in body:
				body.units_per_bar = units_per_bar
			if body.has_method("_recalculate_physics"):
				body._recalculate_physics()
		
		# 2. Driving-Modul holen & Zonen-Konfiguration injizieren
		var driving_module = body.get_node_or_null("DrivingMovement")
		body.set("is_driving_active", true)
		
		if driving_module:
			driving_module.set("boost_force", boost_force)
			driving_module.set("boost_duration", boost_duration)
			driving_module.set("can_boost", enable_boost)
			
			if driving_module.has_method("set_active"):
				driving_module.set_active(true)
		
		# 3. DrivingSprite einblenden & alle anderen ausblenden
		var driving_sprite = body.get_node_or_null("DrivingSprite")
		if not driving_sprite and driving_module:
			driving_sprite = driving_module.get_node_or_null("DrivingSprite")

		if body.has_method("show_only_sprite") and driving_sprite:
			body.show_only_sprite(driving_sprite)
		elif driving_sprite:
			driving_sprite.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and _is_player_inside:
		_is_player_inside = false
		
		var driving_module = body.get_node_or_null("DrivingMovement")
		if driving_module and driving_module.has_method("set_active"):
			driving_module.set_active(false)
			
		body.set("is_driving_active", false)

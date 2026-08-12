class_name FermataZone
extends Area2D

@export_group("Rhythmus & Tempo")
@export var bpm: float = 90.0
@export var units_per_bar: float = 200.0

@export_group("Trigger Einstellungen")
@export var one_shot: bool = false

var _is_player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if _is_player_inside:
		return
		
	if body is CharacterBody2D:
		_is_player_inside = true
		
		# 1. Zonen-Tempo setzen
		if body.has_method("set_zone_tempo"):
			body.set_zone_tempo(bpm, units_per_bar)
			
		# 2. Spezialmodi & deren Module ausschalten
		body.set("is_driving_active", false)
		body.set("is_flying_active", false)
		body.set("is_on_path", false)
		if "is_fermata_active" in body:
			body.is_fermata_active = true
		
		var driving_module = body.get_node_or_null("DrivingMovement")
		if driving_module and driving_module.has_method("set_active"):
			driving_module.set_active(false)

		var flying_module = body.get_node_or_null("FlyingMovement")
		if flying_module and flying_module.has_method("set_active"):
			flying_module.set_active(false)

		# 3. Ground-Modul aktivieren
		var ground_module = body.get_node_or_null("GroundMovement")
		if ground_module and ground_module.has_method("set_active"):
			ground_module.set_active(true)
		
		# 4. Walking-Sprite einblenden & alle anderen ausblenden
		var walking_sprite = body.get_node_or_null("Walking")
		if body.has_method("show_only_sprite") and walking_sprite:
			body.show_only_sprite(walking_sprite)
		elif walking_sprite:
			walking_sprite.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and _is_player_inside:
		_is_player_inside = false
		
		if "is_fermata_active" in body:
			body.is_fermata_active = false
			
		# Beim Verlassen wieder auf Standard (Sliding) schalten
		var sliding_sprite = body.get_node_or_null("Sliding")
		if body.has_method("show_only_sprite") and sliding_sprite:
			body.show_only_sprite(sliding_sprite)
			
		if one_shot:
			set_deferred("monitoring", false)

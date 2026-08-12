class_name FlyingZone
extends Area2D

# Im Inspector der Zone anpassbar:
@export var bpm: float = 120.0
@export var units_per_bar: float = 200.0

var _is_player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if _is_player_inside:
		return
		
	if body is CharacterBody2D:
		_is_player_inside = true
		
		# 1. Geschwindigkeiten / Tempo in der Zone setzen
		if body.has_method("set_zone_tempo"):
			body.set_zone_tempo(bpm, units_per_bar)
		else:
			if "bpm" in body:
				body.bpm = bpm
			if "units_per_bar" in body:
				body.units_per_bar = units_per_bar
			
			if body.has_method("_recalculate_physics"):
				body._recalculate_physics()
		
		# 2. Flying-Modul aktivieren
		var flying_module = body.get_node_or_null("FlyingMovement")
		body.set("is_flying_active", true)
		
		if flying_module and flying_module.has_method("set_active"):
			flying_module.set_active(true)
		
		# 3. FlyingSprite einblenden & alle anderen ausblenden
		var flying_sprite = body.get_node_or_null("FlyingSprite")
		if body.has_method("show_only_sprite") and flying_sprite:
			body.show_only_sprite(flying_sprite)
		elif flying_sprite:
			flying_sprite.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and _is_player_inside:
		_is_player_inside = false
		
		var flying_module = body.get_node_or_null("FlyingMovement")
		if flying_module and flying_module.has_method("set_active"):
			flying_module.set_active(false)
			
		body.set("is_flying_active", false)
		
		# Beim Verlassen wieder das normale Walking-Sprite aktivieren
		var main_sprite = body.get_node_or_null("Walking")
		if body.has_method("show_only_sprite") and main_sprite:
			body.show_only_sprite(main_sprite)
		elif main_sprite:
			main_sprite.visible = true

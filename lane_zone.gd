class_name LaneZone
extends Area2D

@export_group("Rhythmus & Tempo")
@export var bpm: float = 115.0
@export var units_per_bar: float = 400.0

@export_group("Lane Konfiguration")
## Y-Positionen der 4 Zwischenräume
@export var lane_y_positions: Array[float] = [240.0, 440.0, 640.0, 840.0]
## Start-Lane beim Betreten (0 = ganz oben, 3 = ganz unten)
@export var default_start_lane: int = 1

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

		# 2. Andere Spezialmodi ausschalten
		body.set("is_driving_active", false)
		body.set("is_flying_active", false)
		body.set("is_fermata_active", false)
		body.set("is_on_path", false)

		# 3. Lane-Modus im Player aktivieren
		if "is_lane_active" in body:
			body.is_lane_active = true

		# 4. LaneMovement-Modul konfigurieren und aktivieren
		var lane_module = body.get_node_or_null("LaneMovement")
		if lane_module:
			lane_module.lane_y_positions = lane_y_positions
			lane_module.current_lane = default_start_lane
			if lane_module.has_method("set_active"):
				lane_module.set_active(true)

		# 5. Animations-Sequenz starten
		_start_lane_animation(body)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and _is_player_inside:
		_is_player_inside = false

		if "is_lane_active" in body:
			body.is_lane_active = false

		var lane_module = body.get_node_or_null("LaneMovement")
		if lane_module and lane_module.has_method("set_active"):
			lane_module.set_active(false)

func _start_lane_animation(player: CharacterBody2D) -> void:
	# LaneSprite unter LaneMovement oder im Player suchen
	var lane_sprite = player.get_node_or_null("LaneMovement/LaneSprite") as AnimatedSprite2D
	if not lane_sprite:
		lane_sprite = player.find_child("LaneSprite", true, false) as AnimatedSprite2D

	if lane_sprite:
		# 1. Nur das LaneSprite sichtbar schalten
		if player.has_method("show_only_sprite"):
			player.show_only_sprite(lane_sprite)

		# 2. Übergangs-Animation "trans" abspielen
		lane_sprite.play("trans")

		# 3. Warten, bis "trans" zu Ende gespielt wurde
		await lane_sprite.animation_finished

		# 4. Auf "drive" (Loop) umschalten, wenn der Player noch in der Zone ist
		if _is_player_inside and lane_sprite:
			lane_sprite.play("drive")

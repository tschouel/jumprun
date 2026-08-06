extends PathFollow2D

@export_group("Rhythmus & Tempo")
@export var bpm: float = 90.0
@export var units_per_bar: float = 1000.0 # Auf Full HD angepasst (1000px pro Takt)
@export var is_moving: bool = true

var forward_speed: float

func _ready() -> void:
	# 4/4-Takt Dauer berechnen
	var bar_duration = (60.0 / bpm) * 4.0
	# Geschwindigkeit in Pixel pro Sekunde
	forward_speed = units_per_bar / bar_duration

func _process(delta: float) -> void:
	if is_moving:
		progress += forward_speed * delta

## Hilfsmethode: Wird aufgerufen, wenn der Player auf den Pfad steigt
func attach_player(player: Node2D) -> void:
	if player is CharacterBody2D:
		if "is_on_path" in player:
			player.is_on_path = true
		if player.has_method("show_only_sprite") and "sliding_sprite" in player:
			player.show_only_sprite(player.sliding_sprite)

## Hilfsmethode: Wird aufgerufen, wenn der Player den Pfad verlässt
func detach_player(player: Node2D) -> void:
	if player is CharacterBody2D:
		if "is_on_path" in player:
			player.is_on_path = false
		if player.has_method("show_only_sprite") and "walking_sprite" in player:
			player.show_only_sprite(player.walking_sprite)

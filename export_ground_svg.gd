extends Node2D

@export_group("FMOD Events")
@export var success_event: FmodEventEmitter2D
@export var fail_event: FmodEventEmitter2D

@onready var player: CharacterBody2D = $Player
@onready var trick_zone: Area2D = $TrickJump
@onready var safe_ground: StaticBody2D = $Safe

var is_in_trick_zone: bool = false
var has_completed_backflip: bool = false

func _ready() -> void:
	print("--- DEBUG START ---")
	print("1. Hauptnode 'Trickjump' Geladen. Name: ", name)
	
	if safe_ground:
		print("2. 'Safe' Node gefunden! Aktuelle Sichtbarkeit: ", safe_ground.visible)
		print("   'Safe' Instanz-ID: ", safe_ground.get_instance_id())
		print("   'Safe' Kinder-Anzahl: ", safe_ground.get_child_count())
		for child in safe_ground.get_children():
			print("   -> Kind von Safe: ", child.name, " (Klasse: ", child.get_class(), ", Sichtbar: ", child.visible if child is CanvasItem else "N/A", ")")
		
		# Entfernen versuchen
		remove_child(safe_ground)
		print("3. remove_child(safe_ground) ausgeführt. Parent von Safe ist jetzt: ", safe_ground.get_parent())
	else:
		printerr("2. FEHLER: '$Safe' konnte über @onready nicht gefunden werden!")
		
	print("--- DEBUG ENDE ---")

	if trick_zone:
		trick_zone.body_entered.connect(_on_trick_zone_body_entered)
		trick_zone.body_exited.connect(_on_trick_zone_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if is_in_trick_zone and not has_completed_backflip:
		if event.is_action_pressed("ui_left"):
			_on_backflip_success()

func _on_trick_zone_body_entered(body: Node2D) -> void:
	if body == player:
		is_in_trick_zone = true
		print("Player in TrickZone")

func _on_trick_zone_body_exited(body: Node2D) -> void:
	if body == player:
		is_in_trick_zone = false
		if not has_completed_backflip:
			_on_backflip_failed()

func _on_backflip_success() -> void:
	has_completed_backflip = true
	print("BACKFLIP ERFOLG -> Füge Safe wieder hinzu")
	if safe_ground and safe_ground.get_parent() == null:
		add_child(safe_ground)
	if success_event:
		success_event.play()

func _on_backflip_failed() -> void:
	if fail_event:
		fail_event.play()
	print("BACKFLIP VERPASST")

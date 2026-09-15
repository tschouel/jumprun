extends Area2D
class_name RespawnZone

## Area2D, die beim Betreten durch den Spieler einen kurzen Blackout ueber
## screen_fade.gd abspielt, den Spieler WAEHREND des Blackouts (also fuer
## die Person unsichtbar) auf respawn_point teleportiert, und danach wieder
## einblendet. Gedacht fuer Abgruende/Fallen/Checkpoints o.ae., wo der
## Spieler "stirbt" und an einem festen Punkt neu spawnen soll.
##
## ABLAUF bei _run_respawn_sequence():
## 1. Spieler wird eingefroren (falls freeze_player_during_fade = true).
## 2. screen_fade.fade_out() - Bildschirm wird schwarz.
## 3. Spieler wird auf respawn_point teleportiert (Position + velocity = 0).
## 4. hold_duration Sekunden komplett schwarz bleiben (etwas Luft, damit
##    der Teleport nicht "hart" wirkt).
## 5. screen_fade.fade_in() - Bildschirm blendet wieder ein.
## 6. Spieler wird wieder freigegeben.
##
## Waehrend eine Respawn-Sequenz laeuft, werden weitere Ausloesungen
## ignoriert (kein Ueberlappen, falls der Spieler direkt nach dem Respawn
## nochmal in der Zone landet).
##
## SETUP:
## - Dieses Skript auf eine Area2D legen (mit eigenem CollisionShape2D als
##   Kind, deckt den Bereich ab, der den Respawn ausloesen soll - z.B. eine
##   Fallgrube).
## - player auf den CharacterBody2D-Player zeigen lassen.
## - screen_fade auf eure ScreenFade-CanvasLayer-Instanz zeigen lassen
##   (screen_fade.gd).
## - respawn_point auf einen beliebigen Node2D (z.B. Marker2D) an der
##   Stelle zeigen lassen, an der der Spieler wieder auftauchen soll.

signal respawn_triggered

@export_group("Ausloeser")
@export var player: CharacterBody2D
@export var freeze_player_during_fade: bool = true

@export_group("Fade")
@export var screen_fade: ScreenFade
@export var fade_out_duration: float = 0.6
@export var fade_in_duration: float = 0.6
## Wie lange (Sekunden) der Bildschirm nach dem Fade-Out komplett schwarz
## bleibt, BEVOR wieder eingeblendet wird.
@export var hold_duration: float = 0.2

@export_group("Respawn")
@export var respawn_point: Node2D

var _is_respawning: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _is_respawning:
		return
	if not body.is_in_group("player"):
		return
	_is_respawning = true
	_run_respawn_sequence()

func _run_respawn_sequence() -> void:
	if freeze_player_during_fade and player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO

	if screen_fade and screen_fade.has_method("fade_out"):
		await screen_fade.fade_out(fade_out_duration)

	_teleport_player()
	respawn_triggered.emit()

	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration).timeout

	if screen_fade and screen_fade.has_method("fade_in"):
		await screen_fade.fade_in(fade_in_duration)

	if freeze_player_during_fade and player:
		player.set_physics_process(true)

	_is_respawning = false

func _teleport_player() -> void:
	if not player or not respawn_point:
		return
	player.global_position = respawn_point.global_position
	player.velocity = Vector2.ZERO

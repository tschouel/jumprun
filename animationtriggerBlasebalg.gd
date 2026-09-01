extends Node

## Kleiner, wiederverwendbarer Ausloeser: sobald der Player die zugewiesene
## trigger_zone (Area2D) betritt, wird EINE Animation gestartet - auf DREI
## moeglichen Wegen, beliebig kombinierbar:
##   1) sprite + animation_name         -> sprite.play(animation_name)
##   2) animation_player + player_animation_name -> animation_player.play(player_animation_name)
##   3) target + target_method_name     -> target.call(target_method_name), per
##      Duck-Typing (has_method()), z.B. fuer bagpipe.gd-artige jump()/pump()-
##      Methoden auf einem anderen Skript.
##
## Setup: als Node irgendwo in die Szene (z.B. neben den Blasebalg-Sprite),
## dieses Skript dran, trigger_zone zuweisen. Dann EINEN oder MEHRERE der drei
## Wege oben befuellen - leere/nicht gesetzte Felder werden ignoriert.
##
## WICHTIG bei Weg 2 (AnimationPlayer): falls die Animation eine
## AnimatableBody2D-Transform bewegt (z.B. Rotation eines Blasebalgs, auf dem
## der Player steht), muss die AnimatableBody2D sync_to_physics = true haben
## UND der AnimationPlayer sollte Process Callback: Physics verwenden (statt
## Idle) - sonst kann es zu Rucklern oder falschem "Mitnehmen" des Spielers
## kommen (gleiche Ursache wie das Halbbildflimmern beim Dudelsack).
##
## only_once (Standard true): der Trigger loest nur beim ALLERERSTEN Betreten
## aus - danach ignoriert er weitere body_entered-Signale. Auf false setzen,
## falls der Trigger mehrfach ausloesen soll (z.B. bei jedem erneuten
## Ueberqueren).

signal triggered

@export_group("Trigger")
## Area2D, deren body_entered das Ausloesen startet.
@export var trigger_zone: Area2D
## Falls true, loest der Trigger nur beim ersten Betreten aus. Falls false,
## bei jedem Betreten erneut.
@export var only_once: bool = true
## Der Player muss in dieser Gruppe sein, damit der Trigger reagiert.
@export var required_group: String = "player"

@export_group("Weg 1: Sprite direkt abspielen")
## Optional - falls gesetzt, wird animation_name auf diesem Sprite gestartet.
@export var sprite: AnimatedSprite2D
## Name der Animation im SpriteFrames-Panel, die abgespielt werden soll.
@export var animation_name: String = ""

@export_group("Weg 2: AnimationPlayer abspielen")
## Optional - falls gesetzt UND player_animation_name nicht leer ist, wird
## animation_player.play(player_animation_name) aufgerufen. Fuer sowas wie
## BlasebalgAnim, das z.B. die Rotation-Node2D animiert.
@export var animation_player: AnimationPlayer
## Name der Animation im AnimationPlayer-Panel (z.B. "rotate" o.ae.).
@export var player_animation_name: String = ""

@export_group("Weg 3: Methode auf anderem Skript aufrufen")
## Optional - falls gesetzt UND target_method_name nicht leer ist, wird diese
## Methode per Duck-Typing aufgerufen (z.B. ein anderer Node mit jump() oder
## pump(), wie bagpipe.gd). NICHT fuer AnimationPlayer verwenden - dafuer Weg 2.
@export var target: Node
## Name der Methode auf target, die aufgerufen werden soll (ohne Klammern).
@export var target_method_name: String = ""

@export_group("Debug")
@export var debug_prints: bool = false

var _already_triggered: bool = false

func _ready() -> void:
	if trigger_zone and not trigger_zone.body_entered.is_connected(_on_trigger_zone_entered):
		trigger_zone.body_entered.connect(_on_trigger_zone_entered)

func _on_trigger_zone_entered(zone_body: Node2D) -> void:
	if not zone_body.is_in_group(required_group):
		return
	if only_once and _already_triggered:
		return
	_already_triggered = true
	_fire()

## Fuehrt das eigentliche Ausloesen aus - fuer alle drei Wege unabhaengig
## voneinander, damit z.B. Sprite-Animation UND AnimationPlayer gleichzeitig
## gestartet werden koennen.
func _fire() -> void:
	if sprite and animation_name != "":
		sprite.speed_scale = 1.0
		sprite.play(animation_name)
		if debug_prints:
			print("[", get_path(), "] spielt Animation '", animation_name, "' auf ", sprite.get_path())
	if animation_player and player_animation_name != "":
		if animation_player.has_animation(player_animation_name):
			animation_player.play(player_animation_name)
			if debug_prints:
				print("[", get_path(), "] spielt AnimationPlayer-Animation '", player_animation_name, "' auf ", animation_player.get_path())
		elif debug_prints:
			print("[", get_path(), "] WARNUNG: AnimationPlayer ", animation_player.get_path(), " kennt keine Animation '", player_animation_name, "'")
	if target and target_method_name != "":
		if target.has_method(target_method_name):
			target.call(target_method_name)
			if debug_prints:
				print("[", get_path(), "] ruft ", target_method_name, "() auf ", target.get_path(), " auf")
		elif debug_prints:
			print("[", get_path(), "] WARNUNG: target hat keine Methode '", target_method_name, "'")
	triggered.emit()

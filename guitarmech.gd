extends Node

## Steuert den gesamten Gitarren-Mechanismus: Taste F in der Mechanik-Zone
## aktiviert/verlaesst den Spielmodus. Kein automatischer Takt mehr - und die
## Hebel-Tasten loesen selbst KEINEN Zupf mehr aus, die bestimmen nur noch
## welcher Bund gedrueckt wird (Fretting). Das eigentliche Zupfen passiert
## unabhaengig davon ueber zwei eigene "Pedal"-Tasten:
## - pluck_key (default E): Standard-Zupf - eigene Animation (pluck_sprite),
##   kurz danach (pluck_delay) string_node.pluck(false) (Bereich start_point
##   -> aktiver Druckpunkt vibriert).
## - pedal_key (default Q): zweiter Zupf - eigene Animation (pedal_sprite),
##   kurz danach string_node.pluck(true) (Bereich end_point -> aktiver
##   Druckpunkt vibriert).
##
## Die 4 Hebel-Tasten spielen daneben weiterhin JEWEILS ihre eigene
## Hebel-Animation, solange sie gehalten werden (mehrere gleichzeitig moeglich
## - das ist rein visuell, der physische Hebel wird gedrueckt). Jede
## Hebel-Animation laeuft zweistufig: erst einmalig lever_animation_name
## ("default"), danach automatisch in die Loop-Animation lever_loop_animation_name
## ("loop"), solange die Taste weiter gehalten wird.
##
## Welcher Hebel die Saite tatsaechlich verbiegt, folgt der Gitarren-Prioritaet
## taste4 > taste3 > taste2 > taste1: solange Hebel 4 (index 3, hoechster Ton)
## gehalten wird, "gewinnt" er immer, egal welche tieferen Hebel zusaetzlich
## gehalten werden - die haben dann einfach keinen Effekt auf die Saite
## (bleiben aber sichtbar gedrueckt/animiert).
##
## Annahme (bei Bedarf im Inspector anpassen): lever_keys default =
## [KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_UP] (taste1..taste4), da nur
## "links, unten, rechts" genannt wurden - die 4. Taste bitte pruefen.

@export_group("Zone & Aktivierung")
@export var interaction_zone: Area2D
@export var toggle_key: Key = KEY_F
@export var player: CharacterBody2D
@export var freeze_player_while_active: bool = true
## Animationsname im Player-SpriteFrames (z.B. "sitzend_gitarre"), der waehrend
## des Spielmodus per GroundMovement.set_animation_override() angezeigt wird.
## Leer lassen, um die Player-Animation nicht anzufassen.
@export var player_animation_override: String = ""

@export_group("Saite")
@export var string_node: Node

@export_group("Zupf-Animation")
## Loest den Standard-Zupf aus - unabhaengig davon, ob gerade ein Hebel
## gehalten wird oder nicht.
@export var pluck_key: Key = KEY_E
## Optional: eigene AnimatedSprite2D fuer den Zupf-/Strum-Moment (z.B. ein Arm
## oder Plektrum). Kann leer bleiben - dann wird trotzdem geplueckt, nur ohne
## eigene Animation dafuer.
@export var pluck_sprite: AnimatedSprite2D
@export var pluck_animation_name: String = "pluck"
## Wie lange nach dem Tastendruck gewartet wird, bevor die Saite tatsaechlich
## vibriert (string_node.pluck()) - fuer den Sync mit der Zupf-Animation. 0 = sofort.
@export var pluck_delay: float = 0.1

@export_group("Zweites Pedal")
## Einmaliges Druecken (kein Halten) loest dieses Pedal aus - eigene
## Animation, eigener Zupf mit umgekehrtem Vibrationsbereich (end_point ->
## Druckpunkt statt start_point -> Druckpunkt).
@export var pedal_key: Key = KEY_Q
@export var pedal_sprite: AnimatedSprite2D
@export var pedal_animation_name: String = "default"

@export_group("Hebel (Index 0 = taste1 ... Index 3 = taste4, hoechster Ton)")
@export var lever_sprites: Array[AnimatedSprite2D] = []
@export var lever_keys: Array[Key] = [KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_UP]
## Einmalige Start-Animation, die beim Druecken der Taste zuerst abgespielt wird.
@export var lever_animation_name: String = "default"
## Loop-Animation, in die nach lever_animation_name automatisch gewechselt wird,
## solange die Taste weiter gehalten wird. Muss im SpriteFrames als "Loop" markiert sein.
@export var lever_loop_animation_name: String = "loop"

var _player_in_zone: bool = false
var _is_active: bool = false
var _current_lever: int = -1
var _current_lever_low: int = -1
var _lever_in_loop: Array[bool] = []
var _ground_movement: Node = null

func _ready() -> void:
	_lever_in_loop.resize(lever_sprites.size())
	for i in range(lever_sprites.size()):
		_lever_in_loop[i] = false
		var sprite: AnimatedSprite2D = lever_sprites[i]
		if sprite:
			sprite.animation_finished.connect(_on_lever_animation_finished.bind(i))
	if player:
		_ground_movement = player.get_node_or_null("GroundMovement")
	if interaction_zone:
		interaction_zone.body_entered.connect(_on_zone_body_entered)
		interaction_zone.body_exited.connect(_on_zone_body_exited)

func _on_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = true

func _on_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = false
		if _is_active:
			_deactivate()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_zone:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == toggle_key:
		if _is_active:
			_deactivate()
		else:
			_activate()
	elif event.physical_keycode == pluck_key and _is_active:
		_trigger_pluck_sequence()
	elif event.physical_keycode == pedal_key and _is_active:
		_trigger_pedal()

func _activate() -> void:
	_is_active = true
	if freeze_player_while_active and player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO
	if player_animation_override != "" and _ground_movement and _ground_movement.has_method("set_animation_override"):
		_ground_movement.set_animation_override(player_animation_override)

func _deactivate() -> void:
	_is_active = false
	if freeze_player_while_active and player:
		player.set_physics_process(true)
	if _ground_movement and _ground_movement.has_method("clear_animation_override"):
		_ground_movement.clear_animation_override()
	_current_lever = -1
	_current_lever_low = -1
	if string_node and string_node.has_method("set_pressed_lever"):
		string_node.set_pressed_lever(-1)
	if string_node and string_node.has_method("set_pressed_lever_alt"):
		string_node.set_pressed_lever_alt(-1)
	if pluck_sprite:
		pluck_sprite.stop()
	if pedal_sprite:
		pedal_sprite.stop()
		pedal_sprite.animation = pedal_animation_name
		pedal_sprite.set_frame_and_progress(0, 0.0)
	for i in range(lever_sprites.size()):
		var sprite: AnimatedSprite2D = lever_sprites[i]
		if sprite:
			sprite.stop()
			sprite.animation = lever_animation_name
			sprite.set_frame_and_progress(0, 0.0)
		_lever_in_loop[i] = false

func _process(_delta: float) -> void:
	if not _is_active:
		return
	_poll_levers()

func _pluck() -> void:
	if string_node and string_node.has_method("pluck"):
		string_node.pluck(false)

## Wird nur beim WECHSEL "nicht gehalten -> gehalten" ausgeloest (nicht bei
## jedem Frame, in dem eine Taste gehalten wird) - also einmal pro Tastendruck.
func _trigger_pluck_sequence() -> void:
	if pluck_sprite:
		pluck_sprite.stop()
		pluck_sprite.play(pluck_animation_name)
	if pluck_delay <= 0.0:
		_pluck()
	else:
		get_tree().create_timer(pluck_delay).timeout.connect(_deferred_pluck)

func _deferred_pluck() -> void:
	# Falls der Modus zwischen Tastendruck und Ablauf des delays schon
	# verlassen wurde, soll nicht nachtraeglich noch geplueckt werden.
	if _is_active:
		_pluck()

## Zweites Pedal (pedal_key, einmaliges Druecken): eigene Animation, zupft
## die Saite mit umgekehrtem Vibrationsbereich (end_point -> Druckpunkt).
func _trigger_pedal() -> void:
	if pedal_sprite:
		pedal_sprite.stop()
		pedal_sprite.play(pedal_animation_name)
	if pluck_delay <= 0.0:
		_pluck_from_end()
	else:
		get_tree().create_timer(pluck_delay).timeout.connect(_deferred_pluck_from_end)

func _pluck_from_end() -> void:
	if string_node and string_node.has_method("pluck"):
		string_node.pluck(true)

func _deferred_pluck_from_end() -> void:
	if _is_active:
		_pluck_from_end()

func _poll_levers() -> void:
	# Jede gehaltene Taste spielt ihre eigene Hebel-Animation und bestimmt den
	# aktiven Druckpunkt - loest aber selbst KEINEN Zupf mehr aus (das machen
	# jetzt ausschliesslich pluck_key und pedal_key, siehe _unhandled_input).
	#
	# Zwei Prioritaeten werden parallel ermittelt, weil E und Q unterschiedlich
	# aufloesen sollen, wenn mehrere Hebel gleichzeitig gehalten werden:
	# - dominant_high (taste4 > taste3 > taste2 > taste1): fuer die sichtbare
	#   Biegung der Saite und das Standard-Pedal E.
	# - dominant_low (taste1 > taste2 > taste3 > taste4, umgekehrt): nur fuer
	#   die Vibrationsgrenze beim zweiten Pedal Q (guitar_string.gd:
	#   set_pressed_lever_alt).
	var dominant_high: int = -1
	var dominant_low: int = -1
	for i in range(lever_keys.size()):
		var held: bool = Input.is_physical_key_pressed(lever_keys[i])
		_update_lever_sprite(i, held)
		if held:
			# Wir laufen aufsteigend index 0 -> 3 durch, daher gewinnt am Ende
			# immer der hoechste gehaltene Index = taste4 > taste3 > taste2 > taste1.
			dominant_high = i
			if dominant_low == -1:
				# Der ERSTE (also niedrigste) gehaltene Index gewinnt.
				dominant_low = i
	if dominant_high != _current_lever:
		_current_lever = dominant_high
		if string_node and string_node.has_method("set_pressed_lever"):
			string_node.set_pressed_lever(_current_lever)
	if dominant_low != _current_lever_low:
		_current_lever_low = dominant_low
		if string_node and string_node.has_method("set_pressed_lever_alt"):
			string_node.set_pressed_lever_alt(_current_lever_low)

func _update_lever_sprite(index: int, held: bool) -> void:
	if index < 0 or index >= lever_sprites.size():
		return
	var sprite: AnimatedSprite2D = lever_sprites[index]
	if not sprite:
		return
	if held:
		# Nur neu starten, wenn der Hebel gerade nicht schon animiert -
		# ein bereits laufender Intro- oder Loop-Zustand wird nicht unterbrochen.
		if not sprite.is_playing():
			_lever_in_loop[index] = false
			sprite.speed_scale = 1.0
			sprite.play(lever_animation_name)
	else:
		# Taste losgelassen: Loop verlassen und sauber auf Frame 0 der
		# default-Animation zurueckschalten (nicht einfach stoppen - dann
		# bliebe sie irgendwo mitten in der Loop-Animation stehen).
		sprite.stop()
		sprite.animation = lever_animation_name
		sprite.set_frame_and_progress(0, 0.0)
		_lever_in_loop[index] = false

func _on_lever_animation_finished(index: int) -> void:
	if index < 0 or index >= lever_sprites.size():
		return
	var sprite: AnimatedSprite2D = lever_sprites[index]
	if not sprite:
		return
	if sprite.animation == lever_animation_name and not _lever_in_loop[index]:
		_lever_in_loop[index] = true
		sprite.speed_scale = 1.0
		sprite.play(lever_loop_animation_name)

class_name GroundMovement
extends Node2D

@export_group("Geschwindigkeit & Beschleunigung")
## Maximale Laufgeschwindigkeit
@export var speed: float = 350.0
## Beschleunigung beim Anlaufen
@export var acceleration: float = 3000.0
## Hohe Reibung beim Bremsen (verhindert Schlittschuhlaufen)
@export var friction: float = 4500.0

@export_group("Sprung & Schwerkraft")
@export var jump_velocity: float = -550.0
@export var gravity: float = 1400.0
## Wie viel von der Lift-Geschwindigkeit zusaetzlich in den Sprung einfliesst,
## GEDECKELT auf diesen Betrag (px/s). 0 = wie "Platform on Leave: Do Nothing"
## (kein Boost). Ein hoher Wert (z.B. 9999) waere effektiv wie "Add Velocity"
## (ungedeckelt). Sinnvoll ist meist ein Wert deutlich unter der maximalen
## Lift-Geschwindigkeit, damit sich der Sprung staerker/schwaecher anfuehlt,
## je nachdem wie schnell der Lift gerade faehrt, aber nie explodiert.
@export var max_platform_jump_boost: float = 250.0

@export_group("Referenzen")
@export var sprite: AnimatedSprite2D

var is_active: bool = false
var _player: CharacterBody2D = null

func setup(player: CharacterBody2D) -> void:
	_player = player
	if not sprite:
		# "Walk" ist ein direktes Kind von GroundMovement selbst
		sprite = get_node_or_null("Walk") as AnimatedSprite2D
	if not sprite and _player:
		sprite = _player.find_child("*Sprite*", true, false) as AnimatedSprite2D

func set_active(active: bool) -> void:
	is_active = active
	if not is_active:
		_play_stand_animation()

## Wird vom player.gd im Haupt-_physics_process aufgerufen
func process_movement(delta: float) -> void:
	if not _player:
		return

	# 1. Schwerkraft
	# WICHTIG (Fix): Ohne das "else" bleibt velocity.y nach der Landung auf dem
	# Wert vom letzten Fall "eingefroren", statt auf 0 zu gehen. Auf einem
	# statischen Boden fällt das nicht auf (move_and_slide blockt die Kollision
	# einfach), aber auf einer sich bewegenden Plattform (z.B. dem Acclift)
	# kämpft diese alte Rest-Fallgeschwindigkeit jeden Physik-Tick gegen die
	# Kollisions-Verdrängung der Plattform - das erzeugt genau das
	# geschwindigkeitsabhängige Zittern/"Aneinanderschlagen".
	if not _player.is_on_floor():
		_player.velocity.y += gravity * delta
	else:
		_player.velocity.y = 0.0

	# 2. Sprung
	# "jump" wird nur abgefragt, wenn diese Action im Input Map überhaupt existiert
	# (verhindert die "InputMap action doesn't exist"-Fehlerflut)
	var jump_pressed: bool = Input.is_action_just_pressed("ui_up")
	if InputMap.has_action("jump"):
		jump_pressed = jump_pressed or Input.is_action_just_pressed("jump")
	if jump_pressed and _player.is_on_floor():
		# Plattform-Geschwindigkeit (z.B. vom Acclift) zum Sprung dazuaddieren,
		# aber gedeckelt - so bleibt es "Sprung + etwas Lift-Schwung" statt bei
		# einer schnellen Lift-Phase unkontrollierbar hoch zu katapultieren.
		# Voraussetzung: "Platform on Leave" am CharacterBody2D steht auf
		# "Do Nothing", sonst addiert Godot zusaetzlich noch seine eigene,
		# ungedeckelte Portion oben drauf.
		var platform_vy: float = _player.get_platform_velocity().y
		var platform_boost: float = 0.0
		if platform_vy < 0.0:
			# Nur der nach oben gerichtete Anteil zaehlt (negatives y = nach oben),
			# und wird auf max_platform_jump_boost begrenzt.
			platform_boost = max(platform_vy, -max_platform_jump_boost)
		_player.velocity.y = jump_velocity + platform_boost

	# 3. Horizontaler Input
	var input_axis: float = Input.get_axis("ui_left", "ui_right")
	if input_axis == 0.0:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_axis -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_axis += 1.0

	# 4. Knackiges Beschleunigen & Sofort-Stopp
	if input_axis != 0.0:
		_player.velocity.x = move_toward(_player.velocity.x, input_axis * speed, acceleration * delta)
		# Spiegelt die Figur horizontal, sodass sie in Laufrichtung schaut
		if sprite:
			sprite.flip_h = (input_axis < 0.0)
	else:
		_player.velocity.x = move_toward(_player.velocity.x, 0.0, friction * delta)

	# 5. Animationssteuerung
	_update_animation(input_axis)

func _update_animation(input_axis: float) -> void:
	if not sprite:
		return
	var on_floor: bool = _player.is_on_floor()
	# Nur "moving", solange aktiv links/rechts gelaufen wird
	var is_moving: bool = input_axis != 0.0 and abs(_player.velocity.x) > 10.0
	if not on_floor:
		_play_animation("jump")
	elif is_moving:
		_play_animation("walking")
	else:
		_play_animation("stand")

func _play_stand_animation() -> void:
	_play_animation("stand")

func _play_animation(anim_name: String) -> void:
	if not sprite:
		return
	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)

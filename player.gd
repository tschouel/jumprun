extends CharacterBody2D

# Schalter für Pfad- & Spiralen-Level (im Inspektor auf TRUE setzen!)
@export var is_on_path: bool = false 

@export_group("Spiegelung & Grafik")
## Direktes Zuweisen der Sprite2D / AnimatedSprite2D Node im Inspektor
@export var sprite_node: Node2D 
## Soll die Figur immer aufrecht stehen (0° Drehung), egal wie der Pfad verläuft?
@export var keep_upright: bool = true

@export_group("Rhythmus & Tempo")
@export var bpm: float = 90.0
@export var units_per_bar: float = 200.0

@export_group("Sprung Einstellungen (Auto-Movement)")
@export var beats_per_jump: float = 1.0  
@export var jump_height: float = 20.0 

@export_group("Fermate & Handsteuerung")
## Sprunghöhe speziell bei Sprüngen nach rechts im Fermate-Modus
@export var fermata_right_jump_height: float = 35.0
## Wie schnell die Figur im Fermate-Modus ohne Input ausrollt
@export var fermata_friction: float = 600.0
## Wie schnell die Figur auf neue Bewegungseingaben anspricht
@export var fermata_acceleration: float = 1200.0

@export_group("Flying Zone (Heißluftballon)")
## Maximale Fluggeschwindigkeit
@export var fly_max_speed: float = 200.0
## Wie schnell der Ballon auf WASD anspricht (Trägheit)
@export var fly_acceleration: float = 300.0
## Luftwiderstand für horizontales Ausgleiten
@export var fly_friction: float = 1.5
## Permanente Schwerkraft im Flug (leichtes Sinking)
@export var fly_gravity: float = 30.0
## Wie stark die Taste "E" den Ballon nach oben katapultiert (Einfeuer-Impuls)
@export var fly_boost_force: float = 350.0
## Schwächere Kraft für die normale Hoch-Taste
@export var fly_up_speed_factor: float = 0.4

@export_group("FMOD Einstellungen")
## Die FMOD EventEmitter2D Node für Musik/Sounds
@export var music_emitter: Node2D

var gravity: float
var JUMP_VELOCITY: float
var FERMATA_RIGHT_JUMP_VELOCITY: float
var forward_speed: float

# Zonen-Schalter
var is_fermata_active: bool = false
var is_flying_active: bool = false

# Interner Status für Einfeuer-Impuls (E-Taste)
var _boost_triggered_last_frame: bool = false

# Speicher für die letzte Position zur Richtungsbestimmung
var _last_global_x: float = 0.0

func _ready() -> void:
	_last_global_x = global_position.x
	if not is_on_path:
		_recalculate_physics()

func _recalculate_physics() -> void:
	var bar_duration = (60.0 / bpm) * 4.0
	forward_speed = units_per_bar / bar_duration
	
	var beat_duration = 60.0 / bpm
	var jump_duration = beat_duration * beats_per_jump
	
	gravity = (8.0 * jump_height) / (jump_duration * jump_duration)
	JUMP_VELOCITY = -(4.0 * jump_height) / jump_duration
	FERMATA_RIGHT_JUMP_VELOCITY = -(4.0 * fermata_right_jump_height) / jump_duration

func _process(_delta: float) -> void:
	if is_on_path:
		_handle_path_orientation()

func _handle_path_orientation() -> void:
	if keep_upright:
		global_rotation = 0.0

	var current_global_x = global_position.x
	var delta_x = current_global_x - _last_global_x
	
	if abs(delta_x) > 0.01:
		var is_moving_left: bool = delta_x < 0.0
		
		var target_node = sprite_node
		if not target_node:
			target_node = get_node_or_null("Sprite2D")
		if not target_node:
			target_node = get_node_or_null("AnimatedSprite2D")
			
		if target_node:
			if "flip_h" in target_node:
				target_node.flip_h = is_moving_left
			if "flip_v" in target_node:
				target_node.flip_v = false
		else:
			var base_scale_x = abs(scale.x)
			scale.x = -base_scale_x if is_moving_left else base_scale_x

	_last_global_x = current_global_x

func _physics_process(delta: float) -> void:
	# 1. Spezial-Modus: Flugphysik (Flying Zone)
	if is_flying_active:
		_handle_flying_movement(delta)
		move_and_slide()
		return

	# 2. Spezial-Modus: Bewegung auf festem Pfad
	if is_on_path:
		position = Vector2.ZERO
		velocity = Vector2.ZERO
		return

	# 3. Plattformer-Physik für Auto-Scroll & Fermate
	var input_dir: float = 0.0
	
	if is_fermata_active:
		input_dir = Input.get_axis("ui_left", "ui_right")
		if input_dir != 0.0:
			velocity.x = move_toward(velocity.x, input_dir * forward_speed, fermata_acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, fermata_friction * delta)
	else:
		velocity.x = forward_speed

	var is_in_any_zone: bool = false
	if has_node("Area2D_Detector"):
		for area in $Area2D_Detector.get_overlapping_areas():
			if area is GameZone:
				is_in_any_zone = true
				break

	if not is_in_any_zone:
		if not is_on_floor():
			velocity.y += gravity * delta
		elif Input.is_key_pressed(KEY_UP):
			if is_fermata_active and (input_dir > 0.0 or velocity.x > 10.0):
				velocity.y = FERMATA_RIGHT_JUMP_VELOCITY
			else:
				velocity.y = JUMP_VELOCITY

	move_and_slide()

func _handle_flying_movement(delta: float) -> void:
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 1. WASD-Steuerung & Ausgleiten
	if input_vector != Vector2.ZERO:
		if input_vector.y < 0:
			input_vector.y *= fly_up_speed_factor
		velocity = velocity.move_toward(input_vector * fly_max_speed, fly_acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, fly_friction * fly_max_speed * delta)
		# Bremsung greift nur beim Aufstieg (Y < 0), damit Fallen durch Schwerkraft nicht blockiert wird
		if velocity.y < 0:
			velocity.y = move_toward(velocity.y, 0.0, fly_friction * fly_max_speed * delta)

	# 2. Einfeuer-Impuls (Taste E) für die Flugphysik
	if Input.is_physical_key_pressed(KEY_E) and not _boost_triggered_last_frame:
		velocity.y = -fly_boost_force
		_boost_triggered_last_frame = true
	elif not Input.is_physical_key_pressed(KEY_E):
		_boost_triggered_last_frame = false

	# 3. Permanente Schwerkraft nach unten (wenn nicht hoch gedrückt wird)
	if input_vector.y <= 0:
		velocity.y += fly_gravity * delta

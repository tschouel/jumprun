extends CharacterBody2D

# Schalter für Pfad- & Level-Zustände
@export var is_on_path: bool = false:
	set(value):
		is_on_path = value

# Direkt über den Szenenbaum eingebunden (Pfade ggf. anpassen)
@onready var walking_sprite: Node2D = $Walking
@onready var sliding_sprite: Node2D = $Sliding
@onready var flying_sprite: Node2D = $FlyingSprite

@export_group("Spiegelung & Grafik")
@export var keep_upright: bool = true

@export_group("Rhythmus & Tempo")
@export var bpm: float = 90.0
@export var units_per_bar: float = 200.0

@export_group("Sprung Einstellungen")
@export var beats_per_jump: float = 1.0  
@export var jump_height: float = 20.0 

@export_group("Fermate & Handsteuerung")
@export var fermata_right_jump_height: float = 35.0
@export var fermata_friction: float = 600.0
@export var fermata_acceleration: float = 1200.0

@export_group("FMOD Einstellungen")
@export var music_emitter: Node2D

var gravity: float
var JUMP_VELOCITY: float
var FERMATA_RIGHT_JUMP_VELOCITY: float
var forward_speed: float

# Zonen-Schalter
var is_fermata_active: bool = false
var is_flying_active: bool = false

# Modul-Referenzen
@onready var flying_module: FlyingMovement = $FlyingMovement
@onready var ground_module: GroundMovement = $GroundMovement
@onready var path_module: PathMovement = $PathMovement

var _last_global_x: float = 0.0

func _ready() -> void:
	_last_global_x = global_position.x
	if not is_on_path:
		_recalculate_physics()
	
	if flying_module:
		flying_module.setup(self)
	if ground_module:
		ground_module.setup(self)
	if path_module:
		path_module.setup(self)

func _recalculate_physics() -> void:
	var bar_duration = (60.0 / bpm) * 4.0
	forward_speed = units_per_bar / bar_duration
	var beat_duration = 60.0 / bpm
	var jump_duration = beat_duration * beats_per_jump
	gravity = (8.0 * jump_height) / (jump_duration * jump_duration)
	JUMP_VELOCITY = -(4.0 * jump_height) / jump_duration
	FERMATA_RIGHT_JUMP_VELOCITY = -(4.0 * fermata_right_jump_height) / jump_duration

func _physics_process(delta: float) -> void:
	# 1. Flug-Modus
	if is_flying_active:
		if flying_module:
			flying_module.process_movement(delta)
		move_and_slide()
		return

	# 2. Pfad- / Schlitten-Modus
	if is_on_path:
		if path_module:
			path_module.process_movement(delta)
		return

	# 3. Normaler Boden- / Fermata-Modus
	if ground_module:
		ground_module.process_movement(delta)

	move_and_slide()

## Schaltet exakt ein Sprite aktiv und blendet ausnahmslos ALLE anderen aus
func show_only_sprite(active_sprite: Node2D) -> void:
	var all_sprites: Array[Node2D] = []
	
	if walking_sprite: all_sprites.append(walking_sprite)
	if sliding_sprite: all_sprites.append(sliding_sprite)
	if flying_sprite: all_sprites.append(flying_sprite)

	# Sicherheitsnetz: Erfasse zusätzlich wirklich ALLE Sprite-Kinder des Players
	for child in get_children():
		if child is AnimatedSprite2D or child is Sprite2D:
			if not all_sprites.has(child):
				all_sprites.append(child)

	# Exakte Sichtbarkeit & Animationszustand setzen
	for s in all_sprites:
		if s == active_sprite:
			s.visible = true
			if s is AnimatedSprite2D and not s.is_playing():
				s.play()
		else:
			s.visible = false
			if s is AnimatedSprite2D:
				s.stop()

func _get_main_sprite_node() -> Node2D:
	return walking_sprite

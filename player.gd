extends CharacterBody2D
# Schalter für Pfad- & Level-Zustände
@export var is_on_path: bool = false:
	set(value):
		is_on_path = value
# Direkt über den Szenenbaum eingebunden
@onready var walking_sprite: Node2D = get_node_or_null("GroundMovement/Walk")
@onready var sliding_sprite: Node2D = get_node_or_null("Sliding/Slide")
@onready var flying_sprite: Node2D = get_node_or_null("FlyingSprite")
@export_group("Spiegelung & Grafik")
@export var keep_upright: bool = true
@export_group("Rhythmus & Tempo (Standardwerte - werden von Zonen überschrieben)")
@export var bpm: float = 90.0:
	set(value):
		bpm = value
		_recalculate_physics()
@export var units_per_bar: float = 200.0:
	set(value):
		units_per_bar = value
		_recalculate_physics()
@export_group("Sprung Einstellungen")
@export var beats_per_jump: float = 1.0
@export var jump_height: float = 20.0
@export_group("Fermate & Handsteuerung")
@export var fermata_right_jump_height: float = 35.0
@export var fermata_friction: float = 600.0
@export var fermata_acceleration: float = 1200.0
var gravity: float
var JUMP_VELOCITY: float
var FERMATA_RIGHT_JUMP_VELOCITY: float
var forward_speed: float
# Zonen-Schalter
var is_fermata_active: bool = false
var is_flying_active: bool = false
var is_driving_active: bool = false
var is_lane_active: bool = false
var is_ground_active: bool = true
# Modul-Referenzen
@onready var flying_module = $FlyingMovement
@onready var ground_module = $GroundMovement
@onready var path_module = $PathMovement
@onready var driving_module = $DrivingMovement
@onready var lane_module = $LaneMovement
var _last_global_x: float = 0.0

# --- Spiegelung asymmetrischer Collider bei Richtungswechsel ---
@onready var headcoll: CollisionPolygon2D = $Headcoll
@onready var footcoll: CollisionPolygon2D = $Footcoll
var _headcoll_original_polygon: PackedVector2Array
var _footcoll_original_polygon: PackedVector2Array
var _headcoll_original_x: float
var _footcoll_original_x: float
var _facing: int = 1  # 1 = rechts (Standard), -1 = links

func _ready() -> void:
	_last_global_x = global_position.x
	_headcoll_original_polygon = headcoll.polygon.duplicate()
	_footcoll_original_polygon = footcoll.polygon.duplicate()
	_headcoll_original_x = headcoll.position.x
	_footcoll_original_x = footcoll.position.x
	if not is_on_path:
		_recalculate_physics()
	if flying_module:
		flying_module.setup(self)
	if ground_module:
		ground_module.setup(self)
	if path_module:
		path_module.setup(self)
	if driving_module:
		driving_module.setup(self)
	if lane_module:
		lane_module.setup(self)
	_check_default_sprite_state()

## Wird von den Movement-Modulen aufgerufen, sobald sich die Blickrichtung ändert.
## dir: 1 = nach rechts, -1 = nach links
func set_facing(dir: int) -> void:
	if dir == _facing:
		return
	_facing = dir
	_mirror_collider(headcoll, _headcoll_original_polygon, _headcoll_original_x)
	_mirror_collider(footcoll, _footcoll_original_polygon, _footcoll_original_x)

func _mirror_collider(node: CollisionPolygon2D, original_polygon: PackedVector2Array, original_x: float) -> void:
	if _facing == 1:
		node.polygon = original_polygon
		node.position.x = original_x
	else:
		var mirrored := PackedVector2Array()
		for p in original_polygon:
			mirrored.append(Vector2(-p.x, p.y))
		node.polygon = mirrored
		node.position.x = -original_x

func _recalculate_physics() -> void:
	if bpm <= 0.0:
		return
	var bar_duration = (60.0 / bpm) * 4.0
	forward_speed = units_per_bar / bar_duration
	var beat_duration = 60.0 / bpm
	var jump_duration = beat_duration * beats_per_jump
	if jump_duration > 0.0:
		gravity = (8.0 * jump_height) / (jump_duration * jump_duration)
		JUMP_VELOCITY = -(4.0 * jump_height) / jump_duration
		FERMATA_RIGHT_JUMP_VELOCITY = -(4.0 * fermata_right_jump_height) / jump_duration
## Zwingt den Player sofort auf das neue Tempo der Zone
func set_zone_tempo(new_bpm: float, new_units_per_bar: float) -> void:
	self.bpm = new_bpm
	self.units_per_bar = new_units_per_bar
func _physics_process(delta: float) -> void:
	# 1. 5-Linien- / Lane-Modus (Blockiert alle Standard-Sprites darunter!)
	if is_lane_active:
		if lane_module:
			lane_module.process_movement(delta)
		move_and_slide()
		return
	# 2. Fahr- / Driving-Modus (Auto)
	if is_driving_active:
		if driving_module:
			driving_module.process_movement(delta)
		move_and_slide()
		return
	# 3. Flug-Modus
	if is_flying_active:
		if flying_module:
			flying_module.process_movement(delta)
		move_and_slide()
		return
	# 4. Pfad- / Schlitten-Modus (auf vorgegebenem Pfad)
	if is_on_path:
		if path_module:
			path_module.process_movement(delta)
		return
	# 5. Normaler Boden-Modus (Standard = Sliding / Schlittern, ausser Fermata ist aktiv)
	_check_default_sprite_state()
	if ground_module:
		ground_module.process_movement(delta)
	move_and_slide()
## Steuert das Sprite ausserhalb von Spezialzonen: Fermata = Walking, sonst IMMER Sliding
## Steuert das Grund-Sprite: Wenn Ground oder Fermata aktiv ist -> Walking, sonst Sliding
func _check_default_sprite_state() -> void:
	var target_sprite: Node2D = null
	if is_ground_active or is_fermata_active:
		if not walking_sprite or not is_instance_valid(walking_sprite):
			walking_sprite = get_node_or_null("GroundMovement/Walk")
		target_sprite = walking_sprite
	else:
		if not sliding_sprite or not is_instance_valid(sliding_sprite):
			sliding_sprite = get_node_or_null("Sliding/Slide")
		target_sprite = sliding_sprite
	if target_sprite:
		show_only_sprite(target_sprite)
func _get_main_sprite_node() -> Node2D:
	if not walking_sprite or not is_instance_valid(walking_sprite):
		walking_sprite = get_node_or_null("GroundMovement/Walk")
	return walking_sprite
## Schaltet exakt ein Sprite aktiv und blendet ausnahmslos ALLE anderen aus
func show_only_sprite(active_sprite: Node2D) -> void:
	if not active_sprite:
		return
	# Stelle sicher, dass die Grund-Referenzen geladen sind
	if not walking_sprite or not is_instance_valid(walking_sprite):
		walking_sprite = get_node_or_null("GroundMovement/Walk")
	if not sliding_sprite or not is_instance_valid(sliding_sprite):
		sliding_sprite = get_node_or_null("Sliding/Slide")
	if not flying_sprite or not is_instance_valid(flying_sprite):
		flying_sprite = get_node_or_null("FlyingSprite")
	var all_sprites: Array[Node2D] = []
	if walking_sprite: all_sprites.append(walking_sprite)
	if sliding_sprite: all_sprites.append(sliding_sprite)
	if flying_sprite: all_sprites.append(flying_sprite)
	# Erfasse zusätzlich ALLE Sprite-Kinder des Players und seiner Unter-Module (inkl. LaneSprite)
	for child in get_children():
		if child is AnimatedSprite2D or child is Sprite2D:
			if not all_sprites.has(child):
				all_sprites.append(child)
		for sub in child.get_children():
			if sub is AnimatedSprite2D or sub is Sprite2D:
				if not all_sprites.has(sub):
					all_sprites.append(sub)
	# Exakte Sichtbarkeit & Animationszustand setzen
	for s in all_sprites:
		if s == active_sprite or s.name == active_sprite.name:
			if not s.visible:
				s.visible = true
			if s is AnimatedSprite2D:
				if not s.is_playing():
					s.play()
		else:
			if s.visible:
				s.visible = false
			if s is AnimatedSprite2D:
				s.stop()

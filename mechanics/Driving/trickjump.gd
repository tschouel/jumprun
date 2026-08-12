class_name TrickJump
extends Area2D

@export_group("Trick Jump Einstellungen")
## Aufwärts-Impuls (-180 = flacher Sprung)
@export var jump_impulse: float = -180.0
## FMOD-Parameter für den erfolgreichen Backflip
@export var trick_fmod_param: String = "Yeah"

@export_group("Safe Ground Einstellungen")
## Zuweisung des Safe-Bodens im Inspektor (Fallback: automatische Suche nach Geschwisternode "Safe")
@export var safe_ground: StaticBody2D

@export_group("FMOD Einstellungen")
@export var fmod_emitter: FmodEventEmitter2D

# Interner Status
var current_player: CharacterBody2D = null
var player_sprite: Node2D = null
var trick_completed: bool = false
var circle_step: int = 0
var initial_sprite_rotation: float = 0.0


func _ready() -> void:
	# Fallback: Falls safe_ground nicht im Inspektor zugewiesen ist, suche '../Safe'
	if not safe_ground:
		safe_ground = get_node_or_null("../Safe") as StaticBody2D

	# Safe-Boden beim Start unsichtbar machen & Physik deaktivieren
	_set_safe_ground_active(false)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		current_player = body
		trick_completed = false
		circle_step = 0
		
		# Impuls geben
		current_player.velocity.y = jump_impulse
		
		# Sprite-Node finden und Startrotation merken
		player_sprite = _find_sprite_node(current_player)
		if player_sprite:
			initial_sprite_rotation = player_sprite.rotation_degrees
		elif current_player:
			initial_sprite_rotation = current_player.rotation_degrees


func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		# Ausgangsrotation beim Verlassen exakt wiederherstellen
		_apply_rotation_offset(0.0)
		current_player = null
		player_sprite = null


func _unhandled_input(event) -> void:
	if not current_player or trick_completed:
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		_check_input_step(event.keycode)


func _check_input_step(keycode: int) -> void:
	# Schritt 0: Oben (W oder Pfeil Oben) -> -90°
	# Schritt 1: Links (A oder Pfeil Links) -> -180°
	# Schritt 2: Unten (S oder Pfeil Unten) -> -270°
	# Schritt 3: Rechts (D oder Pfeil Rechts) -> 0° / Erfolg
	match circle_step:
		0:
			if keycode == KEY_W or keycode == KEY_UP:
				circle_step = 1
				_apply_rotation_offset(-90.0)
				print("[TRICK] Oben gedrückt (W / Pfeil Oben)")
		1:
			if keycode == KEY_A or keycode == KEY_LEFT:
				circle_step = 2
				_apply_rotation_offset(-180.0)
				print("[TRICK] Links gedrückt (A / Pfeil Links)")
		2:
			if keycode == KEY_S or keycode == KEY_DOWN:
				circle_step = 3
				_apply_rotation_offset(-270.0)
				print("[TRICK] Unten gedrückt (S / Pfeil Unten)")
		3:
			if keycode == KEY_D or keycode == KEY_RIGHT:
				circle_step = 4
				_apply_rotation_offset(0.0)
				_on_trick_success()


func _apply_rotation_offset(offset_deg: float) -> void:
	var target_deg = initial_sprite_rotation + offset_deg
	if player_sprite:
		player_sprite.rotation_degrees = target_deg
	elif current_player:
		current_player.rotation_degrees = target_deg


func _on_trick_success() -> void:
	trick_completed = true
	_apply_rotation_offset(0.0)
	print("[TRICK JUMP] Backflip geklappt! 'Yeah' -> 1.0 & Safe-Boden aktiviert")
	
	# Safe-Boden freischalten
	_set_safe_ground_active(true)
	
	_send_fmod_param(trick_fmod_param, 1.0)


func _set_safe_ground_active(active: bool) -> void:
	if not safe_ground:
		printerr("[TRICK JUMP] Warnung: Kein 'Safe'-StaticBody2D gefunden!")
		return
		
	# 1. Visuell ein-/ausblenden
	safe_ground.visible = active
	
	# 2. Prozess/Physik der Node deaktivieren/aktivieren
	safe_ground.process_mode = PROCESS_MODE_INHERIT if active else PROCESS_MODE_DISABLED
	
	# 3. Alle untergeordneten CollisionShapes gezielt toggeln
	for child in safe_ground.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", not active)


func _send_fmod_param(param_name: String, value: float) -> void:
	if fmod_emitter:
		fmod_emitter.set_parameter(param_name, value)
	elif current_player and current_player.get("music_emitter") and current_player.music_emitter:
		current_player.music_emitter.set_parameter(param_name, value)

	if ClassDB.class_exists("FmodServer"):
		FmodServer.set_global_parameter_by_name(param_name, value)


func _find_sprite_node(node: Node) -> Node2D:
	if node is Sprite2D or node is AnimatedSprite2D:
		return node as Node2D
	for child in node.get_children():
		var found = _find_sprite_node(child)
		if found:
			return found
	return null

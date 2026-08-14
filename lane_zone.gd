class_name LaneZone
extends Area2D

enum NextMovementType {
	GROUND,
	PATH,
	FLYING,
	NONE
}

@export_group("Folge-Bewegung nach der Zone")
## Wähle hier im Inspektor aus, welche Physik nach dieser LaneZone aktiv werden soll:
@export var next_movement: NextMovementType = NextMovementType.GROUND

@export_group("Rhythmus & Tempo")
@export var bpm: float = 115.0
@export var units_per_bar: float = 400.0

@export_group("Lane Konfiguration")
@export var lane_y_positions: Array[float] = [240.0, 440.0, 640.0, 840.0]
@export var default_start_lane: int = 1

@export_group("Blockaden & Visuelles")
@export var startblock_collision: CollisionShape2D 
@export var background_lines: Node2D 

@export_group("FMOD / Audio")
@export var audio_controller: Node 

var _is_player_inside: bool = false
var _is_crashing: bool = false
var _is_transitioning: bool = false
var _is_driving: bool = false
var _active_player: CharacterBody2D = null

func _ready() -> void:
	add_to_group("lane_zones")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	# Startblock zu Beginn aktiv
	if startblock_collision:
		startblock_collision.set_deferred("disabled", false)

	# Backgroundlines vorbereiten
	if not background_lines:
		background_lines = get_tree().current_scene.find_child("Backgroundlines", true, false) as Node2D
	if background_lines:
		background_lines.visible = true
		background_lines.modulate.a = 0.5

	# AudioController finden
	if not audio_controller:
		audio_controller = get_tree().get_first_node_in_group("audio_controller")

	await get_tree().process_frame
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			_on_body_entered(body)
			break

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _is_player_inside and _active_player and not _is_transitioning and not _is_driving:
			_start_lane_sequence()

func _on_body_entered(body: Node2D) -> void:
	if _is_player_inside or _is_crashing:
		return

	if body is CharacterBody2D:
		_is_player_inside = true
		_active_player = body

		if body.has_method("set_zone_tempo"):
			body.set_zone_tempo(bpm, units_per_bar)

		# Alle bisherigen Bewegungen stoppen (Fermata aktiv)
		body.set("is_driving_active", false)
		body.set("is_flying_active", false)
		body.set("is_ground_active", false)
		body.set("is_on_path", false)
		body.set("is_lane_active", false)
		body.set("is_fermata_active", true)

		# Lane-Modul initialisieren
		var lane_module = body.get_node_or_null("LaneMovement")
		if lane_module:
			lane_module.lane_y_positions = lane_y_positions
			lane_module.current_lane = default_start_lane
			if lane_module.has_method("set_active"):
				lane_module.set_active(true)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body == _active_player:
		_exit_lane_sequence(body)

func _start_lane_sequence() -> void:
	if not _active_player:
		return

	_is_transitioning = true

	# 1. FMOD Go = 1 senden
	if audio_controller and audio_controller.has_method("set_go"):
		audio_controller.set_go(1.0)

	# 2. Startblock freigeben
	if startblock_collision:
		startblock_collision.set_deferred("disabled", true)

	# 3. Vorwärts-Transition abspielen
	var lane_module = _active_player.get_node_or_null("LaneMovement")
	var anim_duration: float = 0.5

	if lane_module and lane_module.has_method("start_transition"):
		lane_module.start_transition()

		var sprite = lane_module.get_node_or_null("LaneSprite") as AnimatedSprite2D
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("trans"):
			var frame_count = sprite.sprite_frames.get_frame_count("trans")
			var fps = sprite.sprite_frames.get_animation_speed("trans")
			if fps > 0:
				anim_duration = float(frame_count) / fps

	await get_tree().create_timer(anim_duration).timeout

	# 4. Backgroundlines einblenden
	if not background_lines:
		background_lines = get_tree().current_scene.find_child("Backgroundlines", true, false) as Node2D

	if background_lines:
		var tween = create_tween()
		tween.tween_property(background_lines, "modulate:a", 1.0, 0.2)

	_is_transitioning = false
	_is_driving = true

## Rückwärts-Animation und Aktivierung des Folgemodus
func _exit_lane_sequence(player: CharacterBody2D) -> void:
	_is_player_inside = false
	_is_driving = false
	_is_transitioning = false

	# 1. LaneMovement stoppen
	var lane_module = player.get_node_or_null("LaneMovement")
	var anim_duration: float = 0.5

	if lane_module:
		if lane_module.has_method("set_active"):
			lane_module.set_active(false)
		
		# Rückwärts-Animation "trans" abspielen
		var sprite = lane_module.get_node_or_null("LaneSprite") as AnimatedSprite2D
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("trans"):
			sprite.play_backwards("trans")
			var frame_count = sprite.sprite_frames.get_frame_count("trans")
			var fps = sprite.sprite_frames.get_animation_speed("trans")
			if fps > 0:
				anim_duration = float(frame_count) / fps

	# 2. Dauer der Rückwärts-Animation abwarten
	await get_tree().create_timer(anim_duration).timeout

	# 3. Ziel-Physikmodus aktivieren
	match next_movement:
		NextMovementType.GROUND:
			player.set("is_ground_active", true)
			player.set("is_lane_active", false)
			var ground_module = player.get_node_or_null("GroundMovement")
			if ground_module and ground_module.has_method("set_active"):
				ground_module.set_active(true)
			print("[LaneZone] Folge-Modus aktiviert: GROUND")

		NextMovementType.PATH:
			player.set("is_on_path", true)
			player.set("is_lane_active", false)
			print("[LaneZone] Folge-Modus aktiviert: PATH")

		NextMovementType.FLYING:
			player.set("is_flying_active", true)
			player.set("is_lane_active", false)
			print("[LaneZone] Folge-Modus aktiviert: FLYING")

		NextMovementType.NONE:
			print("[LaneZone] Kein Folge-Modus gewählt.")

	_active_player = null

func trigger_crash_and_reload(player: Node2D) -> void:
	if _is_crashing:
		return

	_is_crashing = true
	_is_driving = false
	_is_transitioning = false

	if player is CharacterBody2D:
		if "forward_speed" in player:
			player.forward_speed = 0.0
		player.velocity = Vector2.ZERO

	var lane_module = player.get_node_or_null("LaneMovement")
	if lane_module and lane_module.has_method("trigger_crash"):
		lane_module.trigger_crash()

	await get_tree().create_timer(0.6).timeout
	get_tree().reload_current_scene()

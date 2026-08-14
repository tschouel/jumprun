class_name LaneZone
extends Area2D

@export_group("Rhythmus & Tempo")
@export var bpm: float = 115.0
@export var units_per_bar: float = 400.0

@export_group("Lane Konfiguration")
@export var lane_y_positions: Array[float] = [240.0, 440.0, 640.0, 840.0]
@export var default_start_lane: int = 1

@export_group("Blockaden & Visuelles")
## Ziehe hier die CollisionShape2D deines Startblocks rein
@export var startblock_collision: CollisionShape2D 
## Ziehe hier deine Backgroundlines-Node rein (falls leer, wird gesucht)
@export var background_lines: Node2D 

@export_group("FMOD / Audio")
## Ziehe hier die Node 'FmodEventEmitter2D' rein
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
	
	# Startblock zu Beginn AKTIV schalten
	if startblock_collision:
		startblock_collision.set_deferred("disabled", false)
		
	# Backgroundlines vorbereiten (Alpha 0.5)
	if not background_lines:
		background_lines = get_tree().current_scene.find_child("Backgroundlines", true, false) as Node2D
	if background_lines:
		background_lines.visible = true
		background_lines.modulate.a = 0.5
		
	# Emitter automatisch finden falls nicht manuell zugewiesen
	if not audio_controller:
		audio_controller = get_tree().current_scene.find_child("FmodEventEmitter2D", true, false)
	
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

		body.set("is_driving_active", false)
		body.set("is_flying_active", false)
		body.set("is_fermata_active", true)
		body.set("is_on_path", false)
		body.set("is_lane_active", false)

		var lane_module = body.get_node_or_null("LaneMovement")
		if lane_module:
			lane_module.lane_y_positions = lane_y_positions
			lane_module.current_lane = default_start_lane
			if lane_module.has_method("set_active"):
				lane_module.set_active(true)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body == _active_player:
		_is_player_inside = false
		_is_driving = false
		_is_transitioning = false

		if "is_lane_active" in body:
			body.is_lane_active = false

		var lane_module = body.get_node_or_null("LaneMovement")
		if lane_module and lane_module.has_method("set_active"):
			lane_module.set_active(false)

		_active_player = null

func _start_lane_sequence() -> void:
	if not _active_player:
		return

	_is_transitioning = true

	# 1. FMOD Go = 1 über den Controller setzen
	if audio_controller and audio_controller.has_method("set_go"):
		audio_controller.set_go(1.0)

	# 2. Startblock deaktivieren
	if startblock_collision:
		startblock_collision.set_deferred("disabled", true)

	# 3. Transition im LaneMovement auslösen
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

	# 4. Warten für Animationsdauer
	await get_tree().create_timer(anim_duration).timeout

	# 5. Backgroundlines auf 100% einblenden
	if not background_lines:
		background_lines = get_tree().current_scene.find_child("Backgroundlines", true, false) as Node2D

	if background_lines:
		var tween = create_tween()
		tween.tween_property(background_lines, "modulate:a", 1.0, 0.2)

	_is_transitioning = false
	_is_driving = true

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

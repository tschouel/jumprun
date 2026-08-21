extends Area2D
## Kombinierter Trigger: Drückt das Ventil runter (wie valve_trigger.gd) UND
## startet danach ein zugewiesenes Video - alles in einer Node, ausgelöst vom
## selben body_entered-Event. Aktiviert optional zusätzlich einen WindPath-
## Entry, genau wie beim Original.
##
## Setup: Node ans/ins Ventil legen (Collision-Shape drauf), "Valve" im
## Inspector zuweisen (oder Fallback: Node liegt als Kind am Ventil),
## "Target Sprite" + Start-/Loop-Animationsnamen zuweisen, VideoStreamPlayer
## + Stream zuweisen - fertig.

@export_group("Ventil")
@export var valve: AnimatableBody2D        # Das Ventil selbst (z.B. Valve1), das runtergedrückt wird
@export var valve_id: int = 1              # 1, 2 oder 3 - später nützlich für FMOD (welche Note/welches Sample)
@export var press_distance: float = 15.0   # Wie tief das Ventil gedrückt wird
@export var press_duration: float = 0.15   # Schnell, wie ein knackiger Tastendruck
@export var wind_path_entry: Area2D        # -> WindPathEntry, aktiviert den Windpfad

@export_group("Animation")
@export var target_sprite: AnimatedSprite2D # Beliebiges AnimatedSprite2D, das beim Trigger animiert wird
@export var start_animation: String = "ventdown"  # Einmal-Animation, die beim Druck startet
@export var loop_animation: String = "ventil"     # Läuft danach dauerhaft im Loop

@export_group("Video")
@export var video_player: VideoStreamPlayer
@export var video_stream: VideoStream
## Falls true, startet das Video nach Ende automatisch neu (Loop-Hintergrund).
@export var loop: bool = false
## Falls true, wird der VideoStreamPlayer nach Ende wieder unsichtbar (nur
## relevant, wenn loop = false).
@export var hide_on_finish: bool = true
## Optionale Verzögerung, bevor das Video nach dem vollständigen Ventil-Druck
## tatsächlich startet.
@export var start_delay: float = 0.0

var is_pressed: bool = false

func _ready() -> void:
	if not valve:
		valve = get_parent()  # Fallback: Node liegt als Kind am Ventil
	if not video_player:
		video_player = get_node_or_null("VideoStreamPlayer") as VideoStreamPlayer
	if not video_player:
		push_warning("ValveVideoStart: Kein VideoStreamPlayer gefunden - bitte im Inspector zuweisen.")
	else:
		if video_stream:
			video_player.stream = video_stream
		# Vor dem ersten Trigger unsichtbar/gestoppt, damit nicht schon beim
		# Szenenstart ein Frame des Videos aufblitzt.
		video_player.visible = false
		video_player.stop()
		if not video_player.finished.is_connected(_on_video_finished):
			video_player.finished.connect(_on_video_finished)
	if not target_sprite:
		push_warning("ValveVideoStart: 'Target Sprite' ist im Inspector nicht zugewiesen - Animation wird nicht abgespielt.")
	else:
		if not target_sprite.animation_finished.is_connected(_on_anim_finished):
			target_sprite.animation_finished.connect(_on_anim_finished)
		# Vor dem ersten Trigger nichts anzeigen (kein Autoplay-Rest wie "stand"/"ventil").
		target_sprite.stop()
		target_sprite.visible = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_pressed:
		is_pressed = true
		press_valve()

func press_valve() -> void:
	var target_y = valve.position.y + press_distance
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(valve, "position:y", target_y, press_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_on_valve_fully_pressed)

func _on_valve_fully_pressed() -> void:
	if wind_path_entry and wind_path_entry.has_method("activate"):
		wind_path_entry.activate()
	if target_sprite:
		target_sprite.visible = true
		target_sprite.play(start_animation)
	# Visueller Effekt: Video starten (an derselben Stelle, wo vorher der
	# "HIER SPÄTER"-Platzhalter stand). FMOD-Event später ebenfalls hier.
	start_video()

func _on_anim_finished() -> void:
	# start_animation ist kein Loop (siehe SpriteFrames-Panel) -> feuert genau
	# einmal, danach nahtlos in loop_animation (Loop aktiviert) wechseln.
	if target_sprite.animation == start_animation:
		target_sprite.play(loop_animation)

func start_video() -> void:
	if not video_player or not video_player.stream:
		push_warning("ValveVideoStart: start_video() aufgerufen, aber kein Player/Stream vorhanden.")
		return
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	video_player.visible = true
	video_player.play()

func stop_video() -> void:
	if video_player:
		video_player.stop()
		video_player.visible = false

func _on_video_finished() -> void:
	if loop:
		video_player.play()
		return
	if hide_on_finish and video_player:
		video_player.visible = false

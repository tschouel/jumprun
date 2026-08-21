extends Area2D
@export var valve: AnimatableBody2D        # Das Ventil selbst (z.B. Valve1), das runtergedrückt wird
@export var valve_id: int = 1              # 1, 2 oder 3 - später nützlich für FMOD (welche Note/welches Sample)
@export var press_distance: float = 15.0   # Wie tief das Ventil gedrückt wird
@export var press_duration: float = 0.15   # Schnell, wie ein knackiger Tastendruck
@export var wind_path_entry: Area2D        # -> WindPathEntry, aktiviert den Windpfad

@export_group("Animation")
@export var target_sprite: AnimatedSprite2D # Beliebiges AnimatedSprite2D, das beim Trigger animiert wird
@export var start_animation: String = "aufbau"  # Einmal-Animation, die beim Druck startet
@export var loop_animation: String = "stand"    # Läuft danach dauerhaft im Loop

var is_pressed: bool = false

func _ready() -> void:
	if not valve:
		valve = get_parent()  # Fallback: ValveTrigger liegt als Kind am Ventil
	if not target_sprite:
		push_warning("Valvetrigger: 'Target Sprite' ist im Inspector nicht zugewiesen - Animation wird nicht abgespielt.")
	else:
		if not target_sprite.animation_finished.is_connected(_on_anim_finished):
			target_sprite.animation_finished.connect(_on_anim_finished)
		# Vor dem ersten Trigger nichts anzeigen (kein Autoplay-Rest wie "stand").
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
	# HIER SPÄTER: FMOD-Event abspielen + visuellen Effekt auslösen
	# z.B. je nach valve_id eine andere Note/Sample triggern

func _on_anim_finished() -> void:
	# start_animation ist kein Loop (siehe SpriteFrames-Panel) -> feuert genau
	# einmal, danach nahtlos in loop_animation (Loop aktiviert) wechseln.
	if target_sprite.animation == start_animation:
		target_sprite.play(loop_animation)

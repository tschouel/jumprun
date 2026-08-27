extends Area2D

@export_group("Trigger 1")
@export var anim_player: AnimationPlayer
@export var animation_name: String = "taste_bewegung"
@export var trigger: Area2D
@export var pre_delay: float = 0.0

@export_group("Fader-Bedingung 1")
@export var fader: Fader
@export_range(0.0, 1.0) var min_value: float = 0.5
@export_range(0.0, 1.0) var max_value: float = 1.0

@export_group("Trigger 2")
@export var anim_player_2: AnimationPlayer
@export var animation_name_2: String = "taste_bewegung_2"
@export var trigger_2: Area2D
@export var pre_delay_2: float = 0.0

@export_group("Fader-Bedingung 2")
@export var fader_2: Fader
@export_range(0.0, 1.0) var min_value_2: float = 0.5
@export_range(0.0, 1.0) var max_value_2: float = 1.0

var _has_triggered: bool = false
var _has_triggered_2: bool = false
var _anim_1_finished: bool = false

func _ready() -> void:
	if not anim_player:
		anim_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not trigger:
		trigger = get_node_or_null("%TasteTrigger") as Area2D
	if trigger:
		trigger.body_entered.connect(_on_trigger_body_entered)
	if anim_player:
		anim_player.animation_finished.connect(_on_anim_1_finished)

	if not anim_player_2:
		anim_player_2 = get_node_or_null("AnimationPlayer2") as AnimationPlayer
	if not trigger_2:
		trigger_2 = get_node_or_null("%TasteTrigger2") as Area2D
	if trigger_2:
		trigger_2.body_entered.connect(_on_trigger_2_body_entered)

func _on_trigger_body_entered(body: Node2D) -> void:
	if _has_triggered:
		return
	if not body.is_in_group("player"):
		return
	if not _fader_in_range(fader, min_value, max_value):
		return

	_has_triggered = true
	if trigger:
		trigger.set_deferred("monitoring", false)

	if pre_delay > 0.0:
		await get_tree().create_timer(pre_delay).timeout

	if anim_player:
		anim_player.play(animation_name)

func _on_trigger_2_body_entered(body: Node2D) -> void:
	if _has_triggered_2:
		return
	if not body.is_in_group("player"):
		return
	if not body.is_in_group("player"):
		return
	if _anim_1_finished:
		return  # Animation 2 nur möglich, solange Animation 1 noch nicht abgeschlossen ist
	if not _fader_in_range(fader_2, min_value_2, max_value_2):
		return

	_has_triggered_2 = true
	if trigger_2:
		trigger_2.set_deferred("monitoring", false)

	if pre_delay_2 > 0.0:
		await get_tree().create_timer(pre_delay_2).timeout

	if anim_player_2:
		anim_player_2.play(animation_name_2)

func _on_anim_1_finished(anim_name: String) -> void:
	if anim_name == animation_name:
		_anim_1_finished = true

func _fader_in_range(f: Fader, min_v: float, max_v: float) -> bool:
	if not f:
		return true  # Kein Fader zugewiesen -> Bedingung übersprungen
	return f.value >= min_v and f.value <= max_v

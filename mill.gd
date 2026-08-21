extends Node2D
class_name Muehle
## Dreht die vier angehängten Achsen-Geraden (als Kinder dieser Node) wie
## ein Mühlerad gemeinsam um jeweils 90°. Nur der Arm, der gerade "vorne"
## steht, ist für den Spieler physisch erreichbar - die anderen drei
## schwenken beim Drehen automatisch weg. Reine Geometrie, keine
## zusätzliche Logik nötig, welche Achse gerade aktiv ist: die Buttons auf
## den weggedrehten Armen bleiben zwar technisch funktionsfähig, sind aber
## schlicht nicht erreichbar.
##
## Die Buttons drehen sich mit dem jeweiligen Arm mit (liegen also quer/
## kopfüber, solange ihr Arm nicht vorne ist) - so wie ein echtes
## Mühlenrad sich als Ganzes dreht.
##
## Die 2 Dreh-Buttons ("davor") sind normale DiscTrigger-Keys (gleiches
## .gd, gleiche Absinkmechanik) und bleiben fix an ihrem Platz - sie sind
## NICHT Kinder dieser Mühle. Setz bei beiden im Inspector "Momentary" auf
## true, damit sie nach dem Verlassen von selbst wieder hochfedern und
## erneut gedrückt werden können. Zieh sie dann einfach in die zwei Felder
## unten.
##
## Setup: Die 4 Geraden (deine bestehenden Button-Reihen) als Kinder dieser
## Node anlegen, in der Szene um 0°/90°/180°/270° vorgedreht platzieren
## (Rotation-Feld jeder Geraden im Inspector), damit von Anfang an eine
## Gerade "vorne" (Richtung Spieler) steht.

@export var rotate_forward_trigger: Area2D
@export var rotate_backward_trigger: Area2D

## Wie weit pro Dreh-Schritt gedreht wird - normalerweise 90°, ein Schritt
## pro Arm.
@export var rotation_step_degrees: float = 90.0
@export var rotation_duration: float = 0.4

## Sperrzeit NACH einer fertigen Drehung, bevor der nächste Trigger wieder
## angenommen wird - filtert kurze Doppel-Auslöser raus (z.B. wenn der
## Spieler beim Wegspringen die Trigger-Fläche nochmal kurz streift).
@export var post_rotation_cooldown: float = 0.3

var _is_rotating: bool = false

func _ready() -> void:
	if rotate_forward_trigger:
		rotate_forward_trigger.body_entered.connect(_on_forward_entered)
	else:
		push_warning("Muehle: 'Rotate Forward Trigger' ist im Inspector nicht zugewiesen.")
	if rotate_backward_trigger:
		rotate_backward_trigger.body_entered.connect(_on_backward_entered)
	else:
		push_warning("Muehle: 'Rotate Backward Trigger' ist im Inspector nicht zugewiesen.")

func _on_forward_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_rotate_step(1.0)

func _on_backward_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_rotate_step(-1.0)

func _rotate_step(direction: float) -> void:
	if _is_rotating:
		return
	_is_rotating = true
	var target_rotation := rotation + direction * deg_to_rad(rotation_step_degrees)
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "rotation", target_rotation, rotation_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_on_rotation_finished)

func _on_rotation_finished() -> void:
	if post_rotation_cooldown > 0.0:
		await get_tree().create_timer(post_rotation_cooldown).timeout
	_is_rotating = false

extends Area2D
## Trigger-Button für die Disc-Arrays (shape_triggers / style_triggers /
## pattern_triggers / rotation_triggers). Reduzierte Kopie von
## Valvetrigger.gd: die Absink-Mechanik (Tween drückt "valve" runter) bleibt
## erhalten, alles rund um Sprite-Animation/WindPath/Video ist raus, weil
## das hier nicht gebraucht wird.
##
## Radio-Button-Verhalten: Liegen mehrere Keys nebeneinander, von denen
## immer nur einer "unten" sein darf (z.B. die 4 Keys einer Achse), gib
## ihnen im Inspector alle denselben "Key Group"-Namen. Wird einer davon
## gedrückt, kommen alle anderen mit demselben Namen automatisch wieder
## hoch. Leer lassen = Key verhält sich unabhängig (kein Auto-Hochkommen).
##
## "Momentary" (Taster statt Radio-Button): Wenn aktiviert, kommt DIESER
## Key von selbst wieder hoch, sobald der Spieler ihn verlässt - für Keys,
## die man wiederholt drücken will (z.B. die Dreh-Buttons einer Mühle),
## statt fest ausgewählt zu bleiben.
##
## Setup: Node wie gehabt ans/ins zu drückende Objekt legen (Collision-Shape
## drauf), "Valve" im Inspector zuweisen (oder Fallback: Node liegt als Kind
## am Objekt). Danach diese Node direkt in einen der vier Trigger-Slots auf
## der Disc ziehen (Disc hört selbst auf body_entered - keine weitere
## Zuweisung hier nötig).
@export var valve: AnimatableBody2D        # Das Objekt, das beim Trigger runtergedrückt wird
@export var press_distance: float = 15.0   # Wie tief gedrückt wird
@export var press_duration: float = 0.15   # Schnell, wie ein knackiger Tastendruck
@export var key_group: String = ""         # Gleicher Name bei allen Keys einer Achse = nur einer gleichzeitig unten
@export var momentary: bool = false        # true = federt beim Verlassen automatisch wieder hoch (wiederholt drückbar)

var is_pressed: bool = false
var base_y: float = 0.0                    # Ausgangsposition (oben), um sauber zurückzufahren

func _ready() -> void:
	if not valve:
		valve = get_parent()  # Fallback: Trigger liegt als Kind am Objekt
	base_y = valve.position.y
	if key_group != "":
		add_to_group(key_group)
	body_entered.connect(_on_body_entered)
	if momentary:
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_pressed:
		is_pressed = true
		_release_other_keys()
		press_valve()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		release_key()

func press_valve() -> void:
	var target_y = base_y + press_distance
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(valve, "position:y", target_y, press_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_on_valve_fully_pressed)

func _on_valve_fully_pressed() -> void:
	pass # HIER SPÄTER: z.B. FMOD-Klick-Sound beim vollständigen Drücken

## Fährt DIESEN Key wieder hoch - wird von einem anderen Key derselben
## key_group aufgerufen, wenn der gedrückt wird (siehe _release_other_keys).
func release_key() -> void:
	if not is_pressed:
		return
	is_pressed = false
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(valve, "position:y", base_y, press_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _release_other_keys() -> void:
	if key_group == "":
		return
	for node in get_tree().get_nodes_in_group(key_group):
		if node != self and node.has_method("release_key"):
			node.release_key()

extends Node2D
## Steuert Form (Maske), Muster (Füllung) und Rotationsverhalten einer
## Scheibe - ausgelöst durch bis zu 16 Trigger-Areas (4 pro Achse), die im
## Inspector zugewiesen werden. Jeder Trigger setzt beim Betreten direkt
## seinen festen Ziel-Wert (kein Durchschalten wie vorher testweise über
## Tasten).
##
## Achse 1 (Grundform: 3/4/5/6) und Achse 2 (Stil: fat/norm/thin/spez) sind
## ZWEI unabhängige Wahlmöglichkeiten, keine durchlaufende Kette - deshalb
## zwei getrennte Indizes (shape_index, style_index), die zusammen den
## richtigen Eintrag im 16er mask_textures-Array errechnen.
##
## Reihenfolge beim Befüllen im Inspector (so wie du's auch anlegst):
## shape_index 0-3 = 3/4/5/6 Ecken, style_index 0-3 = fat/norm/thin/spez.
## Die ersten 4 Elemente (Index 0-3) gehören alle zur ERSTEN Grundform
## (3 Ecken, in den 4 Stilen fat/norm/thin/spez), Elemente 4-7 zur zweiten
## Grundform (4 Ecken), usw. Kurz: Array-Index = shape_index * 4 + style_index.

## Die Sprite2D-Node aus Schritt 1, die das ShaderMaterial trägt (zeigt
## das Muster, das "mask_texture"-Shader-Parameter schneidet die Form aus).
@export var pattern_sprite: Sprite2D

## Achse 4 (Rotationsverhalten): läuft immer, unabhängig von Form/Stil/
## Muster. FLIESSEND = gleichmässige Dauerdrehung, STOCKEND = springt nur
## im BPM-Takt ein Stück weiter und steht dazwischen still.
enum RotationMode { FLIESSEND_RECHTS, FLIESSEND_LINKS, STOCKEND_RECHTS, STOCKEND_LINKS }

@export var rotation_mode: RotationMode = RotationMode.FLIESSEND_RECHTS

## Nur relevant im FLIESSEND-Modus: Grad pro Sekunde.
@export var rotation_speed_degrees: float = 90.0

## Nur relevant im STOCKEND-Modus: Schläge pro Minute, bestimmt den Takt.
@export var bpm: float = 120.0

## Nur relevant im STOCKEND-Modus: Wie viel Umdrehung pro Schlag - gültige
## Werte: 0.125 (1/8), 0.25 (1/4), 0.5 (1/2).
@export var beat_turn_fraction: float = 0.25

var _beat_accumulator: float = 0.0

## Achse 1+2 zusammen: alle 16 Hüllen-Varianten (4 Grundformen x 4 Stile),
## siehe Reihenfolge-Hinweis oben.
@export var mask_textures: Array[Texture2D] = []

## Achse 3 (Füllung/Schraffur-Richtung): die 4 Muster-Varianten.
@export var pattern_1: Texture2D
@export var pattern_2: Texture2D
@export var pattern_3: Texture2D
@export var pattern_4: Texture2D

var pattern_textures: Array[Texture2D] = []

const SHAPE_COUNT: int = 4
const STYLE_COUNT: int = 4

var shape_index: int = 0
var style_index: int = 0
var pattern_index: int = 0

## Trigger-Areas fuer Achse 1 (Grundform). Betritt der Spieler eine dieser
## Areas, springt die Scheibe direkt auf den zugehoerigen Wert:
## Slot 0 = 3 Ecken, Slot 1 = 4 Ecken, Slot 2 = 5 Ecken, Slot 3 = 6 Ecken.
## Jeder Trigger braucht ein CollisionShape2D; leere Slots werden ignoriert.
@export_group("Trigger - Grundform")
@export var shape_triggers: Array[Area2D] = [null, null, null, null]

## Trigger-Areas fuer Achse 2 (Stil):
## Slot 0 = fat, Slot 1 = norm, Slot 2 = thin, Slot 3 = spez.
@export_group("Trigger - Stil")
@export var style_triggers: Array[Area2D] = [null, null, null, null]

## Trigger-Areas fuer Achse 3 (Schraffur):
## Slot 0 = pattern_1, Slot 1 = pattern_2, Slot 2 = pattern_3, Slot 3 = pattern_4.
@export_group("Trigger - Schraffur")
@export var pattern_triggers: Array[Area2D] = [null, null, null, null]

## Trigger-Areas fuer Achse 4 (Bewegung) - Reihenfolge identisch zu
## RotationMode oben:
## Slot 0 = fliessend rechts, Slot 1 = fliessend links,
## Slot 2 = stockend rechts, Slot 3 = stockend links.
@export_group("Trigger - Bewegung")
@export var rotation_triggers: Array[Area2D] = [null, null, null, null]

func _ready() -> void:
	pattern_textures = [pattern_1, pattern_2, pattern_3, pattern_4]
	# Eigene Kopie des Materials erzwingen - sonst teilen sich mehrere Disc-
	# Instanzen (z.B. durch Szenen-Instanzierung wie beim zweiten, grossen
	# Turntable) versehentlich dieselbe Material-Resource, und Änderungen
	# an der einen (z.B. per Trigger) schlagen auf alle anderen durch.
	if pattern_sprite and pattern_sprite.material:
		pattern_sprite.material = pattern_sprite.material.duplicate()
	_apply_mask()
	_apply_pattern()
	_connect_triggers(shape_triggers, set_shape)
	_connect_triggers(style_triggers, set_style)
	_connect_triggers(pattern_triggers, set_pattern)
	_connect_triggers(rotation_triggers, _set_rotation_mode_by_index)

func _process(delta: float) -> void:
	match rotation_mode:
		RotationMode.FLIESSEND_RECHTS:
			rotation += deg_to_rad(rotation_speed_degrees) * delta
		RotationMode.FLIESSEND_LINKS:
			rotation -= deg_to_rad(rotation_speed_degrees) * delta
		RotationMode.STOCKEND_RECHTS:
			_process_beat(delta, 1.0)
		RotationMode.STOCKEND_LINKS:
			_process_beat(delta, -1.0)

func _process_beat(delta: float, direction: float) -> void:
	if bpm <= 0.0:
		return
	_beat_accumulator += delta
	var beat_interval := 60.0 / bpm
	while _beat_accumulator >= beat_interval:
		_beat_accumulator -= beat_interval
		rotation += direction * beat_turn_fraction * TAU

func set_rotation_mode(mode: RotationMode) -> void:
	rotation_mode = mode
	_beat_accumulator = 0.0

## Wrapper, damit ein Trigger (der nur einen int-Slot kennt) denselben
## _connect_triggers()-Mechanismus wie die anderen drei Achsen nutzen kann.
func _set_rotation_mode_by_index(index: int) -> void:
	set_rotation_mode(index as RotationMode)

func set_shape(index: int) -> void:
	shape_index = wrapi(index, 0, SHAPE_COUNT)
	_apply_mask()

func set_style(index: int) -> void:
	style_index = wrapi(index, 0, STYLE_COUNT)
	_apply_mask()

func set_pattern(index: int) -> void:
	if pattern_textures.is_empty():
		return
	pattern_index = wrapi(index, 0, pattern_textures.size())
	_apply_pattern()

func _apply_mask() -> void:
	var index := shape_index * STYLE_COUNT + style_index
	if index < 0 or index >= mask_textures.size():
		push_warning("Disc: mask_textures hat an Index %d keinen Eintrag - Array vollständig befüllt?" % index)
		return
	var material := pattern_sprite.material as ShaderMaterial
	if not material:
		push_warning("Disc: pattern_sprite hat kein ShaderMaterial zugewiesen.")
		return
	material.set_shader_parameter("mask_texture", mask_textures[index])

func _apply_pattern() -> void:
	if pattern_textures.is_empty():
		return
	pattern_sprite.texture = pattern_textures[pattern_index]

## Verbindet jeden zugewiesenen Trigger einer Achse mit dem passenden
## Setter (set_shape / set_style / set_pattern / _set_rotation_mode_by_index),
## gebunden an seinen festen Slot-Index (0-3). Leere Slots werden übersprungen.
func _connect_triggers(triggers: Array[Area2D], setter: Callable) -> void:
	for i in triggers.size():
		var trigger := triggers[i]
		if trigger:
			trigger.body_entered.connect(_on_trigger_entered.bind(i, setter))

func _on_trigger_entered(body: Node2D, index: int, setter: Callable) -> void:
	if body is CharacterBody2D:
		setter.call(index)

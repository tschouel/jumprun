extends Node2D
## "Lösungsvorlage" - zeigt die zu erreichende Zielkombination dauerhaft an,
## damit der Spieler beim interaktiven Disc sieht, worauf er hin muss. Rein
## statisch/anzeigend: keine Trigger, keine Interaktion. Rotiert aber genau
## wie die echte Disc weiter (Achse 4/Bewegung gehört ja mit zur Lösung),
## damit man auch die Bewegungsart direkt vergleichen kann.
##
## Setup: Wie bei der echten Disc eine Sprite2D-Node mit ShaderMaterial
## (derselbe Masken-Shader) im Feld "Pattern Sprite" zuweisen. Dann pro
## Achse einfach die EINE richtige Textur reinziehen bzw. den richtigen
## Rotationsmodus wählen - fertig, keine 16er-Arrays und keine Indizes
## nötig, weil sich hier zur Laufzeit nichts mehr ändert.

## Die Sprite2D-Node mit dem ShaderMaterial (identischer Masken-Shader wie
## bei der echten Disc).
@export var pattern_sprite: Sprite2D

## Achse 1+2 (Grundform + Stil zusammen): die EINE Hüllen-Textur, die die
## Ziel-Kombination zeigt (z.B. "3 Ecken, fett").
@export var target_mask_texture: Texture2D

## Achse 3 (Schraffur-Richtung): die EINE Ziel-Musterrichtung.
@export var target_pattern_texture: Texture2D

## Achse 4 (Bewegung) - identische Logik wie bei der echten Disc, damit
## sich die Lösungsvorlage exakt so bewegt, wie die Lösung es verlangt.
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

func _ready() -> void:
	_apply_target()

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

func _apply_target() -> void:
	if not pattern_sprite:
		push_warning("diskfix: 'Pattern Sprite' ist im Inspector nicht zugewiesen.")
		return
	var material := pattern_sprite.material as ShaderMaterial
	if not material:
		push_warning("diskfix: pattern_sprite hat kein ShaderMataerial zugewiesen.")
		return
	if target_mask_texture:
		material.set_shader_parameter("mask_texture", target_mask_texture)
	else:
		push_warning("diskfix: 'Target Mask Texture' ist im Inspector nicht zugewiesen.")
	if target_pattern_texture:
		pattern_sprite.texture = target_pattern_texture
	else:
		push_warning("diskfix: 'Target Pattern Texture' ist im Inspector nicht zugewiesen.")

extends Node2D
class_name LevelStringDisplay
## Zeigt fuer jedes geschaffte Level eine zusaetzliche, DAUERHAFT
## vibrierende Saite (StringRing) an - baut sich also Stueck fuer Stueck zu
## einer kompletten "Harfe" aus abgeschlossenen Leveln auf. Jede neue Saite
## schwingt ab dem Erscheinen UNUNTERBROCHEN (siehe StringRing.gd's
## continuous_vibration) statt nach kurzem Ausschlag abzuklingen - dazu
## zusaetzlich sanftes Einblenden (Alpha 0 -> 1).
##
## KOMPATIBEL MIT DEM BESTEHENDEN success_target-MUSTER: CallAndResponse.gd
## ruft bei Erfolg success_target.start_tuning() auf (dieselbe Konvention
## wie bei TunerButterfly.gd) - deshalb heisst die oeffentliche Methode
## hier ebenfalls start_tuning(), obwohl inhaltlich keine Stimmschluessel-
## Animation passiert, sondern add_string(). Dadurch kann dieser Node
## direkt als success_target in einen CallAndResponse-Node eingetragen
## werden, ganz ohne CallAndResponse.gd anfassen zu muessen.
##
## VERSTAERKTE, DAUERHAFTE VIBRATION: Diese Saiten werden ausserhalb des
## eingezoomten Instrument-Blicks angezeigt (der Kamera-Zoom von
## gopichand.gd ist beim Erfolg ja schon wieder zurueckgefahren) - dadurch
## wirken StringRing's Standardwerte optisch viel zu schwach/kurz.
## override_vibration_amplitude/override_wave_length_px werden daher NACH
## dem Instanziieren direkt auf der neuen StringRing-Instanz gesetzt
## (siehe add_string unten), UND continuous_vibration wird aktiviert, damit
## die Saite dauerhaft sichtbar in Bewegung bleibt statt auszuschwingen.
##
## POSITIONIERUNG: analog zu StringHarp.gd - start_point/end_point (zwei
## Marker2D-Kinder) definieren Position, Laenge UND Neigung der ERSTEN
## Saite. Jede weitere Saite wird exakt parallel dazu um spacing * Index
## SENKRECHT zur Saitenrichtung verschoben. invert_direction dreht um, auf
## welche Seite hin aufgereiht wird. Anders als StringHarp werden die
## Saiten aber NICHT alle auf einmal in _ready() erzeugt, sondern erst
## nacheinander, jede einzeln durch einen eigenen start_tuning()-Aufruf
## (= ein geschafftes Level).
##
## Setup:
## 1. Neue Szene, Root-Typ Node2D, dieses Skript drauf.
## 2. StartPoint und EndPoint (zwei Marker2D) als Kinder anlegen - Position/
##    Laenge/Neigung der ERSTEN Saite (genau wie bei StringHarp), ins
##    Inspector-Feld "Start Point"/"End Point" ziehen.
## 3. string_scene auf string_ring.tscn zeigen lassen.
## 4. count = maximale Anzahl Saiten (= Anzahl Level insgesamt). Weitere
##    start_tuning()-Aufrufe ueber count hinaus werden ignoriert.
## 5. Diesen Node als "Success Target" in JEDEN CallAndResponse-Node
##    eintragen, der ein Level abschliesst - jeder Erfolg fuegt eine neue
##    Saite hinzu.
## 6. override_vibration_amplitude/override_wave_length_px im Inspector
##    nach Geschmack anpassen.

@export var string_scene: PackedScene
@export var start_point: Node2D
@export var end_point: Node2D
@export var count: int = 32
@export var spacing: float = 40.0
## Dreht die Aufreih-Richtung um (falls die Saiten auf der falschen Seite
## der ersten Saite entstehen, z.B. links statt rechts).
@export var invert_direction: bool = false

@export_group("Erscheinen")
## Wie lange das sanfte Einblenden (Alpha 0 -> 1) einer neu hinzugefuegten
## Saite dauert.
@export var appear_fade_duration: float = 0.6
## Wo entlang der Saite (0..1) die Schwingung zentriert ist. 0.5 = Mitte.
@export var appear_pluck_t: float = 0.5

@export_group("Vibration (verstaerkt, dauerhaft)")
## Ueberschreibt StringRing.vibration_amplitude auf jeder hier erzeugten
## Instanz - deutlich hoeher als StringRing's eigener Default (10.0), da
## diese Saiten im nicht eingezoomten Kamera-Massstab erscheinen.
@export var override_vibration_amplitude: float = 45.0
## Ueberschreibt StringRing.wave_length_px - groesser = grobwelligere,
## dadurch aus der Distanz deutlicher erkennbare Wellenform (StringRing-
## Default: 40.0).
@export var override_wave_length_px: float = 90.0

var _next_index: int = 0

## Wird von aussen aufgerufen (z.B. CallAndResponse.gd bei Erfolg, ueber
## das success_target-Muster) - fuegt GENAU EINE neue Saite hinzu, an der
## naechsten freien Position.
func start_tuning() -> void:
	add_string()

## Fuegt eine neue, dauerhaft vibrierende Saite hinzu. Kann auch direkt
## aufgerufen werden, falls du nicht ueber das success_target-Muster gehen
## willst. Ignoriert weitere Aufrufe, sobald count erreicht ist.
func add_string() -> void:
	if not string_scene:
		push_warning("LevelStringDisplay: string_scene ist nicht gesetzt.")
		return
	if not start_point or not end_point:
		push_warning("LevelStringDisplay: start_point/end_point sind nicht gesetzt.")
		return
	if _next_index >= count:
		return  # Alle Saiten schon vorhanden.

	var base_from: Vector2 = start_point.global_position
	var base_to: Vector2 = end_point.global_position
	var dir: Vector2 = base_to - base_from
	var normal: Vector2 = dir.orthogonal().normalized() if dir.length() > 0.0 else Vector2.DOWN
	if invert_direction:
		normal = -normal

	var offset: Vector2 = normal * spacing * float(_next_index)
	_next_index += 1

	var instance: Node2D = string_scene.instantiate()
	add_child(instance)

	var inst_start: Node2D = instance.get_node_or_null("StartPoint")
	var inst_end: Node2D = instance.get_node_or_null("EndPoint")
	if inst_start:
		inst_start.global_position = base_from + offset
	if inst_end:
		inst_end.global_position = base_to + offset

	# Verstaerkung + Dauer-Vibration setzen, BEVOR gepluckt wird - siehe
	# Klassenkommentar oben. Direkter Property-Zugriff, da StringRing diese
	# als normale @export-Felder deklariert.
	if "vibration_amplitude" in instance:
		instance.vibration_amplitude = override_vibration_amplitude
	if "wave_length_px" in instance:
		instance.wave_length_px = override_wave_length_px
	if "continuous_vibration" in instance:
		instance.continuous_vibration = true

	# Sanftes Einblenden statt kommentarlosem Auftauchen.
	instance.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(instance, "modulate:a", 1.0, appear_fade_duration)

	# Zentriert die Dauerschwingung auf appear_pluck_t.
	if instance.has_method("pluck"):
		instance.pluck(appear_pluck_t)

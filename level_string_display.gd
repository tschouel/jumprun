extends Node2D
class_name LevelStringDisplay
## Zeigt fuer jedes geschaffte Level eine zusaetzliche, DAUERHAFT
## vibrierende Saite (StringRing) an - baut sich also Stueck fuer Stueck zu
## einer kompletten "Harfe" aus abgeschlossenen Leveln auf. Jede aktivierte
## Saite schwingt ab dann UNUNTERBROCHEN (siehe StringRing.gd's
## continuous_vibration) statt nach kurzem Ausschlag abzuklingen.
##
## ALLE SAITEN-PLAETZE VON ANFANG AN SICHTBAR: Anders als vorher wird bei
## Levelabschluss keine neue Saiten-Instanz mehr erzeugt - stattdessen
## werden schon in _ready() ALLE count Saiten instanziert und angezeigt,
## aber im Ruhezustand (continuous_vibration = false, nicht gezupft). So
## sieht man von Beginn des Spiels an die komplette potenzielle Harfe als
## stillen Umriss. start_tuning()/add_string() "aktiviert" dann nur noch
## die naechste, noch ruhende Saite (schaltet continuous_vibration ein und
## zupft sie einmal an) - es wird nichts mehr neu instanziert.
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
## override_vibration_amplitude/override_wave_length_px werden daher schon
## beim Instanziieren in _ready() auf jeder StringRing-Instanz gesetzt
## (siehe _build_string unten).
##
## POSITIONIERUNG: analog zu StringHarp.gd - start_point/end_point (zwei
## Marker2D-Kinder) definieren Position, Laenge UND Neigung der ERSTEN
## Saite. Jede weitere Saite wird exakt parallel dazu um spacing * Index
## SENKRECHT zur Saitenrichtung verschoben. invert_direction dreht um, auf
## welche Seite hin aufgereiht wird (z.B. links statt rechts der ersten
## Saite).
##
## Setup:
## 1. Neue Szene, Root-Typ Node2D, dieses Skript drauf.
## 2. StartPoint und EndPoint (zwei Marker2D) als Kinder anlegen - Position/
##    Laenge/Neigung der ERSTEN Saite (genau wie bei StringHarp), ins
##    Inspector-Feld "Start Point"/"End Point" ziehen.
## 3. string_scene auf string_ring.tscn zeigen lassen.
## 4. count = maximale Anzahl Saiten (= Anzahl Level insgesamt) - alle
##    werden sofort beim Start angelegt (ruhend). Weitere start_tuning()-
##    Aufrufe ueber count hinaus werden ignoriert.
## 5. Diesen Node als "Success Target" in JEDEN CallAndResponse-Node
##    eintragen, der ein Level abschliesst - jeder Erfolg aktiviert eine
##    weitere, schon vorhandene Saite.
## 6. override_vibration_amplitude/override_wave_length_px im Inspector
##    nach Geschmack anpassen.
## 7. invert_direction anhaken, falls die Saiten auf der falschen Seite der
##    ersten Saite aufgereiht werden.

@export var string_scene: PackedScene
@export var start_point: Node2D
@export var end_point: Node2D
@export var count: int = 32
@export var spacing: float = 40.0
## Dreht die Aufreih-Richtung um (falls die Saiten auf der falschen Seite
## der ersten Saite entstehen, z.B. links statt rechts).
@export var invert_direction: bool = false

@export_group("Aktivierung")
## Wo entlang der Saite (0..1) die Schwingung beim Aktivieren zentriert
## ist. 0.5 = Mitte.
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
## Ueberschreibt StringRing.continuous_touch_strength - die Start-Staerke
## des zusaetzlichen, abklingenden Ausschlags bei einer Spieler-Beruehrung
## (die Dauer-Grundschwingung selbst bleibt davon unberuehrt). Niedriger
## als StringRing's eigener Default (1.0), weil sie hier durch den grossen
## override_vibration_amplitude sonst zu stark wirkt (siehe StringRing.gd-
## Klassenkommentar zu continuous_touch_strength). Wirkt sich NICHT auf die
## Aktivierungs-Zupfer in add_string() aus, nur auf echte Spieler-
## Beruehrung.
@export_range(0.0, 2.0, 0.01) var override_touch_strength: float = 0.5

var _strings: Array[Node2D] = []
var _next_index: int = 0

func _ready() -> void:
	_build_all_strings()

## Erzeugt schon beim Start ALLE count Saiten-Plaetze an ihrer jeweiligen
## Position und laesst sie im Ruhezustand (keine Vibration) sichtbar
## stehen - siehe Klassenkommentar oben.
func _build_all_strings() -> void:
	if not string_scene:
		push_warning("LevelStringDisplay: string_scene ist nicht gesetzt.")
		return
	if not start_point or not end_point:
		push_warning("LevelStringDisplay: start_point/end_point sind nicht gesetzt.")
		return

	var base_from: Vector2 = start_point.global_position
	var base_to: Vector2 = end_point.global_position
	var dir: Vector2 = base_to - base_from
	var normal: Vector2 = dir.orthogonal().normalized() if dir.length() > 0.0 else Vector2.DOWN
	if invert_direction:
		normal = -normal

	for i in range(count):
		var offset: Vector2 = normal * spacing * float(i)
		_strings.append(_build_string(base_from + offset, base_to + offset))

## Instanziert eine einzelne StringRing-Saite an from/to (globale
## Positionen), setzt die Verstaerkungswerte und laesst sie ruhen (keine
## Vibration, nicht gezupft) - Aktivierung passiert separat in add_string().
func _build_string(from: Vector2, to: Vector2) -> Node2D:
	var instance: Node2D = string_scene.instantiate()
	add_child(instance)

	var inst_start: Node2D = instance.get_node_or_null("StartPoint")
	var inst_end: Node2D = instance.get_node_or_null("EndPoint")
	if inst_start:
		inst_start.global_position = from
	if inst_end:
		inst_end.global_position = to

	# Verstaerkung setzen, aber Vibration bleibt vorerst aus - siehe
	# Klassenkommentar oben.
	if "vibration_amplitude" in instance:
		instance.vibration_amplitude = override_vibration_amplitude
	if "wave_length_px" in instance:
		instance.wave_length_px = override_wave_length_px
	if "continuous_vibration" in instance:
		instance.continuous_vibration = false
	if "continuous_touch_strength" in instance:
		instance.continuous_touch_strength = override_touch_strength

	return instance

## Wird von aussen aufgerufen (z.B. CallAndResponse.gd bei Erfolg, ueber
## das success_target-Muster) - aktiviert GENAU EINE bereits vorhandene,
## noch ruhende Saite an der naechsten freien Position.
func start_tuning() -> void:
	add_string()

## Aktiviert die naechste noch ruhende Saite: schaltet ihre Dauer-Vibration
## ein und zupft sie einmal an. Kann auch direkt aufgerufen werden, falls
## du nicht ueber das success_target-Muster gehen willst. Ignoriert weitere
## Aufrufe, sobald count erreicht ist.
func add_string() -> void:
	if _next_index >= _strings.size():
		return  # Alle Saiten schon aktiv.

	var instance: Node2D = _strings[_next_index]
	_next_index += 1

	if "continuous_vibration" in instance:
		instance.continuous_vibration = true
	if instance.has_method("pluck"):
		instance.pluck(appear_pluck_t)

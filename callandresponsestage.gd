extends Resource
class_name CallAndResponseStage
## Eine einzelne Call-and-Response-Stufe: definiert die erwartete Tonhoehe
## und (optional) einen Rhythmus, den der Spieler nachspielen muss. Wird
## in CallAndResponse.gd im Array "stages" verwendet - jede Stufe ist eine
## eigene Instanz dieser Resource. Dadurch kann eine neue Stufe (z.B.
## "Stufe 3 = Kopie von Stufe 2 mit anderem Tempo/Rhythmus") einfach als
## zusaetzlicher Array-Eintrag im Inspector angelegt werden, OHNE
## CallAndResponse.gd anfassen zu muessen.
##
## rhythm_pattern LEER (Groesse 0) => reine "Ton kopieren"-Stufe: es wird
## genau EIN Ton erwartet, der expected_tension_level treffen muss (wie
## die urspruengliche Stufe 1).
##
## rhythm_pattern MIT Eintraegen => zusaetzlich zum Ton wird ein Rhythmus
## erwartet: Array-Groesse + 1 = Anzahl erwarteter Noten. Jeder Eintrag ist
## die erwartete PAUSE (in Schlaegen: 1.0 = Viertelnote, 0.5 = Achtelnote,
## 0.25 = Sechzehntel, ...) zwischen zwei aufeinanderfolgenden Noten. bpm
## bestimmt, wie lang ein Schlag in Sekunden ist. Geprueft werden
## ausschliesslich die RELATIONEN zwischen den gespielten Noten - das
## absolute Tempo/Timing des Spielens ist egal.

@export var expected_tension_level: int = 0
## Muss JEDE gespielte Note expected_tension_level treffen? Bei reinen
## "Ton kopieren"-Stufen (rhythm_pattern leer) ist das ohnehin die einzige
## Note. Bei Rhythmus-Stufen kannst du das auch ausschalten, falls nur der
## Rhythmus zaehlen soll, egal auf welcher Tonhoehe gespielt wird.
@export var require_correct_pitch: bool = true

@export_group("Rhythmus (leer lassen = reine Ton-Stufe)")
@export var bpm: float = 100.0
@export var rhythm_pattern: Array[float] = []
## Erlaubte Abweichung (Form UND Gesamttempo), 0.25 = 25% Kulanz.
@export_range(0.01, 1.0, 0.01) var tolerance_percent: float = 0.25

@export_group("Ankuendigung")
## Text, der angezeigt wird, NACHDEM die VORHERIGE Stufe erfolgreich war
## und zu DIESER Stufe gewechselt wird (direkt nach success_text, im
## selben Feedback-Label). Leer lassen fuer keinen Ankuendigungstext.
@export var intro_text: String = ""

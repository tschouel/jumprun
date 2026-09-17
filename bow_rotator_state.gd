class_name BowRotatorState
extends Resource

## Ein Abschnitt in BowRotator's states-Sequenz (siehe bow_rotator.gd).
## Definiert sowohl seine eigene Dauer (in Takten + Notenwerten, bezogen
## auf BowRotator's gemeinsames bpm) als auch sein eigenes
## Rotations-Verhalten fuer genau diesen Abschnitt - dadurch lassen sich
## beliebig viele unterschiedliche Bewegungs-Phasen exakt an die Musik
## anpassen, z.B. "2 Takte + 3 Viertel lang mit 20 Grad pendeln, dann 3
## Takte + 2 Sechzehntel lang still stehen".
##
## Dauer dieses Abschnitts in Sekunden:
##
##   dauer_sekunden = (bars * 4.0 + note_count * notenwert_bruchteil * 4.0) * (60.0 / bpm)
##
## (bars = volle Takte im 4/4-Takt, notenwert_bruchteil siehe
## NOTE_FRACTIONS in bow_rotator.gd - "Ganze" = 1 Takt. bpm kommt von der
## BowRotator-Node, nicht von hier.)
##
## Rotations-Verhalten waehrend der Dauer dieses Abschnitts, ausgehend von
## target's Rotation GENAU zu Beginn dieses Abschnitts (= Ende des vorigen
## Abschnitts, dadurch keine Spruenge zwischen Abschnitten):
##
## PENDEL: schwingt sanft (Kosinus-Kurve, von selbst ein- und
## ausschwingend) einmal komplett hin zu rotate_degrees (in per direction
## gewaehlter Richtung) und wieder zurueck - OHNE Wiederholung (siehe unten)
## ist die GESAMTE Abschnittsdauer eine einzige volle Hin-Zurueck-Schwingung.
##
## WEITERDREHEN: dreht mit konstanter Geschwindigkeit gleichmaessig um
## rotate_degrees weiter (in per direction gewaehlter Richtung), sodass am
## Ende des Abschnitts genau rotate_degrees erreicht sind - kein
## Zurueckpendeln. (Siehe unten, wie sich das mit Wiederholung kombiniert.)
##
## rotate_degrees = 0: der Bogen bleibt fuer die Dauer dieses Abschnitts
## einfach unbewegt stehen (in beiden Modi identisch) - nuetzlich fuer
## musikalische Pausen zwischen Bewegungsphasen.

@export var bars: int = 0
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var note_value: int = 2
@export var note_count: int = 0

@export_enum("Pendel", "Weiterdrehen") var rotation_mode: int = 0
@export_enum("Uhrzeigersinn", "Gegenuhrzeigersinn") var direction: int = 0
## Grad, immer positiv angeben - direction (siehe oben) bestimmt die
## tatsaechliche Richtung. 0 = dieser Abschnitt ist eine Pause (siehe oben).
@export var rotate_degrees: float = 90.0

@export_group("Wiederholung (optional)")
## Notenwert EINES Wiederhol-Zyklus, z.B. "Viertel" fuer "jede Viertel neu
## pendeln". Nur relevant, wenn repeat_note_count > 0 ist (siehe dort).
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var repeat_note_value: int = 2
## 0 (Standard) = KEINE Wiederholung - dieser Abschnitt macht genau EINE
## Bewegung (Pendel-Hin-und-Zurueck bzw. Weiterdrehen-Rampe) ueber die
## GESAMTE Abschnittsdauer (bars/note_value/note_count), wie bisher.
##
## > 0 = die Bewegung wird in kleinere Zyklen von je
## repeat_note_count * repeat_note_value Laenge unterteilt und dieser
## Zyklus wird fortlaufend WIEDERHOLT, bis die Gesamtdauer des Abschnitts
## (bars/note_value/note_count) erreicht ist. Beispiel: bars=4, note_value=
## Viertel, note_count=2 (Gesamtdauer = 4 Takte + 2 Viertel) zusammen mit
## rotation_mode=Pendel, repeat_note_value=Viertel, repeat_note_count=1
## ergibt "4 Takte + 2 Viertel lang JEDE Viertel einmal hin-und-zurueck
## pendeln um rotate_degrees".
##
## PENDEL + Wiederholung: jeder Zyklus ist eine eigene volle
## Hin-Zurueck-Schwingung (Kosinus geht in jedem Zyklus wieder auf 0
## zurueck) - dadurch immer nahtlos, keine Spruenge zwischen den Zyklen.
##
## WEITERDREHEN + Wiederholung: jeder Zyklus dreht rotate_degrees WEITER
## (kumulativ, nicht auf 0 zurueckspringend) - nach n ganzen Zyklen steht
## der Bogen bei n * rotate_degrees zusaetzlicher Drehung. Das ist
## rechnerisch dasselbe wie eine einzige gleichmaessige Drehung ueber die
## Gesamtdauer, mit repeat_note_count * repeat_note_value als "Geschwindig-
## keits-Referenz" - gedacht z.B. fuer "pro Viertel 90 Grad weiterdrehen,
## macht pro Takt eine volle Umdrehung".
##
## Passt die Gesamtdauer (bars/note_value/note_count) nicht exakt zu einem
## Vielfachen von repeat_note_count * repeat_note_value, wird der letzte
## Zyklus einfach an der Abschnittsgrenze abgeschnitten (keine Pause,
## kein Warten auf einen vollen Zyklus).
@export var repeat_note_count: int = 0

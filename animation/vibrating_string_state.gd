class_name VibratingStringState
extends Resource

## Ein Abschnitt in VibratingString's states-Sequenz (siehe vibrating_string.gd)
## - GENAU GLEICH AUFGEBAUT wie BowRotatorState (siehe bow_rotator_state.gd):
## eigene Dauer (Takte + Notenwerte) und eigenes Verhalten fuer genau diesen
## Abschnitt, dadurch lassen sich beliebig viele unterschiedliche
## Anschlag-Phasen exakt an die Musik anpassen, z.B. "2 Takte lang jede
## Viertel anschlagen, dann 4 Takte lang jede Achtel anschlagen, dann 1 Takt
## Pause".
##
## Dauer dieses Abschnitts in Sekunden:
##
##   dauer_sekunden = (bars * 4.0 + note_count * notenwert_bruchteil * 4.0) * (60.0 / bpm)
##
## (bars = volle Takte im 4/4-Takt, notenwert_bruchteil siehe NOTE_FRACTIONS
## in vibrating_string.gd - "Ganze" = 1 Takt. bpm kommt von der
## VibratingString-Node, nicht von hier.)
##
## ANSCHLAG WAEHREND DIESES ABSCHNITTS (repeat_note_value/repeat_note_count):
## alle string_points werden alle repeat_note_count * repeat_note_value (im
## gemeinsamen bpm-Takt) angeschlagen, wiederholt fortlaufend fuer die
## GESAMTE Dauer dieses Abschnitts - der erste Anschlag ist gleich zu Beginn
## des Abschnitts (bzw. im allerersten states-Eintrag, Index 0, erst nach
## dem jeweiligen string_point-eigenen Delay, siehe unten).
##
## repeat_note_count = 0: REINE PAUSE - in diesem Abschnitt wird ueberhaupt
## nicht angeschlagen, bereits laufende Vibration von vorher klingt aber
## normal aus. Fuer "4 Takte lang soll nichts vibrieren": bars=4,
## repeat_note_count=0 (repeat_note_value ist dann egal).
##
## Willst du in einem Abschnitt genau EINEN einzelnen Anschlag (Akzent) statt
## einer Pause oder einer Wiederholung, setze repeat_note_count=1 und
## repeat_note_value/note_count so lang, dass der naechste Wiederholungs-
## Zeitpunkt schon ausserhalb der Abschnittsdauer laege (z.B. repeat_note_value
## = derselbe Notenwert wie die Abschnittsdauer selbst) - dann feuert nur der
## erste Anschlag.
##
## Passt die Gesamtdauer (bars/note_value/note_count) nicht exakt zu einem
## Vielfachen von repeat_note_count * repeat_note_value, wird der letzte,
## nicht mehr vollstaendig hineinpassende Anschlag einfach ausgelassen -
## siehe vibrating_string.gd.
##
## HINWEIS ZU DEN EINZELNEN string_points-DELAYS: der eigene
## delay_note_value/delay_count jedes StringPulsePoint (siehe
## vibrating_string.gd) gilt weiterhin, aber NUR innerhalb des ALLERERSTEN
## states-Eintrags (Index 0, auch bei jedem erneuten Loop-Durchlauf) - dort
## sorgt er weiterhin fuer den zeitlichen Versatz zwischen den Punkten. In
## allen spaeteren Abschnitten schlagen alle string_points synchron
## zusammen an, jeweils ab dem exakten Start dieses Abschnitts.

@export var bars: int = 0
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var note_value: int = 2
@export var note_count: int = 0

@export_group("Anschlag")
@export_enum("Ganze", "Halbe", "Viertel", "Achtel", "Sechzehntel") var repeat_note_value: int = 2
## 0 = nur ein einziger Anschlag zu Beginn dieses Abschnitts (siehe oben).
@export var repeat_note_count: int = 1
## Verschiebt NUR den Ausloese-Zeitpunkt JEDES geplanten Anschlags in DIESEM
## Abschnitt, relativ zum eigentlichen Taktschlag, in Sekunden - der
## Rhythmus selbst (Abstand zwischen den Anschlaegen, repeat_note_value/
## repeat_note_count) bleibt dabei unangetastet, es verschiebt sich nur
## WANN jeder einzelne Anschlag ausgeloest wird. NEGATIV = frueher (der
## Anschlag kommt schon VOR dem Beat), POSITIV = spaeter (danach). Jeder
## Abschnitt (state) hat sein EIGENES predelay, unabhaengig von den anderen.
@export_range(-1.0, 1.0, 0.01, "or_greater", "or_less") var repeat_predelay: float = 0.0

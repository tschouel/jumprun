class_name TuningPegColor
extends Resource

## Gemeinsame Farbe fuer beliebig viele TuningPeg-Instanzen. Der Trick: alle
## TuningPegs referenzieren im Inspector DIESELBE .tres-Datei (siehe
## TuningPeg.gd's color_theme-Feld) statt jeweils eine eigene, neu angelegte
## Ressource - deshalb reicht es, color EINMAL in dieser einen Datei zu
## aendern, damit sich ALLE damit verknuepften TuningPegs auf einen Schlag
## umfaerben.
##
## EINMALIGES SETUP:
## 1. Im FileSystem-Panel: Rechtsklick in einen Ordner -> Neue Ressource... ->
##    "TuningPegColor" suchen -> anlegen -> z.B. als tuning_peg_color.tres
##    speichern (Name/Ort egal, Hauptsache du findest die Datei wieder).
## 2. Bei JEDEM TuningPeg im Inspector unter "Farbe" -> color_theme -> genau
##    diese tuning_peg_color.tres-Datei reinziehen. WICHTIG: bei ALLEN
##    TuningPegs dieselbe Datei verwenden, nicht bei jedem eine neue Ressource
##    ueber "Neue Ressource..." anlegen - sonst hat wieder jedes Peg seine
##    eigene, unabhaengige Farbe.
##
## FARBE AENDERN (danach jederzeit): entweder tuning_peg_color.tres im
## FileSystem-Panel doppelklicken (oeffnet sie im Inspector), ODER bei
## irgendeinem beliebigen TuningPeg auf den kleinen Pfeil neben color_theme
## klicken und dort direkt editieren - beides aendert dieselbe Datei. Die
## Aenderung wird ueber das eingebaute changed-Signal von Resource sofort an
## alle TuningPeg-Instanzen weitergereicht, die diese Datei referenzieren
## (siehe TuningPeg.gd's _apply_color_theme()) - kein erneuter Szenenstart
## noetig, solange das Spiel bereits laeuft.

@export var color: Color = Color.WHITE

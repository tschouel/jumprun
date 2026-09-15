@tool
class_name RampTestEntry
extends Resource
## Eine einzelne Ramp-Test-Station innerhalb einer Sequenz aus mehreren
## Ramps hintereinander (siehe RampTestSequencer.gd). timing bestimmt Start-
## Position (Takte/Schlaege/Tempo) und Fenster-Laenge dieser einen Station,
## required_key die dafuer zu druckende Taste - beides pro Station frei
## waehlbar, damit sich aufeinanderfolgende Ramps auch mal unterscheiden
## koennen (andere Taste, anderer Rhythmus).

@export var timing: RampTestTiming
@export var required_key: Key = KEY_SPACE

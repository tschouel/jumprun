# Seifenblasen-Harfe (Godot 4.7, 2D)

Eine Maschine bläst Seifenblasen, die sanft nach oben treiben und wackeln.
Berühren sie eine Harfensaite, wackelt die Saite und ein Pop-Effekt spielt ab.

## Dateien

| Datei | Zweck |
|---|---|
| `bubble.gd` / `bubble.tscn` | Eine einzelne Blase: steigt auf, wackelt, erkennt Kollision mit Saiten |
| `pop_effect.gd` / `pop_effect.tscn` | Kurzer visueller Platz-Effekt (Ring + Tröpfchen) |
| `harp_string.gd` / `harp_string.tscn` | Eine einzelne Saite mit gedämpfter Wackel-Animation beim Pluck |
| `harp.gd` / `harp.tscn` | Ordnet mehrere Saiten fächerförmig an (echte Harfen-Optik) |
| `bubble_machine.gd` / `bubble_machine.tscn` | Spawner mit Marker "Muendung" für die Austrittsöffnung |
| `demo.tscn` | Fertige Testszene: Maschine + Harfe, sofort startklar |

## Installation

1. Kopiere den gesamten Ordner (oder nur die Dateien) in dein Godot-4.7-Projektverzeichnis,
   z.B. nach `res://bubble_harp/`.
2. Liegen die Dateien NICHT direkt in `res://` (Projekt-Root), musst du die `preload("res://...")`-Pfade
   am Anfang von `bubble.gd`, `bubble_machine.gd` und `harp.gd` auf den tatsächlichen Unterordner anpassen
   (z.B. `res://bubble_harp/bubble.tscn`).
3. Öffne `demo.tscn`, setze sie als Startszene (oder drücke F6, um nur sie zu starten) und teste.

## Wie es funktioniert

- **Blasen** (`bubble.gd`) zeichnen sich selbst (kein Sprite nötig), sind ein `Area2D` mit
  Kreis-Kollisionsform und bewegen sich rein rechnerisch: `Position = Startpunkt + Richtung*Zeit
  + Senkrechte*Amplitude*sin(Zeit*Frequenz)`. Das ergibt das typische Aufsteigen mit Seitwärtswackeln,
  ganz ohne Physik-Engine.
- **BubbleMachine** hat ein Kind `Muendung` (Marker2D) – das ist die Austrittsöffnung. Verschiebe diesen
  Marker im Editor an die Stelle, an der später die Mündung deiner Maschinengrafik sitzt.
- **HarpString** ist ebenfalls ein `Area2D`, dessen Ursprung oben am "Hals" der Saite sitzt; die Saite
  verläuft lokal nach unten. Trifft eine Blase (Gruppe `harp_strings` wird automatisch beigetreten),
  ruft die Blase `pluck()` auf der Saite auf – die Saite schwingt dann mit einer gedämpften
  Sinuskurve aus (klassische "gezupfte Saite"-Optik) und wird jeden Frame neu gezeichnet.
- **Harp** erzeugt beim Start `string_count` Saiten mit steigendem Winkel (`angle_range`) und steigender
  Länge (`length_min` → `length_max`) – dadurch der schräge Fächer-Look wie bei einer echten Harfe.

## Wichtige Stellschrauben (im Inspector einstellbar)

- `BubbleMachine`: `spawn_interval_min/max` (Taktung), `radius_min/max`, `rise_speed_min/max`,
  `wobble_amplitude_min/max`, `direction` (Standard: nach oben).
- `Harp`: `string_count`, `angle_range` (Grad), `length_min/max`.
- `HarpString`: `pluck_amplitude_max`, `pluck_frequency`, `pluck_damping` (wie heftig/schnell/wie lange
  die Saite nachschwingt).

## Für später vorbereitet: Harfenton beim Platzen

Wie besprochen ist der Ton noch nicht angeschlossen, aber `harp_string.gd` hat bereits die Hooks dafür:

- `@export var pluck_sound: AudioStream` – trage hier eine Audiodatei (z.B. eine einzelne Harfen-Note) ein,
  dann wird sie bei jedem `pluck()` automatisch über einen automatisch erzeugten `AudioStreamPlayer2D`
  abgespielt (mit leichter zufälliger Tonhöhen-Variation).
- `@export var note_name: String` – rein informatives Feld, um z.B. "C4", "D4" usw. pro Saite zu vermerken,
  wenn du später den einzelnen Saiten unterschiedliche Samples zuweist.

Sobald du Audiodateien hast, kannst du sie in `Harp.gd` beim Erzeugen der Saiten passend zur Tonleiter
zuweisen (z.B. über ein Array von AudioStreams, indiziert nach `i`).

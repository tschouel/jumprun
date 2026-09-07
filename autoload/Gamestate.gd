extends Node

## Persistenter Spielzustand – überlebt Szenenwechsel automatisch,
## da dieses Script als Autoload läuft und nie entladen wird.

# Speichert, welche Wesen/Rätsel bereits gelöst wurden.
# Key: eindeutige ID (z.B. "wesen_1"), Value: true/false
var solved_creatures: Dictionary = {}

# Merkt sich, durch welche Tür der Spieler zuletzt gegangen ist.
# Kann nützlich sein für Debug-Zwecke oder spezielle Spawn-Logik.
var last_door_used: String = ""

# Optional: aktueller Spielername/Speicherstand-Slot, falls später gebraucht.
var current_save_slot: String = ""


func mark_solved(creature_id: String) -> void:
	solved_creatures[creature_id] = true


func is_solved(creature_id: String) -> bool:
	return solved_creatures.get(creature_id, false)


func has_unlocked(key: String) -> bool:
	# Wird von LevelDoor.gd genutzt, um zu prüfen, ob eine Tür
	# durch ein gelöstes Rätsel freigeschaltet wurde.
	return solved_creatures.get(key, false)


func reset_progress() -> void:
	# Nützlich für Debug/Testing oder einen "New Game"-Button.
	solved_creatures.clear()
	last_door_used = ""


func get_debug_state() -> String:
	# Praktisch, um im Editor-Output schnell den aktuellen Stand zu sehen.
	return "Solved: %s | Last door: %s" % [solved_creatures, last_door_used]

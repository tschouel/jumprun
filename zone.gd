class_name GameZone
extends Area2D

enum ZoneType {
	NONE,
	RAMP_JUMP,
	STAFF_NAVIGATION,
	FREE_FLIGHT,
	SOLO
}

@export_group("Zonen-Konfiguration")
## Welche Mechanik soll in dieser Zone aktiv sein?
@export var zone_type: ZoneType = ZoneType.FREE_FLIGHT

@export_group("Ramp Jump Einstellungen")
@export var hover_arc_height: float = 15.0

@export_group("Notenlinien Einstellungen")
@export var line_spacing: float = 6.0
@export var current_lane: int = 2

@export_group("Freiflug Einstellungen")
@export var flight_speed: float = 150.0
@export var high_zone_y: float = -50.0
@export var low_zone_y: float = 50.0

@export_group("Solo Einstellungen")
## Auswertungs-Intervall in Sekunden (0.5 = 500ms)
@export var solo_interval: float = 0.5
## FMOD Parameter für den Tastenzähler
@export var solo_fmod_param: String = "SoloCount"

@export_group("FMOD Einstellungen (Allgemein)")
@export var updates_fmod_parameter: bool = false
@export var fmod_param_name: String = "FlightZone"

# Interne Player-Referenz
var current_player: CharacterBody2D = null

# State: Freiflug & FMOD
var current_flight_zone: int = -1

# State: Ramp Jump & Notenlinien
var ramp_jump_prepared: bool = false
var hover_start_x: float = 0.0
var hover_start_y: float = 0.0
var hover_zone_length: float = 100.0
var is_hovering: bool = false
var staff_base_y: float = 0.0
var is_on_staff: bool = false

# State: Solo Zone
var solo_timer: float = 0.0
var hits_in_current_interval: int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		current_player = body
		
		# Initialisierung beim Betreten
		hover_start_x = current_player.position.x
		hover_start_y = current_player.position.y
		staff_base_y = current_player.position.y
		ramp_jump_prepared = false
		is_hovering = false
		is_on_staff = false
		
		# Solo Resets
		solo_timer = 0.0
		hits_in_current_interval = 0


func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		# Beim Verlassen der Solo-Zone den Parameter auf 0 zurücksetzen
		if zone_type == ZoneType.SOLO:
			_send_solo_count_to_fmod(0)
			
		current_player = null


func _unhandled_input(event: InputEvent) -> void:
	if not current_player or zone_type != ZoneType.SOLO:
		return

	# Zählt jeden einzelnen neuen Tastenanschlag (ohne Halte-Wiederholungen)
	if event is InputEventKey and event.pressed and not event.is_echo():
		hits_in_current_interval += 1


func _physics_process(delta: float) -> void:
	if not current_player:
		return

	match zone_type:
		ZoneType.RAMP_JUMP:
			_process_ramp_jump(delta)
		ZoneType.STAFF_NAVIGATION:
			_process_staff_navigation(delta)
		ZoneType.FREE_FLIGHT:
			_process_free_flight(delta)
		ZoneType.SOLO:
			_process_solo(delta)


# --- 1. RAMP JUMP LOGIK ---
func _process_ramp_jump(_delta: float) -> void:
	if Input.is_key_pressed(KEY_UP) and not ramp_jump_prepared:
		ramp_jump_prepared = true

	if ramp_jump_prepared:
		if not is_hovering:
			is_hovering = true
			hover_start_y = current_player.position.y
			hover_start_x = current_player.position.x
			var shape = $CollisionShape2D.shape if has_node("CollisionShape2D") else null
			if shape and shape is RectangleShape2D:
				hover_zone_length = shape.size.x
			else:
				hover_zone_length = 100.0

		var progress: float = clamp((current_player.position.x - hover_start_x) / hover_zone_length, 0.0, 1.0)
		var arc_offset: float = sin(progress * PI) * hover_arc_height
		current_player.position.y = hover_start_y - arc_offset
		current_player.velocity.y = 0.0


# --- 2. NOTENLINIEN LOGIK ---
func _process_staff_navigation(delta: float) -> void:
	if not is_on_staff:
		is_on_staff = true
		staff_base_y = current_player.position.y

	if Input.is_action_just_pressed("ui_up") and current_lane > 0:
		current_lane -= 1
	elif Input.is_action_just_pressed("ui_down") and current_lane < 4:
		current_lane += 1

	var target_y = staff_base_y + (current_lane - 2) * line_spacing
	current_player.position.y = move_toward(current_player.position.y, target_y, 200.0 * delta)
	current_player.velocity.y = 0.0


# --- 3. FREIFLUG LOGIK ---
func _process_free_flight(_delta: float) -> void:
	var move_dir: float = Input.get_axis("ui_up", "ui_down")
	current_player.velocity.y = move_dir * flight_speed
	
	if updates_fmod_parameter:
		_update_fmod_zone()


func _update_fmod_zone() -> void:
	var new_zone: int = 1
	if current_player.position.y < high_zone_y:
		new_zone = 0
	elif current_player.position.y > low_zone_y:
		new_zone = 2
	else:
		new_zone = 1

	if new_zone != current_flight_zone:
		current_flight_zone = new_zone
		var param_val: float = float(current_flight_zone)
		
		if current_player.get("music_emitter") and current_player.music_emitter:
			current_player.music_emitter.set_parameter(fmod_param_name, param_val)
				
		if ClassDB.class_exists("FmodServer"):
			FmodServer.set_global_parameter_by_name(fmod_param_name, param_val)


# --- 4. SOLO SHRED LOGIK ---
func _process_solo(delta: float) -> void:
	# Vertikale Bewegung in der Solo-Zone sperren
	current_player.velocity.y = 0.0
	
	solo_timer += delta

	# Alle solo_interval Sekunden (z. B. 0.5s) auswerten
	if solo_timer >= solo_interval:
		var total_hits = hits_in_current_interval
		
		print("[SOLO] Hits in den letzten ", solo_interval, "s: ", total_hits)
		_send_solo_count_to_fmod(total_hits)

		solo_timer = 0.0
		hits_in_current_interval = 0


func _send_solo_count_to_fmod(count: int) -> void:
	var param_val: float = float(count)

	if current_player.get("music_emitter") and current_player.music_emitter:
		current_player.music_emitter.set_parameter(solo_fmod_param, param_val)

	if ClassDB.class_exists("FmodServer"):
		FmodServer.set_global_parameter_by_name(solo_fmod_param, param_val)

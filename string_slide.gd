extends Node2D
class_name StringSlide
## Eine gerade Linie (z.B. Bogenhaar/Saite), an der der Spieler herunterrutschen
## kann. Die Rutschlinie wird AUTOMATISCH aus der Form von target_collider
## abgeleitet (Langachse einer RectangleShape2D, oder die Mittelpunkte der
## zwei langen Kanten eines rechteckigen CollisionPolygon2D).
##
## WICHTIG: target_collider MUSS ein Shape-Kind von slide_area sein (also ein
## CollisionShape2D oder CollisionPolygon2D, das direkt unter der SlideArea
## im Baum haengt) - siehe SETUP unten.
##
## Rutschgeschwindigkeit verhaelt sich wie auf einer schiefen Ebene:
## a = gravity * sin(winkel) - friction_coefficient * gravity * cos(winkel).
## min_slide_speed sorgt dafuer, dass auch bei flachen/falsch eingeschaetzten
## Neigungen immer spuerbar weitergerutscht wird, statt vorzeitig stecken zu
## bleiben.
##
## Kein Teleport beim Einstieg, kein Versatz zum Collider: der Spieler wird
## NICHT exakt auf die Linienmitte gezwungen, sondern behaelt seinen
## senkrechten Abstand zur Linie waehrend des gesamten Rutschens bei.
##
## DREI Wege, die Linie zu verlassen, ALLE geben kraeftigen Schwung mit:
## 1. Sprung-Taste waehrend des Rutschens (jump_exit_key) - staerkster Boost.
## 2. Natuerliches Erreichen des unteren Endes - bekommt exit_forward_boost.
## 3. Seitliches Verlassen der SlideArea - behaelt die zuletzt simulierte
##    Geschwindigkeit plus exit_forward_boost.
##
## Nach JEDEM Verlassen ignoriert das Skript fuer re_entry_lock_duration
## Sekunden neue Beruehrungen, damit man nicht sofort wieder einklinkt.
##
## Waehrend des Rutschens wird optional ein GPUParticles2D-Node (dust_particles,
## bereits fest hier in der StringSlide-Szene liegend) auf emitting=true
## geschaltet UND jeden Frame auf die aktuelle Spielerposition gesetzt, damit
## der Staub sichtbar an den Fuessen mitwandert, waehrend der Spieler die
## Linie herunterrutscht. Local Coords beim Partikel-Node sollte im Inspector
## AUS sein, damit bereits emittierte Partikel an ihrer Emissionsstelle
## "liegen bleiben" statt der Node-Bewegung zu folgen.
##
## SETUP:
## 1. SlideArea (Area2D) anlegen.
## 2. Darunter target_collider anlegen: CollisionShape2D (RectangleShape2D)
##    oder CollisionPolygon2D (4 Punkte, Rechteck) - MUSS direktes Kind von
##    SlideArea sein, nicht von einem StaticBody2D o.ae.!
## 3. Fuer die physische Tragflaeche (damit der Spieler nicht durchfaellt):
##    separat einen StaticBody2D mit eigener Kollision anlegen, der an der
##    gleichen Stelle liegt - Area2D blockiert nichts physisch.
## 4. Unten im Inspector bei "Referenzen": target_collider UND slide_area
##    per Drag & Drop zuweisen.
## 5. Im Walk-SpriteFrames des Spielers eine Rutsch-Animation anlegen (Name
##    unten bei "Slide Animation Name"), ODER ein eigenes AnimatedSprite2D
##    bei "Override Sprite" angeben.
## 6. OPTIONAL fuer Staubpartikel: einen GPUParticles2D-Node hier in der
##    StringSlide-Szene anlegen (Emitting im Editor AUS, One Shot AUS, Local
##    Coords AUS), bei "Dust Particles" im Inspector zuweisen.

signal slide_started
signal slide_ended

@export_group("Referenzen")
## CollisionShape2D (mit RectangleShape2D) oder CollisionPolygon2D (4 Punkte,
## Rechteck) - repraesentiert die Rutschlinie UND die exakte Beruehrungsflaeche.
## Muss ein Shape-Kind von slide_area sein (siehe SETUP).
@export var target_collider: Node
@export var slide_area: Area2D

@export_group("Bewegungsphysik")
## Fallbeschleunigung, die entlang der Neigung wirkt.
@export var gravity_strength: float = 1400.0
## Reibungskoeffizient (0 = butterglatt, groesser = bremst staerker).
@export var friction_coefficient: float = 0.15
## Maximale Rutschgeschwindigkeit (px/s).
@export var max_slide_speed: float = 900.0
## Mindest-Rutschgeschwindigkeit (px/s) - verhindert, dass Reibung/geringe
## Neigung das Rutschen komplett zum Erliegen bringt. 0 = aus (Reibung kann
## dann theoretisch bis zum Stillstand bremsen).
@export var min_slide_speed: float = 200.0
## Falls true: die Geschwindigkeit, mit der der Spieler die Flaeche beruehrt
## (Anteil in Rutschrichtung), wird als Startgeschwindigkeit uebernommen.
@export var inherit_entry_speed: bool = true
## Wie lange (Sekunden) die Geschwindigkeit ~0 bleiben muss, bevor die
## Kontrolle automatisch wieder freigegeben wird (nur relevant, falls
## min_slide_speed <= 0 ist).
@export var stuck_release_time: float = 0.4
## Wie lange (Sekunden) nach dem Verlassen der Linie neue Beruehrungen
## ignoriert werden - verhindert sofortiges Wieder-Einklinken.
@export var re_entry_lock_duration: float = 0.3

@export_group("Ausstieg")
## Erlaubt, waehrend des Rutschens vorzeitig abzuspringen (Taste siehe
## jump_exit_key).
@export var allow_jump_exit: bool = true
## Taste, mit der waehrend des Rutschens vorzeitig abgesprungen werden kann.
@export var jump_exit_key: Key = KEY_UP
## Vertikaler Schub (negativ = nach oben) beim SPRUNG-Absprung, ON TOP der
## aktuellen Rutschgeschwindigkeit.
@export var jump_exit_velocity: float = -650.0
## Zusaetzlicher HORIZONTALER Schub beim SPRUNG-Absprung, in Rutschrichtung.
@export var jump_exit_forward_boost: float = 450.0
## Zusaetzlicher Schub (in Rutschrichtung), der IMMER angewendet wird, wenn
## die Linie natuerlich/seitlich verlassen wird.
@export var exit_forward_boost: float = 300.0
## Multipliziert die GESAMTE Ausstiegsgeschwindigkeit (inkl. exit_forward_boost)
## am natuerlichen unteren Ende / bei seitlichem Verlassen.
@export var exit_speed_multiplier: float = 1.0

@export_group("Animation")
@export var slide_animation_name: String = "slide"
## Optional: eigenes AnimatedSprite2D statt einer Animation im
## Haupt-SpriteFrames des Spielers (siehe set_animation_override).
@export var override_sprite: AnimatedSprite2D

@export_group("Staubpartikel")
## Direkte Referenz auf einen GPUParticles2D-Node, der bereits hier in der
## StringSlide-Szene liegt (Emitting im Editor AUS, One Shot AUS, Local
## Coords AUS). Wird bei Rutschbeginn auf emitting=true, bei Rutschende auf
## emitting=false geschaltet, und waehrend des Rutschens jeden Frame auf die
## aktuelle Spielerposition gesetzt. Leer lassen fuer kein Partikel-Feedback.
@export var dust_particles: GPUParticles2D

@export_group("Debug")
## Gibt beim Einstieg und periodisch waehrend des Rutschens Infos in die
## Ausgabe-Konsole aus (Endpunkte, erkannte Richtung, Neigung, Speed).
@export var debug_prints: bool = false

var _active: bool = false
var _player: CharacterBody2D = null
var _ground_module: Node = null
var _direction: Vector2 = Vector2.ZERO
var _total_length: float = 0.0
var _distance: float = 0.0
var _speed: float = 0.0
var _slope_sin: float = 0.0
var _slope_cos: float = 1.0
var _stuck_time: float = 0.0
var _re_entry_lock_time: float = 0.0
var _perpendicular_offset: Vector2 = Vector2.ZERO
var _debug_timer: float = 0.0

var _local_point_a: Vector2 = Vector2.ZERO
var _local_point_b: Vector2 = Vector2.ZERO
var _geometry_ready: bool = false

func _ready() -> void:
	if not target_collider or not slide_area:
		push_warning("StringSlide: target_collider oder slide_area ist im Inspector nicht zugewiesen.")
		return
	if not _extract_local_axis_points():
		push_warning("StringSlide: target_collider hat einen nicht unterstuetzten Typ/Shape (erwartet CollisionShape2D mit RectangleShape2D/SegmentShape2D/CapsuleShape2D oder CollisionPolygon2D).")
		return
	_geometry_ready = true
	slide_area.body_shape_entered.connect(_on_slide_area_body_shape_entered)
	slide_area.body_exited.connect(_on_slide_area_body_exited)

	if debug_prints:
		print("[StringSlide] _ready OK. local_point_a=", _local_point_a, " local_point_b=", _local_point_b, " target_collider type=", target_collider.get_class())

func _extract_local_axis_points() -> bool:
	if target_collider is CollisionShape2D:
		var shape: Shape2D = target_collider.shape
		if shape is RectangleShape2D:
			var half: Vector2 = shape.size * 0.5
			if half.x >= half.y:
				_local_point_a = Vector2(-half.x, 0.0)
				_local_point_b = Vector2(half.x, 0.0)
			else:
				_local_point_a = Vector2(0.0, -half.y)
				_local_point_b = Vector2(0.0, half.y)
			return true
		elif shape is CapsuleShape2D:
			var half_h: float = shape.height * 0.5
			_local_point_a = Vector2(0.0, -half_h)
			_local_point_b = Vector2(0.0, half_h)
			return true
		elif shape is SegmentShape2D:
			_local_point_a = shape.a
			_local_point_b = shape.b
			return true
		return false
	elif target_collider is CollisionPolygon2D:
		var pts: PackedVector2Array = target_collider.polygon
		if pts.size() == 4:
			var edges: Array = []
			for i in range(4):
				var p1: Vector2 = pts[i]
				var p2: Vector2 = pts[(i + 1) % 4]
				edges.append({"mid": (p1 + p2) * 0.5, "len": p1.distance_to(p2)})
			edges.sort_custom(func(a, b): return a["len"] > b["len"])
			_local_point_a = edges[0]["mid"]
			_local_point_b = edges[1]["mid"]
			return true
		elif pts.size() >= 2:
			var best_dist: float = -1.0
			for i in range(pts.size()):
				for j in range(i + 1, pts.size()):
					var d: float = pts[i].distance_to(pts[j])
					if d > best_dist:
						best_dist = d
						_local_point_a = pts[i]
						_local_point_b = pts[j]
			return true
		return false
	return false

func _get_ordered_endpoints() -> Array:
	var a: Vector2 = target_collider.to_global(_local_point_a)
	var b: Vector2 = target_collider.to_global(_local_point_b)
	if a.y > b.y:
		var tmp: Vector2 = a
		a = b
		b = tmp
	return [a, b]

func _on_slide_area_body_shape_entered(_body_rid: RID, body: Node2D, _body_shape_index: int, local_shape_index: int) -> void:
	if not _geometry_ready:
		return
	if _active or _re_entry_lock_time > 0.0:
		return
	if not (body is CharacterBody2D):
		return
	var owner_id: int = slide_area.shape_find_owner(local_shape_index)
	var owner_node: Object = slide_area.shape_owner_get_owner(owner_id)
	if debug_prints:
		print("[StringSlide] body_shape_entered: body=", body.name, " owner_node=", owner_node, " target_collider=", target_collider, " match=", owner_node == target_collider)
	if owner_node != target_collider:
		return
	_start_slide(body)

func _on_slide_area_body_exited(body: Node2D) -> void:
	if not _active or body != _player:
		return
	_perform_natural_exit()

func _start_slide(player: CharacterBody2D) -> void:
	var ground_module: Node = player.get("ground_module")
	if not ground_module or not ground_module.has_method("set_animation_override"):
		push_warning("StringSlide: kein ground_module mit set_animation_override auf dem Spieler gefunden.")
		return

	_player = player
	_ground_module = ground_module

	var endpoints: Array = _get_ordered_endpoints()
	var top_pos: Vector2 = endpoints[0]
	var bottom_pos: Vector2 = endpoints[1]

	var full_vec: Vector2 = bottom_pos - top_pos
	_total_length = full_vec.length()
	if _total_length <= 0.001:
		if debug_prints:
			print("[StringSlide] ABBRUCH: total_length zu klein (", _total_length, ").")
		return
	_direction = full_vec / _total_length
	_slope_sin = _direction.y
	_slope_cos = sqrt(max(1.0 - _slope_sin * _slope_sin, 0.0))

	if debug_prints:
		print("[StringSlide] START top=", top_pos, " bottom=", bottom_pos, " direction=", _direction, " slope_sin=", _slope_sin, " total_length=", _total_length)

	var to_player: Vector2 = player.global_position - top_pos
	var parallel_dist: float = to_player.dot(_direction)
	_distance = clamp(parallel_dist, 0.0, _total_length)
	_perpendicular_offset = to_player - _direction * parallel_dist

	_speed = 0.0
	if inherit_entry_speed:
		_speed = max(player.velocity.dot(_direction), 0.0)

	_active = true
	_stuck_time = 0.0
	_debug_timer = 0.0
	player.velocity = _direction * _speed
	ground_module.set_animation_override(slide_animation_name, override_sprite)
	_set_dust_emitting(true)
	if dust_particles:
		dust_particles.global_position = player.global_position
	slide_started.emit()

func _set_dust_emitting(value: bool) -> void:
	if dust_particles:
		dust_particles.emitting = value

func _unhandled_key_input(event: InputEvent) -> void:
	if not _active or not allow_jump_exit:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == jump_exit_key:
		if debug_prints:
			print("[StringSlide] Jump-Exit ausgeloest bei speed=", _speed)
		_perform_jump_exit()
		get_viewport().set_input_as_handled()

func _perform_jump_exit() -> void:
	var forward: Vector2 = _direction * (_speed + jump_exit_forward_boost)
	var exit_velocity: Vector2 = Vector2(forward.x, forward.y + jump_exit_velocity)
	_end_slide(exit_velocity)

func _perform_natural_exit() -> void:
	var exit_velocity: Vector2 = _direction * (_speed + exit_forward_boost) * exit_speed_multiplier
	if debug_prints:
		print("[StringSlide] Natuerlicher Exit bei speed=", _speed, " exit_velocity=", exit_velocity)
	_end_slide(exit_velocity)

func _physics_process(delta: float) -> void:
	if _re_entry_lock_time > 0.0:
		_re_entry_lock_time -= delta

	if not _active or not _player:
		return

	var acceleration: float = gravity_strength * _slope_sin - friction_coefficient * gravity_strength * _slope_cos
	_speed = clamp(_speed + acceleration * delta, min_slide_speed, max_slide_speed)

	if debug_prints:
		_debug_timer += delta
		if _debug_timer >= 0.5:
			_debug_timer = 0.0
			print("[StringSlide] TICK speed=", _speed, " acceleration=", acceleration, " distance=", _distance, "/", _total_length)

	if _speed < 1.0 and min_slide_speed <= 0.0:
		_stuck_time += delta
		if _stuck_time >= stuck_release_time:
			if debug_prints:
				print("[StringSlide] STUCK-Ausstieg ausgeloest.")
			_perform_natural_exit()
			return
	else:
		_stuck_time = 0.0

	_distance += _speed * delta
	var endpoints: Array = _get_ordered_endpoints()
	var top_pos: Vector2 = endpoints[0]
	var bottom_pos: Vector2 = endpoints[1]

	if _distance >= _total_length:
		_player.global_position = bottom_pos + _perpendicular_offset
		if dust_particles:
			dust_particles.global_position = _player.global_position
		_perform_natural_exit()
		return

	_player.global_position = top_pos.lerp(bottom_pos, _distance / _total_length) + _perpendicular_offset
	_player.velocity = _direction * _speed
	if dust_particles:
		dust_particles.global_position = _player.global_position

func _end_slide(exit_velocity: Vector2) -> void:
	if _ground_module:
		_ground_module.clear_animation_override()
	if _player:
		_player.velocity = exit_velocity
	_set_dust_emitting(false)
	_active = false
	_speed = 0.0
	_player = null
	_ground_module = null
	_re_entry_lock_time = re_entry_lock_duration
	slide_ended.emit()

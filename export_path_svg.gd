extends StaticBody2D

@export_group("SVG Export Settings")
@export var canvas_size: Vector2 = Vector2(1920, 1080)
@export var stroke_color: String = "#00FFCC"
@export var stroke_width: float = 4.0
@export var output_filename: String = "ground_export.svg"

func _ready() -> void:
	# Eine Frame-Verzögerung einbauen, damit alle Child-Nodes garantiert geladen sind
	call_deferred("_export_to_svg")

func _export_to_svg() -> void:
	print("[Ground Exporter] Starte Export für Node: ", name)
	var shapes: Array[PackedVector2Array] = []
	
	for child in get_children():
		if child is CollisionShape2D:
			if not child.shape:
				print("[Ground Exporter] Warning: CollisionShape2D ohne 'shape' übersprungen.")
				continue
				
			var shape = child.shape
			# Globale/Lokale Transform des CollisionShape-Childs berechnen
			var child_trans = child.transform
			
			if shape is RectangleShape2D:
				var half_size = shape.size / 2.0
				var rect_points = PackedVector2Array([
					child_trans * Vector2(-half_size.x, -half_size.y),
					child_trans * Vector2(half_size.x, -half_size.y),
					child_trans * Vector2(half_size.x, half_size.y),
					child_trans * Vector2(-half_size.x, half_size.y)
				])
				shapes.append(rect_points)
				print("[Ground Exporter] RectangleShape2D gefunden.")
				
			elif shape is SegmentShape2D:
				var line_points = PackedVector2Array([
					child_trans * shape.a,
					child_trans * shape.b
				])
				shapes.append(line_points)
				print("[Ground Exporter] SegmentShape2D gefunden.")
				
			elif shape is CircleShape2D:
				# Approximiere einen Kreis als 16-Eck für SVG
				var circle_points = PackedVector2Array()
				var radius = shape.radius
				for i in range(16):
					var angle = (i / 16.0) * TAU
					var pt = Vector2(cos(angle), sin(angle)) * radius
					circle_points.append(child_trans * pt)
				shapes.append(circle_points)
				print("[Ground Exporter] CircleShape2D gefunden.")

		elif child is CollisionPolygon2D:
			if child.polygon.is_empty():
				continue
			var poly_points = PackedVector2Array()
			var child_trans = child.transform
			for p in child.polygon:
				poly_points.append(child_trans * p)
			shapes.append(poly_points)
			print("[Ground Exporter] CollisionPolygon2D mit ", child.polygon.size(), " Punkten gefunden.")

	if shapes.is_empty():
		printerr("==================================================")
		printerr("EXPORT FEHLER: Keine CollisionShape2D oder CollisionPolygon2D direkt unter '", name, "' gefunden!")
		printerr("Bitte prüfe im Szenen-Baum, ob die CollisionShape2D direkt ein Kind von 'Ground' ist.")
		printerr("==================================================")
		return

	# SVG Aufbau
	var svg = '<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n'
	svg += '<svg width="%d" height="%d" viewBox="0 0 %d %d" xmlns="http://www.w3.org/2000/svg">\n' % [
		int(canvas_size.x), int(canvas_size.y), int(canvas_size.x), int(canvas_size.y)
	]

	# Transformation des Ground-Nodes selbst einrechnen
	var main_trans = transform

	for shape in shapes:
		if shape.size() == 2:
			# Linie / Segment
			var p1 = main_trans * shape[0]
			var p2 = main_trans * shape[1]
			svg += '  <line x1="%f" y1="%f" x2="%f" y2="%f" stroke="%s" stroke-width="%f" stroke-linecap="round" />\n' % [
				p1.x, p1.y, p2.x, p2.y, stroke_color, stroke_width
			]
		elif shape.size() > 2:
			# Polygon / Rechteck / Kreis
			var points_str = ""
			for pt in shape:
				var global_pt = main_trans * pt
				points_str += "%f,%f " % [global_pt.x, global_pt.y]
			svg += '  <polygon points="%s" fill="none" stroke="%s" stroke-width="%f" stroke-linejoin="round" />\n' % [
				points_str.strip_edges(), stroke_color, stroke_width
			]

	svg += '</svg>'

	var save_path = "res://" + output_filename
	var global_path = ProjectSettings.globalize_path(save_path)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	
	if file:
		file.store_string(svg)
		file.close()
		print("==================================================")
		print("SUCCESS! Ground SVG wurde gespeichert unter:\n", global_path)
		print("==================================================")
	else:
		printerr("EXPORT FEHLER beim Schreiben der Datei. Code: ", FileAccess.get_open_error())

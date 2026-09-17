shader_type canvas_item;

// Ersetzt die RGB-Farbe der Textur KOMPLETT durch tint_color, behaelt aber
// die Alpha-Maske (also die Form/Kontur/Silhouette) der urspruenglichen
// Grafik bei. Dadurch funktioniert das Einfaerben auch bei schwarz (oder
// beliebig anders) gezeichneten PNGs - im Gegensatz zu CanvasItem.modulate,
// das die Texturfarbe nur MULTIPLIZIERT und daher schwarze Pixel (0,0,0)
// niemals aufhellen kann (weiss * schwarz = schwarz, pink * schwarz =
// schwarz, immer schwarz).
//
// Setup pro Sprite, das umgefaerbt werden soll:
// 1. Node auswaehlen (z.B. die AnimatedSprite2D "TuningPegAn").
// 2. Im Inspector: CanvasItem -> Material -> Material-Feld -> "Neue
//    Ressource..." -> "ShaderMaterial" anlegen.
// 3. Im neu angelegten ShaderMaterial: Shader-Feld -> "Laden" -> diese Datei
//    (recolor_silhouette.gdshader) auswaehlen.
// Fertig - TuningPeg.gd / ColorTint.gd setzen den Parameter "tint_color"
// automatisch aus deiner tuning_peg_color.tres-Farbe.
//
// Optional: das ShaderMaterial selbst kannst du (kleiner Pfeil daneben ->
// "Speichern als...") auch als eigene .tres-Datei sichern und bei mehreren
// Sprites zuweisen, um dir das Neuanlegen zu sparen - notwendig ist das
// aber nicht, da die Farbe sowieso zentral ueber color_theme kommt.

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	COLOR = vec4(tint_color.rgb, tex_color.a * tint_color.a);
}
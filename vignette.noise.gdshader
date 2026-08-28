shader_type canvas_item;

// intensity kommt vom zweiten Fader (0..1) - 0 = sauber/unveraendert,
// 1 = starke Vignette + deutliches Rauschen.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_strength : hint_range(0.0, 3.0) = 2.0;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.6;
uniform float noise_speed : hint_range(0.0, 10.0) = 3.0;

// Guenstiger Hash OHNE sin() - die klassische sin(dot(uv, ...))-Variante ist
// auf vielen (v.a. mobilen/integrierten) GPUs pro Pixel spuerbar teuer, weil
// sin() eine transzendente Funktion ist. Diese Variante kommt mit reinen
// Multiplikationen/fract() aus und ist deutlich guenstiger bei grossen Flaechen.
float random(vec2 uv) {
	vec3 p3 = fract(vec3(uv.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 base = COLOR;
	// intensity ist fuer ALLE Pixel im selben Draw-Call identisch (ein
	// Uniform) - dieser Branch divergiert also nicht pro Pixel und ist auf
	// der GPU billig. Steht der Fader auf 0, wird die komplette Vignette-/
	// Rausch-Berechnung fuer die ganze Flaeche uebersprungen.
	// Hinweis: "return" ist in fragment() in Godot-Shadern nicht erlaubt,
	// deshalb if/else statt fruehem Ausstieg.
	if (intensity <= 0.001) {
		COLOR = base;
	} else {
		vec2 centered = UV - vec2(0.5);
		float vignette = 1.0 - smoothstep(0.2, 0.75, length(centered) * vignette_strength) * intensity;
		float grain = (random(UV * vec2(1000.0, 1000.0) + TIME * noise_speed) - 0.5) * noise_amount * intensity;
		vec3 col = base.rgb * vignette + grain;
		COLOR = vec4(col, base.a);
	}
}
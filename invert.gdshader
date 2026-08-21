shader_type canvas_item;

uniform float mix_factor : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec4 screen_color = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec3 inverted = 1.0 - screen_color.rgb;
	COLOR = vec4(mix(screen_color.rgb, inverted, mix_factor), screen_color.a);
}
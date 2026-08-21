shader_type canvas_item;

uniform sampler2D mask_texture;

void fragment() {
    vec4 pattern = texture(TEXTURE, UV);
    vec4 mask = texture(mask_texture, UV);
    COLOR = vec4(pattern.rgb, pattern.a * mask.a);
}
shader_type canvas_item;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    // Wenn die Farbe nah an Weiß ist, setze Alpha auf 0
    if (tex_color.r > 0.9 && tex_color.g > 0.9 && tex_color.b > 0.9) {
        discard;
    }
    COLOR = tex_color;
}
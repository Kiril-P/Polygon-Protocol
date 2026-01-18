shader_type canvas_item;

uniform float strength : hint_range(0.0, 0.1) = 0.05;
uniform float center_size : hint_range(0.0, 1.0) = 0.2;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 rel = uv - vec2(0.5);
    float dist = length(rel);
    
    // Only distort outer edges
    float mask = smoothstep(center_size, 1.0, dist);
    
    vec4 color = texture(SCREEN_TEXTURE, uv - rel * strength * mask);
    
    // Add a bit of chromatic aberration on the edges
    color.r = texture(SCREEN_TEXTURE, uv - rel * strength * mask * 1.1).r;
    color.b = texture(SCREEN_TEXTURE, uv - rel * strength * mask * 0.9).b;
    
    COLOR = color;
}

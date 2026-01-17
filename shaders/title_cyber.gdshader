shader_type canvas_item;

uniform float bloom_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float chromatic_aberration : hint_range(0.0, 10.0) = 2.0;
uniform float scanline_speed : hint_range(0.0, 10.0) = 1.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.1;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Chromatic Aberration
    float r = texture(TEXTURE, UV + vec2(SCREEN_PIXEL_SIZE.x * chromatic_aberration, 0.0)).r;
    float g = texture(TEXTURE, UV).g;
    float b = texture(TEXTURE, UV - vec2(SCREEN_PIXEL_SIZE.x * chromatic_aberration, 0.0)).b;
    float a = texture(TEXTURE, UV).a;
    
    vec4 color = vec4(r, g, b, a);
    
    // Scanlines
    float scanline = sin(UV.y * 200.0 + TIME * scanline_speed * 10.0);
    color.rgb += scanline * scanline_intensity;
    
    // Bloom/Glow
    color.rgb *= bloom_intensity;
    
    COLOR = color;
}

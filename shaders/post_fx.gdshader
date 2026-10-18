shader_type canvas_item;
// Full-screen finishing pass: bloom, chromatic aberration, vignette,
// danger pulse and a faint scanline texture.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float aberration = 0.0015;
uniform float bloom_strength = 0.26;
uniform float vignette = 0.32;
uniform vec4 danger_color : source_color = vec4(1.0, 0.05, 0.1, 1.0);
uniform float danger = 0.0;
uniform float scanline = 0.018;
uniform float time = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);

	float ab = aberration * (0.35 + r2 * 4.0);
	vec3 col;
	col.r = texture(screen_tex, uv + c * ab * 1.0).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ab * 1.0).b;

	// Cheap bloom from mip levels
	vec3 b = textureLod(screen_tex, uv, 2.0).rgb * 0.30
		+ textureLod(screen_tex, uv, 3.0).rgb * 0.30
		+ textureLod(screen_tex, uv, 4.0).rgb * 0.25
		+ textureLod(screen_tex, uv, 5.0).rgb * 0.20;
	b = max(b - 0.10, vec3(0.0));
	col += b * bloom_strength * 2.2;

	// Vignette + danger pulse at the edges
	float v = smoothstep(0.15, 0.85, r2 * 2.2);
	col *= 1.0 - v * vignette;
	col = mix(col, col + danger_color.rgb * v * 0.55, danger);

	// Scanlines
	col *= 1.0 - scanline * (0.5 + 0.5 * sin(SCREEN_UV.y * 1400.0));

	COLOR = vec4(col, 1.0);
}

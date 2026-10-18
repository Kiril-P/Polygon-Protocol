shader_type canvas_item;
// Living background: deep-space nebula, parallax stars and a neon grid that
// ripples when VFX.shockwave() fires. Coordinates are in canvas pixels.

uniform vec2 view_size = vec2(1920.0, 1080.0);
uniform vec2 offset = vec2(0.0);
uniform vec4 line_color : source_color = vec4(0.0, 0.5, 1.0, 0.1);
uniform float time = 0.0;
uniform vec4 waves[12]; // xy = canvas px, z = age (s), w = strength (0 = unused)
uniform float line_thickness : hint_range(0.0, 10.0) = 1.2;
uniform float grid_spacing = 80.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

vec3 stars(vec2 p, float cell, float density, float seed) {
	vec2 g = floor(p / cell);
	vec2 f = fract(p / cell);
	float h = hash21(g + seed);
	if (h > density) return vec3(0.0);
	vec2 sp = vec2(hash21(g + seed + 1.7), hash21(g + seed + 3.1));
	float d = length(f - sp) * cell;
	float tw = 0.65 + 0.35 * sin(time * (1.0 + h * 5.0) + h * 40.0);
	float s = exp(-d * d / (1.2 + h * 3.0)) * tw;
	return mix(vec3(0.6, 0.8, 1.0), vec3(1.0, 0.8, 0.9), step(0.5, hash21(g + seed + 9.0))) * s * (0.4 + h / density);
}

void fragment() {
	vec2 p = UV * view_size;

	// Shockwave displacement of the grid
	vec2 disp = vec2(0.0);
	float heat = 0.0;
	for (int i = 0; i < 12; i++) {
		vec4 w = waves[i];
		if (w.w > 0.0) {
			vec2 diff = p - w.xy;
			float dist = length(diff) + 0.001;
			float r = w.z * 850.0;
			float ring = exp(-pow((dist - r) / 80.0, 2.0));
			float amp = w.w * exp(-w.z * 1.7);
			disp += diff / dist * ring * amp * 55.0;
			heat += ring * amp;
		}
	}

	vec2 gp = p - disp + offset;
	float s = grid_spacing;
	vec2 q = abs(fract(gp / s - 0.5) - 0.5) * s;
	float dmin = min(q.x, q.y);
	float line = 1.0 - smoothstep(0.0, line_thickness, dmin);
	float glow = exp(-dmin * 0.3);

	vec2 qm = abs(fract(gp / (s * 5.0) - 0.5) - 0.5) * s * 5.0;
	float major = 1.0 - smoothstep(0.0, line_thickness * 2.2, min(qm.x, qm.y));
	float node = exp(-dot(qm, qm) / 50.0);

	vec3 lc = line_color.rgb;
	float tint = 0.6 + clamp(line_color.a * 4.0, 0.0, 1.0);

	vec3 col = vec3(0.012, 0.012, 0.04);
	float n = fbm((p + offset * 0.2) / 520.0 + vec2(time * 0.012, 0.0));
	col += lc * n * n * 0.22;
	col += stars(p + offset * 0.25, 90.0, 0.35, 0.0);
	col += stars(p + offset * 0.45, 140.0, 0.25, 11.0) * 0.8;

	col += lc * (line * 0.12 + glow * 0.07 + major * 0.2) * tint;
	col += lc * node * 0.55;
	col += mix(lc, vec3(1.0), 0.35) * heat * (line * 0.8 + glow * 0.35) * 0.8;
	col += lc * heat * 0.06;

	vec2 c = UV - 0.5;
	col *= 1.0 - dot(c, c) * 1.3;
	COLOR = vec4(col, 1.0);
}

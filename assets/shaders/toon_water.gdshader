shader_type spatial;
// Toy pond water (Pond): bright blue in soft bands, moving ripples with light crests, and a white
// foam ring at the shore that breathes in and out. Opaque and without the depth texture: the
// distance to the shore comes from the mesh (UV.x: 0 at the shore, 1 in the middle).
render_mode cull_back;

uniform vec3 shallow_color : source_color = vec3(0.08, 0.72, 1.0);
uniform vec3 deep_color : source_color = vec3(0.0, 0.3, 0.94);
uniform vec3 foam_color : source_color = vec3(1.0);
uniform float foam_width = 0.1;
uniform float ripple_scale = 0.9;

varying vec2 world_xz;

float waves(vec2 p, float t) {
	return sin(p.x * 1.1 + t * 1.2 + sin(p.y * 0.8 + t * 0.7) * 1.6)
		+ sin(p.y * 1.4 - t * 1.0 + sin(p.x * 0.9 - t * 0.6) * 1.4)
		+ 0.5 * sin((p.x + p.y) * 2.3 + t * 2.1);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float t = TIME;
	vec2 p = world_xz * ripple_scale;
	float w = waves(p, t);
	float wx = waves(p + vec2(0.05, 0.0), t);
	float wz = waves(p + vec2(0.0, 0.05), t);
	vec3 n = normalize(vec3(-(wx - w) * 0.6, 1.0, -(wz - w) * 0.6));
	float shore = UV.x;
	// Toon bands from the shore to the middle, nudged by the ripples.
	float depth = clamp(shore + w * 0.03, 0.0, 1.0);
	float band = floor(depth * 3.0 + 0.6) / 3.0;
	vec3 col = mix(shallow_color, deep_color, clamp(band, 0.0, 1.0));
	// Light lines where the ripples peak.
	float crest = smoothstep(1.75, 1.82, w);
	col = mix(col, vec3(0.8, 0.95, 1.0), crest * 0.6);
	// Foam ring at the shore, and a thin wave line that runs in to the shore and fades.
	float wob = sin(p.x * 2.0 + t * 1.5) * sin(p.y * 2.2 - t * 1.2) * 0.025;
	float ring = foam_width * (1.0 + 0.25 * sin(t * 1.3));
	float s = shore + wob;
	float foam = 1.0 - smoothstep(ring - 0.012, ring + 0.012, s);
	float cyc = fract(t * 0.22);
	float line_at = ring + 0.25 * (1.0 - cyc);
	float wave_line = (1.0 - smoothstep(0.008, 0.02, abs(s - line_at))) * cyc;
	foam = max(foam, wave_line * 0.9);
	ALBEDO = mix(col, foam_color, foam);
	ROUGHNESS = mix(0.22, 0.8, foam);
	SPECULAR = 0.12;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mix(n, vec3(0.0, 1.0, 0.0), foam)), 0.0)).xyz);
}

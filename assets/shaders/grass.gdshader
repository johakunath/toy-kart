shader_type spatial;
// Grass tufts, reeds and flowers of a GrassField (MultiMesh). They sway in the wind, tips most,
// and far ones sink into the lawn instead of popping out of sight.
// Mesh: COLOR.rgb = own colour (sRGB), COLOR.a = 1 where the instance colour paints (petals),
// UV.y = 0 at the root, 1 at the tip. INSTANCE_CUSTOM: rgb = petal colour (sRGB), a = phase 0..1.
render_mode cull_disabled, world_vertex_coords;

// Same direction the clouds drift (Atmosphere._wind).
uniform vec2 wind_dir = vec2(0.92, 0.4);
uniform float wind_strength = 0.32;
uniform float wind_speed = 1.3;
uniform float fade_start = 30.0;
uniform float fade_end = 42.0;

varying vec3 world_normal;
varying vec3 petal;
varying float shade;

vec3 to_linear(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 local = VERTEX - origin;
	local *= 1.0 - smoothstep(fade_start, fade_end, distance(origin.xz, CAMERA_POSITION_WORLD.xz));
	float phase = INSTANCE_CUSTOM.a * 6.2832;
	vec2 dir = normalize(wind_dir);
	float t = TIME * wind_speed;
	// Slow gusts roll across the lawn along the wind; each tuft adds its own quick flutter.
	float gust = 0.5 + 0.5 * sin(dot(origin.xz, dir) * 0.16 - t);
	gust *= gust;
	float flutter = sin(t * 2.6 + phase) * 0.6 + sin(t * 4.1 + phase * 1.7) * 0.3;
	float bend = wind_strength * (0.2 + gust + flutter * (0.25 + 0.5 * gust)) * UV.y;
	local.xz += dir * bend * local.y;
	local.y *= 1.0 - 0.3 * bend * bend;
	VERTEX = origin + local;
	world_normal = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6));
	petal = to_linear(INSTANCE_CUSTOM.rgb);
	shade = 0.88 + 0.24 * fract(INSTANCE_CUSTOM.a * 7.31);
}

void fragment() {
	ALBEDO = mix(to_linear(COLOR.rgb) * shade, petal, COLOR.a);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = ALBEDO * 0.3;
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
}

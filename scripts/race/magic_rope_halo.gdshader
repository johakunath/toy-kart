// The magic rope's soft pink glow around the core.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform float fade = 1.0;
void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float glow = pow(facing, 2.5);
	float pulse = 0.75 + 0.25 * sin(UV.x * 1.4 - TIME * 8.0);
	ALBEDO = vec3(1.0, 0.25, 0.6) * glow * pulse;
	ALPHA = glow * 0.22 * fade * UV2.x * smoothstep(1.5, 4.0, -VERTEX.z) * smoothstep(0.95, 0.72, SCREEN_UV.y);
}

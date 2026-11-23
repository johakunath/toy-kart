// The magic rope's core: candy stripes spiralling toward the kid, a light pulse, dark seams.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, blend_mix;
uniform float fade = 1.0;
void fragment() {
	float along = UV.x;
	float band = fract(along * 1.1 - UV.y - TIME * 1.6);
	float w = fwidth(band) * 1.5 + 0.02;
	vec3 magenta = vec3(1.0, 0.02, 0.5);
	vec3 gold = vec3(1.0, 0.68, 0.0);
	vec3 cyan = vec3(0.0, 0.55, 1.0);
	vec3 col = mix(magenta, gold, smoothstep(0.333 - w, 0.333 + w, band));
	col = mix(col, cyan, smoothstep(0.666 - w, 0.666 + w, band));
	col = mix(col, magenta, smoothstep(1.0 - w, 1.0, band));
	// A thin darker seam between the colours, like a twisted toy cord.
	float seam = min(min(abs(band - 0.333), abs(band - 0.666)), min(band, 1.0 - band));
	col *= mix(0.45, 1.0, smoothstep(0.0, 0.05 + w, seam));
	float pulse = pow(0.5 + 0.5 * sin(along * 1.4 - TIME * 8.0), 10.0);
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = col * (0.85 + 0.8 * pulse) + vec3(1.0, 0.9, 0.6) * rim * 0.1;
	// Fades out right in front of a camera and at the bottom of the picture (dad's camera
	// sits above the rope that runs back to the kid behind him).
	ALPHA = fade * UV2.x * smoothstep(1.5, 4.0, -VERTEX.z) * smoothstep(0.95, 0.72, SCREEN_UV.y);
}

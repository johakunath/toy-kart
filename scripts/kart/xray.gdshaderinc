// X-ray silhouette body, shared by xray_p1/xray_p2.gdshader (see xray.gd). Each player file sets
// its own stencil value: a shader's stencil reference is fixed at compile time.
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D mask : source_color, hint_default_white, filter_linear_mipmap;
uniform bool use_mask = false;

void fragment() {
	if (use_mask && texture(mask, UV).a < 0.5) {
		discard;
	}
	// A lighter edge makes the shape read as a body, not a flat blob.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(tint.rgb, vec3(1.0), 0.08 + rim * 0.5);
	ALPHA = tint.a;
}

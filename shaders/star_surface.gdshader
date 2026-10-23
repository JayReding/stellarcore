shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 star_color : source_color = vec4(1.0, 0.93, 0.82, 1.0);
uniform float intensity = 1.8;
uniform float limb_darkening = 0.42;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float brightness = mix(1.0 - limb_darkening, 1.0, facing);
	ALBEDO = star_color.rgb * intensity * brightness;
}

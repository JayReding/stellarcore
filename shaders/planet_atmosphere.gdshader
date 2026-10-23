shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

uniform vec4 atmosphere_color : source_color = vec4(0.35, 0.58, 0.90, 0.55);
uniform float intensity = 0.7;
uniform vec3 star_position = vec3(0.0);

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.6);
	vec3 to_star = normalize(star_position - world_position);
	float daylight = smoothstep(-0.30, 0.35, dot(world_normal, to_star));
	ALBEDO = atmosphere_color.rgb;
	ALPHA = rim * atmosphere_color.a * intensity * mix(0.06, 1.0, daylight);
}

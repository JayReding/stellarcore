shader_type sky;
// Procedural Babylon-5-style deep space: dark blue nebula banks with a dim
// background star field. Rendered once as the Stellar View sky so it costs
// nothing per frame beyond the background pass itself.

uniform vec4 deep_color : source_color = vec4(0.006, 0.010, 0.026, 1.0);
uniform vec4 mid_color : source_color = vec4(0.035, 0.075, 0.180, 1.0);
uniform vec4 high_color : source_color = vec4(0.10, 0.17, 0.34, 1.0);
uniform vec4 ice_color : source_color = vec4(0.38, 0.50, 0.70, 1.0);
uniform float cloud_scale = 2.1;
uniform float star_density = 1.0;
uniform float star_brightness = 0.9;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
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
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * vnoise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		amplitude *= 0.55;
	}
	return value;
}

// Seamless 3D value noise sampled straight on the view direction, so the
// clouds have no UV seams, poles, or branch cuts anywhere on the sky.
float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(
			mix(hash31(i), hash31(i + vec3(1.0, 0.0, 0.0)), u.x),
			mix(hash31(i + vec3(0.0, 1.0, 0.0)), hash31(i + vec3(1.0, 1.0, 0.0)), u.x),
			u.y
		),
		mix(
			mix(hash31(i + vec3(0.0, 0.0, 1.0)), hash31(i + vec3(1.0, 0.0, 1.0)), u.x),
			mix(hash31(i + vec3(0.0, 1.0, 1.0)), hash31(i + vec3(1.0, 1.0, 1.0)), u.x),
			u.y
		),
		u.z
	);
}

float fbm3(vec3 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * vnoise3(p);
		p = p * 2.03 + vec3(17.3, 9.1, 5.3);
		amplitude *= 0.55;
	}
	return value;
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	// Equirectangular lookup only for the tiny star grid and dither, where a
	// seam is invisible. All clouds use seamless 3D noise on the direction.
	vec2 uv = vec2(atan(direction.z, direction.x), asin(clamp(direction.y, -1.0, 1.0)));

	// Domain-warped clouds for long wispy banks rather than round blobs.
	vec3 wobble = direction * 1.7 * cloud_scale + vec3(3.1, 7.7, 1.3);
	float warp = fbm3(wobble);
	float banks = fbm3(direction * cloud_scale + warp * 0.9);
	float detail = fbm3(direction * cloud_scale * 2.6 - vec3(11.0, 4.0, 2.0));
	float clouds = clamp(banks * 0.75 + detail * 0.35, 0.0, 1.0);

	vec3 col = deep_color.rgb;
	col = mix(col, mid_color.rgb, smoothstep(0.32, 0.72, clouds));
	col = mix(col, high_color.rgb, smoothstep(0.52, 0.88, clouds));
	col = mix(col, ice_color.rgb, smoothstep(0.74, 0.98, clouds) * 0.5);

	// Dark dust lanes carve depth into the brightest banks.
	float dust = 1.0 - smoothstep(0.28, 0.62, fbm3(
		direction * cloud_scale * 2.2 + vec3(5.0, 1.0, 8.0)
	));
	col *= mix(1.0, 0.55, dust * smoothstep(0.45, 0.8, clouds));

	// Dim background star field on its own grid so stars ignore the clouds.
	vec2 suv = vec2(uv.x * 0.5, uv.y) * 230.0;
	vec2 cell = floor(suv);
	vec2 cell_pos = fract(suv);
	float seed = hash21(cell);
	float threshold = 1.0 - 0.09 * star_density;
	if (seed > threshold) {
		vec2 offset = vec2(hash21(cell + 7.13), hash21(cell + 3.71)) * 0.7 + 0.15;
		float dist = length(cell_pos - offset);
		float magnitude = pow((seed - threshold) / max(1.0 - threshold, 0.0001), 2.0);
		float disc = 1.0 - smoothstep(0.0, 0.10, dist);
		vec3 tint = mix(vec3(0.72, 0.82, 1.0), vec3(1.0), hash21(cell + 1.7));
		col += tint * disc * magnitude * star_brightness;
	}

	// High-frequency dither kills color banding in the dark gradients.
	col += (vnoise(uv * 900.0) - 0.5) * 0.012;

	COLOR = col;
}

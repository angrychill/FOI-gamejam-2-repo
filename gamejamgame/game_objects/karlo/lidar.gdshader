shader_type spatial;

// ---- LiDAR controls ----
uniform vec3  lidar_origin = vec3(0.0);
uniform float scan_radius  = 5.0;
uniform float band_width   = 0.15;

// ---- Point look ----
uniform float point_density = 25.0;
uniform float point_size    = 0.25;
uniform float point_boost   = 3.0;

// ---- Dimming ----
uniform float dim_strength  = 0.6;
uniform vec3  lidar_color   = vec3(0.9, 1.0, 0.9);

// ---- Varying ----
varying vec3 world_pos;

// ---------- hash helpers ----------
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	float n = hash12(p);
	return vec2(n, hash12(p + n + 19.19));
}

void vertex() {
	// Convert local vertex position to world space
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base_albedo = ALBEDO;

	// Distance from LiDAR origin
	float d = distance(world_pos, lidar_origin);
	float ring = 1.0 - smoothstep(
		band_width,
		band_width * 1.5,
		abs(d - scan_radius)
	);

	// Surface-stable coordinates (XZ projection)
	vec2 p = world_pos.xz;

	vec2 grid = p * point_density;
	vec2 cell = floor(grid);
	vec2 f    = fract(grid);

	vec2 rnd_center = hash22(cell) * 0.8 + 0.1;

	float r = length(f - rnd_center);
	float dot_mask = 1.0 - smoothstep(point_size, point_size * 1.2, r);

	float keep = step(0.35, hash12(cell + 7.7));

	float lidar_pts = ring * dot_mask * keep;

	// Dim base material under scan
	float dim = mix(1.0, 1.0 - dim_strength, ring);
	ALBEDO = base_albedo * dim;

	// Bright LiDAR dots
	EMISSION += lidar_color * (lidar_pts * point_boost);
}

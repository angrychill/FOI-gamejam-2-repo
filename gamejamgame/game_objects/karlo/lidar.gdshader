shader_type spatial;
render_mode unshaded, cull_back;

const int MAX_POINTS = 256;

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform int lidar_point_count = 0;
uniform vec3 lidar_points[MAX_POINTS];
uniform vec4 lidar_colors[MAX_POINTS];

uniform float point_radius = 0.08; // try bigger first
uniform float soft_edge   = 0.06;  // try bigger first
uniform float glow_strength = 1.5; // makes points pop

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Base mesh always visible:
	vec3 base_rgb = base_color.rgb;

	// Find closest lidar point
	float best_d = 1e20;
	vec4 best_col = vec4(0.0);

	for (int i = 0; i < MAX_POINTS; i++) {
		if (i >= lidar_point_count) break;

		vec4 c = lidar_colors[i];
		if (c.a <= 0.0) continue;

		float d = distance(world_pos, lidar_points[i]);
		if (d < best_d) {
			best_d = d;
			best_col = c;
		}
	}

	float inner = point_radius;
	float outer = point_radius + soft_edge;
	float a = 1.0 - smoothstep(inner, outer, best_d); // 0..1

	// Overlay points onto base color (no transparency needed)
	vec3 out_rgb = mix(base_rgb, best_col.rgb, a);

	ALBEDO = out_rgb;
	ALPHA = 1.0;

	// Optional “glow”
	EMISSION = best_col.rgb * a * glow_strength;
}

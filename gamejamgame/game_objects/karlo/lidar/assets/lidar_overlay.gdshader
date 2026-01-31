shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

const int MAX_SHAPES = 256;

uniform bool lidar_enabled = true;
uniform bool lidar_arrays_valid = true; // manager sets true once arrays are pushed
uniform int  lidar_shape_count = 0;

uniform float time_now_s = 0.0; // manager updates every frame

uniform vec4  lidar_t0[MAX_SHAPES];
uniform vec4  lidar_t1[MAX_SHAPES];
uniform vec4  lidar_t2[MAX_SHAPES];
uniform vec4  lidar_t3[MAX_SHAPES];      // origin.xyz + type in w
uniform vec4  lidar_params[MAX_SHAPES];  // params.xyz + birth_time_s in w
uniform vec4  lidar_colors[MAX_SHAPES];  // rgb + intensity in a
uniform float lidar_fade[MAX_SHAPES];    // lifetime_s (<=0 => infinite)

uniform float edge_softness = 0.06;

/* Base material inputs (copied in from your BaseMaterial3D) */
uniform sampler2D base_albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 base_albedo_color : source_color = vec4(1.0);

/* Darkness tint applied to the GRAYSCALE (outside reveal) */
uniform vec3  dark_color : source_color = vec3(0.0,0.0,0.0);
uniform float dark_alpha = 1;

/* Lidar reveal strength */
uniform float reveal_strength = 1.0;

varying vec3 wpos;

float sdf_sphere(vec3 p, float r) { return length(p) - r; }

float sdf_box(vec3 p, vec3 b) {
	vec3 q = abs(p) - b;
	return length(max(q, vec3(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdf_capsule_y(vec3 p, float r, float h) {
	p.y = clamp(p.y, -h, h);
	return length(p) - r;
}

float sdf_cylinder_y(vec3 p, float r, float h) {
	vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
	return min(max(d.x, d.y), 0.0) + length(max(d, vec2(0.0)));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// --- base color (this is what we grayscale and later reveal) ---
	vec4 tex_c  = texture(base_albedo_tex, UV);
	vec4 base_c = tex_c * base_albedo_color;

	// grayscale base
	float g = dot(base_c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 gray_rgb = vec3(g);

	// darken the grayscale by tinting towards dark_color
	vec3 gray_dark = mix(gray_rgb, dark_color, clamp(dark_alpha, 0.0, 1.0));

	// --- lidar mask (0..1) ---
	float amax = 0.0;
	int effective_count = 0;

	if (lidar_enabled && lidar_arrays_valid) {
		effective_count = lidar_shape_count;
	}

	for (int i = 0; i < MAX_SHAPES; i++) {
		if (i >= effective_count) break;

		vec4 c = lidar_colors[i];
		if (c.a <= 0.0) continue;

		// GPU fade from birth/lifetime
		float birth_s = lidar_params[i].w;
		float life_s  = lidar_fade[i]; // <=0 => infinite

		float fade = 1.0;
		if (life_s > 0.0) {
			float age = max(time_now_s - birth_s, 0.0);
			fade = clamp(1.0 - (age / life_s), 0.0, 1.0);
		}
		if (fade <= 0.0) continue;

		mat3 B = mat3(lidar_t0[i].xyz, lidar_t1[i].xyz, lidar_t2[i].xyz);
		vec3 O = lidar_t3[i].xyz;
		float type = lidar_t3[i].w;

		vec3 p = transpose(B) * (wpos - O);
		vec4 prm = lidar_params[i];

		float d = 1e20;
		if (type < 0.5) {          // 0 point (treated as sphere)
			d = sdf_sphere(p, prm.x);
		} else if (type < 1.5) {   // 1 sphere
			d = sdf_sphere(p, prm.x);
		} else if (type < 2.5) {   // 2 box
			d = sdf_box(p, prm.xyz);
		} else if (type < 3.5) {   // 3 capsule
			d = sdf_capsule_y(p, prm.x, prm.y);
		} else if (type < 4.5) {   // 4 cylinder
			d = sdf_cylinder_y(p, prm.x, prm.y);
		} else {
			continue;
		}

		float a = 1.0 - smoothstep(0.0, edge_softness, max(d, 0.0));
		a *= fade;

		amax = max(amax, a * c.a);
	}

	float cut = clamp(amax * reveal_strength, 0.0, 1.0);

	// --- final mix: outside = gray+dark, inside = original base ---
	vec3 out_rgb = mix(gray_dark, base_c.rgb, cut);

	ALBEDO = out_rgb;
	ALPHA  = base_c.a;
}

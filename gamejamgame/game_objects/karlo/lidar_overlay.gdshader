shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

const int MAX_SHAPES = 256;

uniform bool lidar_enabled = true;

uniform int lidar_shape_count = 0;

uniform vec4 lidar_t0[MAX_SHAPES];
uniform vec4 lidar_t1[MAX_SHAPES];
uniform vec4 lidar_t2[MAX_SHAPES];
uniform vec4 lidar_t3[MAX_SHAPES];      // origin.xyz + type in w
uniform vec4 lidar_params[MAX_SHAPES];  // per-type params
uniform vec4 lidar_colors[MAX_SHAPES];  // rgb + intensity in a (ignored here)
uniform float lidar_fade[MAX_SHAPES];   // 0..1 fade multiplier

uniform float edge_softness = 0.06;

/* Darkness overlay:
   - dark_color is the tint applied everywhere (in the overlay pass)
   - dark_alpha is how strong that tint is (1 = fully override, 0 = no effect)
*/
uniform vec3  dark_color:source_color = vec3(0.02, 0.02, 0.02);
uniform float dark_alpha = 0.85;

/* How strongly lidar "cuts out" darkness
   1.0 = full reveal (recommended)
   <1  = leaves some darkness even where lit
*/
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
	if (!lidar_enabled) {
		discard; // no darkness, no lidar effect at all
	}

	// Compute lidar coverage mask (amax: 0..1)
	float amax = 0.0;

	for (int i = 0; i < MAX_SHAPES; i++) {
		if (i >= lidar_shape_count) break;

		float fade = lidar_fade[i];
		if (fade <= 0.0) continue;

		vec4 c = lidar_colors[i];
		if (c.a <= 0.0) continue;

		mat3 B = mat3(lidar_t0[i].xyz, lidar_t1[i].xyz, lidar_t2[i].xyz);
		vec3 O = lidar_t3[i].xyz;
		float type = lidar_t3[i].w;

		vec3 p = transpose(B) * (wpos - O);
		vec4 prm = lidar_params[i];

		float d = 1e20;
		if (type < 0.5) {          // 0 point
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

		// Soft fill mask
		float a = 1.0 - smoothstep(0.0, edge_softness, max(d, 0.0));
		a *= fade;

		amax = max(amax, a * c.a);
	}

	// Darkness alpha is reduced by lidar coverage:
	// - where amax == 0 -> alpha = dark_alpha (dark)
	// - where amax == 1 -> alpha = dark_alpha * (1 - reveal_strength) (transparent if reveal_strength=1)
	float cut = clamp(amax * reveal_strength, 0.0, 1.0);
	float out_a = clamp(dark_alpha * (1.0 - cut), 0.0, 1.0);

	// If fully transparent (fully revealed), skip drawing so base shows untouched
	if (out_a <= 0.001) {
		discard;
	}

	ALBEDO = dark_color;
	ALPHA = out_a;
}

shader_type sky;

uniform sampler2D sky_texture : filter_nearest, repeat_enable;

uniform float grayscale_amount : hint_range(0.0, 1.0) = 1.0;
uniform float uv_scale = 1.0;

/*
 Contrast behavior:
 1.0  = no contrast change
 >1.0 = higher contrast (stars pop, background crushed)
 */
uniform float contrast : hint_range(0.5, 5.0) = 2.5;

/*
 Overall brightness / sky energy
 */
uniform float intensity : hint_range(0.0, 1.0) = 0.05;

void sky() {
    vec2 uv = SKY_COORDS.xy * uv_scale;

    vec3 color = texture(sky_texture, uv).rgb;

    // Grayscale
    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(color, vec3(gray), grayscale_amount);

    // Contrast (power curve, great for stars)
    color = pow(color, vec3(contrast));

    // Final intensity (HDR-safe)
    COLOR = color * intensity;
}

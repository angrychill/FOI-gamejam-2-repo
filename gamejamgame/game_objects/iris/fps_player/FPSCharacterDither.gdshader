shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.15;
uniform float grain_size : hint_range(1.0, 8.0) = 2.0;

float bayer(vec2 uv) {
    float pattern[16] = float[16](
        0.0/16.0, 8.0/16.0, 2.0/16.0, 10.0/16.0,
        12.0/16.0, 4.0/16.0, 14.0/16.0, 6.0/16.0,
        3.0/16.0, 11.0/16.0, 1.0/16.0, 9.0/16.0,
        15.0/16.0, 7.0/16.0, 13.0/16.0, 5.0/16.0
    );
    
    vec2 pos = floor(uv * grain_size);
    int x = int(mod(pos.x, 4.0));
    int y = int(mod(pos.y, 4.0));
    return pattern[y * 4 + x];
}

void fragment() {
    vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
    
    float threshold = bayer(FRAGCOORD.xy);
    vec3 dithered = floor(color.rgb + threshold * dither_strength);
    
    COLOR = vec4(mix(color.rgb, dithered, dither_strength), color.a);
}
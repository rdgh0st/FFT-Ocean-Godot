#[compute]
#version 460 core

layout(local_size_x = 1, local_size_y = 8, local_size_z = 1) in;

const float PI = 3.14159265359;

layout (binding = 16, rgba32f) writeonly uniform image2D butterflyTex;

layout(set = 0, binding = 0) buffer SpectrumParameters {
    float fetch;
    float windSpeed;
    float enhancementFactor;
    float inputFreq;
    float resolution;
    float oceanSize;
    float time;
    float transformHorizontal;
    float lowCutoff;
    float highCutoff;
    float depth;
} params;

int reverse(int i) {
    int res = 0;
    for (int j = 0; j < log2(params.resolution); j++) {
        res = (res << 1) + (i & 1);
        i >>= 1;
    }
    return res;
}

vec2 ComplexExp(vec2 a) {
    return vec2(cos(a.y), sin(a.y)) * exp(a.x);
}

void main() {
    vec2 pixel_coord = gl_GlobalInvocationID.xy;
    float k = mod(((pixel_coord.y * params.resolution) / pow(2.0, pixel_coord.x + 1)), params.resolution);
    vec2 mult = vec2(2.0 * PI * k / params.resolution);
    vec2 twiddle = vec2(cos(2.0 * PI * k / params.resolution), sin(2.0 * PI * k / params.resolution));
    float span = pow(2.0, pixel_coord.x);
    bool top = false;
    if (mod(pixel_coord.y, pow(2.0, pixel_coord.x + 1)) < span) {
        top = true;
    }

    if (pixel_coord.x == 0) {
        if (top) {
            imageStore(butterflyTex, ivec2(pixel_coord), vec4(twiddle.x, twiddle.y, reverse(ivec2(pixel_coord).y), reverse(ivec2(pixel_coord).y + 1)));
        } else {
            imageStore(butterflyTex, ivec2(pixel_coord), vec4(twiddle.x, twiddle.y, reverse(ivec2(pixel_coord).y - 1), reverse(ivec2(pixel_coord).y)));
        }
    } else {
        if (top) {
            imageStore(butterflyTex, ivec2(pixel_coord), vec4(twiddle.x, twiddle.y, pixel_coord.y, pixel_coord.y + span));
        } else {
            imageStore(butterflyTex, ivec2(pixel_coord), vec4(twiddle.x, twiddle.y, pixel_coord.y - span, pixel_coord.y));
        }
    }
    
}
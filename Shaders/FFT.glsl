#[compute]
#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const float PI = 3.14159265359;

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
    float stage; // i in iteration above
    float direction; // vertical or horizontal
    float swell;
} params;

layout(set = 0, binding = 11, rgba32f) readonly uniform image2D displacement_image;
layout(set = 0, binding = 12, rgba32f) readonly uniform image2D slope_image;
layout(set = 0, binding = 13, rgba32f) writeonly uniform image2D heightmap_image;
layout(set = 0, binding = 14, rgba32f) writeonly uniform image2D triangle_image;
layout(set = 0, binding = 16, rgba32f) readonly uniform image2D butterflyTex;

vec2 MultiplyComplex(vec2 a, vec2 b) {
    return vec2(a.r * b.r - a.g * b.g, a.r * b.g + a.g * b.r);
}

vec2 AddComplex(vec2 a, vec2 b) {
    return a + b;
}

void horizontalFFT() {
    ivec2 x = ivec2(gl_GlobalInvocationID.xy);

    vec4 butterflyData = imageLoad(butterflyTex, ivec2(params.stage, x.x)).xyzw;
    vec2 p = imageLoad(displacement_image, ivec2(butterflyData.z, x.y)).xy;
    vec2 q = imageLoad(displacement_image, ivec2(butterflyData.w, x.y)).xy;
    vec2 twiddle = vec2(butterflyData.x, -butterflyData.y);

    vec2 h = AddComplex(p, MultiplyComplex(twiddle, q));

    vec2 p2 = imageLoad(displacement_image, ivec2(butterflyData.z, x.y)).zw;
    vec2 q2 = imageLoad(displacement_image, ivec2(butterflyData.w, x.y)).zw;

    vec2 h2 = AddComplex(p2, MultiplyComplex(twiddle, q2));

    imageStore(heightmap_image, x, vec4(h, h2));

    p = imageLoad(slope_image, ivec2(butterflyData.z, x.y)).xy;
    q = imageLoad(slope_image, ivec2(butterflyData.w, x.y)).xy;
    vec2 s = AddComplex(p, MultiplyComplex(twiddle, q));

    p2 = imageLoad(slope_image, ivec2(butterflyData.z, x.y)).zw;
    q2 = imageLoad(slope_image, ivec2(butterflyData.w, x.y)).zw;
    vec2 s2 = AddComplex(p2, MultiplyComplex(twiddle, q2));

    imageStore(triangle_image, x, vec4(s, s2));
}

void verticalFFT() {
    ivec2 x = ivec2(gl_GlobalInvocationID.xy);

    vec4 butterflyData = imageLoad(butterflyTex, ivec2(params.stage, x.y)).xyzw;
    vec2 p = imageLoad(displacement_image, ivec2(x.x, butterflyData.z)).xy;
    vec2 q = imageLoad(displacement_image, ivec2(x.x, butterflyData.w)).xy;
    vec2 twiddle = vec2(butterflyData.x, -butterflyData.y);

    vec2 h = AddComplex(p, MultiplyComplex(twiddle, q));

    vec2 p2 = imageLoad(displacement_image, ivec2(x.x, butterflyData.z)).zw;
    vec2 q2 = imageLoad(displacement_image, ivec2(x.x, butterflyData.w)).zw;

    vec2 h2 = AddComplex(p2, MultiplyComplex(twiddle, q2));

    imageStore(heightmap_image, x, vec4(h, h2));

    p = imageLoad(slope_image, ivec2(x.x, butterflyData.z)).xy;
    q = imageLoad(slope_image, ivec2(x.x, butterflyData.w)).xy;
    vec2 s = AddComplex(p, MultiplyComplex(twiddle, q));

    p2 = imageLoad(slope_image, ivec2(x.x, butterflyData.z)).zw;
    q2 = imageLoad(slope_image, ivec2(x.x, butterflyData.w)).zw;
    vec2 s2 = AddComplex(p2, MultiplyComplex(twiddle, q2));

    imageStore(triangle_image, x, vec4(s, s2));
}

void main() {
    if (params.direction == 1.0) {
        horizontalFFT();
    } else {
        verticalFFT();
    }
    // DONT FORGET TO CONVERT OTHER IMAGES TO RGBA32 AND SWITCH BUFFERS AFTER EACH PASS
}
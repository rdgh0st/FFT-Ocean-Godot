#[compute]
#version 460 core

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

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
} params;

layout(set = 0, binding = 11, rgba32f) readonly uniform image2D displacement_image;
layout(set = 0, binding = 12, rgba32f) readonly uniform image2D slope_image;
layout(set = 0, binding = 13, rgba32f) writeonly uniform image2D heightmap_image;
layout(set = 0, binding = 14, rgba32f) writeonly uniform image2D triangle_image;
layout(set = 0, binding = 15) buffer TestOutput {
    float x;
    float y;
    float idk;
    float idk2;
} test;
layout(set = 0, binding = 16, rgba32f) readonly uniform image2D butterflyTex;

vec2 MultiplyComplex(vec2 a, vec2 b) {
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

vec2 AddComplex(vec2 a, vec2 b) {
    return a + b;
}

void horizontalFFT() {
    ivec2 x = ivec2(gl_GlobalInvocationID.xy);

    vec4 butterflyData = imageLoad(butterflyTex, ivec2(params.stage, x.x)).rgba;
    vec2 p = imageLoad(displacement_image, ivec2(butterflyData.z, x.y)).rg;
    vec2 q = imageLoad(displacement_image, ivec2(butterflyData.w, x.y)).rg;
    vec2 twiddle = vec2(butterflyData.x, butterflyData.y);

    vec2 h = AddComplex(p, MultiplyComplex(twiddle, q));

    vec2 p2 = imageLoad(displacement_image, ivec2(x.x, butterflyData.z)).ba;
    vec2 q2 = imageLoad(displacement_image, ivec2(x.x, butterflyData.w)).ba;

    vec2 h2 = AddComplex(p2, MultiplyComplex(twiddle, q2));

    imageStore(heightmap_image, x, vec4(h, h2));

    p = imageLoad(slope_image, ivec2(butterflyData.z, x.y)).rg;
    q = imageLoad(slope_image, ivec2(butterflyData.w, x.y)).rg;
    vec2 s = AddComplex(p, MultiplyComplex(twiddle, q));
    imageStore(triangle_image, x, vec4(s, 0, 1));
}

void verticalFFT() {
    ivec2 x = ivec2(gl_GlobalInvocationID.xy);

    vec4 butterflyData = imageLoad(butterflyTex, ivec2(params.stage, x.y)).rgba;
    vec2 p = imageLoad(displacement_image, ivec2(x.x, butterflyData.z)).rg;
    vec2 q = imageLoad(displacement_image, ivec2(x.x, butterflyData.w)).rg;
    vec2 twiddle = vec2(butterflyData.x, butterflyData.y);

    vec2 h = AddComplex(p, MultiplyComplex(twiddle, q));

    vec2 p2 = imageLoad(displacement_image, ivec2(x.x, butterflyData.z)).ba;
    vec2 q2 = imageLoad(displacement_image, ivec2(x.x, butterflyData.w)).ba;

    vec2 h2 = AddComplex(p2, MultiplyComplex(twiddle, q2));

    imageStore(heightmap_image, x, vec4(h, h2));

    p = imageLoad(slope_image, ivec2(x.x, butterflyData.z)).rg;
    q = imageLoad(slope_image, ivec2(x.x, butterflyData.w)).rg;
    vec2 s = AddComplex(p, MultiplyComplex(twiddle, q));
    imageStore(triangle_image, x, vec4(s, 0, 1));
}

void main() {
    if (params.direction == 1.0) {
        horizontalFFT();
    } else {
        verticalFFT();
    }
    // DONT FORGET TO CONVERT OTHER IMAGES TO RGBA32 AND SWITCH BUFFERS AFTER EACH PASS
}
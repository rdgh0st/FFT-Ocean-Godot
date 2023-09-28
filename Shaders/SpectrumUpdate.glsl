#[compute]
#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const float PI = 3.14159265359;
const float g = 9.81;

layout(set = 0, binding = 10, r32f) readonly uniform image2D spectrum_image;
layout(set = 0, binding = 11, rg32f) writeonly uniform image2D displacement_image;
layout(set = 0, binding = 12, r32f) writeonly uniform image2D slope_image;

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

vec2 MultiplyComplex(vec2 a, vec2 b) {
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

void main() {
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    vec2 h0 = vec2(imageLoad(spectrum_image, pixel_coord).r, 0.0);
    vec2 h0star = vec2(imageLoad(spectrum_image, (int(params.resolution) - pixel_coord) % int (params.resolution)).r, 0.0);
    h0star.y *= -1.0;

    float halfN = params.resolution / 2.0f;
    float deltaK = 2.0f * PI / params.oceanSize;
    vec2 k = (pixel_coord.xy - halfN) * deltaK;
    float kLength = length(k);
    float kLengthRcp = 1.0;

    if (kLength > 0.0001) {
        kLengthRcp = 1.0 / kLength;
    }

    float w0 = 2.0 * PI / 200;
    float dispersion = floor(sqrt(g * kLength) / w0) * w0 * params.time;
    vec2 dispersionFactor = vec2(cos(dispersion), sin(dispersion));

    vec2 hTilda = MultiplyComplex(h0, dispersionFactor) + MultiplyComplex(h0star, vec2(dispersionFactor.x, -dispersionFactor.y));
    vec2 ihTilda = vec2(-hTilda.y, hTilda.x);

    vec2 hX = ihTilda * k.x * kLengthRcp;
    vec2 hZ = ihTilda * k.y * kLengthRcp;

    if (k.x == 0.0 && k.y == 0.0) {
        hTilda = vec2(0.0);
        hX = vec2(0.0);
    }

    imageStore(displacement_image, pixel_coord, vec4(hX + ihTilda, 0.0, 0.0));
}
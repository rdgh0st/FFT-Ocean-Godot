#[compute]
#version 460 core

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

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

layout(set = 0, binding = 11, rgba32f) writeonly uniform image2D displacement_image;
layout(set = 0, binding = 13, rgba32f) readonly uniform image2D heightmap_image;

void main() {
    ivec2 x = ivec2(gl_GlobalInvocationID.xy);
    float perm = 1.0 - 2.0 * ((x.x + x.y) % 2);

    vec4 h = imageLoad(heightmap_image, x);
    imageStore(displacement_image, x, vec4(perm * (h.x), perm * (h.y), perm * (h.z), 1));
}
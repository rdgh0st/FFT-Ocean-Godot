#[compute]
#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const float PI = 3.14159265359;
const float g = 9.81;

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

layout(set = 0, binding = 11, rg32f) readonly uniform image2D displacement_image;
layout(set = 0, binding = 12, r32f) readonly uniform image2D slope_image;
layout(set = 0, binding = 13, rgba16f) writeonly uniform image2D heightmap_image;
layout(set = 0, binding = 14, rgba16f) writeonly uniform image2D triangle_image;
layout(set = 0, binding = 15) buffer TestOutput {
    vec2 testSum;
    vec2 testTriangleSum;
} test;

void main() {
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    vec2 sum = vec2(0.0);
    vec2 triangleSum = vec2(0.0);
    for (int spectrum_x = 0; spectrum_x < params.resolution; spectrum_x++) {
        for (int spectrum_y = 0; spectrum_y < params.resolution; spectrum_y++) {
            ivec2 spectrum_pixel_coords = ivec2(spectrum_x, spectrum_y);
            sum += imageLoad(displacement_image, spectrum_pixel_coords).xy * exp(dot(spectrum_pixel_coords, pixel_coord));
            triangleSum += spectrum_pixel_coords * imageLoad(displacement_image, spectrum_pixel_coords).xy * exp(dot(spectrum_pixel_coords, pixel_coord));
        }
    }
    test.testSum = sum;
    test.testTriangleSum = triangleSum;
    imageStore(heightmap_image, pixel_coord, vec4(sum, 0.0, 0.0));
    imageStore(triangle_image, pixel_coord, vec4(triangleSum, 0.0, 0.0));
}
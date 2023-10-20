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

void main() {
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    vec2 x = pixel_coord * 1.0;
    vec2 sum = vec2(0.0);
    vec2 triangleSum = vec2(0.0);
    for (int spectrum_x = 0; spectrum_x < params.resolution; spectrum_x++) {
        float kz = 2.0 * PI * (spectrum_x - params.resolution / 2.0f) / params.oceanSize;
        for (int spectrum_y = 0; spectrum_y < params.resolution; spectrum_y++) {
            ivec2 spectrum_pixel_coords = ivec2(spectrum_x, spectrum_y);
            float kx = 2.0 * PI * (spectrum_y - params.resolution / 2.0f) / params.oceanSize;
            vec2 k = vec2(kx, kz);
            vec2 ik = vec2(-k.y, k.x);
            float kLength = length(k) + params.transformHorizontal;
            float kDotX = dot(ik, x);
            vec2 c = vec2(cos(kDotX), sin(kDotX));
            vec2 hTilda_c = imageLoad(displacement_image, spectrum_pixel_coords).xy * c;
            sum += hTilda_c;
            triangleSum += ik * imageLoad(displacement_image, spectrum_pixel_coords).xy * c;
        }
    } 
    /*
    for (int spectrum_x = 0; spectrum_x < params.resolution; spectrum_x++) {
        for (int spectrum_y = 0; spectrum_y < params.resolution; spectrum_y++) {
            vec2 initialSignal = imageLoad(displacement_image, ivec2(spectrum_x, spectrum_y)).xy;
            vec2 k = vec2(spectrum_x * 1.0, spectrum_y * 1.0);
            float theta = (2.0 * PI * k.x * k.x * x.x * x.y) / (params.resolution * params.resolution);
            sum += initialSignal * vec2(cos(theta), sin(theta));
            triangleSum += k * initialSignal * vec2(cos(theta), sin(theta));
        }
    }
    sum /= (params.resolution * params.resolution);
    */
    test.x = sum.x;
    test.y = 0;
    test.idk = 0;
    test.idk2 = 0;
    imageStore(heightmap_image, pixel_coord, vec4(sum, 0.0, 0.0));
    imageStore(triangle_image, pixel_coord, vec4(triangleSum, 0.0, 0.0));
}
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

layout(set = 0, binding = 17) buffer FoamParamters {
    float lambda;
    float foamDecay;
    float foamBias;
    float foamThreshold;
    float foamAdd;
} foamParams;

layout(set = 0, binding = 11, rgba32f) writeonly uniform image2D displacement_image;
layout(set = 0, binding = 12, rgba32f) writeonly uniform image2D slope_image;
layout(set = 0, binding = 13, rgba32f) readonly uniform image2D heightmap_image;
layout(set = 0, binding = 14, rgba32f) readonly uniform image2D triangle_image;
layout(set = 0, binding = 16, r32f) uniform image2D foam_image;

void main() {
    ivec2 x = ivec2(gl_GlobalInvocationID.xy);
    float perm = 1.0 - 2.0 * ((x.x + x.y) % 2);
    vec4 h = imageLoad(heightmap_image, x);
    vec4 t = imageLoad(triangle_image, x);

    vec2 dxdz = vec2(perm * (h.x), perm * (h.y));
    vec2 dydxz = vec2(perm * (h.z), perm * (h.a));
    vec2 dyzdyz = vec2(perm * (t.x), perm * (t.y));
    vec2 dxxdzz = vec2(perm * (t.z), perm * (t.a));

    float jacobian = (1.0f + foamParams.lambda * dxxdzz.x) * (1.0f + foamParams.lambda * dxxdzz.y) - foamParams.lambda * foamParams.lambda * dxdz.y * dxdz.y;

    vec3 displacement = vec3(foamParams.lambda * dxdz.x, dydxz.x, foamParams.lambda * dxdz.y);
    vec2 slopes = dyzdyz.xy / (1 + abs(dxxdzz * foamParams.lambda));
    float covariance = slopes.x * slopes.y;

    float foam = imageLoad(foam_image, x).r;
    foam *= exp(foamParams.foamDecay);
    foam = clamp(foam, 0.0, 1.0);

    float finalJacobian = max(0.0, -(jacobian - foamParams.foamBias));

    if (finalJacobian > foamParams.foamThreshold) {
        foam += foamParams.foamAdd * finalJacobian;
    }

    imageStore(foam_image, x, vec4(foam, 0, 0, 1));

    imageStore(displacement_image, x, vec4(displacement, foam));

    imageStore(slope_image, x, vec4(slopes, perm * (t.z), perm * (t.a)));

}
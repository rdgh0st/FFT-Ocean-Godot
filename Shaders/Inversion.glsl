#[compute]
#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

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

layout(set = 0, binding = 17) buffer FoamParamters {
    float lambda;
    float foamDecay;
    float foamBias;
    float foamThreshold;
    float foamAdd;
    float lowerAdjustment;
} foamParams;

layout(set = 0, binding = 11, rgba32f) writeonly uniform image2D displacement_image;
layout(set = 0, binding = 12, rgba32f) writeonly uniform image2D slope_image;
layout(set = 0, binding = 13, rgba32f) readonly uniform image2D heightmap_image;
layout(set = 0, binding = 14, rgba32f) readonly uniform image2D triangle_image;
layout(set = 0, binding = 16, r32f) uniform image2D foam_image;

void main() {
    ivec2 x = ivec2(gl_GlobalInvocationID.xy);
    float perm = 1.0 - 2.0 * ((x.x + x.y) % 2);
    vec4 h = imageLoad(heightmap_image, x) * perm;
    vec4 t = imageLoad(triangle_image, x) * perm;
    vec2 dxdz = h.xy;
    vec2 dydxz = h.zw;
    vec2 dyzdyz = t.xy;
    vec2 dxxdzz = t.zw;

    float jacobian = (1.0f + foamParams.lambda * dxxdzz.x) * (1.0f + foamParams.lambda * dxxdzz.y) - foamParams.lambda * foamParams.lambda * dydxz.y * dydxz.y;

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

    if (x.y > params.resolution / 2.0) {
        foam *= exp(foamParams.lowerAdjustment);
    }
    

    imageStore(foam_image, x, vec4(foam, 0, 0, 1));

    imageStore(displacement_image, x, vec4(displacement, 1));

    imageStore(slope_image, x, vec4(slopes, dxxdzz));

}
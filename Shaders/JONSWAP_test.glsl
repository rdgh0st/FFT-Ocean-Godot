#[compute]
#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const float PI = 3.14159265359;
const float g = 9.81;

layout(set = 0, binding = 10, r32f) writeonly uniform image2D spectrum_image;

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

float square(float x) {
    return x * x;
}

//note: uniformly distributed, normalized rand, [0;1[
float nrand( vec2 n )
{
	return fract(sin(dot(n.xy, vec2(12.9898, 78.233)))* 43758.5453);
}

const float ALPHA = 0.14;
const float INV_ALPHA = 1.0 / ALPHA;
const float K = 2.0 / (PI * ALPHA);

float inv_error_function(float x)
{
	float y = log(1.0 - x*x);
	float z = K + 0.5 * y;
	return sqrt(sqrt(z*z - y * INV_ALPHA) - z) * sign(x);
}

float gaussian_rand( vec2 n )
{
	float t = fract( params.time );
	float x = nrand( n + 0.07*t );
    
	return inv_error_function(x*2.0-1.0)*0.15 + 0.5;
}

float JONSWAP(float freq) {
    float peak = 22.0f * pow(((g * g) / (params.windSpeed * params.fetch)), (1.0f / 3.0f));

    float sigma = (freq <= peak) ? 0.07f : 0.09f;

    float alpha = 0.076 * (pow((params.windSpeed * params.windSpeed) / (params.fetch * g), 0.22f));

    float r = exp(-square(freq - peak) / (2.0f * square(sigma) * square(peak)));

    return ((alpha * square(g)) / pow(freq, 5.0f)) * exp(-1.25 * pow((peak / freq), 4.0f)) * pow(params.enhancementFactor, r);
}

void main() {
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    float halfN = params.resolution / 2.0f;
    float deltaK = 2.0f * PI / params.oceanSize;
    vec2 k = (pixel_coord.xy - halfN) * deltaK;
    float kLength = length(k) + params.transformHorizontal;

    if (params.lowCutoff <= kLength && kLength <= params.highCutoff) {
        float coeff = 1.0f / sqrt(2);
        float dispersionK = sqrt(g * kLength * tanh(min(kLength * params.depth, 20)));
        float JSroot = sqrt(JONSWAP(dispersionK));
        float res = coeff * gaussian_rand(k) * gaussian_rand(pixel_coord) * JSroot;

        imageStore(spectrum_image, pixel_coord, vec4(res, 0.0, 0.0, 0.0));
    } else {
        imageStore(spectrum_image, pixel_coord, vec4(0.0));
    }
}
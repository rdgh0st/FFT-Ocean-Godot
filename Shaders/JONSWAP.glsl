#[compute]
#version 460 core

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

const float PI = 3.14159265359;
const float g = 9.81;

layout(set = 0, binding = 10, rg32f) writeonly uniform image2D spectrum_image;

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
    float waveAngle;
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

vec2 UniformToGaussian(float u1, float u2) {
    float R = sqrt(-2.0 * log(u1));
    float theta = 2.0 * PI * u2;

    return vec2(R * cos(theta), R * sin(theta));
}

float NormalizationFactor(float s) {
    float s2 = s * s;
    float s3 = s2 * s;
    float s4 = s3 * s;
    if (s < 5) return -0.000564f * s4 + 0.00776f * s3 - 0.044f * s2 + 0.192f * s + 0.163f;
    else return -4.80e-08f * s4 + 1.07e-05f * s3 - 9.53e-04f * s2 + 5.90e-02f * s + 3.93e-01f;
}

float Hasselmann(float freq) {
    float peak = 22.0f * pow(((params.windSpeed * params.fetch) / (g * g)), -(1.0f / 3.0f));
    if (freq <= peak) {
        return 6.97 * pow(freq / peak, 4.06);
    } else {
        return 9.77 * pow(freq / peak, -2.33 - 1.45 * ((params.fetch * peak / g) - 1.17));
    }
}

float DirectionSpectrum(float freq, float theta) {
    float peak = 22.0f * pow(((params.windSpeed * params.fetch) / (g * g)), -(1.0f / 3.0f));
    float xi = Hasselmann(freq) + 16 * tanh(peak / freq) * params.swell * params.swell;
    return NormalizationFactor(xi) * pow(cos((theta - params.waveAngle) / 2.0), 2.0 * xi);
}

float TMACorrection(float omega)
{
	float omegaH = omega * sqrt(params.depth / g);
	if (omegaH <= 1)
		return 0.5 * omegaH * omegaH;
	if (omegaH < 2)
		return 1.0 - 0.5 * (2.0 - omegaH) * (2.0 - omegaH);
	return 1;
}

float JONSWAP(float freq) {
    float peak = 22.0f * pow(((params.windSpeed * params.fetch) / (g * g)), -(1.0f / 3.0f));

    float sigma = (freq <= peak) ? 0.07f : 0.09f;

    float alpha = 0.076 * (pow((params.windSpeed * params.windSpeed) / (params.fetch * g), 0.22f));

    float r = exp(-square(freq - peak) / (2.0f * square(sigma) * square(peak)));

    return TMACorrection(freq) * ((alpha * square(g)) / pow(freq, 5.0f)) * exp(-1.25 * pow((peak / freq), 4.0f)) * pow(params.enhancementFactor, r);
}

void main() {
    ivec2 pixel_coord = ivec2(gl_GlobalInvocationID.xy);
    float halfN = params.resolution / 2.0f;
    float deltaK = 2.0f * PI / params.oceanSize;
    vec2 k = (pixel_coord.xy - halfN) * deltaK;
    float kLength = length(k) + params.transformHorizontal;

    if (params.lowCutoff <= kLength && kLength <= params.highCutoff) {
        float kAngle = atan(k.x, k.y);
        float coeff = 1.0f / sqrt(2);
        float omega = sqrt(g * kLength * tanh(min(kLength * params.depth, 20)));
        float th = tanh(min(kLength * params.depth, 20));
	    float ch = cosh(kLength * params.depth);
	    float dOmegak = g * (params.depth * kLength / ch / ch + th) / omega / 2.0;
        float jonswap = JONSWAP(omega) * DirectionSpectrum(omega, kAngle);

        vec2 gauss = UniformToGaussian(nrand(normalize(k)), nrand(normalize(pixel_coord) + 0.0001));
        vec2 res = gauss * sqrt(2.0 * jonswap * abs(dOmegak) / kLength * deltaK * deltaK);
        if (isinf(res.x) || isnan(res.x) || isinf(res.y) || isnan(res.y)) {
            res = vec2(0.0);
        }

        imageStore(spectrum_image, pixel_coord, vec4(res, 0.0, 0.0));
    } else {
        imageStore(spectrum_image, pixel_coord, vec4(0.0));
    }
    
}
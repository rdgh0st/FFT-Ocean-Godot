shader_type spatial;

uniform vec3 color1 : source_color;
uniform vec3 color2 : source_color;
uniform float numWaves = 1;

uniform float wavelength;
uniform float amplitude;
uniform float speed;
uniform vec2 direction;
uniform vec3 lightDirection;

struct sosOutput {
	float height;
	vec3 tangent;
	vec3 binormal;
	vec3 normalTest;
};

sosOutput sumOfSines(vec3 v) {
	sosOutput value;
	value.height = 0.0;
	value.tangent = vec3(0.0);
	value.binormal = vec3(0.0);
	value.normalTest = vec3(0.0);
	for (float i = 0.0; i < numWaves; i++) {
		float freq = 2.0 / (wavelength + i);
		float lamda = (speed + i) * freq;
		float tempAmplitude = amplitude + i / 3.0;
		value.height += (tempAmplitude) * sin(dot(direction, vec2(v.x, v.z)) * freq + TIME * lamda);
		// from textbook:
		// freq * direction.x * amplitude * cos(dot(direction, vec2(v.x, v.z)) * freq + TIME * lamda);
		value.normalTest += normalize(vec3(-(freq * direction.x * tempAmplitude * cos(dot(direction, vec2(v.x, v.z)) * freq + TIME * lamda)), 1.0, -(freq * direction.y * tempAmplitude * cos(dot(direction, vec2(v.x, v.z)) * freq + TIME * lamda))));
		// from video
		// dx (tangent) = sum:
		//freq * amplitude * directionX * cos(v.x * freq + time * lamda);
		value.tangent += normalize(vec3(1.0, 0.0, freq * tempAmplitude * direction.x * cos(v.x * freq + TIME * lamda)));
		// dz (binormal) = sum of same except directionZ and v.z instead
		value.binormal += normalize(vec3(0.0, 1.0, freq * tempAmplitude * direction.y * cos(v.z * freq + TIME * lamda)));
	}
	return value;
}

void vertex() {
	// frequency = 2 / wavelength
	// lamda = speed * 2 / wavelength
	// pos = amp * sin(dot(dir, xz) * frequency + time * lamda)
	sosOutput values = sumOfSines(VERTEX);
	VERTEX.y = values.height;
	TANGENT = values.tangent;
	BINORMAL = values.binormal;
	//NORMAL = values.normalTest;
}

void fragment() {
  float fresnel = sqrt(1.0 - dot(NORMAL, VIEW));
  RIM = 0.2;
  METALLIC = 0.0;
  ROUGHNESS = 0.01 * (1.0 - fresnel);
  ALBEDO = vec3(0.1, 0.3, 0.5) + (0.1 * fresnel);
}

void light() {
    DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * ALBEDO;
}

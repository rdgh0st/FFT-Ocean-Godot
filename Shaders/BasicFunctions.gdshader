shader_type spatial;

uniform vec3 color1 : source_color;
uniform vec3 color2 : source_color;
uniform float numWaves = 1;

uniform float wavelength;
uniform float amplitude;
uniform float speed;
uniform vec2 direction;

float sumOfSines(vec3 v) {
	float value = 0.0;
	for (float i = 0.0; i < numWaves; i++) {
		float freq = 2.0 / (wavelength + i);
		float lamda = (speed + i) * freq;
		value += (amplitude + i / 3.0) * sin(dot(direction, vec2(v.x, v.z)) * freq + TIME * lamda);
	}
	return value;
}

void vertex() {
	// frequency = 2 / wavelength
	// lamda = speed * 2 / wavelength
	// pos = amp * sin(dot(dir, xz) * frequency + time * lamda)
	VERTEX.y = sumOfSines(VERTEX);
}

void fragment() {
	float pct = 1.0 - pow(max(0.0, abs(sin(TIME)) * 2.0 - 1.0), 0.5);
	
	//ALBEDO = mix(color1, color2, pct);
}

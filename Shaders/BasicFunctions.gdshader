shader_type spatial;

uniform vec3 ambientLightColor : source_color;
uniform float ambientReflectance;
uniform vec3 diffuseColor : source_color;
uniform vec3 lightColor : source_color;
uniform vec3 specColor : source_color;
uniform vec3 specLightColor : source_color;
uniform vec3 lightPos;
uniform float shininess;

uniform float numWaves = 1;

uniform float ampMultiplier;
uniform float freqMultiplier;
uniform float speed;

uniform float fresnelBias;
uniform float fresnelScale;
uniform float fresnelPower;
uniform sampler2D panorama;

struct sosOutput {
	float height;
	vec3 tangent;
	vec3 binormal;
	float previousDerivative;
};

float random (vec2 uv) {
    return fract(sin(dot(uv.xy,
        vec2(12.9898,78.233))) * 43758.5453123);
}

vec2 uv_sphere(vec3 v)
{
	vec2 uv=vec2(0.5 + atan(v.z, v.x) / (2.0 * PI), acos(v.y) / PI);
	uv.y=1.-uv.y;
	uv.x=-0.75+uv.x;
	uv=fract(uv);
	return uv;
}

sosOutput singleSine(vec3 v, float a, float freq, float lamda, vec2 direction, float previousDerivative) {
	sosOutput output;
	
	output.height = a * pow(E, sin((dot(direction, vec2(v.x, v.z)) + previousDerivative) * freq + TIME * lamda) - 1.0);
	
	float tangentZ = freq * direction.x * a * pow(E, sin((dot(direction, vec2(v.x, v.z)) + previousDerivative) * freq + TIME * lamda) - 1.0) * cos((dot(direction, vec2(v.x, v.z)) + previousDerivative) * freq + TIME * lamda);
	output.tangent = vec3(1.0, 0.0, tangentZ);
	
	float binormalZ = freq * direction.y * a * pow(E, sin((dot(direction, vec2(v.x, v.z)) + previousDerivative) * freq + TIME * lamda) - 1.0) * cos((dot(direction, vec2(v.x, v.z)) + previousDerivative) * freq + TIME * lamda);
	output.binormal = vec3(0.0, 1.0, binormalZ);
	
	output.previousDerivative = tangentZ;
	
	return output;
}

sosOutput sumOfSines(vec3 v) {
	sosOutput value;
	value.height = 0.0;
	value.tangent = vec3(0.0);
	value.binormal = vec3(0.0);
	float previousDerivative = 0.0;
	float freq = 1.0;
	float amplitude = 1.0;
	for (float i = 0.0; i < numWaves; ++i) {
		freq *= freqMultiplier;
		amplitude *= ampMultiplier;
		float lamda = speed * freq;
		//vec2 direction = normalize(vec2(random(vec2(TIME, i)), random(vec2(i, TIME))));
		
		float input1 = clamp(random(vec2(i, i + 12.5)), 0.01, 1.0);
		float input2 = clamp(random(vec2(i + 100.3, i)), 0.01, 1.0);
		vec2 direction = normalize(vec2(input1, input2));
		
		sosOutput test = singleSine(v, amplitude, freq, lamda, direction, previousDerivative);
		value.height += test.height;
		value.tangent += test.tangent;
		value.binormal += test.binormal;
		previousDerivative = test.previousDerivative;
	}
	return value;
}

void vertex() {
	sosOutput values = sumOfSines(VERTEX);
	VERTEX.y = values.height;
	TANGENT = normalize(values.tangent);
	BINORMAL = normalize(values.binormal);
	NORMAL = normalize(cross(TANGENT, BINORMAL));
}

void fragment() {
	/*
  float fresnel = sqrt(1.0 - dot(NORMAL, VIEW));
  RIM = 0.2;
  METALLIC = 0.0;
  ROUGHNESS = 0.01 * (1.0 - fresnel);
*/
	vec3 P = VERTEX;
	vec3 N = normalize(NORMAL);
	vec3 ambient = ambientReflectance * ambientLightColor;
	vec3 L = normalize(lightPos - P);
	float diffuseLight = max(dot(N, L), 0.0);
	vec3 diffuse = diffuseColor * lightColor * diffuseLight;
	vec3 H = normalize(L + VIEW);
	float facing = 0.0;
	if (dot(N, L) > 0.0) {
		facing = 1.0;
	}
	vec3 I = normalize(VERTEX - VIEW);
	
	float fresnel = fresnelBias + fresnelScale * pow(1.0 + dot(I, N), fresnelPower);
	
	vec3 specular = specColor * specLightColor * facing * pow(max(dot(N, H), 0.0), shininess) * fresnel;
	
	vec3 R = reflect(I, N);
	
	vec2 uv = uv_sphere(normalize(R));
	vec4 reflectance = texture(panorama, uv);
	
	ALBEDO = ambient + diffuse + specular + (reflectance.rgb * fresnel);
}

/*
void light() {
    DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * ALBEDO;
	vec3 half = normalize(LIGHT + VIEW);
	SPECULAR_LIGHT += pow(clamp(dot(half, NORMAL), 0.0, 1.0), shininess);
}
*/

shader_type spatial;

uniform sampler2D outputImage;
varying vec3 world_pos;
uniform float height_scale = 0.15;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = texture(outputImage, world_pos.xz).r;
	VERTEX.y += height * height_scale;
}

void fragment() {
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

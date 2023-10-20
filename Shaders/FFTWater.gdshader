shader_type spatial;
render_mode unshaded;

uniform sampler2D outputImage;
uniform sampler2D normalImage;
varying vec3 world_pos;
uniform float height_scale = 0.15;
uniform float oceanSize;
uniform float lambda;

uniform vec3 ambientLightColor : source_color;
uniform float ambientReflectance;
uniform vec3 diffuseColor : source_color;
uniform float diffuseFactor;
uniform vec3 lightColor : source_color;
uniform vec3 specColor : source_color;
uniform float specFactor;
uniform vec3 lightPos;
uniform vec3 lightDir;
uniform float shininess;
uniform float exposure;

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
	world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz / oceanSize;
	float height = texture(outputImage, world_pos.xz).x;
	float dispX = texture(outputImage, world_pos.xz).z * lambda;
	float dispZ = texture(outputImage, world_pos.xz).y * lambda;
	VERTEX += vec3(dispX, height * height_scale, dispZ);
	vec3 center = texture(normalImage, world_pos.xz).xyz;
	/*
	vec3 right = vec3(1, 0, 0) * texture(normalImage, vec2(max(world_pos.x + 1.0, resolution - 1.0), world_pos.z)).xyz - center;
	vec3 left = vec3(-1, 0, 0) * texture(normalImage, vec2(min(world_pos.x - 1.0, 0.0), world_pos.z)).xyz - center;
	vec3 top = vec3(0, 0, -1) * texture(normalImage, vec2(world_pos.x, min(world_pos.z - 1.0, 0.0))).xyz - center;
	vec3 bottom = vec3(0, 0, 1) * texture(normalImage, vec2(world_pos.x, max(world_pos.z + 1.0, resolution - 1.0))).xyz - center;
	
	vec3 top_right = cross(right, top);
	vec3 top_left = cross(top, left);
	vec3 bottom_left = cross(left, bottom);
	vec3 bottom_right = cross(bottom, right);
	NORMAL = vec3(top_right + top_left + bottom_right + bottom_left);
	*/
	NORMAL = vec3(-center.x, 1.0, -center.y);
}

vec3 HDR(vec3 color) {
	return 1.0 - exp(-color * exposure);
}

void fragment() {
	/*
	vec3 P = VERTEX;
	vec3 N = normalize(NORMAL);
	vec3 ambient = ambientReflectance * ambientLightColor;
	vec3 L = normalize(lightPos - P);
	float diffuseLight = max(dot(N, L), 0.0);
	vec3 diffuse = diffuseColor * lightColor * diffuseLight * diffuseFactor;
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
	*/
	vec3 N = normalize(NORMAL);
	vec3 L = normalize(lightPos - world_pos);
	vec3 H = L + normalize(-VIEW.xyz);
	float fog = min(world_pos.z / 500.0, 1.0);
	
	float D = dot(N, L);
	bool facing = D > 0.0;
	
	vec3 color = ambientLightColor * ambientReflectance + diffuseColor * diffuseFactor * max(D, 0.0) + (facing ? specColor * specFactor * max(pow(dot(N, H), shininess), 0.0) : vec3(0.0, 0.0, 0.0));
	color *= (1.0 - fog) + vec3(0.25, 0.75, 0.65) * fog;
	ALBEDO = color;
}

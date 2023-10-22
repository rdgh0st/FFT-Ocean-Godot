shader_type spatial;
render_mode unshaded;

uniform sampler2D outputImage;
uniform sampler2D normalImage;
varying vec3 world_pos;
uniform float height_scale = 0.15;
uniform float oceanSize;
uniform float lambda;
uniform float lambdaClamp;

uniform vec4 AmbientColor : source_color;
uniform float AmbientIntensity;
uniform vec4 DiffuseColor : source_color;
uniform float DiffuseIntensity;
uniform vec4 LightColor : source_color;
uniform vec4 SpecularColor : source_color;
uniform vec3 specLightColor : source_color;
uniform float SpecularIntensity;
uniform vec3 lightPos;
uniform float Roughness;
uniform float F0;
uniform float exposure;
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
	float dispX = min(texture(outputImage, world_pos.xz).z * lambda, lambdaClamp);
	float dispZ = min(texture(outputImage, world_pos.xz).y * lambda, lambdaClamp);
	VERTEX += vec3(dispX, height * height_scale, dispZ);
	world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz / oceanSize;
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
	vec3 N = normalize(NORMAL.xyz);
	vec3 V = normalize(CAMERA_POSITION_WORLD - world_pos.xyz);
	vec3 L = normalize(lightPos);
	vec3 H = normalize(L + V);
    float VdotH = dot(V, H);
    float NdotH = dot(N, H);
    float LdotH = dot(L, H);
    float NdotL = dot(N, L);
    float NdotV = dot(N, V);

	vec4 ambient = AmbientColor * AmbientIntensity;
	vec4 diffuse = DiffuseIntensity * DiffuseColor * min(max(0, NdotL), 1);

    if (NdotH <= 0.0 || NdotL <= 0.0) {
        ALBEDO = (ambient + diffuse).rgb;
    }
	
    // float3 specular intensity is the cook torrance formula, multiply it with specular color
    float denom = 4.0 * NdotL * NdotV;

    // GGXDistribution
    float alphaSquare = pow(Roughness, 2);
    float pi = 3.14159265358979323846;
    float denomGGX = pi * pow((pow(NdotH, 2) * (alphaSquare - 1.0)) + 1.0, 2);
    float GGXDistribution = alphaSquare / denomGGX;

    // FresnelSchlick
    float M = pow(min(0, max(1, 1.0 - VdotH)), 5);
    float FresnelSchlick = F0 + (1.0 - F0) * M;

    // Geometry
    float K = pow((Roughness + 1.0), 2) / 8.0;
    float denomG1L = (NdotL * (1.0 - K)) + K;
    float G1L = NdotL / denomG1L;

    float denomG1V = (NdotV * (1.0 - K)) + K;
    float G1V = NdotV / denomG1V;

    float Geometry = G1L * G1V;

    // Apply Cook-Torrance Formula and find final Specular value
    float numer = GGXDistribution * FresnelSchlick * Geometry;
    float cookTorranceValue = numer / denom;
    vec4 finalSpecular = cookTorranceValue * SpecularColor * SpecularIntensity * NdotL;

    // integrate all color values into final return color
    vec4 color = LightColor * clamp(NdotL, 0, 1) * ((diffuse) + finalSpecular) + ambient;
    ALBEDO = color.rgb;
	/*
	vec3 N = normalize(NORMAL);
	vec3 L = normalize(lightPos - world_pos);
	vec3 H = L + normalize(-VIEW.xyz);
	float fog = min(world_pos.z / 500.0, 1.0);
	
	float D = dot(N, L);
	bool facing = D > 0.0;
	
	vec3 color = ambientLightColor * ambientReflectance + diffuseColor * diffuseFactor * max(D, 0.0) + (facing ? specColor * specFactor * max(pow(dot(N, H), shininess), 0.0) : vec3(0.0, 0.0, 0.0));
	color *= (1.0 - fog) + vec3(0.25, 0.75, 0.65) * fog;
	ALBEDO = color;
	*/
}

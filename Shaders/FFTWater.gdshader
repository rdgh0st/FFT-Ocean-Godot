shader_type spatial;
render_mode world_vertex_coords, depth_draw_always, cull_disabled;

uniform sampler2D outputImage;
uniform sampler2D normalImage;
uniform sampler2D foamImage;
varying vec3 world_pos;
varying vec3 world_normal;
varying float jacobian;
varying float foam_specular_factor;
varying float foam_mix_factor;
uniform float jacobianBias;
uniform float height_scale = 0.15;
uniform float oceanSize;
uniform float resolution;
uniform float lambda;
uniform float lambdaClamp;
uniform float foam_mix_strength;

uniform vec4 AmbientColor : source_color;
uniform float AmbientIntensity;
uniform vec4 DiffuseColor : source_color;
uniform float DiffuseIntensity;
uniform vec4 LightColor : source_color;
uniform vec4 SpecularColor : source_color;
uniform vec4 foamColor : source_color;
uniform vec4 sssColor : source_color;
uniform float SpecularIntensity;
uniform float SpecularPower;
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
	world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz / resolution;
	
	/*
	float height = texture(outputImage, world_pos.xz).x;
	float dispX = min(texture(outputImage, world_pos.xz).z * lambda, lambdaClamp);
	float dispZ = min(texture(outputImage, world_pos.xz).a * lambda, lambdaClamp);
	VERTEX += vec3(dispX, height * height_scale, dispZ);
	world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz / resolution;
	
	float texel = 1.0 / resolution;
	float texelSize = oceanSize / resolution;
	
	vec4 derivatives = texture(normalImage, world_pos.xz);
	
	jacobian = (1.0 + lambda * derivatives.b) * (1.0 + lambda * derivatives.a) - lambda * lambda * texture(outputImage, world_pos.xz).y * texture(outputImage, world_pos.xz).y;
	jacobian = jacobian + jacobianBias;
	
	vec2 slope = vec2(derivatives.x / (1.0 + derivatives.z), (derivatives.y / (1.0 + derivatives.w)) * lambda);
	
	NORMAL = normalize(vec3(-slope.x, 1, -slope.y));
	*/
	
	VERTEX += texture(outputImage, world_pos.xz).xyz;
	VERTEX.y = min(VERTEX.y * height_scale, 5000);
	world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz / resolution;
	
}

vec3 HDR(vec3 color) {
	return 1.0 - exp(-color * exposure);
}

void fragment() {
	vec2 slope = texture(normalImage, world_pos.xz).xy;
	NORMAL = normalize(vec3(-slope.y, 1, -slope.x));
	
	
	mat4 worldToObj = inverse(MODEL_MATRIX);

	world_normal = normalize(NORMAL * mat3(worldToObj));
	NORMAL = world_normal;
	
	vec3 N = normalize(NORMAL.xyz);
	vec3 V = normalize(CAMERA_POSITION_WORLD - world_pos.xyz);
	vec3 L = normalize(lightPos);
	vec3 H = normalize(L + V);
    float VdotH = dot(V, H);
    float NdotH = dot(world_normal, H);
    float LdotH = dot(L, H);
    float NdotL = dot(world_normal, L);
    float NdotV = dot(world_normal, V);

    // integrate all color values into final return color
	
	foam_mix_factor = clamp((texture(foamImage, world_pos.xz).r), 0.0, 1.0);
	foam_mix_factor = (foam_mix_factor * foam_mix_factor) * foam_mix_strength;
	ALBEDO = mix(AmbientColor, foamColor, foam_mix_factor).rgb;
	foam_specular_factor = (1.0 - foam_mix_factor);
	
	ROUGHNESS = foam_mix_factor * 0.02;
	METALLIC = DiffuseIntensity * foam_specular_factor;
	SPECULAR = SpecularIntensity * foam_specular_factor;
	
    //vec4 color = ambient + foam;
    //ALBEDO = color.rgb;
	
	
	
}

void light() {
	vec3 H = normalize(LIGHT + VIEW);
	float spec = clamp(pow(dot(NORMAL, H), SpecularPower), 0.0, 1.0) * SpecularIntensity;
	SPECULAR_LIGHT += (LIGHT_COLOR * ALBEDO * ATTENUATION / PI) * clamp(dot(world_normal, H), 0.0, 1.0) * foam_specular_factor;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * foam_specular_factor;
	
	// Foam Lighting
	DIFFUSE_LIGHT += DiffuseIntensity * foam_mix_factor * foamColor.rgb * ATTENUATION;
	
}

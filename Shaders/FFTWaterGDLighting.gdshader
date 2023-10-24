shader_type spatial;
render_mode world_vertex_coords, depth_draw_always, cull_disabled;

uniform sampler2D outputImage;
uniform sampler2D normalImage;
varying vec3 world_pos;
varying float jacobian;
uniform float height_scale = 0.15;
uniform float oceanSize;
uniform float resolution;
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
	world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz / resolution;
	float height = texture(outputImage, world_pos.xz).x;
	float dispX = min(texture(outputImage, world_pos.xz).z * lambda, lambdaClamp);
	float dispZ = min(texture(outputImage, world_pos.xz).y * lambda, lambdaClamp);
	VERTEX += vec3(dispX, height * height_scale, dispZ);
	
	
	vec4 slope = texture(normalImage, world_pos.xz);
	
	jacobian = (1.0 + lambda * slope.b) * (1.0 + lambda * slope.a) - lambda * lambda * texture(outputImage, world_pos.xz).a * texture(outputImage, world_pos.xz).a;
	
	world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz / resolution;
	NORMAL = cross(normalize(slope.xyz), vec3(0, 0, 1));
}

vec3 HDR(vec3 color) {
	return 1.0 - exp(-color * exposure);
}

void fragment() {
}

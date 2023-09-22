shader_type spatial;

uniform sampler2D outputImage;
varying vec3 world_pos;
uniform float height_scale = 0.15;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height = texture(outputImage, world_pos.xz).r;
	VERTEX.y += height * height_scale;
}

void fragment() {
	ALBEDO = vec3(0.0, 1.0, 0.0);
}

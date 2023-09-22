shader_type spatial;
render_mode unshaded;

uniform sampler2D outputImage : hint_depth_texture, filter_linear_mipmap;

void vertex() {
	//VERTEX.y += texture(outputImage, UV).y;
}

void fragment() {
	ALBEDO = texture(outputImage, UV).rgb;
}

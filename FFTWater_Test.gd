extends MeshInstance3D
@export_file("*.glsl") var compute_shader
@export_file("*.glsl") var displacement_shader;
@export_file("*.glsl") var brute_force;
@export_file("*.glsl") var butterfly_texture_shader;
@export_file("*.glsl") var inversion_shader;
@export var frameSkip: float;
var currentFrame: float;
@export var fetch : float;
@export var windSpeed : float;
@export var enhancementFactor: float;
@export var inputfreq: float;
@export var resolution: float;
@export var oceanSize: float;
@export var transformHorizontal: float;
@export var lowCutoff: float;
@export var highCutoff: float;
@export var depth: float;

var imageUniform : RDUniform;
var displacementUniform: RDUniform;
var slopeUniform: RDUniform;
var butterflyUniform: RDUniform;

var rd: RenderingDevice;
var shader_rid: RID;
var uniform_set: RID;
var pipeline: RID;

var disp_shader_rid: RID;
var disp_uniform_set: RID;
var disp_pipeline: RID;
var displacement_rid: RID;

var normal_shader_rid: RID;
var normal_uniform_set: RID;
var normal_pipeline: RID;

var butterfly_shader_rid: RID;
var inversion_shader_rid: RID;
var slope_rid: RID;

var params_buffer: RID;
var params_uniform: RDUniform;

var initTime: float;
var deltaTime: float;

var prevParams;

# Called when the node enters the scene tree for the first time.
func _ready():
	initTime = Time.get_unix_time_from_system();
	prevParams = [fetch, windSpeed, enhancementFactor, inputfreq, resolution, oceanSize, transformHorizontal, lowCutoff, highCutoff, depth];
	init_gpu();

func init_gpu():
	rd = RenderingServer.create_local_rendering_device();
	
	var shader_file_data: RDShaderFile = load(compute_shader);
	var shader_spirv: RDShaderSPIRV = shader_file_data.get_spirv();
	shader_rid = rd.shader_create_from_spirv(shader_spirv);
	
	var disp_shader_file_data: RDShaderFile = load(displacement_shader);
	var disp_shader_spirv: RDShaderSPIRV = disp_shader_file_data.get_spirv();
	disp_shader_rid = rd.shader_create_from_spirv(disp_shader_spirv);
	
	var normal_shader_file_data: RDShaderFile = load(brute_force);
	var normal_shader_spirv: RDShaderSPIRV = normal_shader_file_data.get_spirv();
	normal_shader_rid = rd.shader_create_from_spirv(normal_shader_spirv);
	
	var butterfly_shader_file_data: RDShaderFile = load(butterfly_texture_shader);
	var butterfly_shader_spirv: RDShaderSPIRV = butterfly_shader_file_data.get_spirv();
	butterfly_shader_rid = rd.shader_create_from_spirv(butterfly_shader_spirv);
	
	var inversion_shader_file_data: RDShaderFile = load(inversion_shader);
	var inversion_shader_spirv: RDShaderSPIRV = inversion_shader_file_data.get_spirv();
	inversion_shader_rid = rd.shader_create_from_spirv(inversion_shader_spirv);
	
	generate_init_spectrum();
	#generate_disp();

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		cleanup_gpu();

func generate_init_spectrum():
	var input: PackedFloat32Array = [fetch, windSpeed, enhancementFactor, inputfreq, resolution, oceanSize, Time.get_unix_time_from_system() - initTime, transformHorizontal, lowCutoff, highCutoff, depth, 0, 0];
	
	var params: PackedByteArray = input.to_byte_array();
	params_buffer = rd.storage_buffer_create(params.size(), params);
	params_uniform = RDUniform.new();
	params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	params_uniform.binding = 0;
	params_uniform.add_id(params_buffer);
	
	var image = Image.create(resolution, resolution, false, Image.FORMAT_RGF);
	
	var imageFormat = RDTextureFormat.new();
	imageFormat.width = resolution;
	imageFormat.height = resolution;
	imageFormat.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT;
	imageFormat.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
	
	var image_rid = rd.texture_create(imageFormat, RDTextureView.new(), [image.get_data()]);
	imageUniform = RDUniform.new();
	imageUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	imageUniform.binding = 10;
	imageUniform.add_id(image_rid);
	
	uniform_set = rd.uniform_set_create([params_uniform, imageUniform], shader_rid, 0);
	
	pipeline = rd.compute_pipeline_create(shader_rid);
	
	
	
	var compute_list := rd.compute_list_begin();
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	rd.compute_list_dispatch(compute_list, resolution / 8, resolution / 8, 1);
	rd.compute_list_end();
	rd.submit();
	rd.sync();
	
	var image_output_bytes := rd.texture_get_data(image_rid, 0);
	var image_new := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RGF, image_output_bytes);
	var tex := ImageTexture.create_from_image(image_new);
	$TextureRect.texture = tex;
	
	var ButterflyImage = Image.create((log(resolution) / log(2)), resolution, false, Image.FORMAT_RGBAF);
	
	var butterflyFormat = RDTextureFormat.new();
	butterflyFormat.width = (log(resolution) / log(2));
	butterflyFormat.height = resolution;
	butterflyFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT;
	butterflyFormat.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
	
	var butterfly_rid = rd.texture_create(butterflyFormat, RDTextureView.new(), [ButterflyImage.get_data()]);
	butterflyUniform = RDUniform.new();
	butterflyUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	butterflyUniform.binding = 16;
	butterflyUniform.add_id(butterfly_rid);
	
	var butterfly_uniform_set = rd.uniform_set_create([params_uniform, butterflyUniform], butterfly_shader_rid, 0);
	
	var butterfly_pipeline = rd.compute_pipeline_create(butterfly_shader_rid);
	
	compute_list = rd.compute_list_begin();
	rd.compute_list_bind_compute_pipeline(compute_list, butterfly_pipeline);
	rd.compute_list_bind_uniform_set(compute_list, butterfly_uniform_set, 0);
	print(log(resolution) / log(2));
	rd.compute_list_dispatch(compute_list, (log(resolution) / log(2)), resolution / 8, 1);
	rd.compute_list_end();
	rd.submit();
	rd.sync();
	
	var butterfly_image_bytes := rd.texture_get_data(butterfly_rid, 0);
	var butterfly_image := Image.create_from_data((log(resolution) / log(2)), resolution, false, Image.FORMAT_RGBAF, butterfly_image_bytes);
	var butterfly_tex := ImageTexture.create_from_image(butterfly_image);
	#$TextureRect.texture = butterfly_tex;

func generate_disp():
	var input: PackedFloat32Array = [fetch, windSpeed, enhancementFactor, inputfreq, resolution, oceanSize, Time.get_unix_time_from_system() - initTime, transformHorizontal, lowCutoff, highCutoff, depth, 0, 0];
	
	var params: PackedByteArray = input.to_byte_array();
	rd.buffer_update(params_buffer, 0, params.size(), params);
	
	var DisplacementImage = Image.create(resolution, resolution, false, Image.FORMAT_RGBAF);
	
	var displacementFormat = RDTextureFormat.new();
	displacementFormat.width = resolution;
	displacementFormat.height = resolution;
	displacementFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT;
	displacementFormat.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
	
	displacement_rid = rd.texture_create(displacementFormat, RDTextureView.new(), [DisplacementImage.get_data()]);
	displacementUniform = RDUniform.new();
	displacementUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	displacementUniform.binding = 11;
	displacementUniform.add_id(displacement_rid);
	
	var SlopeImage = Image.create(resolution, resolution, false, Image.FORMAT_RGBAF);
	
	var slopeFormat = RDTextureFormat.new();
	slopeFormat.width = resolution;
	slopeFormat.height = resolution;
	slopeFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT;
	slopeFormat.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
	
	slope_rid = rd.texture_create(slopeFormat, RDTextureView.new(), [SlopeImage.get_data()]);
	
	slopeUniform = RDUniform.new();
	slopeUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	slopeUniform.binding = 12;
	slopeUniform.add_id(slope_rid);
	
	disp_uniform_set = rd.uniform_set_create([params_uniform, displacementUniform, slopeUniform, imageUniform], disp_shader_rid, 0);
	
	disp_pipeline = rd.compute_pipeline_create(disp_shader_rid);
	
	var compute_list := rd.compute_list_begin();
	rd.compute_list_bind_compute_pipeline(compute_list, disp_pipeline);
	rd.compute_list_bind_uniform_set(compute_list, disp_uniform_set, 0);
	rd.compute_list_dispatch(compute_list, resolution / 8, resolution / 8, 1);
	rd.compute_list_end();
	rd.submit();
	rd.sync();
	
	var disp_output_bytes = rd.texture_get_data(displacement_rid, 0);
	var disp_image := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RGBAF, disp_output_bytes);
	var tex := ImageTexture.create_from_image(disp_image);
	$TextureRect.texture = tex;
	
	var slope_output_bytes = rd.texture_get_data(slope_rid, 0);
	var slope_image := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RGBAF, slope_output_bytes);
	var tex2 := ImageTexture.create_from_image(slope_image);
	$TextureRect2.texture = tex2;
	#FFT();
	
func FFT():
	var ping = true; # ping means default values
	var test = [0, 0, 0, 0];
	var testParams := PackedFloat32Array(test).to_byte_array();
	var testBuffer = rd.storage_buffer_create(test.size(), test);
	var testUniform := RDUniform.new();
	testUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	testUniform.binding = 15;
	testUniform.add_id(testBuffer);
		
	var HeightMap = Image.create(resolution, resolution, false, Image.FORMAT_RGBAF);
		
	var heightFormat = RDTextureFormat.new();
	heightFormat.width = resolution;
	heightFormat.height = resolution;
	heightFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT;
	heightFormat.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
		
	var height_rid = rd.texture_create(heightFormat, RDTextureView.new(), [HeightMap.get_data()]);
	var heightUniform = RDUniform.new();
	heightUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	heightUniform.binding = 13;
	heightUniform.add_id(height_rid);
	
	var SlopeImage = Image.create(resolution, resolution, false, Image.FORMAT_RGBAF);
	
	var slopeFormat = RDTextureFormat.new();
	slopeFormat.width = resolution;
	slopeFormat.height = resolution;
	slopeFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT;
	slopeFormat.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
	
	var triangle_rid = rd.texture_create(slopeFormat, RDTextureView.new(), [SlopeImage.get_data()]);
	
	var slopeNormalUniform = RDUniform.new();
	slopeNormalUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	slopeNormalUniform.binding = 14;
	slopeNormalUniform.add_id(triangle_rid);
	
	var direction = 1.0;
	
	for stage in (log(resolution) / log(2)):
		var input: PackedFloat32Array = [fetch, windSpeed, enhancementFactor, inputfreq, resolution, oceanSize, Time.get_unix_time_from_system() - initTime, transformHorizontal, lowCutoff, highCutoff, depth, stage, direction];
		var params: PackedByteArray = input.to_byte_array();
		rd.buffer_update(params_buffer, 0, params.size(), params);
		
		normal_uniform_set = rd.uniform_set_create([params_uniform, displacementUniform, heightUniform, testUniform, butterflyUniform, slopeUniform, slopeNormalUniform], normal_shader_rid, 0);
		normal_pipeline = rd.compute_pipeline_create(normal_shader_rid);
		
		var compute_list := rd.compute_list_begin();
		rd.compute_list_bind_compute_pipeline(compute_list, normal_pipeline);
		rd.compute_list_bind_uniform_set(compute_list, normal_uniform_set, 0);
		rd.compute_list_dispatch(compute_list, resolution / 32, resolution / 32, 1);
		rd.compute_list_end();
		rd.submit();
		#await get_tree().create_timer(3).timeout
		rd.sync();
		
		rd.free_rid(normal_uniform_set);
		
		var temp = displacementUniform.binding;
		displacementUniform.binding = heightUniform.binding;
		heightUniform.binding = temp;
		
		var temp2 = slopeUniform.binding;
		slopeUniform.binding = slopeNormalUniform.binding;
		slopeNormalUniform.binding = temp2;
		ping = !ping;
	
	direction = 0.0;
	
	for stage in (log(resolution) / log(2)):
		var input: PackedFloat32Array = [fetch, windSpeed, enhancementFactor, inputfreq, resolution, oceanSize, Time.get_unix_time_from_system() - initTime, transformHorizontal, lowCutoff, highCutoff, depth, stage, direction];
		var params: PackedByteArray = input.to_byte_array();
		rd.buffer_update(params_buffer, 0, params.size(), params);
		
		normal_uniform_set = rd.uniform_set_create([params_uniform, displacementUniform, heightUniform, testUniform, butterflyUniform, slopeUniform, slopeNormalUniform], normal_shader_rid, 0);
		normal_pipeline = rd.compute_pipeline_create(normal_shader_rid);
		
		var compute_list := rd.compute_list_begin();
		rd.compute_list_bind_compute_pipeline(compute_list, normal_pipeline);
		rd.compute_list_bind_uniform_set(compute_list, normal_uniform_set, 0);
		rd.compute_list_dispatch(compute_list, resolution / 32, resolution / 32, 1);
		rd.compute_list_end();
		rd.submit();
		rd.sync();
		
		rd.free_rid(normal_uniform_set);
		
		var temp = displacementUniform.binding;
		displacementUniform.binding = heightUniform.binding;
		heightUniform.binding = temp;
		
		var temp2 = slopeUniform.binding;
		slopeUniform.binding = slopeNormalUniform.binding;
		slopeNormalUniform.binding = temp2;
		ping = !ping;
	
	var input: PackedFloat32Array = [fetch, windSpeed, enhancementFactor, inputfreq, resolution, oceanSize, Time.get_unix_time_from_system() - initTime, transformHorizontal, lowCutoff, highCutoff, depth, 0, 0];
	var params: PackedByteArray = input.to_byte_array();
	rd.buffer_update(params_buffer, 0, params.size(), params);
		
	normal_uniform_set = rd.uniform_set_create([params_uniform, displacementUniform, heightUniform, testUniform, butterflyUniform, slopeUniform, slopeNormalUniform], inversion_shader_rid, 0);
	normal_pipeline = rd.compute_pipeline_create(inversion_shader_rid);
		
	var compute_list := rd.compute_list_begin();
	rd.compute_list_bind_compute_pipeline(compute_list, normal_pipeline);
	rd.compute_list_bind_uniform_set(compute_list, normal_uniform_set, 0);
	rd.compute_list_dispatch(compute_list, resolution / 16, resolution / 16, 1);
	rd.compute_list_end();
	rd.submit();
	rd.sync();
	
	var normal_output_bytes = rd.texture_get_data(height_rid, 0);
	var disp_output_bytes = rd.texture_get_data(displacement_rid, 0);
	var normal_image = Image.create_from_data(resolution, resolution, false, Image.FORMAT_RGBAF, disp_output_bytes);
	var tex = ImageTexture.create_from_image(normal_image);
	$TextureRect.texture = tex;
	
	var slope_output_bytes = rd.texture_get_data(slope_rid, 0);
	var slope_image := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RGBAF, slope_output_bytes);
	var tex2 := ImageTexture.create_from_image(slope_image);
	$TextureRect2.texture = tex2;
	
	get_surface_override_material(0).set_shader_parameter("outputImage", tex);
	get_surface_override_material(0).set_shader_parameter("normalImage", tex2);
	

func cleanup_gpu():
	if rd == null:
		return;
	
	rd.free_rid(butterfly_shader_rid);
	butterfly_shader_rid = RID();
	
	rd.free_rid(pipeline);
	pipeline = RID();
	
	rd.free_rid(uniform_set);
	uniform_set = RID();
	
	rd.free_rid(shader_rid);
	shader_rid = RID();
	
	rd.free_rid(disp_pipeline);
	disp_pipeline = RID();
	
	rd.free_rid(displacement_rid);
	displacement_rid = RID();
	
	rd.free_rid(disp_uniform_set);
	disp_uniform_set = RID();
	
	rd.free_rid(disp_shader_rid);
	disp_shader_rid = RID();
	
	rd.free_rid(normal_pipeline);
	normal_pipeline = RID();
	
	rd.free_rid(normal_uniform_set);
	normal_uniform_set = RID();
	
	rd.free_rid(normal_shader_rid);
	normal_shader_rid = RID();
	
	rd.free();
	rd = null;

func _process(delta):
	var currentParams = [fetch, windSpeed, enhancementFactor, inputfreq, resolution, oceanSize, transformHorizontal, lowCutoff, highCutoff, depth];
	if (currentParams != prevParams):
		prevParams = currentParams;
		generate_init_spectrum();
	
	if (Input.is_action_just_pressed("move_backward")):
		generate_disp();
	if (currentFrame < frameSkip):
		currentFrame = currentFrame + 1;
	else:
		currentFrame = 0;
		generate_disp();
		FFT();

extends MeshInstance3D
@export_file("*.glsl") var compute_shader
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

var rd: RenderingDevice;
var shader_rid: RID;
var uniform_set: RID;
var pipeline: RID;

var initTime: float;

# Called when the node enters the scene tree for the first time.
func _ready():
	initTime = Time.get_unix_time_from_system();
	init_gpu();

func init_gpu():
	rd = RenderingServer.create_local_rendering_device();
	
	var shader_file_data: RDShaderFile = load(compute_shader);
	var shader_spirv: RDShaderSPIRV = shader_file_data.get_spirv();
	shader_rid = rd.shader_create_from_spirv(shader_spirv);
	
	var input = [fetch, windSpeed, enhancementFactor, inputfreq, resolution, oceanSize, Time.get_unix_time_from_system() - initTime, transformHorizontal, lowCutoff, highCutoff, depth];
	
	var params := PackedFloat32Array(input).to_byte_array();
	var buffer = rd.storage_buffer_create(params.size(), params);
	var uniform := RDUniform.new();
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	uniform.binding = 0;
	uniform.add_id(buffer);
	
	var image = Image.create(resolution, resolution, false, Image.FORMAT_RF);
	
	var imageFormat = RDTextureFormat.new();
	imageFormat.width = resolution;
	imageFormat.height = resolution;
	imageFormat.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT;
	imageFormat.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
	
	var image_rid = rd.texture_create(imageFormat, RDTextureView.new(), image.get_data());
	var imageUniform = RDUniform.new();
	imageUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	imageUniform.binding = 10;
	imageUniform.add_id(image_rid);
	
	uniform_set = rd.uniform_set_create([uniform, imageUniform], shader_rid, 0);
	
	pipeline = rd.compute_pipeline_create(shader_rid);
	var compute_list := rd.compute_list_begin();
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	rd.compute_list_dispatch(compute_list, resolution / 8, resolution / 8, 1);
	rd.compute_list_end();
	rd.submit();
	rd.sync();
	
	var DisplacementImage = Image.create(resolution, resolution, false, Image.FORMAT_RGF);
	
	var displacementFormat = RDTextureFormat.new();
	displacementFormat.width = resolution;
	displacementFormat.height = resolution;
	displacementFormat.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT;
	displacementFormat.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
	
	var displacement_rid = rd.texture_create(displacementFormat, RDTextureView.new(), DisplacementImage.get_data());
	var displacementUniform = RDUniform.new();
	displacementUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	displacementUniform.binding = 11;
	displacementUniform.add_id(displacement_rid);
	
	
	var output_bytes := rd.buffer_get_data(buffer);
	var output := output_bytes.to_float32_array();
	print("Input: ", input)
	print("Output: ", output)
	
	var image_output_bytes := rd.texture_get_data(image_rid, 0);
	var image_new := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, image_output_bytes);
	var tex := ImageTexture.create_from_image(image_new);
	$TextureRect.texture = tex;

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		cleanup_gpu();

func cleanup_gpu():
	if rd == null:
		return;
	
	rd.free_rid(pipeline);
	pipeline = RID();
	
	rd.free_rid(uniform_set);
	uniform_set = RID();
	
	rd.free_rid(shader_rid);
	shader_rid = RID();
	
	rd.free();
	rd = null;

func _process(delta):
	if (Input.is_action_just_pressed("move_backward")):
		init_gpu();

extends MeshInstance3D
@export_file("*.glsl") var compute_shader
@export_range(128, 4096, 1, "exp") var dimension: int = 128;

var attached_material: ShaderMaterial;

var seed: float;
var heightmap_rect: TextureRect;
var island_rect: TextureRect;

var noise: FastNoiseLite;
var gradient: Gradient;
var gradient_tex: GradientTexture1D;

var po2_dimensions: int;
var start_time: int;

var rd: RenderingDevice;
var shader_rid: RID;
var heightmap_rid: RID;
var gradient_rid: RID;
var uniform_set: RID;
var pipeline: RID;

func _init():
	noise = FastNoiseLite.new();
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH;
	noise.fractal_octaves = 5;
	noise.fractal_lacunarity = 1.9;
	
	gradient = Gradient.new();
	gradient.add_point(0.6, Color(0.9, 0.9, 0.9, 1.0));
	gradient.add_point(0.8, Color(1.0, 1.0, 1.0, 1.0));
	gradient.reverse()
	
	gradient_tex = GradientTexture1D.new();
	gradient_tex.gradient = gradient;
	
func _ready():
	attached_material = get_surface_override_material(0);
	
	po2_dimensions = nearest_po2(dimension);
	
	noise.frequency = 0.003 / (float(po2_dimensions) / 512.0);
	
	create_texture_using_gpu();

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		cleanup_gpu();

func init_gpu():
	rd = RenderingServer.create_local_rendering_device();
	
	var shader_file_data: RDShaderFile = load(compute_shader);
	var shader_spirv: RDShaderSPIRV = shader_file_data.get_spirv();
	shader_rid = rd.shader_create_from_spirv(shader_spirv);
	
	# heightmap format initialization
	var heightmap_format := RDTextureFormat.new();
	heightmap_format.format = RenderingDevice.DATA_FORMAT_R8_UNORM;
	heightmap_format.width = po2_dimensions;
	heightmap_format.height = po2_dimensions;
	heightmap_format.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
	
	heightmap_rid = rd.texture_create(heightmap_format, RDTextureView.new());
	
	var heightmap_uniform := RDUniform.new();
	heightmap_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	heightmap_uniform.binding = 0;
	heightmap_uniform.add_id(heightmap_rid);
	
	#gradient format initialization
	var gradient_format := RDTextureFormat.new();
	gradient_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM;
	gradient_format.width = gradient_tex.width;
	gradient_format.height = 1;
	gradient_format.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT;
	
	gradient_rid = rd.texture_create(gradient_format, RDTextureView.new(), [gradient_tex.get_image().get_data()]);
	
	var gradient_uniform := RDUniform.new();
	gradient_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	gradient_uniform.binding = 1;
	gradient_uniform.add_id(gradient_rid);
	
	uniform_set = rd.uniform_set_create([heightmap_uniform, gradient_uniform], shader_rid, 0);
	
	pipeline = rd.compute_pipeline_create(shader_rid);

func create_texture_using_gpu():
	seed = randi();
	noise.seed = seed;
	
	var heightmap := noise.get_image(po2_dimensions, po2_dimensions, false, false);
	
	if rd == null:
		init_gpu();
	
	rd.texture_update(heightmap_rid, 0, heightmap.get_data());
	
	var compute_list := rd.compute_list_begin();
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	# this is the key
	rd.compute_list_dispatch(compute_list, po2_dimensions / 8, po2_dimensions / 8, 1);
	rd.compute_list_end();
	
	rd.submit();
	rd.sync();
	# sync waits for GPU to finish
	
	var output_bytes := rd.texture_get_data(heightmap_rid, 0);
	var image := Image.create_from_data(po2_dimensions, po2_dimensions, false, Image.FORMAT_L8, output_bytes);
	var tex := ImageTexture.create_from_image(image);
	print(tex);
	attached_material.set_shader_parameter("outputImage", tex);
	print(attached_material.get_shader_parameter("outputImage"));
	$TextureRect.texture = tex;

func cleanup_gpu():
	if rd == null:
		return;
	
	rd.free_rid(pipeline);
	pipeline = RID();
	
	rd.free_rid(uniform_set);
	uniform_set = RID();
	
	rd.free_rid(gradient_rid);
	gradient_rid = RID();
	
	rd.free_rid(heightmap_rid);
	heightmap_rid = RID();
	
	rd.free_rid(shader_rid);
	shader_rid = RID();
	
	rd.free();
	rd = null;

func _process(delta):
	if (Input.is_action_just_pressed("move_backward")):
		#call_deferred("create_texture_using_gpu");
		create_texture_using_gpu();

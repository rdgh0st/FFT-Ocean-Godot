extends Camera3D

@export_group("Camera Parameters")
@export var moveSpeed: float;
@export var rotationSpeed: float;

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var rotation_input = Input.get_vector("Look Right", "Look Left", "Look Down", "Look Up");
	var newRotation = rotation + Vector3(rotation_input.y * delta * rotationSpeed, rotation_input.x * delta * rotationSpeed, 0);
	transform.basis = Basis.from_euler(newRotation);
	rotation.z = 0.0;
	
	var input_dir = Input.get_vector("Move Left", "Move Right", "Move Forward", "Move Backward");
	var up_down = Input.get_axis("Float Down", "Float Up");
	var direction = (transform.basis * Vector3(input_dir.x, up_down, input_dir.y)).normalized();
	if direction:
		position += direction * moveSpeed
	
	#if Input.is_action_pressed("Look Left"):
		#rotate_y(rotationSpeed);
	#if Input.is_action_pressed("Look Right"):
		#rotate_y(-rotationSpeed);
	#if Input.is_action_pressed("Look Up"):
		#rotate_x(rotationSpeed);
	#if Input.is_action_pressed("Look Down"):
		#rotate_x(-rotationSpeed);
	#if Input.is_action_pressed("Move Backward"):
		#position += global_transform.basis.z * moveSpeed;
	#if Input.is_action_pressed("Move Forward"):
		#position -= global_transform.basis.z * moveSpeed;
	#if Input.is_action_pressed("Move Left"):
		#position.x -= moveSpeed;
	#if Input.is_action_pressed("Move Right"):
		#position.x += moveSpeed;
	#if Input.is_action_pressed("Float Down"):
		#position.y -= moveSpeed;
	if Input.is_action_pressed("Float Up"):
		position.y += moveSpeed;

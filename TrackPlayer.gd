extends Marker3D

@export var rotationSpeed : float;
@export var moveSpeed : float;

@onready var player = $Boat2;

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	global_position = Vector3(player.global_position.x, global_position.y, player.global_position.z);

func _physics_process(delta):
	var direction = Vector3.ZERO;
	var target_velocity = Vector3.ZERO;
	
	if Input.is_action_pressed("turn_left"):
		rotate_y(rotationSpeed);
	if Input.is_action_pressed("turn_right"):
		rotate_y(-rotationSpeed);
	if Input.is_action_pressed("move_forward"):
		direction += -global_transform.basis.z;
	if Input.is_action_pressed("move_backward"):
		direction += global_transform.basis.z;
	
	target_velocity.x = direction.x * moveSpeed;
	target_velocity.z = direction.z * moveSpeed;
	
	global_position += target_velocity;

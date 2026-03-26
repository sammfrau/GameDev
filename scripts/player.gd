# Assumes this script is attached to a CharacterBody3D node.
extends CharacterBody3D

# Inputs for player movement
@export var walk_speed: float = 5.0 # Speed when walking
@export var sprint_speed: float = 10.0 # Speed when sprinting
@export var gravity_align_speed: float = 5.0 # Controls the smoothness of rotation when aligning to gravity/surface normal.
@export var acceleration: float = 10.0 # For air speeds
@export var friction: float = 20.0 # Higher value for quicker stopping/less slip
@export var gravity: float = 9.8 # Default gravity when outside any zone
@export var run_speed_threshold: float = 8.0 # Threshold for a change in animation
@export var jump_velocity: float = 7.0 # For when the player jumps
# Inputs for camera controls
@export var mouse_sensitivity: float = 0.003 # For camera movement
@export var min_pitch: float = -50.0 # Min vertical rotation in degrees (looking down)
@export var max_pitch: float = 80.0 # Max vertical rotation in degrees (looking up)

# Reference to the AnimatedSprite3D node
@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite3D
# References to the camera system
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_3d: Camera3D = $CameraPivot/SpringArm3D/Camera3D

# Animation names in your SpriteFrames resource
# Toward for player looking at the player camera
# Away for the player looking away from the player camera
const ANIM_IDLE_TOWARD = "IdleToward"
const ANIM_IDLE_AWAY = "IdleAway"
const ANIM_WALK_TOWARD = "WalkToward"
const ANIM_WALK_AWAY = "WalkAway"
const ANIM_RUN_TOWARD = "RunToward"
const ANIM_RUN_AWAY = "RunAway"
const ANIM_JUMP_START_TOWARD = "JumpStartToward"
const ANIM_JUMP_START_AWAY = "JumpStartAway"
const ANIM_FALL_TOWARD = "FallToward"
const ANIM_FALL_AWAY = "FallAway"

# Constant threshold to determine if movement is considered 'forward' or 'backward'
const DIRECTION_THRESHOLD: float = 0.5

# Stores the normalized movement direction based on input
var input_direction: Vector2 = Vector2.ZERO

# Stores the 3D movement vector based on input and character rotation
var move_direction: Vector3 = Vector3.ZERO

# --- Multi-Source Spherical Gravity Storage ---
# Stores all currently active gravity sources: {StaticBody3D: force_float}
var active_gravity_sources: Dictionary = {}


# Handles inputs from user
func _input(event: InputEvent) -> void:
	# Captures inputs for player movement
	input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# For getting in an out of the game
	if event.is_action_pressed("ui_cancel") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Captures mouse movement for the player camera
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_look(event)


# Public method to ADD a gravity source (called by gravity_zone on body_entered)
func add_gravity_source(center_node: StaticBody3D, force: float) -> void:
	if is_instance_valid(center_node):
		active_gravity_sources[center_node] = force


# Public method to REMOVE a gravity source (called by gravity_zone on body_exited)
func remove_gravity_source(center_node: StaticBody3D) -> void:
	if active_gravity_sources.has(center_node):
		active_gravity_sources.erase(center_node)


# Handles camera rotation based on mouse input (Yaw and Pitch)
func _handle_mouse_look(event: InputEventMouseMotion) -> void:
	# 1. Horizontal rotation (Yaw) - Rotates the CharacterBody3D (Player)
	rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
	
	# 2. Vertical rotation (Pitch) - Rotates the CameraPivot
	var cam_rotation_x = camera_pivot.rotation.x - (event.relative.y * mouse_sensitivity)
	
	# Clamp the vertical rotation (Pitch)
	var min_rad = deg_to_rad(min_pitch)
	var max_rad = deg_to_rad(max_pitch)
	camera_pivot.rotation.x = clamp(cam_rotation_x, min_rad, max_rad)


# Handles movement from the player and the player camera
func _physics_process(delta: float) -> void:
	
	var current_gravity_force = gravity
	var gravity_direction = Vector3.DOWN
	var using_custom_gravity = !active_gravity_sources.is_empty()
	
	# Determine Gravity Direction (Airborne) by Summing All Sources
	if using_custom_gravity:
		var total_gravity_pull = Vector3.ZERO
		
		for center_node in active_gravity_sources:
			if is_instance_valid(center_node):
				var force = active_gravity_sources[center_node]
				
				# Calculate the direction and vector of the gravitational pull from this source
				var direction_to_center = (center_node.global_position - global_position)
				var gravity_vector = direction_to_center.normalized() * force
				
				# Sum the vectors
				total_gravity_pull += gravity_vector
		
		if total_gravity_pull.length_squared() > 0.0:
			# The final gravity direction is the normalized sum of all pulls (the resultant vector)
			gravity_direction = total_gravity_pull.normalized()
			# The final gravity force is the magnitude of the combined pull
			current_gravity_force = total_gravity_pull.length()
		else:
			# Fallback to default linear gravity if sources cancel out or are invalid
			using_custom_gravity = false
			current_gravity_force = gravity
	
	# Override Gravity Direction based on Floor Normal (Grounded)
	if is_on_floor() and using_custom_gravity:
		# When on the floor, snap gravity direction to the normal of the collision shape.
		gravity_direction = -get_floor_normal()
	
	# Align Player to Surface
	if using_custom_gravity:
		_align_to_gravity(gravity_direction, delta)
	
	# Calculate the UP vector (anti-gravity direction) once
	var up_vector = -gravity_direction.normalized()
	
	# Separate Velocities
	var horizontal_velocity: Vector3 = velocity.slide(gravity_direction)
	var vertical_velocity: Vector3 = velocity - horizontal_velocity
	
	# Apply Gravity, Sticking, and Jump
	if is_on_floor():
		# Zero out any residual upward vertical velocity
		if vertical_velocity.dot(up_vector) > 0.0:
			vertical_velocity = Vector3.ZERO
		
		# Apply a small, constant downward force (sticking force)
		vertical_velocity += gravity_direction * 0.1
		
		# Jump implementation
		if Input.is_action_just_pressed("jump"):
			vertical_velocity = up_vector * jump_velocity
			_update_sprite_animation()
	
	else:
		# Apply gravity accumulation in the air
		vertical_velocity += gravity_direction * current_gravity_force * delta
	
	# Calculate Movement and Acceleration
	var forward = -global_transform.basis.z.normalized()
	var right = global_transform.basis.x.normalized()
	
	# Calculate the raw desired movement vector based on input
	move_direction = (forward * -input_direction.y) + (right * input_direction.x)
	
	# If player is moving
	if move_direction.length_squared() > 0.0:
		
		# Project and Normalize move_direction to be strictly tangent to the surface
		move_direction = move_direction.slide(gravity_direction).normalized()
		
		# Walk speed
		var current_target_speed: float = walk_speed
		
		# Sprint functionality
		if is_on_floor() and Input.is_action_pressed("sprint"):
			current_target_speed = sprint_speed
		
		# Air Momentum Preservation
		if not is_on_floor():
			var current_horiz_speed = horizontal_velocity.length()
			if current_horiz_speed > current_target_speed:
				current_target_speed = current_horiz_speed
		
		# Apply acceleration/movement along the move_direction
		var target_velocity_horiz = move_direction * current_target_speed
		horizontal_velocity = horizontal_velocity.lerp(target_velocity_horiz, delta * acceleration)
		
		# Updating animted sprite based on player movement
		_update_sprite_animation()
		_update_sprite_flip()
	else:
		# Decelerate when no input is given (Friction)
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, friction * delta)
		
		# Default idle animation
		if is_on_floor():
			if animated_sprite_3d.animation != ANIM_IDLE_TOWARD:
				animated_sprite_3d.play(ANIM_IDLE_TOWARD)
		
		# Updating animted sprite based on player movement
		_update_sprite_animation()
	
	# Final Recombination and Move
	velocity = horizontal_velocity + vertical_velocity
	self.up_direction = up_vector
	move_and_slide()


func _align_to_gravity(gravity_direction: Vector3, delta: float) -> void:
	# Define the current forward direction (preserves player's yaw)
	var current_forward: Vector3 = -global_transform.basis.z
	
	# The target UP vector is always opposite the gravity direction.
	var target_up: Vector3 = -gravity_direction
	
	# Project the current forward vector onto the tangent plane (horizontal to the surface).
	var tangent_forward: Vector3 = current_forward.slide(target_up).normalized()
	if tangent_forward.is_zero_approx():
		tangent_forward = global_transform.basis.x.cross(target_up).normalized()
	
	# Construct the stable target basis.
	var target_basis: Basis = Basis.looking_at(tangent_forward, target_up)
	
	# Smoothly interpolate the player's rotation towards the target basis (using gravity_align_speed)
	global_transform.basis = global_transform.basis.slerp(target_basis, min(1.0, delta * gravity_align_speed))


# Handles player animated sprite based on player movement
func _update_sprite_animation() -> void:
	var char_forward_vector: Vector3 = -global_transform.basis.z
	var horiz_velocity: Vector3 = velocity.slide(-global_transform.basis.y)
	var speed: float = horiz_velocity.length()
	var normalized_horiz_velocity: Vector3 = horiz_velocity.normalized()
	var dot_product: float = char_forward_vector.dot(normalized_horiz_velocity)
	var moving_backward: bool = false
	var current_anim: String = ""
	
	if speed > 0.1:
		if dot_product < -DIRECTION_THRESHOLD:
			moving_backward = true
	
	if is_on_floor():
		if speed > run_speed_threshold:
			current_anim = ANIM_RUN_AWAY if moving_backward else ANIM_RUN_TOWARD
		elif speed > 0.1:
			current_anim = ANIM_WALK_AWAY if moving_backward else ANIM_WALK_TOWARD
		else:
			current_anim = ANIM_IDLE_TOWARD
	else:
		var vertical_velocity_local = global_transform.basis.y.dot(velocity)
		
		if vertical_velocity_local > 0.1:
			current_anim = ANIM_JUMP_START_AWAY if moving_backward else ANIM_JUMP_START_TOWARD
		elif vertical_velocity_local < -0.1:
			current_anim = ANIM_FALL_AWAY if moving_backward else ANIM_FALL_TOWARD
		else:
			current_anim = ANIM_FALL_TOWARD 
	
	if animated_sprite_3d.animation != current_anim and current_anim != "":
		animated_sprite_3d.play(current_anim)


# Handles flipping the player animated sprite based on player movement
func _update_sprite_flip() -> void:
	if input_direction.x > 0.0:
		animated_sprite_3d.flip_h = false
	elif input_direction.x < 0.0:
		animated_sprite_3d.flip_h = true

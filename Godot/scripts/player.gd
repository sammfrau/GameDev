# File: player.gd
# AI Help From: Google Gemini
# Edited By: Sam Frauenhoffer
# Purpose: Player Movement & Art Updates

# Extending a CharacterBody3D
extends CharacterBody3D


# === Export Node Assignments
@export_group("Nodes")
@export var animated_sprite_3d: AnimatedSprite3D
@export var camera_pivot: Node3D
@export var camera_3d: Camera3D

# === Exports for Player Movement
@export_group("Movement Actions")
@export var action_move_left: StringName = "move_left"
@export var action_move_right: StringName = "move_right"
@export var action_move_forward: StringName = "move_forward"
@export var action_move_backward: StringName = "move_backward"
@export var action_sprint: StringName = "sprint"
@export var action_jump: StringName = "jump"

# === Exports for Camera Movement
@export_group("Camera Actions")
@export var action_look_left: StringName = "look_left"
@export var action_look_right: StringName = "look_right"
@export var action_look_up: StringName = "look_up"
@export var action_look_down: StringName = "look_down"

# === Exports for UI Actions
@export_group("UI Actions")
@export var action_exit_window: StringName = "exit_window"

# === Exports for Player Movement & Sensitivity Settings
@export_group("Movement Settings")
@export var walk_speed: float = 2.0 # Speed when walking
@export var sprint_speed: float = 3.5 # Speed when sprinting
@export var jump_velocity: float = 4.5 # Jump force
@export var gravity_align_speed: float = 5.0 # Smoothness of rotation when aligning to gravity/surface normal
@export var acceleration: float = 10.0 # For air speeds
@export var friction: float = 20.0 # Stopping force while on custom gravity object
@export var default_gravity: float = 10.0 # Default gravity outside of custom gravity object zones
@export var run_speed_threshold: float = 2.5 # Speed threshold for run animation

# === Exports for Camera Movement & Sensitivity Settings
@export_group("Camera Settings")
@export var controller_sensitivity: float = 2.0 # Controller joystick look sensitivity
@export var mouse_sensitivity: float = 0.003 # Mouse look sensitivity
@export var minimum_pitch: float = -50.0 # Min vertical angle (degrees looking down)
@export var maximum_pitch: float = 80.0 # Max vertical angle (degrees looking up)

# === Player Animations
@export_group("Player Animations")
@export var ANIM_IDLE_TOWARD = "IdleToward"
@export var ANIM_IDLE_AWAY = "IdleAway"
@export var ANIM_WALK_TOWARD = "WalkToward"
@export var ANIM_WALK_AWAY = "WalkAway"
@export var ANIM_RUN_TOWARD = "RunToward"
@export var ANIM_RUN_AWAY = "RunAway"
@export var ANIM_JUMP_TOWARD = "JumpToward"
@export var ANIM_JUMP_AWAY = "JumpAway"
@export var ANIM_FALL_TOWARD = "FallToward"
@export var ANIM_FALL_AWAY = "FallAway"


# === Runtime Variables
var input_direction: Vector2 = Vector2.ZERO
var camera_input: Vector2 = Vector2.ZERO
var active_gravity_sources: Dictionary = {}
var active_planet_stick_sources: Dictionary = {}


# === Gravitation Source Registration
func add_gravity_source(center_node: StaticBody3D, force: float) -> void:
	if is_instance_valid(center_node):
		active_gravity_sources[center_node] = force

func remove_gravity_source(center_node: StaticBody3D) -> void:
	if active_gravity_sources.has(center_node):
		active_gravity_sources.erase(center_node)

func add_planet_stick_source(center_node: StaticBody3D, force: float) -> void:
	if is_instance_valid(center_node):
		active_planet_stick_sources[center_node] = force

func remove_planet_stick_source(center_node: StaticBody3D) -> void:
	if active_planet_stick_sources.has(center_node):
		active_planet_stick_sources.erase(center_node)


# === Input Handling
func _input(event: InputEvent) -> void:
	# 1. Capture movement input vector using exported action names
	input_direction = Input.get_vector(
		action_move_left,
		action_move_right,
		action_move_forward,
		action_move_backward
	)
	
	# 2. Toggle mouse capture
	if event.is_action_pressed(action_exit_window) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# 3. Camera movement execution
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_camera_rotation(event.relative.x * mouse_sensitivity, event.relative.y * mouse_sensitivity)


# === Player Logic
func _physics_process(delta: float) -> void:
	# 1. Local variables declaration
	var using_custom_gravity
	var using_planet_stick
	var current_gravity_force
	var current_gravity_direction
	var total_gravity
	var active_source_force
	var active_source_center_direction
	var active_source_vector
	var up_vector
	var player_horizontal_velocity: Vector3
	var player_vertical_velocity: Vector3
	var player_normal_z
	var player_normal_x
	var move_direction: Vector3
	var current_player_speed: float
	var current_horizontal_speed
	
	# 2. Local variables assignment
	current_gravity_force = default_gravity
	current_gravity_direction = Vector3.DOWN
	using_custom_gravity = !active_gravity_sources.is_empty()
	using_planet_stick = !active_planet_stick_sources.is_empty()
	total_gravity = Vector3.ZERO
	up_vector = Vector3.UP
	move_direction = Vector3.ZERO
	
	# 3. Sum up gravity sources
	if using_custom_gravity:
		for center_node in active_gravity_sources:
			if is_instance_valid(center_node):
				active_source_force = active_gravity_sources[center_node]
				active_source_center_direction = (center_node.global_position - global_position)
				active_source_vector = active_source_center_direction.normalized() * active_source_force
				total_gravity += active_source_vector
		if total_gravity.length_squared() > 0.0:
			current_gravity_direction = total_gravity.normalized()
			current_gravity_force = total_gravity.length()
			up_vector = -current_gravity_direction.normalized()
	
	# 4. Override surface gravity when grounded
	if is_on_floor() and using_planet_stick:
		current_gravity_direction = -get_floor_normal()
		up_vector = -current_gravity_direction.normalized()
	
	# 5. Align body orientation to surface/gravity
	_align_to_gravity(current_gravity_direction, delta)
	
	# 6. Separate vertical & horizontal velocities
	player_horizontal_velocity = velocity.slide(current_gravity_direction)
	player_vertical_velocity= velocity - player_horizontal_velocity
	
	# 7. Handle jump & ground sticking
	if is_on_floor():
		if player_vertical_velocity.dot(up_vector) > 0.0:
			player_vertical_velocity = Vector3.ZERO
		player_vertical_velocity += current_gravity_direction * 0.1
		if Input.is_action_just_pressed(action_jump):
			player_vertical_velocity = up_vector * jump_velocity
	else:
		player_vertical_velocity += current_gravity_direction * current_gravity_force * delta
	
	# 8. Movement calculation
	player_normal_z = -global_transform.basis.z.normalized()
	player_normal_x = global_transform.basis.x.normalized()
	move_direction = (player_normal_z * -input_direction.y) + (player_normal_x * input_direction.x)
	if move_direction.length_squared() > 0.0:
		move_direction = move_direction.slide(current_gravity_direction).normalized()
		current_player_speed = walk_speed
		if is_on_floor() and Input.is_action_pressed(action_sprint):
			current_player_speed = sprint_speed
		if not is_on_floor():
			current_horizontal_speed = player_horizontal_velocity.length()
			if current_horizontal_speed > current_player_speed:
				current_player_speed = current_horizontal_speed
		player_horizontal_velocity = move_direction * current_player_speed
		player_horizontal_velocity = player_horizontal_velocity.move_toward(player_horizontal_velocity, delta * acceleration)
	else:
		player_horizontal_velocity = player_horizontal_velocity.move_toward(Vector3.ZERO, friction * delta)
	
	# 9. Update animation
	_update_sprite_animation()
	
	# 10. Apply recombined movement
	velocity = player_horizontal_velocity + player_vertical_velocity
	self.up_direction = up_vector
	move_and_slide()


# === Camera Logic
func _apply_camera_rotation(yaw_delta: float, pitch_delta: float) -> void:
	# 1. Local variables declaration
	var camera_rotation_x
	
	# 2. Local variables assignment
	camera_rotation_x = camera_pivot.rotation.x - pitch_delta
	
	# 3. Apply camera movement
	rotate_object_local(Vector3.UP, -yaw_delta)
	camera_pivot.rotation.x = clamp(camera_rotation_x, deg_to_rad(minimum_pitch), deg_to_rad(maximum_pitch))


# === Sub Function for Player Logic
func _align_to_gravity(gravity_direction: Vector3, delta: float) -> void:
	var current_scale: Vector3 = global_transform.basis.get_scale()
	var current_forward: Vector3 = -global_transform.basis.z
	var player_up: Vector3 = -gravity_direction
	
	var tangent_forward: Vector3 = current_forward.slide(player_up).normalized()
	if tangent_forward.is_zero_approx():
		tangent_forward = global_transform.basis.x.cross(player_up).normalized()
	
	var target_basis: Basis = Basis.looking_at(tangent_forward, player_up)
	var current_basis_clean: Basis = global_transform.basis.orthonormalized()
	
	var weight: float = 1.0 - exp(-gravity_align_speed * delta)
	var current_quat: Quaternion = current_basis_clean.get_rotation_quaternion()
	var target_quat: Quaternion = target_basis.get_rotation_quaternion()
	
	var new_rotation_basis: Basis = Basis(current_quat.slerp(target_quat, weight)).orthonormalized()
	global_transform.basis = new_rotation_basis.scaled(current_scale)


# === Sub Function for Player Logic
func _update_sprite_animation() -> void:
	var forward_vector: Vector3 = global_transform.basis.z
	var vertical_velocity_local = global_transform.basis.y.dot(velocity)
	var relative_horizontal_velocity: Vector3 = velocity.slide(-global_transform.basis.y.normalized())
	var relative_horizontal_speed: float = relative_horizontal_velocity.length()
	var normalized_horizontal_speed: Vector3 = relative_horizontal_velocity.normalized()
	var dot_product: float = forward_vector.dot(normalized_horizontal_speed)
	var moving_backward: bool = false
	var current_animation: String = ""
	
	if relative_horizontal_speed > 0.1:
		if dot_product < -0.5:
			moving_backward = true
	
	if is_on_floor():
		if relative_horizontal_speed > run_speed_threshold:
			current_animation = ANIM_RUN_TOWARD if moving_backward else ANIM_RUN_AWAY
		elif relative_horizontal_speed > 0.1:
			current_animation = ANIM_WALK_AWAY if moving_backward else ANIM_WALK_TOWARD
		else:
			current_animation = ANIM_IDLE_TOWARD
	else:
		if vertical_velocity_local > -0.1:
			current_animation = ANIM_JUMP_AWAY if moving_backward else ANIM_JUMP_TOWARD
		elif vertical_velocity_local < 0.1:
			current_animation = ANIM_FALL_AWAY
		else:
			current_animation = ANIM_FALL_TOWARD
	
	if animated_sprite_3d.animation != current_animation and current_animation != "":
		animated_sprite_3d.play(current_animation)

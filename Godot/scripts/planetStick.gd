# planet_stick.gd
extends Area3D


# Export the custom stick force for planets
@export var planet_stick_force: float = 10.0


func _on_body_entered(body: Node3D):
	
	# 1. Check if the parent is a Area3D
	var collision_source = get_parent()
	if not collision_source is StaticBody3D:
		return
	
	# 2. Check if the entered body is the player and has the required method
	if body.has_method("add_planet_stick_source"):
		# Tell the player to start calculating stick force from this Area3D source
		body.add_planet_stick_source(collision_source, planet_stick_force)


func _on_body_exited(body: Node3D):
	# 1. Check if the parent is a Area3D
	var collision_source = get_parent()
	if not collision_source is StaticBody3D:
		return
	
	
	# 2. Check if the entered body is the player and has the required method
	if body.has_method("remove_planet_stick_source"):
		# Tell the player to start calculating stick force from this Area3D source
		body.remove_planet_stick_source(collision_source)

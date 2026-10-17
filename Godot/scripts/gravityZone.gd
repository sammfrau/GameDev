# gravity_zone.gd
extends Area3D


# Export the custom force for this specific gravity zone
@export var gravity_force: float = 10.0


# Called when another physics body enters this area
func _on_body_entered(body: Node3D):
	
	# 1. Check if the parent is a StaticBody3D
	var gravity_source = get_parent()
	if not gravity_source is StaticBody3D:
		return
	
	# 2. Check if the entered body is the player and has the required method
	if body.has_method("add_gravity_source"):
		# Tell the player to start calculating gravity from this StaticBody3D source
		body.add_gravity_source(gravity_source, gravity_force)


# Called when a physics body exits this area
func _on_body_exited(body: Node3D):
	
	# 1. Check if the parent is a StaticBody3D
	var gravity_source = get_parent()
	if not gravity_source is StaticBody3D:
		return
	
	# 2. Check if the exited body is the player
	if body.has_method("remove_gravity_source"):
		# Tell the player to stop calculating gravity from this StaticBody3D source
		body.remove_gravity_source(gravity_source)

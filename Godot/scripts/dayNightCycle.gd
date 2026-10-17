extends Node

@export var day_speed: float = 0.01
@export var sun_light: DirectionalLight3D
@export var moon_light: DirectionalLight3D
@export var world_environment: WorldEnvironment

@export_group("Cycle Thresholds")
@export_range(0.0, 1.0) var day_start_height: float = 0.3

@export_subgroup("Sunrise (Morning)")
@export_range(-1.0, 0.5) var sunrise_start_height: float = -0.1
@export_range(0.0, 1.0) var sunrise_end_height: float = 0.3

@export_subgroup("Sunset (Evening)")
@export_range(0.0, 1.0) var sunset_start_height: float = 0.3
@export_range(-1.0, 0.5) var sunset_end_height: float = -0.1

@export_group("Sun Colors")
@export var sun_day_color: Color = Color("fff3cf")
@export var sun_sunset_color: Color = Color("ff7b3d")
@export var sun_night_color: Color = Color("b41e26")

@export_group("Moon Properties")
@export var moon_color: Color = Color("8bb1eb")
@export var moon_max_energy: float = 0.3

@export_group("Sky Top Colors")
@export var sky_top_color_day: Color = Color("3a86ff")
@export var sky_top_color_sunset: Color = Color("8338ec")
@export var sky_top_color_night: Color = Color("03071e")

@export_group("Sky Horizon Colors")
@export var sky_horizon_color_day: Color = Color("a1c4fd")
@export var sky_horizon_color_sunset: Color = Color("ff7b3d")
@export var sky_horizon_color_night: Color = Color("070a14")

@export_group("Ground Horizon Colors")
@export var ground_horizon_color_day: Color = Color("a1c4fd")
@export var ground_horizon_color_sunset: Color = Color("ff7b3d")
@export var ground_horizon_color_night: Color = Color("070a14")

var sky_material: ProceduralSkyMaterial

func _ready() -> void:
	if world_environment and world_environment.environment:
		var env = world_environment.environment
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			sky_material = env.sky.sky_material

func _process(delta: float) -> void:
	if not sun_light:
		return

	# Rotate sun around X-axis
	var rotation_angle = deg_to_rad(day_speed * delta * 360.0)
	sun_light.rotate_x(rotation_angle)

	# Synchronize moon so it sits directly opposite the sun
	if moon_light:
		moon_light.transform = sun_light.transform
		moon_light.rotate_x(PI) # 180 degrees offset

	# Sun height level (Y-component of light direction)
	var sun_height: float = sun_light.transform.basis.z.y
	var is_setting: bool = sun_light.transform.basis.z.z < 0.0

	var transition_factor: float = get_transition_factor(sun_height, is_setting)

	update_sun_properties(transition_factor)
	update_moon_properties(transition_factor)

	if sky_material:
		update_sky_properties(transition_factor)

func get_transition_factor(height: float, is_setting: bool) -> float:
	if is_setting:
		if height >= sunset_start_height:
			return 1.0
		elif height <= sunset_end_height:
			return 0.0
		else:
			return clamp((height - sunset_end_height) / (sunset_start_height - sunset_end_height), 0.0, 1.0)
	else:
		if height >= sunrise_end_height:
			return 1.0
		elif height <= sunrise_start_height:
			return 0.0
		else:
			return clamp((height - sunrise_start_height) / (sunrise_end_height - sunrise_start_height), 0.0, 1.0)

func update_sun_properties(t: float) -> void:
	if t >= 1.0:
		sun_light.light_color = sun_day_color
		sun_light.light_energy = 1.0
		sun_light.visible = true
	elif t <= 0.0:
		sun_light.light_color = sun_night_color
		sun_light.light_energy = 0.0
		sun_light.visible = false
	else:
		if t > 0.5:
			var day_blend = (t - 0.5) * 2.0
			sun_light.light_color = sun_sunset_color.lerp(sun_day_color, day_blend)
		else:
			var night_blend = t * 2.0
			sun_light.light_color = sun_night_color.lerp(sun_sunset_color, night_blend)
			
		sun_light.light_energy = lerp(0.0, 1.0, t)
		sun_light.visible = true

func update_moon_properties(t: float) -> void:
	if not moon_light:
		return

	# Invert transition factor: 0.0 = full night/full moon, 1.0 = full day/no moon
	var moon_t: float = 1.0 - t

	moon_light.light_color = moon_color
	moon_light.light_energy = lerp(0.0, moon_max_energy, moon_t)
	moon_light.visible = moon_light.light_energy > 0.01

func update_sky_properties(t: float) -> void:
	if t >= 1.0:
		sky_material.sky_top_color = sky_top_color_day
		sky_material.sky_horizon_color = sky_horizon_color_day
		sky_material.ground_horizon_color = ground_horizon_color_day
	elif t <= 0.0:
		sky_material.sky_top_color = sky_top_color_night
		sky_material.sky_horizon_color = sky_horizon_color_night
		sky_material.ground_horizon_color = ground_horizon_color_night
	else:
		if t > 0.5:
			var day_blend = (t - 0.5) * 2.0
			sky_material.sky_top_color = sky_top_color_sunset.lerp(sky_top_color_day, day_blend)
			sky_material.sky_horizon_color = sky_horizon_color_sunset.lerp(sky_horizon_color_day, day_blend)
			sky_material.ground_horizon_color = ground_horizon_color_sunset.lerp(ground_horizon_color_day, day_blend)
		else:
			var night_blend = t * 2.0
			sky_material.sky_top_color = sky_top_color_night.lerp(sky_top_color_sunset, night_blend)
			sky_material.sky_horizon_color = sky_horizon_color_night.lerp(sky_horizon_color_sunset, night_blend)
			sky_material.ground_horizon_color = ground_horizon_color_night.lerp(ground_horizon_color_sunset, night_blend)

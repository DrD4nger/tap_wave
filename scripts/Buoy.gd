# Buoy.gd
#
# Shared physics system for both regular buoys and flag buoys (gate markers).
# Creates floating navigation markers that bob naturally in the water.
#
# Key Responsibilities:
# - Realistic buoyancy simulation with wave interaction
# - Gentle wobbling animation for natural movement
# - Position anchoring to prevent drifting while allowing movement
# - Blinking light effect for visibility
# - Special handling for flag buoys (Y-axis rotation locked)
#
# Buoy Types:
# 1. **Regular Buoy**: Red navigation marker with full rotational freedom.
#    Wobbles and tilts naturally with waves.
#
# 2. **Flag Buoy**: Gate marker with directional flags. Y-axis rotation is
#    locked to maintain flag direction while still allowing tilt/roll.
#
# Physics Features:
# - **Anchored Position**: Buoys stay near their spawn point but can move
#   slightly with waves. Strong restore force prevents drifting.
# - **Tilt Limiting**: Maximum 30° tilt prevents capsizing
# - **Wave Response**: Follows Gerstner wave heights but ignores ripples
#   for more stable behavior
# - **Wobble System**: Subtle rotation forces create natural bobbing motion
#
# Visual Features:
# - **Blinking Light**: 2-second interval with smooth fade in/out
# - **Material Emission**: Dynamic emission energy for light pulsing
#
# Gate Integration:
# When used as flag buoys in gates, the Y-axis lock ensures flags always
# point in the intended direction while the buoy still responds naturally
# to water physics on other axes.

extends RigidBody3D

# Buoyancy parameters
@export var buoyancy_force : float = 35.0
@export var water_drag : float = 2.0
@export var water_angular_drag : float = 5.0
@export var stability_force : float = 50.0
@export var max_tilt_angle : float = 30.0  # Maximum tilt in degrees
@export var position_restore_force : float = 80.0
@export var wobble_force : float = 5.0
@export var wobble_frequency : float = 0.8
@export var rotation_wobble_force : float = 2.0
@export var rotation_wobble_frequency : float = 0.6

# Water reference
var water_material : ShaderMaterial = null
var anchor_position : Vector3  # Fixed XZ position

# Light blinking parameters
@export var blink_interval : float = 2.0
@export var blink_duration : float = 0.3

# Light node reference
@onready var light_mesh : MeshInstance3D = $Light
var light_material : StandardMaterial3D
var base_emission_energy : float = 2.0
var time_since_last_blink : float = 0.0

# Flag buoy detection
var is_flag_buoy : bool = false

func _ready():
	# Store anchor position
	anchor_position = global_position
	
	# Check if this is a flag buoy (has a Flag node)
	is_flag_buoy = has_node("Flag")
	
	# Get water material from main scene
	var water_mesh = get_node_or_null("/root/Main/Water/WaterMesh")
	if water_mesh:
		water_material = water_mesh.get_surface_override_material(0)
	
	# Get light material for blinking
	if light_mesh:
		light_material = light_mesh.get_surface_override_material(0)
		if light_material:
			base_emission_energy = light_material.emission_energy_multiplier
	
	# Position buoy on water surface
	await get_tree().process_frame
	position_on_water_surface()

func position_on_water_surface():
	# Calculate water height at anchor position
	var buoy_pos_2d = Vector2(anchor_position.x, anchor_position.z)
	var surface_height = get_water_height_at_position(buoy_pos_2d)
	
	# Position buoy so the float sits at water level
	global_position = Vector3(anchor_position.x, surface_height - 0.5, anchor_position.z)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func _physics_process(delta):
	if not water_material:
		return
	
	# Apply buoyancy forces
	apply_buoyancy_forces()
	
	# Add gentle wobble
	apply_wobble()
	
	# Keep buoy near anchor position (XZ only)
	restore_position()
	
	# Limit tilt angle
	limit_tilt()
	
	# Apply drag
	apply_drag()
	
	# Lock Y-axis rotation for flag buoys
	if is_flag_buoy:
		lock_y_rotation()

func _process(delta):
	# Handle light blinking
	handle_light_blinking(delta)

func handle_light_blinking(delta):
	if not light_material:
		return
	
	time_since_last_blink += delta
	
	# Check if it's time for a blink cycle
	if time_since_last_blink >= blink_interval:
		# Calculate blink phase (0 to 1 during blink duration)
		var blink_phase = (time_since_last_blink - blink_interval) / blink_duration
		
		if blink_phase <= 1.0:
			# During blink: fade in and out
			var blink_intensity = sin(blink_phase * PI)
			light_material.emission_energy_multiplier = base_emission_energy * (0.3 + blink_intensity * 0.7)
		else:
			# Blink finished, reset timer and return to dim state
			light_material.emission_energy_multiplier = base_emission_energy * 0.3
			time_since_last_blink = 0.0

func apply_buoyancy_forces():
	# Simple center buoyancy probe (adjusted for smaller buoy)
	var buoy_bottom = global_position + Vector3(0, -0.33, 0)  # Bottom of scaled float
	var water_height = get_water_height_at_position(Vector2(buoy_bottom.x, buoy_bottom.z))
	var depth = water_height - buoy_bottom.y
	
	if depth > 0:
		# Apply buoyancy force proportional to submersion
		var force = Vector3.UP * buoyancy_force * depth
		apply_central_force(force)
	
	# Apply surface alignment to keep buoy upright
	var up_vector = global_transform.basis.y
	var water_normal = Vector3.UP
	var alignment = up_vector.dot(water_normal)
	
	if alignment < 0.95:  # If buoy is tilted
		var correction_axis = up_vector.cross(water_normal).normalized()
		var correction_torque = correction_axis * stability_force * (1.0 - alignment)
		apply_torque(correction_torque)

func apply_wobble():
	# Add gentle rotational wobble (tilt and yaw only)
	var time = Time.get_ticks_msec() / 1000.0
	var rot_time = time * rotation_wobble_frequency
	var tilt_x = sin(rot_time * 1.1) * rotation_wobble_force  # Pitch wobble
	var tilt_z = cos(rot_time * 0.9) * rotation_wobble_force  # Roll wobble  
	var yaw_y = sin(rot_time * 0.7) * rotation_wobble_force * 0.5  # Gentle yaw wobble
	
	apply_torque(Vector3(tilt_x, yaw_y, tilt_z))

func restore_position():
	# Calculate force to pull buoy back to anchor position (XZ only)
	var position_offset = Vector3(
		global_position.x - anchor_position.x,
		0,  # Don't constrain Y
		global_position.z - anchor_position.z
	)
	
	if position_offset.length() > 0.1:  # Small deadzone since no positional wobble
		var restore_force = -position_offset * position_restore_force
		apply_central_force(restore_force)

func limit_tilt():
	# Check if buoy is tilted too much
	var up_vector = global_transform.basis.y
	var tilt_angle = rad_to_deg(acos(up_vector.dot(Vector3.UP)))
	
	if tilt_angle > max_tilt_angle:
		# Apply strong corrective torque
		var correction_axis = up_vector.cross(Vector3.UP).normalized()
		var excess_tilt = tilt_angle - max_tilt_angle
		var correction_torque = correction_axis * stability_force * excess_tilt * 0.1
		apply_torque(correction_torque)

func apply_drag():
	# Apply drag forces
	var velocity = linear_velocity
	var drag_force = -velocity * water_drag
	apply_central_force(drag_force)
	
	# Apply angular drag
	var angular_drag_torque = -angular_velocity * water_angular_drag
	apply_torque(angular_drag_torque)

func lock_y_rotation():
	# Lock Y-axis rotation by zeroing out Y-axis angular velocity
	var current_angular_velocity = angular_velocity
	angular_velocity = Vector3(current_angular_velocity.x, 0, current_angular_velocity.z)

func get_water_height_at_position(pos: Vector2) -> float:
	if not water_material:
		return 0.0
	
	# Get shader parameters with null checks
	var wave_speed = water_material.get_shader_parameter("wave_speed")
	if wave_speed == null: wave_speed = 0.4
	var wave_amplitude = water_material.get_shader_parameter("wave_amplitude")
	if wave_amplitude == null: wave_amplitude = 0.2
	var wave_length = water_material.get_shader_parameter("wave_length")
	if wave_length == null: wave_length = 4.0
	var wave_direction = water_material.get_shader_parameter("wave_direction")
	if wave_direction == null: wave_direction = Vector2(1.0, 0.0)
	var wave_steepness = water_material.get_shader_parameter("wave_steepness")
	if wave_steepness == null: wave_steepness = 0.5
	
	var wave2_amplitude = water_material.get_shader_parameter("wave2_amplitude")
	if wave2_amplitude == null: wave2_amplitude = 0.15
	var wave2_length = water_material.get_shader_parameter("wave2_length")
	if wave2_length == null: wave2_length = 2.5
	var wave2_direction = water_material.get_shader_parameter("wave2_direction")
	if wave2_direction == null: wave2_direction = Vector2(0.3, 1.0)
	var wave2_speed = water_material.get_shader_parameter("wave2_speed")
	if wave2_speed == null: wave2_speed = 0.6
	
	var swell_amplitude = water_material.get_shader_parameter("swell_amplitude")
	if swell_amplitude == null: swell_amplitude = 0.1
	var swell_length = water_material.get_shader_parameter("swell_length")
	if swell_length == null: swell_length = 8.0
	var swell_speed = water_material.get_shader_parameter("swell_speed")
	if swell_speed == null: swell_speed = 0.2
	
	var time = Time.get_ticks_msec() / 1000.0
	
	# Calculate Gerstner wave heights (ignoring ripples for buoy stability)
	var height = 0.0
	
	# Wave 1
	height += calculate_gerstner_wave(pos, wave_amplitude, wave_length, wave_direction, wave_speed * time, wave_steepness)
	
	# Wave 2
	height += calculate_gerstner_wave(pos, wave2_amplitude, wave2_length, wave2_direction, wave2_speed * time, wave_steepness * 0.7)
	
	# Swell
	height += calculate_gerstner_wave(pos, swell_amplitude, swell_length, Vector2(0.7, 0.7), swell_speed * time, 0.2)
	
	return height

func calculate_gerstner_wave(pos: Vector2, amplitude: float, wavelength: float, direction: Vector2, phase: float, _steepness: float) -> float:
	var k = TAU / wavelength  # wave number
	var d = direction.normalized()
	var f = k * (d.dot(pos) - sqrt(9.8 / k) * phase)
	
	return amplitude * cos(f)

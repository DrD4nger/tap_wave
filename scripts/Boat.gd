# Boat.gd
#
# Complete boat physics and movement system implementing realistic water interaction.
# This is the player's controllable vessel that responds to water physics, ripples,
# and boundary constraints.
#
# Key Responsibilities:
# - Multi-point buoyancy simulation using 8 probe points for realistic floating
# - Dynamic response to both ambient waves and player-created ripples
# - Visual hull rotation that follows movement direction
# - Boundary detection and bouncing to keep boat in play area
# - Surface alignment to make boat tilt with wave slopes
#
# Physics Systems:
# 1. **Buoyancy**: 8 probe points around hull calculate water depth and apply
#    upward forces. Deeper probes = stronger force. Above-water probes apply
#    slight downward force for stability.
# 
# 2. **Wave Interaction**: Samples Gerstner waves from water shader to calculate
#    accurate water height at any position. Boat rides these waves naturally.
#
# 3. **Ripple Response**: When player taps, ripple wavefronts push boat away.
#    Force decreases with ripple age and distance from wavefront.
#
# 4. **Drag & Stability**: Water drag slows movement, angular drag prevents
#    spinning, stability torque keeps boat upright.
#
# 5. **Boundary System**: Invisible walls at screen edges with strong bounce
#    forces. Uses isometric space calculations for correct 45° camera bounds.
#
# Game Flow Integration:
# - Receives ripple data from WaterController via shader parameters
# - Applies physics forces to create natural boat movement
# - Visual rotation follows velocity for intuitive direction feedback
# - Constrained to camera view to prevent getting lost off-screen

extends RigidBody3D

# Buoyancy parameters
@export var buoyancy_force : float = 15.0
@export var water_drag : float = 0.75
@export var water_angular_drag : float = 3.0
@export var ripple_push_force : float = 1500.0
@export var surface_alignment_force : float = 2.0
@export var stability_force : float = 70.0
@export var water_level : float = 0.35  # Base water level

# Movement parameters
@export var directional_push_force : float = 120.0  # Force pushing away from click location
@export var visual_turn_rate : float = 0.75  # How fast boat mesh rotates to face movement direction

# Camera bounds
@export var bound_margin : float = 3.0  # How far from camera edge boat can go
@export var boundary_bounce_force : float = 1500.0  # Force for bouncing off boundaries

# References to buoyancy probe points
@onready var probes = [
	$BuoyancyProbe1,  # Bow (front center)
	$BuoyancyProbe2,  # Front starboard quarter
	$BuoyancyProbe3,  # Front port quarter  
	$BuoyancyProbe4,  # Mid starboard (right side)
	$BuoyancyProbe5,  # Mid port (left side)
	$BuoyancyProbe6,  # Rear starboard quarter
	$BuoyancyProbe7,  # Rear port quarter
	$BuoyancyProbe8   # Stern (rear center)
]

# Water shader reference (will be set by main scene)
var water_material : ShaderMaterial = null
var water_transform : Transform3D
var camera : Camera3D = null

# Reference to the visual hull that we'll rotate
@onready var hull_visual : Node3D = $Hull

func _ready():
	# Get water material from parent scene
	var water_mesh = get_node_or_null("/root/Main/Water/WaterMesh")
	if water_mesh:
		water_material = water_mesh.get_surface_override_material(0)
		water_transform = water_mesh.global_transform
	
	# Get camera reference
	camera = get_node_or_null("/root/Main/Camera3D")
	
	# Wait a frame for everything to initialize, then position boat on water surface
	await get_tree().process_frame
	position_boat_on_water_surface()

func position_boat_on_water_surface():
	# Calculate the water height at boat's current XZ position
	var boat_pos_2d = Vector2(global_position.x, global_position.z)
	var surface_height = get_water_height_at_position(boat_pos_2d)
	
	# Position boat just above water surface
	global_position.y = surface_height + 0.2
	
	# Reset velocity to prevent initial falling
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func _physics_process(delta):
	if not water_material:
		return
		
	# Calculate water heights at all probe points
	var probe_heights = []
	var probe_positions = []
	var total_depth = 0.0
	var underwater_probes = 0
	
	for probe in probes:
		var probe_pos = probe.global_position
		var water_height = get_water_height_at_position(Vector2(probe_pos.x, probe_pos.z))
		var depth = water_height - probe_pos.y
		
		probe_heights.append(water_height)
		probe_positions.append(probe_pos)
		
		if depth > 0:
			# Apply strong buoyancy force proportional to depth
			var force = Vector3.UP * (buoyancy_force / 2) * depth
			apply_force(force, probe.position)
			
			total_depth += depth
			underwater_probes += 1
		else:
			# If probe is above water, apply downward force to keep boat stable on surface
			var above_water = -depth
			if above_water < 1.5:  # Apply within reasonable range
				var downward_force = Vector3.DOWN * buoyancy_force * above_water * 0.3
				apply_force(downward_force, probe.position)
	
	# Apply surface alignment (make boat follow water surface angle)
	apply_surface_alignment(probe_heights, probe_positions, delta)
	
	# Apply drag and stability
	if underwater_probes > 0:
		var avg_depth = total_depth / underwater_probes
		
		# Apply drag proportional to how submerged we are
		var velocity = linear_velocity
		var drag_force = -velocity * water_drag * avg_depth
		apply_central_force(drag_force)
		
		# Apply angular drag
		var angular_drag_torque = -angular_velocity * water_angular_drag * avg_depth
		apply_torque(angular_drag_torque)
		
		# Apply stability force to keep boat upright
		var up_vector = global_transform.basis.y
		var water_normal = Vector3.UP
		var alignment = up_vector.dot(water_normal)
		
		if alignment < 0.95:  # If boat is tilted
			var correction_axis = up_vector.cross(water_normal).normalized()
			var correction_torque = correction_axis * stability_force * (1.0 - alignment)
			apply_torque(correction_torque)
	
	
	# Apply ripple push forces
	apply_ripple_forces(delta)
	
	# Constrain to camera bounds
	constrain_to_camera_bounds()


func apply_surface_alignment(probe_heights: Array, _probe_positions: Array, _delta):
	if probe_heights.size() < 8:
		return
		
	# Calculate the slope of the water surface using the round-bottom hull probe points
	# Probe layout: 0=bow, 1=front right, 2=front left, 3=starboard beam, 4=port beam, 5=rear right, 6=rear left, 7=stern
	
	# Front/back tilt (pitch) - compare bow/front vs stern/rear sections  
	var front_height = (probe_heights[0] + probe_heights[1] + probe_heights[2]) / 3.0  # Bow section average
	var back_height = (probe_heights[5] + probe_heights[6] + probe_heights[7]) / 3.0   # Stern section average
	var pitch_diff = front_height - back_height
	
	# Left/right tilt (roll) - compare starboard vs port sections
	var right_height = (probe_heights[1] + probe_heights[3] + probe_heights[5]) / 3.0  # Starboard section average
	var left_height = (probe_heights[2] + probe_heights[4] + probe_heights[6]) / 3.0   # Port section average
	var roll_diff = right_height - left_height
	
	# Apply torque to align boat with water surface
	var pitch_torque = global_transform.basis.x * pitch_diff * surface_alignment_force
	var roll_torque = global_transform.basis.z * roll_diff * surface_alignment_force
	
	apply_torque(pitch_torque)
	apply_torque(roll_torque)

func apply_ripple_forces(delta):
	if not water_material:
		return
		
	var boat_pos = Vector2(global_position.x, global_position.z)
	var ripple_positions = water_material.get_shader_parameter("ripple_positions")
	var ripple_times = water_material.get_shader_parameter("ripple_times")
	var ripple_speed = water_material.get_shader_parameter("ripple_speed")
	var ripple_wavelength = water_material.get_shader_parameter("ripple_wavelength")
	var ripple_amplitude = water_material.get_shader_parameter("ripple_amplitude")
	
	if not ripple_positions or not ripple_times:
		return
	
	var total_directional_force = Vector2.ZERO
	
	for i in range(10):
		var ripple_pos = Vector2(ripple_positions[i * 2], ripple_positions[i * 2 + 1])
		var ripple_age = ripple_times[i]
		
		if ripple_age > 0.0 and ripple_age < 4.0:  # Only young ripples push
			var distance = boat_pos.distance_to(ripple_pos)
			var wave_distance = ripple_age * ripple_speed
			
			# Check if boat is near the wavefront
			var wavefront_width = ripple_wavelength * 2.0
			if abs(distance - wave_distance) < wavefront_width:
				# Calculate push direction (away from ripple center)
				var push_dir = (boat_pos - ripple_pos).normalized()
				
				# Calculate force based on proximity to wavefront and age
				var proximity = 1.0 - abs(distance - wave_distance) / wavefront_width
				var age_factor = 1.0 - ripple_age / 4.0
				var force_magnitude = ripple_push_force * proximity * age_factor * ripple_amplitude
				
				# Apply the force
				var push_force = Vector3(push_dir.x, 0, push_dir.y) * force_magnitude * delta
				apply_central_force(push_force)
			
			# Directional movement away from click location
			var move_direction = (boat_pos - ripple_pos).normalized()
			var age_factor = 1.0 - ripple_age / 4.0
			var directional_force = move_direction * directional_push_force * age_factor * delta
			total_directional_force += directional_force
	
	# Apply accumulated directional force
	if total_directional_force.length() > 0.01:
		var force_3d = Vector3(total_directional_force.x, 0, total_directional_force.y)
		apply_central_force(force_3d)
	
	# Rotate visual hull to face movement direction
	rotate_hull_towards_velocity(delta)

func rotate_hull_towards_velocity(delta):
	if not hull_visual:
		return
		
	# Only rotate if moving at reasonable speed
	var velocity_2d = Vector2(linear_velocity.x, linear_velocity.z)
	if velocity_2d.length() < 0.5:
		return
	
	# Convert velocity to 3D direction
	var velocity_3d = Vector3(velocity_2d.x, 0, velocity_2d.y).normalized()
	
	# Simply rotate so the front of the boat points in the movement direction
	# Add PI/2 to rotate 90 degrees so front points forward instead of side
	var target_angle = atan2(velocity_3d.x, velocity_3d.z) + PI/2
	
	# Get current hull rotation
	var current_angle = hull_visual.rotation.y
	
	# Calculate shortest angle difference
	var angle_diff = target_angle - current_angle
	while angle_diff > PI:
		angle_diff -= TAU
	while angle_diff < -PI:
		angle_diff += TAU
	
	# Apply gradual rotation only to the visual hull
	if abs(angle_diff) > 0.0005:  # Only if difference is significant
		var rotation_step = sign(angle_diff) * min(abs(angle_diff), visual_turn_rate * delta)
		hull_visual.rotation.y += rotation_step

func constrain_to_camera_bounds():
	if not camera:
		return
		
	# Get camera frustum bounds at water level
	var camera_size = camera.size
	var aspect_ratio = 720.0 / 1280.0  # Portrait mode
	
	# Calculate bounds based on isometric camera angle (45 degrees rotated)
	# Different margins for width vs height to optimize usable space
	var width_margin = bound_margin * 0.35  # Reduced margin for left/right (half of 0.7)
	var height_margin = bound_margin * 0.05  # Very small margin for top/bottom
	
	var half_width = camera_size * aspect_ratio * 0.5 - width_margin
	var half_height = camera_size * 0.5 - height_margin
	
	# For isometric view, we need to rotate the boundaries by -45 degrees
	# Transform boat position to isometric space (reversed rotation)
	var boat_pos = global_position
	var iso_x = (boat_pos.x - boat_pos.z) / sqrt(2.0)  # Rotated X in isometric space
	var iso_z = (boat_pos.x + boat_pos.z) / sqrt(2.0)  # Rotated Z in isometric space
	
	# Check for boundary collisions and apply bounce forces
	var bounce_force = Vector3.ZERO
	var hit_boundary = false
	
	# Check X boundary (left/right in isometric space)
	if iso_x < -half_width:
		iso_x = -half_width
		bounce_force.x += boundary_bounce_force  # Bounce right
		hit_boundary = true
	elif iso_x > half_width:
		iso_x = half_width
		bounce_force.x -= boundary_bounce_force  # Bounce left
		hit_boundary = true
	
	# Check Z boundary (top/bottom in isometric space)
	if iso_z < -half_height:
		iso_z = -half_height
		bounce_force.z += boundary_bounce_force  # Bounce forward
		hit_boundary = true
	elif iso_z > half_height:
		iso_z = half_height
		bounce_force.z -= boundary_bounce_force  # Bounce backward
		hit_boundary = true
	
	# Transform back to world space
	var new_x = (iso_x + iso_z) / sqrt(2.0)
	var new_z = (iso_z - iso_x) / sqrt(2.0)
	
	var new_pos = Vector3(new_x, boat_pos.y, new_z)
	global_position = new_pos
	
	# Apply bounce force if we hit a boundary
	if hit_boundary:
		# Transform bounce force from isometric space to world space
		var world_bounce_x = (bounce_force.x + bounce_force.z) / sqrt(2.0)
		var world_bounce_z = (bounce_force.z - bounce_force.x) / sqrt(2.0)
		var world_bounce_force = Vector3(world_bounce_x, 0, world_bounce_z)
		
		# Apply the bounce force
		apply_central_force(world_bounce_force)

func get_water_height_at_position(pos: Vector2) -> float:
	if not water_material:
		return water_level
		
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
	
	# Start with base water level
	var height = water_level
	
	# Calculate Gerstner wave heights
	# Wave 1
	height += calculate_gerstner_wave(pos, wave_amplitude, wave_length, wave_direction, wave_speed * time, wave_steepness)
	
	# Wave 2
	height += calculate_gerstner_wave(pos, wave2_amplitude, wave2_length, wave2_direction, wave2_speed * time, wave_steepness * 0.7)
	
	# Swell
	height += calculate_gerstner_wave(pos, swell_amplitude, swell_length, Vector2(0.7, 0.7), swell_speed * time, 0.2)
	
	# Add ripple contributions
	height += get_ripple_height_at_position(pos)
	
	return height

func calculate_gerstner_wave(pos: Vector2, amplitude: float, wavelength: float, direction: Vector2, phase: float, _steepness: float) -> float:
	var k = TAU / wavelength  # wave number
	var d = direction.normalized()
	var f = k * (d.dot(pos) - sqrt(9.8 / k) * phase)
	
	return amplitude * cos(f)

func get_ripple_height_at_position(pos: Vector2) -> float:
	if not water_material:
		return 0.0
		
	var ripple_positions = water_material.get_shader_parameter("ripple_positions")
	var ripple_times = water_material.get_shader_parameter("ripple_times")
	var ripple_amplitude = water_material.get_shader_parameter("ripple_amplitude")
	if ripple_amplitude == null: ripple_amplitude = 0.7
	var ripple_speed = water_material.get_shader_parameter("ripple_speed")
	if ripple_speed == null: ripple_speed = 4.0
	var ripple_wavelength = water_material.get_shader_parameter("ripple_wavelength")
	if ripple_wavelength == null: ripple_wavelength = 3.5
	var ripple_decay = water_material.get_shader_parameter("ripple_decay")
	if ripple_decay == null: ripple_decay = 1.0
	
	if not ripple_positions or not ripple_times:
		return 0.0
	
	var total_height = 0.0
	
	for i in range(min(10, ripple_positions.size() / 2)):  # Ensure we don't go out of bounds
		if i * 2 + 1 >= ripple_positions.size() or i >= ripple_times.size():
			break
			
		var ripple_pos = Vector2(ripple_positions[i * 2], ripple_positions[i * 2 + 1])
		var ripple_age = ripple_times[i]
		
		if ripple_age > 0.0 and ripple_age < 8.0:
			var distance = pos.distance_to(ripple_pos)
			var wave_distance = ripple_age * ripple_speed
			
			# Calculate ripple height (matching shader logic)
			var primary_wave = sin((distance - wave_distance) * TAU / ripple_wavelength)
			var secondary_wave = sin((distance - wave_distance - ripple_wavelength * 0.3) * TAU / ripple_wavelength) * 0.5
			var wave = primary_wave + secondary_wave
			
			var time_decay = exp(-ripple_age * ripple_decay * 0.5)
			var distance_decay = exp(-abs(distance - wave_distance) * 0.2)
			
			var wavefront_width = ripple_wavelength * 1.5
			var in_wavefront = smoothstep(wavefront_width, 0.0, abs(distance - wave_distance))
			
			# Shape the wave
			wave = pow(max(0.0, wave), 0.7) * sign(wave)
			
			total_height += wave * time_decay * distance_decay * in_wavefront * ripple_amplitude
	
	return total_height

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

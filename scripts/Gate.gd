# Gate.gd
#
# Directional gate system that challenges players to navigate through from the correct side.
# Gates consist of two flag buoys that form a checkpoint the boat must pass through.
#
# Key Responsibilities:
# - Detect boat approach and determine which side it's coming from
# - Track boat movement through the gate area
# - Validate correct directional passage
# - Provide visual feedback (lights change from red to green on success)
# - Integrate with level progression system
#
# Gate Mechanics:
# 1. **Detection Zone**: 1.75 unit radius around gate center triggers tracking
# 2. **Approach Detection**: When boat enters zone, system checks which side
#    based on dot product with gate's forward direction
# 3. **Crossing Validation**: Monitors when boat crosses the imaginary line
#    between the two buoys
# 4. **Success Criteria**: Boat must approach from behind gate (negative side)
#    and pass through to front (positive side)
#
# Visual Feedback:
# - **Red Lights**: Default state indicating gate not passed
# - **Green Lights**: Success state when passed correctly
# - **Yellow Flags**: Always visible to show intended direction
#
# Level Integration:
# - Registers with LevelManager on creation
# - Emits signals for successful/failed passages
# - Triggers completion check when passed correctly
# - Can be reset for replay functionality
#
# Technical Details:
# - Uses global transform for accurate direction in rotated gates
# - Creates unique material instances to prevent light color conflicts
# - Maintains gate geometry between two buoy anchor points
# - Tracks state to prevent multiple crossing detections

extends Node3D

# Gate parameters
@export var gate_width : float = 2.0  # Distance between buoys
@export var detection_radius : float = 1.75  # Radius for tracking boat approach
@export var gate_direction : Vector3 = Vector3(0, 0, 1)  # Direction boat should travel through gate

# Internal tracking
var boat : RigidBody3D = null
var boat_was_in_detection_zone : bool = false
var boat_approach_side : int = 0  # -1 = wrong side, 0 = unknown, 1 = correct side
var gate_crossed : bool = false

# Gate line (between the two buoys)
var gate_center : Vector3
var gate_line_start : Vector3
var gate_line_end : Vector3

# References to buoys
@onready var left_buoy : RigidBody3D = $LeftBuoy
@onready var right_buoy : RigidBody3D = $RightBuoy

signal gate_passed_successfully
signal gate_passed_wrong_direction

var has_passed : bool = false

func _ready():
	# Find the boat in the scene
	boat = get_node_or_null("/root/Main/Boat")
	
	# Calculate gate geometry
	update_gate_geometry()
	
	# Register with LevelManager
	if LevelManager:
		LevelManager.register_gate(self)
	
	# Flags are already positioned correctly in the scene, no need to adjust them

func update_gate_geometry():
	# Calculate gate center and line endpoints
	gate_center = global_position
	var half_width = gate_width * 0.5
	
	# Use the actual transform's forward direction instead of export variable
	var actual_gate_direction = global_transform.basis.z
	
	# Gate line is perpendicular to gate direction
	var perpendicular = Vector3(-actual_gate_direction.z, 0, actual_gate_direction.x).normalized()
	gate_line_start = gate_center - perpendicular * half_width
	gate_line_end = gate_center + perpendicular * half_width
	
	# Position buoys at line endpoints
	if left_buoy:
		left_buoy.anchor_position = gate_line_start
	if right_buoy:
		right_buoy.anchor_position = gate_line_end

# Function removed - flags maintain their scene-configured positions

func _process(_delta):
	if not boat:
		return
	
	check_boat_position()

func check_boat_position():
	var boat_pos = boat.global_position
	var distance_to_gate = gate_center.distance_to(boat_pos)
	
	# Check if boat is in detection radius
	var in_detection_zone = distance_to_gate <= detection_radius
	
	if in_detection_zone and not boat_was_in_detection_zone:
		# Boat just entered detection zone - determine approach side
		determine_approach_side(boat_pos)
		boat_was_in_detection_zone = true
		gate_crossed = false
	elif not in_detection_zone and boat_was_in_detection_zone:
		# Boat left detection zone - reset tracking
		boat_was_in_detection_zone = false
		boat_approach_side = 0
		gate_crossed = false
	
	# Check for gate crossing
	if in_detection_zone and not gate_crossed:
		check_gate_crossing(boat_pos)

func determine_approach_side(boat_pos: Vector3):
	# Project boat position onto gate direction to determine which side
	var to_boat = boat_pos - gate_center
	var actual_gate_direction = global_transform.basis.z
	var projection = to_boat.dot(actual_gate_direction)
	
	if projection < -1.0:  # Boat approaching from correct side (behind gate)
		boat_approach_side = 1
		print("Boat approaching from correct side")
	elif projection > 1.0:  # Boat approaching from wrong side (ahead of gate)
		boat_approach_side = -1
		print("Boat approaching from wrong side")
	else:
		boat_approach_side = 0  # Boat too close to gate line to determine side

func check_gate_crossing(boat_pos: Vector3):
	# Check if boat has crossed the gate line
	var crossed = has_crossed_gate_line(boat_pos)
	
	if crossed and not gate_crossed:
		gate_crossed = true
		
		if boat_approach_side == 1:
			# Successful gate passage
			print("Gate passed successfully!")
			has_passed = true
			change_lights_to_green()
			gate_passed_successfully.emit()
			if LevelManager:
				LevelManager.check_completion()
		else:
			# Wrong direction passage
			print("Gate passed in wrong direction!")
			gate_passed_wrong_direction.emit()

func has_crossed_gate_line(boat_pos: Vector3) -> bool:
	# Check if boat is on the opposite side of the gate line from where it started
	var to_boat = boat_pos - gate_center
	var actual_gate_direction = global_transform.basis.z
	var projection = to_boat.dot(actual_gate_direction)
	
	# If boat approached from correct side (negative projection) and is now positive, it crossed
	# If boat approached from wrong side (positive projection) and is now negative, it crossed
	if boat_approach_side == 1 and projection > 0.5:
		return true
	elif boat_approach_side == -1 and projection < -0.5:
		return true
	
	return false

func is_boat_between_buoys(boat_pos: Vector3) -> bool:
	# Check if boat is laterally between the two buoys
	var actual_gate_direction = global_transform.basis.z
	var gate_perpendicular = Vector3(-actual_gate_direction.z, 0, actual_gate_direction.x).normalized()
	var to_boat = boat_pos - gate_center
	var lateral_distance = abs(to_boat.dot(gate_perpendicular))
	
	return lateral_distance <= gate_width * 0.5

func change_lights_to_green():
	# Change both buoy lights to green when gate is passed successfully
	change_buoy_light_color(left_buoy, Color.GREEN)
	change_buoy_light_color(right_buoy, Color.GREEN)

func change_buoy_light_color(buoy: RigidBody3D, color: Color):
	if not buoy:
		return
	
	var light_node = buoy.get_node_or_null("Light")
	if not light_node:
		return
	
	# Create a unique material instance for this specific gate's buoy
	var light_material = light_node.get_surface_override_material(0) as StandardMaterial3D
	if not light_material:
		# Get the original material and create a copy
		light_material = light_node.mesh.surface_get_material(0) as StandardMaterial3D
		if light_material:
			light_material = light_material.duplicate()
	else:
		# If we already have an override, duplicate it to ensure uniqueness
		light_material = light_material.duplicate()
	
	if light_material:
		# Change both the albedo and emission colors
		light_material.albedo_color = color
		light_material.emission = color
		# Apply the unique material to this specific light
		light_node.set_surface_override_material(0, light_material)

func reset():
	has_passed = false
	gate_crossed = false
	boat_approach_side = 0
	boat_was_in_detection_zone = false
	# Reset lights to red with unique materials
	change_buoy_light_color(left_buoy, Color.RED)
	change_buoy_light_color(right_buoy, Color.RED)

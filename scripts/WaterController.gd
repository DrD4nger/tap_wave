# WaterController.gd
#
# Core water interaction system that handles player input and ripple creation.
# This script manages the primary game mechanic where players tap/click on the
# water surface to create ripples that push the boat.
#
# Key Responsibilities:
# - Detects mouse/touch input and converts screen coordinates to world position
# - Creates ripples at tap location using ray casting to find water intersection
# - Manages ripple lifecycle with a ring buffer for performance (max 10 ripples)
# - Enforces 1-second cooldown between taps to prevent spam
# - Updates water shader with ripple data for visual effects
#
# Game Logic Flow:
# 1. Player taps/clicks screen -> _input() receives event
# 2. Ray cast from camera through tap point to find water plane (Y=0)
# 3. If cooldown passed, create new ripple at intersection point
# 4. Store ripple data (position, time, strength) in circular buffer
# 5. Update shader parameters every frame for animated ripple expansion
# 6. Boat physics script reads ripple data to apply push forces
#
# The ripple system uses a fixed-size array to avoid memory allocation during
# gameplay. Old ripples are automatically replaced when the array is full.

extends Node3D

# Maximum number of simultaneous ripples
const MAX_RIPPLES = 10

# Ripple data structure
var ripples = []

# Click cooldown
var last_click_time = 0.0
const CLICK_COOLDOWN = 1.0  # 1 second cooldown

# References
@onready var camera = $Camera3D
@onready var water_mesh = $Water/WaterMesh

func _ready():
	# Initialize ripple array
	for i in range(MAX_RIPPLES):
		ripples.append({
			"position": Vector2.ZERO,
			"time": -999.0,
			"strength": 0.0
		})

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		_create_ripple_at_mouse(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_create_ripple_at_mouse(event.position)

func _create_ripple_at_mouse(screen_pos):
	# Check cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_click_time < CLICK_COOLDOWN:
		return  # Still in cooldown period
	
	# Cast a ray from the camera through the click position
	var from = camera.project_ray_origin(screen_pos)
	var ray_direction = camera.project_ray_normal(screen_pos)
	
	# Since water has no collision, we need to calculate where the ray intersects Y=0 plane
	# Ray equation: point = from + t * direction
	# We want Y = 0, so: from.y + t * direction.y = 0
	# Therefore: t = -from.y / direction.y
	
	if abs(ray_direction.y) > 0.001:  # Avoid division by zero
		var t = -from.y / ray_direction.y
		if t > 0:  # Only if ray points toward water
			var intersection_point = from + ray_direction * t
			_add_ripple(Vector2(intersection_point.x, intersection_point.z))
			last_click_time = current_time  # Update last click time

func _add_ripple(ripple_pos: Vector2):
	# Find the oldest ripple slot
	var oldest_index = 0
	var oldest_time = ripples[0]["time"]
	
	for i in range(MAX_RIPPLES):
		if ripples[i]["time"] < oldest_time:
			oldest_time = ripples[i]["time"]
			oldest_index = i
	
	# Add new ripple
	ripples[oldest_index] = {
		"position": ripple_pos,
		"time": Time.get_ticks_msec() / 1000.0,
		"strength": 1.0
	}
	
	# Update shader parameters
	_update_shader_ripples()

func _update_shader_ripples():
	var shader_material = water_mesh.get_surface_override_material(0)
	if not shader_material:
		return
	
	# Convert ripple data to shader format
	var positions = PackedFloat32Array()
	var times = PackedFloat32Array()
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for i in range(MAX_RIPPLES):
		var ripple = ripples[i]
		positions.append(ripple["position"].x)
		positions.append(ripple["position"].y)
		
		# Calculate age of ripple
		var age = current_time - ripple["time"]
		times.append(age)
	
	# Pass to shader as arrays
	shader_material.set_shader_parameter("ripple_positions", positions)
	shader_material.set_shader_parameter("ripple_times", times)

func _process(_delta):
	# Update ripple times continuously
	_update_shader_ripples()

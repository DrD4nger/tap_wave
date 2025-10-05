# Dock.gd
#
# This is a placeholder mesh to represent the end goal of a level while
# building out the game.
#
# Level goal and completion system representing the harbor/destination.
# The dock serves as the final objective that becomes active after all
# gates are successfully navigated.
#
# Key Responsibilities:
# - Visual representation of level goal
# - Activation based on gate completion status
# - Boat detection for win condition
# - Visual feedback for active/inactive states
# - Level completion celebration
#
# Activation System:
# 1. **Inactive State**: Gray/brown appearance, no light
# 2. **Active State**: Glowing green light, emissive materials
# 3. **Completion**: Pulsing animation and level complete signal
#
# Visual States:
# - **Inactive Material**: Dark wood appearance (0.4, 0.3, 0.2)
# - **Active Material**: Lighter with green emission glow
# - **Activation Light**: Green beacon visible when active
#
# Level Integration:
# - Registers with LevelManager on startup
# - Checks completion status when gates are passed
# - Detects boat arrival via Area3D collision
# - Emits level_completed signal for game flow
#
# Win Condition Logic:
# - All gates must be passed (checked via LevelManager)
# - Boat must be within dock area
# - Both conditions trigger level completion
#
# Visual Feedback:
# - Light appears when dock activates
# - Platform materials change to show active state
# - Completion triggers celebratory light pulse animation
#
# The dock acts as both a visual goal and functional endpoint,
# providing clear feedback about level progression and completion.

extends Node3D

signal level_completed

@onready var activation_light = $ActivationLight
@onready var area = $Area3D
@onready var platform = $Platform

# Level completion
var is_active = false
var boat_at_dock = false
var inactive_material : StandardMaterial3D
var active_material : StandardMaterial3D

func _ready():
	if LevelManager:
		LevelManager.register_dock(self)
	
	create_materials()
	update_visual_state()
	
	if not area.body_entered.is_connected(_on_boat_entered):
		area.body_entered.connect(_on_boat_entered)
	if not area.body_exited.is_connected(_on_boat_exited):
		area.body_exited.connect(_on_boat_exited)

func create_materials():
	inactive_material = StandardMaterial3D.new()
	inactive_material.albedo_color = Color(0.4, 0.3, 0.2, 1)
	
	active_material = StandardMaterial3D.new()
	active_material.albedo_color = Color(0.6, 0.5, 0.3, 1)
	active_material.emission_enabled = true
	active_material.emission = Color(0.2, 0.5, 0.2, 1)
	active_material.emission_energy = 0.3

func check_level_completion():
	var all_gates_completed = false
	if LevelManager:
		all_gates_completed = LevelManager.are_all_gates_completed()
	
	if all_gates_completed != is_active:
		is_active = all_gates_completed
		update_visual_state()
	
	if is_active and boat_at_dock:
		complete_level()

func update_visual_state():
	if activation_light:
		activation_light.visible = is_active
		
		if is_active:
			var material = activation_light.get_surface_override_material(0)
			if not material:
				material = activation_light.mesh.surface_get_material(0)
			if material:
				material.emission_energy = 2.0
				material.albedo_color = Color(0, 1, 0, 1)
				material.emission = Color(0, 1, 0, 1)
	
	# Update platform materials
	if platform:
		for child in platform.get_children():
			if child is MeshInstance3D:
				child.set_surface_override_material(0, active_material if is_active else inactive_material)

func _on_boat_entered(body):
	if body.name == "Boat":
		boat_at_dock = true
		check_level_completion()

func _on_boat_exited(body):
	if body.name == "Boat":
		boat_at_dock = false

func complete_level():
	print("Level Completed!")
	level_completed.emit()
	
	if activation_light:
		var tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(activation_light, "scale", Vector3(1, 1, 1), 0.2)
		tween.tween_property(activation_light, "scale", Vector3(0.5, 0.5, 0.5), 0.2)

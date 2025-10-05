# LevelManager.gd
#
# Central level progression and completion tracking system.
# Manages the relationship between gates and the dock to determine when
# a level is complete.
#
# Key Responsibilities:
# - Track all gates in the current level
# - Monitor gate completion status
# - Activate dock when all gates are passed
# - Handle level reset functionality
# - Emit signals for level completion events
#
# Level Flow:
# 1. **Registration Phase**: Gates and dock register themselves on ready
# 2. **Gameplay Phase**: Player navigates through gates
# 3. **Completion Check**: After each gate pass, system checks if all complete
# 4. **Dock Activation**: When all gates passed, dock becomes active
# 5. **Win Condition**: Player reaches active dock to complete level
#
# System Design:
# - **Singleton Pattern**: Accessible globally as autoload
# - **Event-Driven**: Uses signals to communicate completion
# - **Decoupled**: Gates and dock don't directly reference each other
# - **Automatic Cleanup**: Handles gate removal gracefully
#
# Integration Points:
# - Gates call `check_completion()` when successfully passed
# - Dock checks `are_all_gates_completed()` to determine activation
# - External systems can connect to `all_gates_completed` signal
#
# Future Extensibility:
# - Ready for multiple level support
# - Can track additional objectives beyond gates
# - Supports save/load of progression state
# - Easy to add time tracking or scoring

extends Node

signal all_gates_completed

var gates = []
var dock = null

func _ready():
	set_process(false)

func register_gate(gate):
	if gate not in gates:
		gates.append(gate)
		gate.tree_exiting.connect(_on_gate_removed.bind(gate))

func register_dock(dock_node):
	dock = dock_node

func _on_gate_removed(gate):
	gates.erase(gate)

func are_all_gates_completed():
	if gates.is_empty():
		return false
	
	for gate in gates:
		if not gate.has_passed:
			return false
	
	return true

func check_completion():
	if are_all_gates_completed():
		all_gates_completed.emit()
		if dock:
			dock.check_level_completion()

func reset_level():
	for gate in gates:
		gate.reset()
	
	if dock:
		dock.is_active = false
		dock.update_visual_state()
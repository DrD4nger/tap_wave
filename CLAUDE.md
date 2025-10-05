# Tap Wave - Physics-Based Water Game

## Project Overview
A mobile water physics game built in Godot 4.4.1 featuring realistic water simulation, boat physics, and directional gate challenges. Players control a boat by tapping to create ripples that push the boat around the water.

## Key Game Mechanics
- **Tap Controls**: Players tap the water to create ripples that push the boat away from the tap location
- **Directional Gates**: Players must pass through gates in the correct direction to progress
- **Physics-Based Movement**: Realistic buoyancy, wave interaction, and boundary bouncing

## Technical Architecture

### Core Systems
1. **Water Simulation** - Gerstner wave shader with interactive ripples
2. **Boat Physics** - RigidBody3D with 8-point buoyancy system
3. **Gate System** - Directional detection and visual feedback
4. **Boundary System** - Bouncing constraints for play area

### Project Settings
- **Platform**: Mobile (Portrait 720x1280)
- **Camera**: Orthogonal isometric (45° angle, size=32.0)
- **Engine**: Godot 4.4.1

## File Structure

### Scenes
- `Main.tscn` - Root scene with water, camera, lighting, boat, and objects
- `Boat.tscn` - Player boat with physics and visual components
- `Buoy.tscn` - Decorative buoy with blinking light and gentle wobble
- `FlagBuoy.tscn` - Gate buoy with directional flags (Y-axis rotation locked)
- `Gate.tscn` - Two flag buoys forming a directional challenge

### Scripts
- `WaterController.gd` - Handles tap input and ripple creation (1-second cooldown)
- `Boat.gd` - Complete boat physics, movement, and boundary handling
- `Buoy.gd` - Shared buoy physics with flag buoy Y-axis locking
- `Gate.gd` - Directional detection, collision checking, and success feedback

### Shaders
- `water.gdshader` - Complex water rendering with Gerstner waves and ripples

## Key Physics Parameters

### Boat Physics (Boat.gd)
- `buoyancy_force: 15.0` - Upward force when submerged
- `surface_alignment_force: 2.0` - Keeps boat aligned with water surface
- `ripple_push_force: 1500.0` - Force from ripple interactions
- `directional_push_force: 120.0` - Force pushing away from clicks
- `boundary_bounce_force: 1500.0` - Strong bounce off play area edges
- `visual_turn_rate: 0.75` - Speed of boat rotation to face movement

### Water Shader Parameters
- Multiple Gerstner wave layers for realistic ocean movement
- Up to 10 simultaneous ripples with expanding ring effects
- Ripple speed: 4.0, amplitude: 0.7, wavelength: 3.5

### Buoy Physics
- Regular buoys: Full 3D rotation with gentle wobble
- Flag buoys: Y-axis rotation locked, maintain directional flags

## Game Features

### Water System
- **Base Waves**: Ambient Gerstner waves for ocean feel
- **Interactive Ripples**: Player-created ripples from taps
- **Visual Foam**: Dynamic foam on wave crests and ripples
- **Surface Interaction**: All objects respond to wave height

### Boat Control
- **Tap-to-Move**: Tap creates ripples that push boat away from tap location
- **Natural Physics**: Boat bobs, tilts, and moves with all wave types
- **Visual Rotation**: Hull rotates to face movement direction (visual only)
- **Boundary Bouncing**: Strong bounce forces when hitting play area edges

### Gate Challenges
- **Directional Detection**: Must approach from correct side to succeed
- **Visual Feedback**: Red lights turn green on successful passage
- **Flag Indicators**: Yellow flags show intended direction
- **Detection System**: 3.0 unit radius, 2.0 unit gate width

### Buoy Behaviors
- **Regular Buoys**: Gentle wobble, blinking red lights, stay anchored
- **Flag Buoys**: Same physics but Y-axis rotation locked for directional consistency

## Camera & Bounds
- **Isometric View**: 45° rotated orthogonal projection
- **Portrait Orientation**: Optimized for mobile 720x1280
- **Reduced Margins**: Width margins halved for more play space (0.35x factor)
- **Bounce Boundaries**: Invisible walls with strong repulsion forces

## Development Notes

### Physics Tuning
- Boat mass reduced to 8.0 for responsive feel
- Buoyancy forces balanced for realistic floating without excessive wobble
- Surface alignment forces keep objects upright without over-correction

### Visual Polish
- Double-sided flags using material cull_mode = 0
- Emissive materials for lights with blinking animations
- Proper material properties for water reflection and foam

### Performance
- Water mesh: 67.5x67.5 units with 150x150 subdivisions
- Efficient ripple system with automatic cleanup
- Optimized buoyancy probes (8 points for boat, 1 for buoys)

## Known Working Values
- All physics parameters have been iteratively tuned for optimal feel
- Boundary bounce force of 1500.0 provides satisfying collision response
- Gate detection radius of 3.0 gives good approach detection
- Ripple cooldown of 1.0 seconds prevents spam while maintaining responsiveness

## Future Considerations
- Gate system ready for level progression mechanics
- Buoy system can be extended for different marker types
- Water system supports additional wave types and effects
- Physics system designed for scalability and modification

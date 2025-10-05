# Tap Wave

A physics-based water navigation game where players control a boat by creating ripples in the water through strategic tapping.

## Game Overview

Tap Wave is an isometric traversal game that combines realistic water physics with intuitive touch controls. Players guide a boat through various obstacles and challenges by tapping on the water surface to create ripples that push the boat in the desired direction. The goal is to navigate through gates and reach the end dock of each level.

## Current Features

### Core Gameplay
- **Physics-Based Movement**: Tap the water to create ripples that realistically push your boat
- **Directional Gates**: Navigate through gates that require specific approach angles
- **Dynamic Water System**: Interactive water surface with realistic wave physics
- **Obstacle Navigation**: Maneuver around buoys and other maritime obstacles
- **Isometric View**: Clean, mobile-friendly perspective for optimal gameplay

### Technical Implementation
- **Engine**: Built with Godot 4.4.1
- **Platform**: Optimized for mobile (720x1280 portrait), playable on PC
- **Physics**: Custom buoyancy system with realistic boat floating and movement
- **Water Rendering**: Gerstner wave shader with interactive ripple effects

## How to Play

1. **Tap to Move**: Touch anywhere on the water to create a ripple
2. **Navigate**: Ripples push the boat away from the tap location
3. **Pass Gates**: Approach directional gates from the correct side (follow the flags)
4. **Reach the Goal**: Navigate to the dock to complete the level

## Project Status

This is an early version focusing on core mechanics and physics implementation. The foundation systems are in place and working:
- Boat physics and controls
- Water simulation and interaction
- Basic obstacles (buoys and gates)
- Goal detection (dock)

## Planned Features

### Gameplay Enhancements
- **Level System**: Multiple levels with increasing difficulty
- **New Obstacles**:
  - Whirlpools that pull the boat
  - Walls and cliff sides for maze-like challenges
  - Moving obstacles for dynamic puzzles
- **Audio**: Ambient water sounds and background music
- **UI/UX**: Interactive menus and level selection

### Technical Improvements
- Save/load system for progress tracking
- Performance optimizations for wider device support
- Enhanced visual effects and polish

## Development

### Requirements
- Godot Engine 4.4.1 or later
- Support for GLES3 rendering

### Project Structure
```
tap_wave/
├── scenes/          # Game scenes and prefabs
├── scripts/         # GDScript game logic
├── shaders/         # Water and visual effect shaders
└── assets/          # Game resources
```

### Building
1. Open the project in Godot 4.4.1
2. Configure export templates for your target platform
3. Build using Project > Export

## Controls

### Mobile
- **Tap**: Create ripple to push boat

### PC (Development)
- **Mouse Click**: Create ripple to push boat

## Credits

Developed using Godot Engine 4.4.1

## License

[License information to be added]

## Contact

[Contact information to be added]

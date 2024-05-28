# Worm Brain Plugin

A custom node for creating AI-powered worms in Godot Engine.
`brain.gd` and `weights.gd` use real mapping taken from a *C. elegans* worm brain (it has only 302 neurons), enabling you to simulate it in your game.
Heavily based on this project: [Simulate the C. elegans worm brain on your browser](https://github.com/heyseth/worm-sim).

Drag `WormNode` to your scene and enjoy.  
**Note:** Does not handle collision well, so you need to limit where it can go using an editor property.

## Features
- Customizable worm behavior and segments
- Dynamic segment creation
- Real worm brain simulation

## Installation
1. Download the plugin from the Godot Asset Library or clone the repository.
2. Copy the `addons/worm_ai_plugin` folder into your project's `addons` directory (if not done automatically by Godot).
3. Enable the plugin in `Project > Project Settings > Plugins`.

## Quick Usage
1. Add the `WormNode` to your scene.
2. Customize the worm's properties in the inspector.
3. The worm will "collide" with any `Area2D`, and will eat any that is part of the group `worm_food`.
4. This worm is stubborn, so a wall is a mere suggestion to it. If you want to contain the worm, make sure to decrease the limiting rect in the inspector.

### Worm parameters
```gd
limitingArea # Global area where the worm can move
segment_count = 20
segment_distance = 10 
max_scale = 1.0 # The maximum scale of the worm's girth
min_scale = 0.3 # The minimum scale of the worm's girth
front_rate = 0.2 # Rate of girth increase at the front
back_rate = 0.4 # Rate of girth decrease at the back

hungry_worm = true
time_until_hungry_again = 2
time_scaling_factor = 1.0

wormBrainDelay = 0.0 # Controls the simulation speed
```

### Communicating with the Brain
For these that want to play with the plugin code

`worm.gd` controls the interface of the brain with the game world. 
`brain.gd` powers the brain using the weights configured in `weights.gd`.  
You can stimulate neurons with specific functions by enabling and disabling some flags on the brain, causing these neurons to be continuously stimulated while on:

```gd
stimulateHungerNeurons
stimulateNoseTouchNeuronsLeft
stimulateNoseTouchNeuronsRight
stimulateFoodSenseNeuronsLeft
stimulateFoodSenseNeuronsRight
stimulatePheromonSenseNeuronsLeft
stimulatePheromonSenseNeuronsRight
stimulateChemicalsSenseNeuronsRight
stimulateChemicalsSenseNeuronsLeft
stimulateTemperatureSenseNeuronsRight
stimulateTemperatureSenseNeuronsLeft
stimulateOdorRepelantSenseNeuronsRight
stimulateOdorRepelantSenseNeuronsLeft
```

The worm has 4 sensors (`CollisionArea2D`), 2 for each side. They all are part of the same `sensor` group; the worm knows to ignore these.  
2 big ones represent smell sense, and 2 others represent touch. Collisions with these sensors activate the corresponding neurons.

## License
This project is licensed under the MIT License.

## Acknowledgements
This project is heavily based (it is basically a port to Godot) on the worm-sim made by Seth Miller.  
Huge thanks to him for sharing that online.

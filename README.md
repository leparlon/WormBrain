# Worm Brain Plugin

A custom node for creating AI-powered worms in Godot Engine.
"Brain" uses real mapping taken from a C. Elegans worm brain. Enables you to simulate it on your game. It has only 302 neurons but!
Heavily based on this project: [Simulate the C. Elegans worm brain on your browser](https://github.com/heyseth/worm-sim)
Drag WormNode to your scene and enjoy.
Note: Does not handle collision well, so you need to limit where it can go on a editor property.

## Features
- Customizable worm behaviour and segments
- Dynamic segment creation
- Real worm brain simulation

## Installation
1. Download the plugin from the Godot Asset Library or clone the repository.
2. Copy the `addons/worm_ai_plugin` folder into your project's `addons` directory (if not done automatically by Godot).
3. Enable the plugin in `Project > Project Settings > Plugins`.

## Usage
1. Add the `WormNode` to your scene.
2. Customize the worm's properties in the inspector.
3. Worm will "colide" with any Area2D, and will eat any that is part of the group "worm_food"
4. This thing is stuborn, so a wall is a mere suggestion to it. If you want to contain the worm, make sure to decrease the limiting rect on the inspector

## License
This project is licensed under the MIT License.

## Acknowledgements

This project is heavily based (it is basically a port to Godot) on the worm-sim made by Seth Miller.
Huge thanks to him for sharing that online.

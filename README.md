# Worm Brain Plugin

A custom node for creating AI-powered worms in Godot 4.
`brain.gd` and `weights.gd` use the real neural connectome of *C. elegans* — a nematode worm with exactly 302 neurons — enabling biologically grounded locomotion in your game.

Heavily based on: [Simulate the C. elegans worm brain on your browser](https://github.com/heyseth/worm-sim) by Seth Miller.

See also: [FlyBrain](https://github.com/leparlon/flybrain)

---

## Features

- Full C. elegans connectome simulation (302 neurons, ~4000 synaptic connections)
- Biologically correct motor output: dorsal/ventral muscle classes with ACh/GABA signs
- Proprioceptive body-wave feedback (Wen et al. 2012)
- Forward and backward locomotion driven by command interneurons (AVB/PVC vs AVA/AVD/AVE)
- Customisable body shape, textures, and sensor geometry
- Signal-based food and touch detection

---

## Installation

1. Copy the `addons/worm_brain_plugin` folder into your project's `addons` directory.
2. Enable the plugin in **Project → Project Settings → Plugins**.
3. `WormNode` will appear as a custom node type in the Add Node dialog.

---

## Quick Usage

1. Add a `WormNode` to your 2D scene.
2. Set `limiting_area` in the Inspector to keep the worm inside your level bounds.
3. Tag food objects with the group `worm_food` — the worm will seek and eat them.
4. Any `Area2D` **not** in the `sensor` or `worm_food` groups triggers nose-touch neurons.

---

## Inspector Parameters

### Body
| Parameter | Default | Description |
|---|---|---|
| `limiting_area` | `Rect2(50,50,1000,1000)` | World-space rect the worm cannot leave |
| `segment_count` | `20` | Number of body segments |
| `segment_distance` | `10` | Distance between segments (px) |
| `max_scale` | `1.0` | Maximum girth of the body |
| `min_scale` | `0.3` | Minimum girth at head and tail |
| `front_rate` | `0.2` | Fraction of body used for girth ramp-up |
| `back_rate` | `0.4` | Fraction of body used for girth taper |

### Textures
| Parameter | Description |
|---|---|
| `head_texture` | Sprite for segment 0 |
| `body_texture` | Sprite for middle segments |
| `tail_texture` | Sprite for the last segment |

### Behaviour
| Parameter | Default | Description |
|---|---|---|
| `hungry_worm` | `true` | Enable hunger system |
| `time_until_hungry_again` | `2` | Seconds after eating before hunger returns |
| `time_scaling_factor` | `1.0` | Speed divisor — increase to slow the worm down |
| `worm_brain_delay` | `0.0` | Seconds between neural ticks (0 = every frame) |

### Movement (v2.0)
| Parameter | Default | Description |
|---|---|---|
| `prop_gain` | `0.3` | Proprioceptive coupling strength into B-type neurons. Set to `0` to disable body-wave feedback |
| `bend_gain` | `0.05` | Reserved for future per-segment curvature use |

### Sensors
| Parameter | Default | Description |
|---|---|---|
| `touch_radius` | `20` | Radius of the nose-touch collision areas |
| `touch_offset` | `10` | Lateral offset of touch sensors from head centre |
| `smell_radius` | `130` | Radius of the food-smell detection areas |
| `smell_offset` | `50` | Lateral offset of smell sensors from head centre |

---

## Signals

```gdscript
ate_food(food_area: Area2D)
food_sense_neurons_stimulated(stimulated: bool, left: bool)
hunger_neurons_stimulated(stimulated: bool)
nose_touching_neurons_stimulated(stimulated: bool, left: bool)
```

---

## Interacting with the Brain

`worm.gd` bridges the neural simulation and the game world.
`brain.gd` runs the connectome using weights from `weights.gd`.

You can continuously stimulate any sensory pathway by setting flags on `BRAIN`:

```gdscript
$WormNode.BRAIN.stimulateHungerNeurons          = true
$WormNode.BRAIN.stimulateNoseTouchNeuronsLeft   = true
$WormNode.BRAIN.stimulateNoseTouchNeuronsRight  = true
$WormNode.BRAIN.stimulateFoodSenseNeuronsLeft   = true
$WormNode.BRAIN.stimulateFoodSenseNeuronsRight  = true
$WormNode.BRAIN.stimulatePheromonSenseNeuronsLeft   = true
$WormNode.BRAIN.stimulatePheromonSenseNeuronsRight  = true
$WormNode.BRAIN.stimulateChemicalsSenseNeuronsLeft  = true
$WormNode.BRAIN.stimulateChemicalsSenseNeuronsRight = true
$WormNode.BRAIN.stimulateTemperatureSenseNeuronsLeft  = true
$WormNode.BRAIN.stimulateTemperatureSenseNeuronsRight = true
$WormNode.BRAIN.stimulateOdorRepelantSenseNeuronsLeft  = true
$WormNode.BRAIN.stimulateOdorRepelantSenseNeuronsRight = true
```

Reading neural state:

```gdscript
$WormNode.BRAIN.net_turn        # float: dorsal-ventral steering bias
$WormNode.BRAIN.net_speed       # float: total motor activity (speed proxy)
$WormNode.BRAIN.locomotion_sign # int: +1 forward, -1 backward
$WormNode.BRAIN.segment_curvature  # Array[float]: per-segment D-V curvature
```

Segment world positions (useful for collision or effects):

```gdscript
$WormNode.segment_global_positions() # Array[Vector2]
```

---

## How the Movement Works (v2.0)

The motor output is computed from the C. elegans motor neuron classes each neural tick:

```
D[i] = DA[i] + DB[i] + AS[i] − DD[i]   # dorsal activation at segment i
V[i] = VA[i] + VB[i] + VC[i] − VD[i]   # ventral activation at segment i
curvature[i] = D[i] − V[i]
```

- **Steering** (`net_turn`): total D − V bias → head turns toward the dominant side
- **Speed** (`net_speed`): total D + V activity
- **Direction**: AVB + PVC interneurons drive forward; AVA + AVD + AVE drive reversal
- **Body wave**: each segment follows the previous (kinematic chain); proprioceptive feedback (prop_gain) injects body curvature back into DB/VB neurons, propagating the wave head → tail

---

## License

MIT License — see `LICENSE`.

## Acknowledgements

Connectome data and original simulation concept by Seth Miller ([worm-sim](https://github.com/heyseth/worm-sim)).
Motor neuron class mapping based on WormAtlas and Wen et al. 2012.

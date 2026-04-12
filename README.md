# WormBrain

*C. elegans* is a tiny nematode worm. It has exactly 302 neurons. Its entire neural wiring has been mapped and published. WormBrain puts that wiring into a Godot plugin, gives it a body, and lets it run.

Give it food. Give it walls. Watch what happens.

---

## What is this?

WormBrain is a plugin for [Godot](https://godotengine.org) — a free, open-source game engine popular with indie developers — that adds a `WormNode` to your 2D scene. The worm's behavior is driven by a simulation of the *C. elegans* connectome: all 302 neurons and roughly 4,000 synaptic connections, ticking in real time.

Each frame, neural activity propagates through the connectome. Motor neuron classes produce dorsal and ventral activations. The difference between them becomes a curvature signal. Curvature drives the kinematic chain that is the worm's body. The result is something that moves a bit like a worm — seeking food, avoiding obstacles, reversing when it bumps into things — not because it was scripted to, but because the network says so.

This project is closer to a toy than a scientific model, and that is part of the point.

---

## Why does it exist?

Curiosity, mostly. I wanted to know what it felt like to drop a piece of biology into a game engine and let it run. The *C. elegans* connectome is public, small enough to simulate in real time, and just strange enough to be interesting.

WormBrain is not a research tool. It does not claim to accurately reproduce the worm's biology. The mapping from neuron activity to pixel movement involves simplifications that any neuroscientist would reasonably object to. But as an interactive playground — a way to see connectome-driven behavior in action, in a game context — it does something that feels genuinely fun, and a little bit alive.

---

## Inspiration

The foundation of this project is [worm-sim](https://github.com/heyseth/worm-sim) by Seth Miller — a browser-based *C. elegans* simulation. WormBrain started as a GDScript port of that work and has since grown into a full Godot plugin with body physics, proprioceptive feedback, and customizable sensors.

More recently, work on simulating the *Drosophila* (fruit fly) connectome — a much larger and more complex network — reminded me of how much more could be done here. That renewed interest led to the v2.0 overhaul: better motor neuron class mapping, per-segment curvature, and body-wave propagation via proprioceptive feedback. You can find that experiment at [FlyBrain](https://github.com/leparlon/flybrain).

---

## Demo / Example

**[My Pet Elegans](https://play.google.com/store/apps/details?id=com.pgcn.petworm)** is a small Android game built with this plugin. You feed your worm, watch it roam, and see the connectome at work in a real (if very simple) game context. It's more proof-of-concept than polished product, but it shows what the plugin can actually do in practice.

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

`worm.gd` bridges the neural simulation and the game world. `brain.gd` runs the connectome using weights from `weights.gd`.

You can continuously stimulate any sensory pathway by setting flags on `BRAIN`:

```gdscript
$WormNode.BRAIN.stimulateHungerNeurons               = true
$WormNode.BRAIN.stimulateNoseTouchNeuronsLeft        = true
$WormNode.BRAIN.stimulateNoseTouchNeuronsRight       = true
$WormNode.BRAIN.stimulateFoodSenseNeuronsLeft        = true
$WormNode.BRAIN.stimulateFoodSenseNeuronsRight       = true
$WormNode.BRAIN.stimulatePheromonSenseNeuronsLeft    = true
$WormNode.BRAIN.stimulatePheromonSenseNeuronsRight   = true
$WormNode.BRAIN.stimulateChemicalsSenseNeuronsLeft   = true
$WormNode.BRAIN.stimulateChemicalsSenseNeuronsRight  = true
$WormNode.BRAIN.stimulateTemperatureSenseNeuronsLeft  = true
$WormNode.BRAIN.stimulateTemperatureSenseNeuronsRight = true
$WormNode.BRAIN.stimulateOdorRepelantSenseNeuronsLeft  = true
$WormNode.BRAIN.stimulateOdorRepelantSenseNeuronsRight = true
```

Reading neural state:

```gdscript
$WormNode.BRAIN.net_turn           # float: dorsal-ventral steering bias
$WormNode.BRAIN.net_speed          # float: total motor activity (speed proxy)
$WormNode.BRAIN.locomotion_sign    # int: +1 forward, -1 backward
$WormNode.BRAIN.segment_curvature  # Array[float]: per-segment D-V curvature
```

Segment world positions (useful for collision or effects):

```gdscript
$WormNode.segment_global_positions() # Array[Vector2]
```

---

## How Movement Works (v2.0)

Motor output is computed from the C. elegans motor neuron classes each neural tick:

```
D[i] = DA[i] + DB[i] + AS[i] − DD[i]   # dorsal activation at segment i
V[i] = VA[i] + VB[i] + VC[i] − VD[i]   # ventral activation at segment i
curvature[i] = D[i] − V[i]
```

- **Steering** (`net_turn`): total D − V bias → head turns toward the dominant side
- **Speed** (`net_speed`): total D + V activity
- **Direction**: AVB + PVC interneurons drive forward; AVA + AVD + AVE drive reversal
- **Body wave**: each segment follows the previous (kinematic chain); proprioceptive feedback (`prop_gain`) injects body curvature back into DB/VB neurons, propagating the wave head → tail

---

## License

MIT — see `LICENSE`.

## Acknowledgements

Connectome data and original simulation concept by Seth Miller ([worm-sim](https://github.com/heyseth/worm-sim)).
Motor neuron class mapping based on WormAtlas and Wen et al. 2012.

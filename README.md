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

## The goal: as close to the biology as fun allows

The guiding aim of WormBrain is to stay **as faithful to the real biology as it can while still being a lively, playable pet**. The connectome itself is real; the work is in mapping its output onto a body that both moves correctly *and* looks alive.

Because those two goals sometimes pull in different directions, the plugin lets you choose per axis:

- **Motor** — a `LUDIC_CPG` mode that guarantees a lifelike undulation (a central pattern generator, itself a real feature of *C. elegans* locomotion) with the connectome steering it, or a `BIOLOGICAL_CONNECTOME` mode where the body shape is driven **directly** by the per-segment neural curvature the network produces — honest to the biology, at the mercy of whatever the network is doing.
- **Sensors** — a `KLINOTAXIS` mode that reliably steers the worm toward sensed food (the real behavior, made dependable), or an `EMERGENT` mode that forces nothing and lets the connectome respond on its own.

Pick `LUDIC` + `KLINOTAXIS` for a convincing, food-seeking pet; pick `BIOLOGICAL` + `EMERGENT` to watch the raw connectome drive the body, warts and all.

---

## Inspiration

The foundation of this project is [worm-sim](https://github.com/heyseth/worm-sim) by Seth Miller — a browser-based *C. elegans* simulation. WormBrain started as a GDScript port of that work and has since grown into a full Godot plugin with body physics, proprioceptive feedback, and customizable sensors.

More recently, I tried the same approach with the *Drosophila* (fruit fly) connectome — a much larger and more complex network. That experiment lives at [FlyBrain](https://github.com/leparlon/flybrain), and so far it has not really worked: the network is orders of magnitude bigger, much slower to simulate, and I haven't managed to get meaningful behavior out of it yet. Still, working on it fed ideas back into this project and led to the v2.0 overhaul: better motor neuron class mapping, per-segment curvature, and body-wave propagation via proprioceptive feedback.

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

### Modes
| Parameter | Default | Description |
|---|---|---|
| `motor_mode` | `LUDIC_CPG` | How the body is shaped. `LUDIC_CPG`: guaranteed sinusoidal gait modulated by the connectome. `BIOLOGICAL_CONNECTOME`: body driven directly by per-segment neural curvature |
| `sensor_mode` | `KLINOTAXIS` | How sensors act. `KLINOTAXIS`: steer toward sensed food. `EMERGENT`: pure connectome response, no forcing |

### Gait
| Parameter | Default | Description |
|---|---|---|
| `body_stiffness` | `0.5` | How fast segments settle to their target shape (0–1) |
| `max_bend` | `0.6` | Clamp on per-segment bend angle (rad) — stops the body folding on itself |
| `cpg_amplitude` | `0.28` | *(Ludic)* Bend angle per segment at full speed (rad) |
| `cpg_wavelength` | `8.0` | *(Ludic)* Body segments per full undulation wave |
| `cpg_frequency` | `7.0` | *(Ludic)* Temporal speed of the travelling wave |
| `cpg_speed_ref` | `2.0` | *(Ludic)* Speed at which the wave reaches full amplitude |
| `cpg_idle` | `0.18` | *(Ludic)* Minimum wiggle when nearly stopped (keeps it alive) |
| `bend_gain` | `0.12` | *(Biological)* Neural curvature → body bend scale |
| `prop_gain` | `0.3` | Proprioceptive coupling into B-type neurons. Set to `0` to disable body-wave feedback |

### Sensors
| Parameter | Default | Description |
|---|---|---|
| `touch_radius` | `20` | Radius of the nose-touch collision areas |
| `touch_offset` | `10` | Lateral offset of touch sensors from head centre |
| `smell_radius` | `130` | Radius of the food-smell detection areas |
| `smell_offset` | `50` | Lateral offset of smell sensors from head centre |
| `klinotaxis_gain` | `0.18` | Steering bias toward sensed food (`KLINOTAXIS` mode only) |

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

Every neural tick, motor output is computed from the *C. elegans* motor neuron classes:

```
D[i] = DA[i] + DB[i] + AS[i] − DD[i]   # dorsal activation at segment i
V[i] = VA[i] + VB[i] + VC[i] − VD[i]   # ventral activation at segment i
curvature[i] = D[i] − V[i]
```

The brain always exposes the same signals to the body:

- **Steering** (`net_turn`): total D − V bias → head turns toward the dominant side
- **Speed** (`net_speed`): total D + V activity
- **Direction** (`locomotion_sign`): AVB + PVC interneurons drive forward; AVA + AVD + AVE drive reversal
- **Per-segment curvature** (`segment_curvature[]`): the D − V curve along the body

### The body: an oriented chain

The head is placed by the connectome (heading, speed, direction). The rest of the body is reconstructed as an oriented chain — each segment trails the previous one at a fixed distance, bent by a per-segment curvature. **The source of that curvature is what `motor_mode` selects:**

- **`LUDIC_CPG`** — a travelling sine wave (central pattern generator) generates the curvature, guaranteeing a clean, lifelike undulation. The connectome still decides where the head points, how fast it moves, and which way the wave travels. Amplitude scales with speed (never fully stops, thanks to `cpg_idle`).
- **`BIOLOGICAL_CONNECTOME`** — the curvature is read straight from the brain's `segment_curvature[]` (× `bend_gain`). The body's shape *is* the network's motor output, so the gait reflects whatever the connectome is actually doing.

In both modes, proprioceptive feedback (`prop_gain`) injects the body's real curvature back into DB/VB neurons the next tick, helping the wave propagate head → tail — a delay of one cycle, as in the real animal.

### Sensors

`sensor_mode` controls how sensory input turns into behavior. In `EMERGENT` mode the connectome responds on its own. In `KLINOTAXIS` mode an explicit bias (`klinotaxis_gain`) steers the heading toward whichever smell sensor detects food, making food-seeking dependable — the behavior the real worm performs, made reliable for a pet.

---

## License

MIT — see `LICENSE`.

## Acknowledgements

Connectome data and original simulation concept by Seth Miller ([worm-sim](https://github.com/heyseth/worm-sim)).
Motor neuron class mapping based on WormAtlas and Wen et al. 2012.

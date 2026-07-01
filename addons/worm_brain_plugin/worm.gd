extends Node2D

class_name WormNode

signal ate_food(food_area)
signal food_sense_neurons_stimulated(stimulated, left)
signal hunger_neurons_stimulated(stimulated)
signal nose_touching_neurons_stimulated(stimulated, left)
var BRAIN = Brain.new()

# --- Movement / sensor modes (selectable in the Inspector) ---
enum MotorMode {
	LUDIC_CPG,             # guaranteed sinusoidal gait, modulated by the connectome
	BIOLOGICAL_CONNECTOME, # body shape driven directly by per-segment neural curvature
}
enum SensorMode {
	EMERGENT,   # sensory response arises purely from the connectome
	KLINOTAXIS, # add an explicit bias so the worm steers toward sensed food
}

@export var motor_mode: MotorMode = MotorMode.LUDIC_CPG
@export var sensor_mode: SensorMode = SensorMode.KLINOTAXIS

@export var limitingArea = Rect2(50, 50, 1000, 1000)
@export var segment_count = 20
@export var segment_distance = 10
@export var hungry_worm = true
@export var time_until_hungry_again = 2
@export var time_scaling_factor = 1.0

@export var wormBrainDelay = 0.0

@export var head_texture : Texture2D = preload("res://addons/worm_brain_plugin/segment.png")
@export var body_texture : Texture2D = preload("res://addons/worm_brain_plugin/segment.png")
@export var tail_texture : Texture2D = preload("res://addons/worm_brain_plugin/segment.png")

@export_group("Gait")
@export var body_stiffness: float = 0.5   # How fast segments settle to their target shape (0-1)
@export var max_bend: float = 0.6         # Clamp on per-segment bend angle (rad) — stops folding

@export_subgroup("Ludic (CPG)")
@export var cpg_amplitude: float = 0.28   # Bend angle per segment at full speed (rad)
@export var cpg_wavelength: float = 8.0   # Body segments per full undulation wave
@export var cpg_frequency: float = 7.0    # Temporal speed of the travelling wave
@export var cpg_speed_ref: float = 2.0    # Speed at which the wave reaches full amplitude
@export var cpg_idle: float = 0.18        # Minimum wiggle when nearly stopped (keeps it alive)

@export_subgroup("Biological (connectome)")
@export var bend_gain: float = 0.12       # Neural curvature -> body bend (biological mode only)

@export var prop_gain: float = 0.3        # Proprioceptive coupling into B-type neurons (0 = off)

@export_group("Sensors")
@export var touch_radius: float = 20.0    # Radius of the nose-touch collision areas
@export var touch_offset: float = 10.0    # Lateral offset of touch sensors from head centre
@export var smell_radius: float = 130.0   # Radius of the food-smell detection areas
@export var smell_offset: float = 50.0    # Lateral offset of smell sensors from head centre
@export var klinotaxis_gain: float = 0.18 # Steering bias toward sensed food (KLINOTAXIS mode)

@export var max_scale = 1.0 # The maximum scale of the worm's girth
@export var min_scale = 0.3 # The minimum scale of the worm's girth
@export var front_rate = 0.2 # Rate of girth increase at the front
@export var back_rate = 0.4 # Rate of girth decrease at the back

var time_since_eaten = 0
var segments = []
var facingDir = 0.0
var targetDir = 0.0
var speed = 0.0
var targetSpeed = 0.0
var speedChangeInterval = 0.0
var food = []
var debug = false  # Ativar debug
var head_area
var sense_area
var target = Vector2()
var wormBrainLastUpdate = 0.0
var cpg_phase = 0.0  # travelling-wave phase accumulator (LUDIC_CPG mode)

# Function to calculate the scale based on segment index with different rates for front and back
func calculate_scale(segment_index, segment_count):
	if segment_index < segment_count * front_rate:
		# Growing phase
		return lerp(min_scale, max_scale, float(segment_index) / (segment_count * front_rate))
	elif segment_index < segment_count * (1 - back_rate):
		# Constant width phase
		return max_scale
	else:
		# Shrinking phase
		return lerp(max_scale, min_scale, float(segment_index - segment_count * (1 - back_rate)) / (segment_count * back_rate))

# Function to load worm segments
func load_worm_segments(segment_count, segment_distance, head_texture, body_texture, tail_texture):
	var segments = []
	for i in range(segment_count):
		var segment = Sprite2D.new()
		if i == 0:
			segment.texture = head_texture
		elif i == segment_count - 1:
			segment.texture = tail_texture
		else:
			segment.texture = body_texture

		segment.position = Vector2(i * segment_distance, 0)
		
		var scale = calculate_scale(i, segment_count)
		segment.scale = Vector2(scale, scale)
		
		add_child(segment)
		segments.append(segment)
	
	return segments

func _ready():
	# Assuming these variables are already defined
	# segment_count, segment_distance, head_texture, body_texture, tail_texture
	
	segments = load_worm_segments(segment_count, segment_distance, head_texture, body_texture, tail_texture)

	# Add Area2D to detect collisions on the worm's head
	var head_area_left = Area2D.new()
	var collision_shape_left = CollisionShape2D.new()
	collision_shape_left.shape = CircleShape2D.new()
	collision_shape_left.shape.radius = touch_radius
	head_area_left.add_child(collision_shape_left)
	segments[0].add_child(head_area_left)
	head_area_left.position.y -= touch_offset
	head_area_left.add_to_group("sensor")

	var head_area_right = Area2D.new()
	var collision_shape_right = CollisionShape2D.new()
	collision_shape_right.shape = CircleShape2D.new()
	collision_shape_right.shape.radius = touch_radius
	head_area_right.add_child(collision_shape_right)
	segments[0].add_child(head_area_right)
	head_area_right.position.y += touch_offset
	head_area_right.add_to_group("sensor")

	var sense_area_left = Area2D.new()
	var collision_sense_shape_left = CollisionShape2D.new()
	collision_sense_shape_left.shape = CircleShape2D.new()
	collision_sense_shape_left.shape.radius = smell_radius
	sense_area_left.add_child(collision_sense_shape_left)
	segments[0].add_child(sense_area_left)
	sense_area_left.position.y -= smell_offset
	sense_area_left.add_to_group("sensor")

	var sense_area_right = Area2D.new()
	var collision_sense_shape_right = CollisionShape2D.new()
	collision_sense_shape_right.shape = CircleShape2D.new()
	collision_sense_shape_right.shape.radius = smell_radius
	sense_area_right.add_child(collision_sense_shape_right)
	segments[0].add_child(sense_area_right)
	sense_area_right.position.y += smell_offset
	sense_area_right.add_to_group("sensor")

	head_area_left.connect("area_entered", Callable(self, "_on_head_area_entered_left"))
	head_area_left.connect("area_exited", Callable(self, "_on_head_area_exited_left"))
	head_area_right.connect("area_entered", Callable(self, "_on_head_area_entered_right"))
	head_area_right.connect("area_exited", Callable(self, "_on_head_area_exited_right"))

	sense_area_left.connect("area_entered", Callable(self, "_on_sense_area_entered_left"))
	sense_area_left.connect("area_exited", Callable(self, "_on_sense_area_exited_left"))
	sense_area_right.connect("area_entered", Callable(self, "_on_sense_area_entered_right"))
	sense_area_right.connect("area_exited", Callable(self, "_on_sense_area_exited_right"))

	BRAIN.segment_count = segment_count
	BRAIN.prop_gain = prop_gain
	BRAIN.setup()
	BRAIN.rand_excite()

	coliding(false, null, false)
	coliding(false, null, true)
	sensingFood(false, null, false)
	sensingFood(false, null, true)
	hungry(hungry_worm)

	set_process(true)


func _process(delta):
	if wormBrainLastUpdate > wormBrainDelay:
		wormBrainLastUpdate = wormBrainDelay
		
	if wormBrainLastUpdate > 0:
		wormBrainLastUpdate -= delta
	else:
		wormBrainLastUpdate = wormBrainDelay
		BRAIN.update()
		update_brain()
		update_simulation(delta)
		_update_body(delta)
		# Feed actual body curvature back into the brain for the next tick.
		# Delay of one cycle is biologically correct (proprioception is not instant).
		BRAIN.body_curvature = _compute_body_curvature()

func update_brain():
	var scaling = time_scaling_factor
	# net_turn: dorsal - ventral (normalised). Maps to a target direction offset like the
	# original left-right model, but now anatomically correct: D/V drives planar turning.
	targetDir = facingDir + (BRAIN.net_turn / scaling) * PI
	# In KLINOTAXIS mode, add an explicit turn toward whichever side smells food.
	if sensor_mode == SensorMode.KLINOTAXIS:
		targetDir += _klinotaxis_bias()
	# net_speed: raw total muscle activation, same scale as old accumleft + accumright.
	targetSpeed = BRAIN.net_speed / (scaling * 2.0)
	speedChangeInterval = (targetSpeed - speed) / (scaling * 1.5)

	if debug:
		print("net_turn: ", BRAIN.net_turn, " net_speed: ", BRAIN.net_speed)
		print("targetDir: ", targetDir, " targetSpeed: ", targetSpeed)

func update_simulation(delta):
	if hungry_worm:
		if time_since_eaten > 0:
			time_since_eaten -= delta
			if time_since_eaten <= 0:
				hungry(true)

	speed += speedChangeInterval
	facingDir = lerp_angle(facingDir, targetDir, 0.1)

	var movement = Vector2(cos(facingDir), sin(facingDir)) * speed * BRAIN.locomotion_sign * delta
	target += movement

	# Keep worm inside limiting area
	var converted_target = segments[0].global_position
	var diff = converted_target - segments[0].position
	var converted_area = limitingArea
	converted_area.position -= diff

	if target.x < converted_area.position.x:
		target.x = converted_area.position.x
	elif target.x > converted_area.position.x + converted_area.size.x:
		target.x = converted_area.position.x + converted_area.size.x

	if target.y < converted_area.position.y:
		target.y = converted_area.position.y
	elif target.y > converted_area.position.y + converted_area.size.y:
		target.y = converted_area.position.y + converted_area.size.y

	if debug:
		print("Facing Direction: ", facingDir, " Speed: ", speed)
		print("Movement: ", movement, " Target Position: ", target)

func _update_body(delta):
	# The head is driven by the connectome (heading + speed + direction). The rest of the
	# body is reconstructed as an oriented chain: each segment trails the previous one at a
	# fixed distance, bent by a per-segment curvature whose SOURCE depends on motor_mode.
	segments[0].position = target
	segments[0].rotation = facingDir

	var curv := _segment_curvature_for_mode(delta)
	var angle := facingDir
	for i in range(1, segment_count):
		angle += clampf(curv[i], -max_bend, max_bend)
		var offset := Vector2(cos(angle), sin(angle)) * segment_distance
		var target_position: Vector2 = segments[i - 1].position - offset
		# Lerp toward the target shape so curvature changes look soft, not snappy.
		segments[i].position = segments[i].position.lerp(target_position, body_stiffness)
		var direction := segments[i - 1].position - segments[i].position
		if direction != Vector2.ZERO:
			segments[i].rotation = direction.angle()

func _segment_curvature_for_mode(delta) -> Array:
	var curv: Array = []
	curv.resize(segment_count)
	curv[0] = 0.0

	if motor_mode == MotorMode.LUDIC_CPG:
		# A travelling sine wave guarantees a lifelike undulation. The connectome still
		# controls where the head points (net_turn), how fast it goes (speed) and which
		# way the wave travels (locomotion_sign) — the CPG only shapes the gait itself.
		var sf := clampf(abs(speed) / max(cpg_speed_ref, 0.001), 0.0, 1.0)
		var amp := cpg_amplitude * maxf(sf, cpg_idle)
		cpg_phase += cpg_frequency * delta * BRAIN.locomotion_sign
		for i in range(1, segment_count):
			curv[i] = amp * sin(cpg_phase - i * TAU / cpg_wavelength)
	else:
		# Body shape comes straight from the per-segment neural curvature the connectome
		# produces. Honest to the biology, at the mercy of whatever the network is doing.
		for i in range(1, segment_count):
			var c: float = BRAIN.segment_curvature[i] if i < BRAIN.segment_curvature.size() else 0.0
			curv[i] = c * bend_gain

	return curv

func _klinotaxis_bias() -> float:
	# Nudge the heading toward whichever side smells food. The left smell sensor sits at
	# local -y (port side); reaching it means turning counter-clockwise -> negative angle.
	# Flip the signs if the worm ends up steering AWAY from food.
	var bias := 0.0
	if BRAIN.stimulateFoodSenseNeuronsLeft:
		bias -= klinotaxis_gain
	if BRAIN.stimulateFoodSenseNeuronsRight:
		bias += klinotaxis_gain
	return bias

func _compute_body_curvature() -> Array:
	# Angular difference between consecutive segments = local body curvature.
	# Wrapped to [-PI, PI] so values stay signed and bounded regardless of rotation.
	var curv: Array = []
	curv.resize(segment_count)
	curv[0] = 0.0
	for i in range(1, segment_count):
		curv[i] = wrapf(segments[i].rotation - segments[i - 1].rotation, -PI, PI)
	return curv

func _on_head_area_entered_right(area):
	headAreaEntered(area, false)
		
func _on_head_area_exited_right(area):
	headAreaExited(area, false)
	
func _on_sense_area_entered_right(area):
	senseAreaEntered(area, false)

func _on_sense_area_exited_right(area):
	senseAreaExited(area, false)

func _on_head_area_entered_left(area):
	headAreaEntered(area, true)
		
func _on_head_area_exited_left(area):
	headAreaExited(area, true)
	
func _on_sense_area_entered_left(area):
	senseAreaEntered(area, true)

func _on_sense_area_exited_left(area):
	senseAreaExited(area, true)
		
func headAreaEntered(area, left):
	if area.is_in_group("worm_food"):
		speed += 10
		hungry(false)
		time_since_eaten = time_until_hungry_again
		emit_signal("ate_food", area)
	else:
		if not area.is_in_group("sensor"):
			coliding(true, area, left)

func headAreaExited(area, left):
	if not area.is_in_group("worm_food") and not area.is_in_group("sensor"):
		coliding(false, area, left)
		
func senseAreaEntered(area, left):
	if area.is_in_group("worm_food"):
		sensingFood(true, area, left)
		
func senseAreaExited(area, left):
	if area.is_in_group("worm_food"):
		sensingFood(false, area, left)
		
func coliding(isColiding, area, left):
	if left:
		BRAIN.stimulateNoseTouchNeuronsLeft = isColiding
	else: 
		BRAIN.stimulateNoseTouchNeuronsRight = isColiding
	emit_signal("nose_touching_neurons_stimulated", isColiding, left)
	
func sensingFood(isSensing, area, left):
	if left:
		BRAIN.stimulateFoodSenseNeuronsLeft = isSensing
	else:
		BRAIN.stimulateFoodSenseNeuronsRight = isSensing
	emit_signal("food_sense_neurons_stimulated", isSensing, left)
	
func hungry(isHungry):
	BRAIN.stimulateHungerNeurons = isHungry
	emit_signal("hunger_neurons_stimulated", isHungry)
		
		
func segment_global_positions():
	var segmentPos = []

	for i in range(1, segment_count):
		segmentPos.append(segments[i].global_position)

	return segmentPos

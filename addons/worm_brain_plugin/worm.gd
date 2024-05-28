extends Node2D

class_name WormNode

signal ate_food(food_area)
signal food_sense_neurons_stimulated(stimulated, left)
signal hunger_neurons_stimulated(stimulated)
signal nose_touching_neurons_stimulated(stimulated, left)
var BRAIN = Brain.new()

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
	collision_shape_left.shape.radius = 20
	head_area_left.add_child(collision_shape_left)
	segments[0].add_child(head_area_left)
	head_area_left.position.y -= 10
	head_area_left.add_to_group("sensor")
	
	var head_area_right = Area2D.new()
	var collision_shape_right = CollisionShape2D.new()
	collision_shape_right.shape = CircleShape2D.new()
	collision_shape_right.shape.radius = 20
	head_area_right.add_child(collision_shape_right)
	segments[0].add_child(head_area_right)
	head_area_right.position.y += 10
	head_area_right.add_to_group("sensor")

	var sense_area_left = Area2D.new()
	var collision_sense_shape_left = CollisionShape2D.new()
	collision_sense_shape_left.shape = CircleShape2D.new()
	collision_sense_shape_left.shape.radius = 130
	sense_area_left.add_child(collision_sense_shape_left)
	segments[0].add_child(sense_area_left)
	sense_area_left.position.y -= 50
	sense_area_left.add_to_group("sensor")
	
	var sense_area_right = Area2D.new()
	var collision_sense_shape_right = CollisionShape2D.new()
	collision_sense_shape_right.shape = CircleShape2D.new()
	collision_sense_shape_right.shape.radius = 130
	sense_area_right.add_child(collision_sense_shape_right)
	segments[0].add_child(sense_area_right)
	sense_area_right.position.y += 50
	sense_area_right.add_to_group("sensor")

	head_area_left.connect("area_entered", Callable(self, "_on_head_area_entered_left"))
	head_area_left.connect("area_exited", Callable(self, "_on_head_area_exited_left"))
	head_area_right.connect("area_entered", Callable(self, "_on_head_area_entered_right"))
	head_area_right.connect("area_exited", Callable(self, "_on_head_area_exited_right"))

	sense_area_left.connect("area_entered", Callable(self, "_on_sense_area_entered_left"))
	sense_area_left.connect("area_exited", Callable(self, "_on_sense_area_exited_left"))
	sense_area_right.connect("area_entered", Callable(self, "_on_sense_area_entered_right"))
	sense_area_right.connect("area_exited", Callable(self, "_on_sense_area_exited_right"))

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
		move_segments()

func update_brain():
	var scaling_factor = time_scaling_factor  # Aumentar o fator de escala
	var new_dir = (BRAIN.accumleft - BRAIN.accumright) / scaling_factor
	targetDir = facingDir + new_dir * PI
	targetSpeed = (abs(BRAIN.accumleft) + abs(BRAIN.accumright)) / (scaling_factor * 2)  # Ajustar a fórmula de velocidade
	speedChangeInterval = (targetSpeed - speed) / (scaling_factor * 1.5)
	
	if debug:
		print("Accumleft: ", BRAIN.accumleft, " Accumright: ", BRAIN.accumright)
		print("New Direction: ", new_dir, " Target Direction: ", targetDir)
		print("Target Speed: ", targetSpeed, " Speed Change Interval: ", speedChangeInterval)

func update_simulation(delta):
	if hungry_worm:
		if time_since_eaten > 0:
			time_since_eaten -= delta
			if time_since_eaten <= 0:
				hungry(true)
	
	speed += speedChangeInterval
	facingDir = lerp_angle(facingDir, targetDir, 0.1)
	var movement = Vector2(cos(facingDir), sin(facingDir)) * speed * delta
	target += movement
	segments[0].rotation = facingDir
	
	# Manter a minhoca dentro da área limite
	var converted_target = segments[0].global_position
	var diff = converted_target - segments[0].position
	var converted_area = limitingArea
	converted_area.position -= diff
	var worm_is_coliding = false

	if target.x < converted_area.position.x:
		target.x = converted_area.position.x
		worm_is_coliding = true
	elif target.x > converted_area.position.x + converted_area.size.x:
		target.x = converted_area.position.x + converted_area.size.x
		worm_is_coliding = true
	
	if target.y < converted_area.position.y:
		target.y = converted_area.position.y
		worm_is_coliding = true
	elif target.y > converted_area.position.y + converted_area.size.y:
		target.y = converted_area.position.y + converted_area.size.y
		worm_is_coliding = true
		
	#coliding(worm_is_coliding, null, true)
	#coliding(worm_is_coliding, null, false)
	if debug:
		print("Facing Direction: ", facingDir, " Speed: ", speed)
		print("Movement: ", movement, " Target Position: ", target)

func move_segments():
	segments[0].position = target

	for i in range(1, segment_count):
		var target_position = segments[i - 1].position
		var direction = (target_position - segments[i].position).normalized()
		segments[i].position = segments[i].position.lerp(target_position - direction * segment_distance, 0.5)
		
		if debug:
			print("Segment ", i, " Position: ", segments[i].position)

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

extends Node2D

signal ate_food(food_area)
signal food_sense_neurons_stimulated(stimulated)
signal hunger_neurons_stimulated(stimulated)
signal nose_touching_neurons_stimulated(stimulated)
var BRAIN = Brain.new()

@export var limitingArea = Rect2(50, 50, 1000, 1000)
@export var segment_count = 20
@export var segment_distance = 10
@export var hungry_worm = true
@export var time_until_hungry_again = 2
@export var time_scaling_factor = 1.0

@export var head_texture : Texture2D = preload("res://addons/worm_brain_plugin/segment.png")
@export var body_texture : Texture2D = preload("res://addons/worm_brain_plugin/segment.png")
@export var tail_texture : Texture2D = preload("res://addons/worm_brain_plugin/segment.png")

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

func _ready():
	for i in range(segment_count):
		var segment = Sprite2D.new()
		if i == 0:
			segment.texture = head_texture
		elif i == segment_count - 1:
			segment.texture = tail_texture
		else:
			segment.texture = body_texture
		segment.position = Vector2(i * segment_distance, 0)
		add_child(segment)
		segments.append(segment)

	# Adicionar Area2D para detectar colisões na cabeça da minhoca
	head_area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = CircleShape2D.new()
	collision_shape.shape.radius = 20
	head_area.add_child(collision_shape)
	segments[0].add_child(head_area)

	sense_area = Area2D.new()
	var collision_sense_shape = CollisionShape2D.new()
	collision_sense_shape.shape = CircleShape2D.new()
	collision_sense_shape.shape.radius = 80
	sense_area.add_child(collision_sense_shape)
	segments[0].add_child(sense_area)

	head_area.connect("area_entered", Callable(self, "_on_head_area_entered"))
	head_area.connect("area_exited", Callable(self, "_on_head_area_exited"))

	sense_area.connect("area_entered", Callable(self, "_on_sense_area_entered"))
	sense_area.connect("area_exited", Callable(self, "_on_sense_area_exited"))

	BRAIN.setup()
	BRAIN.rand_excite()

	coliding(false, null)
	sensingFood(false, null)
	hungry(hungry_worm)

	set_process(true)

func _process(delta):
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
		
	coliding(worm_is_coliding, null)
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

func _on_head_area_entered(area):
	if area.is_in_group("worm_food"):
		speed += 10
		hungry(false)
		time_since_eaten = time_until_hungry_again
		emit_signal("ate_food", area)
	else:
		coliding(true, area)
		
func _on_head_area_exited(area):
	if not area.is_in_group("worm_food"):
		coliding(false, area)

func coliding(isColiding, area):
	BRAIN.stimulateNoseTouchNeurons = isColiding
	emit_signal("food_sense_neurons_stimulated", isColiding)
	
func sensingFood(isSensing, area):
	BRAIN.stimulateNoseTouchNeurons = isSensing
	emit_signal("food_sense_neurons_stimulated", isSensing)
	
func hungry(isHungry):
	BRAIN.stimulateHungerNeurons = isHungry
	emit_signal("hunger_neurons_stimulated", isHungry)

func _on_sense_area_entered(area):
	if area.is_in_group("worm_food"):
		sensingFood(true, area)
		emit_signal("sense_food", area)

func _on_sense_area_exited(area):
	if area.is_in_group("worm_food"):
		sensingFood(false, area)

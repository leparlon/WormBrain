extends Node

class_name Brain

var weights = {}
var thisState = 0
var nextState = 1
var fireThreshold = 30
var accumleft = 0
var accumright = 0
var stimulateHungerNeurons = true
var stimulateNoseTouchNeuronsLeft = false
var stimulateNoseTouchNeuronsRight = false
var stimulateFoodSenseNeuronsRight = false
var stimulateFoodSenseNeuronsLeft = false
var stimulatePheromonSenseNeuronsRight = false
var stimulatePheromonSenseNeuronsLeft = false
var stimulateChemicalsSenseNeuronsRight = false
var stimulateChemicalsSenseNeuronsLeft = false
var stimulateTemperatureSenseNeuronsRight = false
var stimulateTemperatureSenseNeuronsLeft = false
var stimulateOdorRepelantSenseNeuronsRight = false
var stimulateOdorRepelantSenseNeuronsLeft = false
var postSynaptic = {}
var synapses = {}
var muscleList = []
var mLeft = []
var mRight = []
var debug = false  # Ativar debug

# --- Muscle-driven locomotion outputs ---
var segment_count: int = 20       # set from WormNode before setup()
var segment_curvature: Array = [] # per-segment D-V curvature (EMA smoothed)
var net_turn: float = 0.0         # total dorsal - ventral bias → steering signal
var net_speed: float = 0.0        # total dorsal + ventral activity → speed signal
var motor_smoothing: float = 0.3  # EMA smoothing on per-segment curvature

# --- Proprioceptive feedback (Wen et al. 2012) ---
var body_curvature: Array = []    # actual segment angles set by WormNode each frame
var prop_gain: float = 0.3        # proprioceptive coupling strength (0 = disabled)

# --- Locomotion direction ---
# AVB + PVC = forward command interneurons; AVA + AVD + AVE = backward command interneurons.
# locomotion_sign = +1 (forward) or -1 (reversal). Hysteresis: requires >5 unit difference
# to flip, so transient noise doesn't cause jitter.
var locomotion_sign: int = 1

func _init():
	var weights_module = preload("res://addons/worm_brain_plugin/weights.gd")
	weights = weights_module.get_weights()

func setup():
	if weights.size() == 0:
		print("Weights are empty. Please initialize weights.")
	
	for preSynaptic in weights.keys():
		synapses[preSynaptic] = func():
			dendrite_accumulate(preSynaptic)

	var neurons = [
		"ADAL", "ADAR", "ADEL", "ADER", "ADFL", "ADFR", "ADLL", "ADLR", "AFDL", "AFDR",
		"AIAL", "AIAR", "AIBL", "AIBR", "AIML", "AIMR", "AINL", "AINR", "AIYL", "AIYR",
		"AIZL", "AIZR", "ALA", "ALML", "ALMR", "ALNL", "ALNR", "AQR", "AS1", "AS10",
		"AS11", "AS2", "AS3", "AS4", "AS5", "AS6", "AS7", "AS8", "AS9", "ASEL", "ASER",
		"ASGL", "ASGR", "ASHL", "ASHR", "ASIL", "ASIR", "ASJL", "ASJR", "ASKL", "ASKR",
		"AUAL", "AUAR", "AVAL", "AVAR", "AVBL", "AVBR", "AVDL", "AVDR", "AVEL", "AVER",
		"AVFL", "AVFR", "AVG", "AVHL", "AVHR", "AVJL", "AVJR", "AVKL", "AVKR", "AVL",
		"AVM", "AWAL", "AWAR", "AWBL", "AWBR", "AWCL", "AWCR", "BAGL", "BAGR", "BDUL",
		"BDUR", "CEPDL", "CEPDR", "CEPVL", "CEPVR", "DA1", "DA2", "DA3", "DA4", "DA5",
		"DA6", "DA7", "DA8", "DA9", "DB1", "DB2", "DB3", "DB4", "DB5", "DB6", "DB7",
		"DD1", "DD2", "DD3", "DD4", "DD5", "DD6", "DVA", "DVB", "DVC", "FLPL", "FLPR",
		"HSNL", "HSNR", "I1L", "I1R", "I2L", "I2R", "I3", "I4", "I5", "I6", "IL1DL",
		"IL1DR", "IL1L", "IL1R", "IL1VL", "IL1VR", "IL2L", "IL2R", "IL2DL", "IL2DR",
		"IL2VL", "IL2VR", "LUAL", "LUAR", "M1", "M2L", "M2R", "M3L", "M3R", "M4", "M5",
		"MANAL", "MCL", "MCR", "MDL01", "MDL02", "MDL03", "MDL04", "MDL05", "MDL06",
		"MDL07", "MDL08", "MDL09", "MDL10", "MDL11", "MDL12", "MDL13", "MDL14", "MDL15",
		"MDL16", "MDL17", "MDL18", "MDL19", "MDL20", "MDL21", "MDL22", "MDL23", "MDL24",
		"MDR01", "MDR02", "MDR03", "MDR04", "MDR05", "MDR06", "MDR07", "MDR08", "MDR09",
		"MDR10", "MDR11", "MDR12", "MDR13", "MDR14", "MDR15", "MDR16", "MDR17", "MDR18",
		"MDR19", "MDR20", "MDR21", "MDR22", "MDR23", "MDR24", "MI", "MVL01", "MVL02",
		"MVL03", "MVL04", "MVL05", "MVL06", "MVL07", "MVL08", "MVL09", "MVL10", "MVL11",
		"MVL12", "MVL13", "MVL14", "MVL15", "MVL16", "MVL17", "MVL18", "MVL19", "MVL20",
		"MVL21", "MVL22", "MVL23", "MVR01", "MVR02", "MVR03", "MVR04", "MVR05", "MVR06",
		"MVR07", "MVR08", "MVR09", "MVR10", "MVR11", "MVR12", "MVR13", "MVR14", "MVR15",
		"MVR16", "MVR17", "MVR18", "MVR19", "MVR20", "MVR21", "MVR22", "MVR23", "MVULVA",
		"NSML", "NSMR", "OLLL", "OLLR", "OLQDL", "OLQDR", "OLQVL", "OLQVR", "PDA", "PDB",
		"PDEL", "PDER", "PHAL", "PHAR", "PHBL", "PHBR", "PHCL", "PHCR", "PLML", "PLMR",
		"PLNL", "PLNR", "PQR", "PVCL", "PVCR", "PVDL", "PVDR", "PVM", "PVNL", "PVNR",
		"PVPL", "PVPR", "PVQL", "PVQR", "PVR", "PVT", "PVWL", "PVWR", "RIAL", "RIAR",
		"RIBL", "RIBR", "RICL", "RICR", "RID", "RIFL", "RIFR", "RIGL", "RIGR", "RIH",
		"RIML", "RIMR", "RIPL", "RIPR", "RIR", "RIS", "RIVL", "RIVR", "RMDDL", "RMDDR",
		"RMDL", "RMDR", "RMDVL", "RMDVR", "RMED", "RMEL", "RMER", "RMEV", "RMFL", "RMFR",
		"RMGL", "RMGR", "RMHL", "RMHR", "SAADL", "SAADR", "SAAVL", "SAAVR", "SABD",
		"SABVL", "SABVR", "SDQL", "SDQR", "SIADL", "SIADR", "SIAVL", "SIAVR", "SIBDL",
		"SIBDR", "SIBVL", "SIBVR", "SMBDL", "SMBDR", "SMBVL", "SMBVR", "SMDDL", "SMDDR",
		"SMDVL", "SMDVR", "URADL", "URADR", "URAVL", "URAVR", "URBL", "URBR", "URXL",
		"URXR", "URYDL", "URYDR", "URYVL", "URYVR", "VA1", "VA10", "VA11", "VA12", "VA2",
		"VA3", "VA4", "VA5", "VA6", "VA7", "VA8", "VA9", "VB1", "VB10", "VB11", "VB2",
		"VB3", "VB4", "VB5", "VB6", "VB7", "VB8", "VB9", "VC1", "VC2", "VC3", "VC4",
		"VC5", "VC6", "VD1", "VD10", "VD11", "VD12", "VD13", "VD2", "VD3", "VD4", "VD5",
		"VD6", "VD7", "VD8", "VD9"
	]
	
	print ("Neuros: "+ str(neurons.size()))
	for neuron in neurons:
		postSynaptic[neuron] = [0, 0]

	muscleList = [
		"MDL07", "MDL08", "MDL09", "MDL10", "MDL11", "MDL12", "MDL13", "MDL14", "MDL15", "MDL16",
		"MDL17", "MDL18", "MDL19", "MDL20", "MDL21", "MDL22", "MDL23", "MVL07", "MVL08", "MVL09",
		"MVL10", "MVL11", "MVL12", "MVL13", "MVL14", "MVL15", "MVL16", "MVL17", "MVL18", "MVL19",
		"MVL20", "MVL21", "MVL22", "MVL23", "MDR07", "MDR08", "MDR09", "MDR10", "MDR11", "MDR12",
		"MDR13", "MDR14", "MDR15", "MDR16", "MDR17", "MDR18", "MDR19", "MDR20", "MDL21", "MDR22",
		"MDR23", "MVR07", "MVR08", "MVR09", "MVR10", "MVR11", "MVR12", "MVR13", "MVR14", "MVR15",
		"MVR16", "MVR17", "MVR18", "MVR19", "MVR20", "MVL21", "MVR22", "MVR23"
	]
	print ("muscleList: "+ str(muscleList.size()))
	
	mLeft = [
		"MDL07", "MDL08", "MDL09", "MDL10", "MDL11", "MDL12", "MDL13", "MDL14", "MDL15", "MDL16",
		"MDL17", "MDL18", "MDL19", "MDL20", "MDL21", "MDL22", "MDL23", "MVL07", "MVL08", "MVL09",
		"MVL10", "MVL11", "MVL12", "MVL13", "MVL14", "MVL15", "MVL16", "MVL17", "MVL18", "MVL19",
		"MVL20", "MVL21", "MVL22", "MVL23"
	]
	print ("mLeft: "+ str(mLeft.size()))
	
	mRight = [
		"MDR07", "MDR08", "MDR09", "MDR10", "MDR11", "MDR12", "MDR13", "MDR14", "MDR15", "MDR16",
		"MDR17", "MDR18", "MDR19", "MDR20", "MDL21", "MDR22", "MDR23", "MVR07", "MVR08", "MVR09",
		"MVR10", "MVR11", "MVR12", "MVR13", "MVR14", "MVR15", "MVR16", "MVR17", "MVR18", "MVR19",
		"MVR20", "MVL21", "MVR22", "MVR23"
	]
	print ("mRight: "+ str(mRight.size()))

	segment_curvature.resize(segment_count)
	segment_curvature.fill(0.0)

func dendrite_accumulate(preSynaptic):
	if preSynaptic in weights:
		for postSynaptic in weights[preSynaptic]:
			if postSynaptic in self.postSynaptic:
				self.postSynaptic[postSynaptic][nextState] += weights[preSynaptic][postSynaptic]
				if debug:
					print("Accumulating for ", postSynaptic, " with weight ", weights[preSynaptic][postSynaptic], " total: ", self.postSynaptic[postSynaptic][nextState])
			else:
				if debug:
					print("PostSynaptic neuron ", postSynaptic, " not found in postSynaptic dictionary.")

func rand_excite():
	var synapses_keys = synapses.keys()
	var synapses_size = synapses_keys.size()
	if synapses_size > 0:
		for i in range(40):
			var random_key = synapses_keys[randi() % synapses_size]
			dendrite_accumulate(random_key)
			if debug:
				print("Exciting random key: ", random_key)

func _inject_proprioception() -> void:
	if prop_gain <= 0.0 or body_curvature.size() < 2:
		return
	# DB (7 neurons, forward/dorsal) and VB (11 neurons, forward/ventral) receive
	# a signal proportional to the change in body curvature at their body position.
	# proprio[i] = curvature[i-1] - curvature[i]  (Wen et al. 2012)
	# Positive proprio at a segment = entering a dorsal bend → excite B-type neurons
	# → wave propagates anterior to posterior.
	var db_neurons: Array = ["DB1", "DB2", "DB3", "DB4", "DB5", "DB6", "DB7"]
	var vb_neurons: Array = ["VB1", "VB2", "VB3", "VB4", "VB5", "VB6", "VB7", "VB8", "VB9", "VB10", "VB11"]
	var n: int = body_curvature.size()

	for j in range(db_neurons.size()):
		var t: float = float(j) / float(db_neurons.size() - 1) * float(n - 1)
		var seg_i: int = clamp(int(round(t)), 1, n - 1)
		var proprio: float = body_curvature[seg_i - 1] - body_curvature[seg_i]
		postSynaptic[db_neurons[j]][nextState] += prop_gain * proprio

	for j in range(vb_neurons.size()):
		var t: float = float(j) / float(vb_neurons.size() - 1) * float(n - 1)
		var seg_i: int = clamp(int(round(t)), 1, n - 1)
		var proprio: float = body_curvature[seg_i - 1] - body_curvature[seg_i]
		postSynaptic[vb_neurons[j]][nextState] += prop_gain * proprio

func update():
	_inject_proprioception()
	if stimulateHungerNeurons:
		dendrite_accumulate("RIML")
		dendrite_accumulate("RIMR")
		dendrite_accumulate("RICL")
		dendrite_accumulate("RICR")
		run_synapses()
	if stimulateNoseTouchNeuronsLeft:
		dendrite_accumulate("FLPL")
		dendrite_accumulate("ASHL")
		dendrite_accumulate("IL1VL")
		dendrite_accumulate("OLQDL")
		dendrite_accumulate("OLQVL")
		run_synapses()
	if stimulateNoseTouchNeuronsRight:
		dendrite_accumulate("FLPR")
		dendrite_accumulate("ASHR")
		dendrite_accumulate("IL1VR")
		dendrite_accumulate("OLQDR")
		dendrite_accumulate("OLQVR")
		run_synapses()
	if stimulateFoodSenseNeuronsLeft:
		dendrite_accumulate("ADFL")
		dendrite_accumulate("ASGL")
		dendrite_accumulate("ASJL")
		run_synapses()
	if stimulateFoodSenseNeuronsRight:
		dendrite_accumulate("ADFR")
		dendrite_accumulate("ASGR")
		dendrite_accumulate("ASJR")
		run_synapses()
	if stimulatePheromonSenseNeuronsLeft:
		dendrite_accumulate("ASIL")
		run_synapses()
	if stimulatePheromonSenseNeuronsRight:
		dendrite_accumulate("ASIR")
		run_synapses()
	if stimulateChemicalsSenseNeuronsRight:
		dendrite_accumulate("ASER")
		run_synapses()
	if stimulateChemicalsSenseNeuronsLeft:
		dendrite_accumulate("ASEL")
		run_synapses()
	if stimulateTemperatureSenseNeuronsRight:
		dendrite_accumulate("AFDR")
		run_synapses()
	if stimulateTemperatureSenseNeuronsLeft:
		dendrite_accumulate("AFDL")
		run_synapses()
	if stimulateOdorRepelantSenseNeuronsRight:
		dendrite_accumulate("AWBR")
		run_synapses()
	if stimulateOdorRepelantSenseNeuronsLeft:
		dendrite_accumulate("AWBL")
		run_synapses()
	run_synapses()

func run_synapses():
	if debug:
		print("Running synapses")
	for ps in postSynaptic:
		if not begins_with_any(ps, ["MVU", "MVL", "MDL", "MVR", "MDR"]) and postSynaptic[ps][thisState] > fireThreshold:
			fire_neuron(ps)
			if debug:
				print("Firing neuron: ", ps)

	motor_control()

	for ps in postSynaptic:
		postSynaptic[ps][thisState] = postSynaptic[ps][nextState]

	var temp = thisState
	thisState = nextState
	nextState = temp

func fire_neuron(fneuron):
	if fneuron != "MVULVA":
		dendrite_accumulate(fneuron)
		postSynaptic[fneuron][nextState] = 0
		if debug:
			print("Neuron ", fneuron, " fired and reset")

func motor_control():
	# Read body-wall locomotion muscle cells 07..23 (01..06 = pharynx, skip)
	# MDL/MDR = dorsal body-wall muscles, MVL/MVR = ventral body-wall muscles
	# Average anatomical L+R since we simulate in 2D (only D/V matters for planar motion)
	var raw_dorsal: Array = []
	var raw_ventral: Array = []
	var total_d: float = 0.0
	var total_v: float = 0.0

	for j in range(7, 24):  # 07..23 inclusive = 17 muscle pairs
		var num: String = "%02d" % j
		var d: float = (postSynaptic["MDL" + num][nextState] + postSynaptic["MDR" + num][nextState]) * 0.5
		var v: float = (postSynaptic["MVL" + num][nextState] + postSynaptic["MVR" + num][nextState]) * 0.5
		total_d += d
		total_v += v
		raw_dorsal.append(d / fireThreshold)  # normalised ~[0,1] for per-segment curvature
		raw_ventral.append(v / fireThreshold)

	# net_turn: dorsal - ventral total (normalised). Positive = dorsal dominates → turn one way.
	# net_speed: total muscle activity in raw units — same scale as old accumleft+accumright.
	net_turn = (total_d - total_v) / fireThreshold
	net_speed = total_d + total_v

	# Reset ALL muscle-cell accumulators to prevent unbounded growth each cycle
	for key in postSynaptic:
		if begins_with_any(key, ["MDL", "MDR", "MVL", "MVR", "MVU"]):
			postSynaptic[key][nextState] = 0

	# Per-segment curvature with EMA smoothing (kept for future proprioception work)
	var n: int = raw_dorsal.size()  # 17
	for i in range(segment_count):
		var t: float = float(i) / float(max(segment_count - 1, 1)) * float(n - 1)
		var lo: int = int(t)
		var hi: int = min(lo + 1, n - 1)
		var frac: float = t - lo
		var d: float = lerp(raw_dorsal[lo], raw_dorsal[hi], frac)
		var v: float = lerp(raw_ventral[lo], raw_ventral[hi], frac)
		segment_curvature[i] = lerp(segment_curvature[i], d - v, motor_smoothing)

	# Locomotion direction from command interneurons (read thisState = prev-cycle potential).
	# AVB + PVC drive forward (B-type motor neurons); AVA + AVD + AVE drive backward (A-type).
	var fwd_bias: float = (postSynaptic["AVBL"][thisState] + postSynaptic["AVBR"][thisState] +
						   postSynaptic["PVCL"][thisState] + postSynaptic["PVCR"][thisState])
	var bwd_bias: float = (postSynaptic["AVAL"][thisState] + postSynaptic["AVAR"][thisState] +
						   postSynaptic["AVDL"][thisState] + postSynaptic["AVDR"][thisState] +
						   postSynaptic["AVEL"][thisState] + postSynaptic["AVER"][thisState])
	var dir_diff: float = fwd_bias - bwd_bias
	if dir_diff > 5.0:
		locomotion_sign = 1
	elif dir_diff < -5.0:
		locomotion_sign = -1
	# else: keep current sign (hysteresis — prevents jitter on balanced states)

	if debug:
		print("net_turn: ", net_turn, " net_speed: ", net_speed, " locomotion_sign: ", locomotion_sign)
		print("fwd_bias: ", fwd_bias, " bwd_bias: ", bwd_bias)
		print("curvature[0..4]: ", segment_curvature.slice(0, 5))

func begins_with_any(string, prefixes):
	for prefix in prefixes:
		if string.begins_with(prefix):
			return true
	return false

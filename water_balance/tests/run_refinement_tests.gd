# Step-size sensitivity and exploratory compensation evidence, not parameter tuning.
extends SceneTree

const Parameters = preload("res://model/model_parameters.gd")
const Model = preload("res://model/water_balance_model.gd")
const INVARIANT_TOLERANCE: float = 1e-8
# Absolute differences in relative-unit readouts: 0.1 percentage point maximum.
# This is a prototype acceptance tolerance, not a physiological error bound.
const READOUT_TOLERANCE: float = 0.001
const ENDPOINT_TIME_TOLERANCE: float = 0.02

var failures: Array[String] = []
var refinements: Array[Dictionary] = []
var probes: Array[Dictionary] = []

func _initialize() -> void:
	for drinking: int in [0, 1, 2]:
		var runs: Array[Dictionary] = []
		for interval: float in [0.02, 0.01, 0.005]:
			runs.append(_run(drinking, interval))
		var reference: Dictionary = runs[2]
		for run: Dictionary in runs:
			var differences: Dictionary = {}
			for key: String in ["c_out", "volume_ratio", "h", "urine_rate"]:
				differences[key] = absf(float(run.endpoint[key]) - float(reference.endpoint[key]))
				_check(float(differences[key]) <= READOUT_TOLERANCE, "Run drink %d dt %s endpoint %s agrees with .005" % [drinking, run.dt, key])
			var max_trace_difference: float = 0.0
			for index: int in range(mini(run.trace.size(), reference.trace.size())):
				for key: String in ["c_out", "volume_ratio"]:
					max_trace_difference = maxf(max_trace_difference, absf(float(run.trace[index][key]) - float(reference.trace[index][key])))
			_check(max_trace_difference <= READOUT_TOLERANCE, "Run drink %d dt %s trace agrees with .005" % [drinking, run.dt])
			_check(run.endpoint.endpoint == reference.endpoint.endpoint, "Matching endpoint reason")
			_check(absf(float(run.endpoint.time) - float(reference.endpoint.time)) <= ENDPOINT_TIME_TOLERANCE, "Matching endpoint time within one default step")
			run.endpoint_differences_from_finest = differences
			run.max_trace_difference_from_finest = max_trace_difference
		refinements.append({"activity": 1, "drinking": drinking, "automatic": true, "runs": runs})
	for index: int in range(13):
		var rate: float = 0.005 + float(index) * 0.00025
		var run: Dictionary = _run(1, 0.02, rate)
		run.compensation_evidence = _compensation(run)
		probes.append(run)
	# Narrow the observed transition between too little recovery (.00575) and
	# continuing late drift (.00600); retain the original broad sweep as evidence.
	for rate: float in [0.0058, 0.00585, 0.0059, 0.00595]:
		var run: Dictionary = _run(1, 0.02, rate)
		run.compensation_evidence = _compensation(run)
		probes.append(run)
	_write_report()
	for failure: String in failures:
		push_error(failure)
	print("Refinement: %d scenarios, %d exploratory rates, %d failures" % [refinements.size(), probes.size(), failures.size()])
	for probe: Dictionary in probes:
		var evidence: Dictionary = probe.compensation_evidence
		print("Rate %.5f: peak %.7f at %.2f, end error %.7f, late slope %.8f, candidate %s" % [probe.drinking_rate, evidence.peak_error, evidence.peak_time, evidence.final_error, evidence.late_slope, evidence.candidate])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _run(drinking: int, interval: float, replacement_rate: float = -1.0) -> Dictionary:
	var parameters: Resource = Parameters.new()
	parameters.dt = interval
	if replacement_rate >= 0.0:
		# Exploratory parameters exist only in this run; the source defaults stay intact.
		parameters.drinking_rates[drinking] = replacement_rate
	var model: RefCounted = Model.new(parameters)
	model.set_controls(1, drinking, true)
	var trace: Array[Dictionary] = [model.snapshot()]
	var peak_error: float = 0.0
	var peak_time: float = 0.0
	var invariant_error: float = 0.0
	var next_sample: float = 5.0
	var current: Dictionary = model.snapshot()
	for step_index: int in range(int(ceil(parameters.duration / interval)) + 2):
		current = model.step()
		for error: float in model.conservation_errors().values():
			invariant_error = maxf(invariant_error, absf(error))
		if float(current.c_out) - 1.0 > peak_error:
			peak_error = float(current.c_out) - 1.0
			peak_time = current.time
		if float(current.time) >= next_sample - 1e-9:
			trace.append(current)
			next_sample += 5.0
		if not String(current.endpoint).is_empty():
			break
	_check(invariant_error <= INVARIANT_TOLERANCE, "Conservation at drink %d dt %s rate %s" % [drinking, interval, replacement_rate])
	_check(String(current.endpoint) == "duration", "Selected refinement/probe scenario reaches duration")
	return {"dt": interval, "drinking_rate": parameters.drinking_rates[drinking], "parameters": parameters.to_dictionary(), "endpoint": current, "trace": trace, "max_invariant_error": invariant_error, "peak_error": peak_error, "peak_time": peak_time}

func _compensation(run: Dictionary) -> Dictionary:
	var trace: Array = run.trace
	var final_error: float = absf(float(run.endpoint.c_out) - 1.0)
	# The regular 5-unit samples include exact 20, 30, 50, 60 within roundoff.
	var middle_slope: float = (float(trace[6].c_out) - float(trace[4].c_out)) / 10.0
	var late_slope: float = (float(trace[12].c_out) - float(trace[10].c_out)) / 10.0
	var candidate: bool = float(run.peak_error) >= 0.003 and float(run.peak_time) < 30.0 and final_error <= float(run.peak_error) * 0.5 and absf(late_slope) <= 0.0001 and absf(late_slope) <= absf(middle_slope) * 0.5
	return {"peak_error": run.peak_error, "peak_time": run.peak_time, "final_error": final_error, "middle_slope": middle_slope, "late_slope": late_slope, "candidate": candidate}

func _write_report() -> void:
	var report: Dictionary = {
		"purpose": "Development-only step refinement and exploratory compensation; no defaults changed",
		"model_version": Parameters.new().model_version,
		"engine_version": Engine.get_version_info().string,
		"tolerances": {"invariants": INVARIANT_TOLERANCE, "relative_readouts": READOUT_TOLERANCE, "endpoint_time": ENDPOINT_TIME_TOLERANCE},
		"compensation_criteria": "Positive peak >= .003 before t30; final absolute error <= half peak; absolute slope t50-60 <= .0001 and <= half absolute slope t20-30. Exploratory evidence criteria, not clinical thresholds.",
		"limitations": "Only selected standard trajectories; does not prove convergence for arbitrary parameter configurations or all transient boundary crossings. Probe candidates require versioned tuning and investigation review.",
		"failures": failures, "refinements": refinements, "compensation_probes": probes,
	}
	DirAccess.make_dir_recursive_absolute("res://tests/reports")
	var file: FileAccess = FileAccess.open("res://tests/reports/refinement.json", FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write refinement report")
		return
	file.store_string(JSON.stringify(report, "\t"))

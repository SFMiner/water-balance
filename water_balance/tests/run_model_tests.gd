# Headless scientific regression checks; no scene or rendering dependencies.
extends SceneTree

const Parameters = preload("res://model/model_parameters.gd")
const Model = preload("res://model/water_balance_model.gd")
const TOLERANCE: float = 1e-8

var failures: Array[String] = []
var checks: int = 0
var scenarios: Array[Dictionary] = []

func _initialize() -> void:
	_test_equilibrium_and_direction()
	_test_feedback()
	_test_absorption_reset_and_copy()
	_test_limits_and_duration()
	_test_configuration_ownership_and_overflow()
	_sweep_scenarios()
	_write_report()
	for failure: String in failures:
		push_error(failure)
	print("Water Balance: %d checks; %d failures; %d scenarios" % [checks, failures.size(), scenarios.size()])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _closed_parameters() -> Resource:
	var parameters: Resource = Parameters.new()
	parameters.u_min = 0.0
	parameters.u_base = 0.0
	return parameters

func _test_equilibrium_and_direction() -> void:
	var equilibrium: RefCounted = Model.new(_closed_parameters())
	equilibrium.set_controls(0, 0, false)
	for index: int in range(100):
		equilibrium.step()
	_check(absf(equilibrium.snapshot().w_in - 2.0) < TOLERANCE, "Equal concentrations: no net osmosis")
	for solute: float in [0.8, 1.2]:
		var parameters: Resource = _closed_parameters()
		parameters.initial_s_out = solute
		parameters.k = 100.0
		var model: RefCounted = Model.new(parameters)
		model.set_controls(0, 0, false)
		var result: Dictionary = model.step()
		_check(result.w_in > 2.0 if solute < 1.0 else result.w_in < 2.0, "Osmosis direction at outside solute %s" % solute)
		_check(absf(result.c_in - result.c_out) < TOLERANCE, "Large flux stops at equilibrium without overshoot")
		_check(absf(result.w_out + result.w_in - 3.0) < TOLERANCE, "Internal transfer conserves water")
		_check(absf(result.s_in - 2.0) < TOLERANCE, "Intracellular solute is fixed")

func _test_feedback() -> void:
	var baseline: RefCounted = Model.new()
	_check(absf(baseline.snapshot().urine_rate - baseline.params.u_base) < TOLERANCE, "Initial H gives baseline urine")
	for solute: float in [0.8, 1.2]:
		var parameters: Resource = Parameters.new()
		parameters.initial_s_out = solute
		parameters.k = 0.0
		var model: RefCounted = Model.new(parameters)
		var before: Dictionary = model.snapshot()
		var after: Dictionary = model.step()
		_check(after.h > before.h if solute > 1.0 else after.h < before.h, "ADH responds to concentration")
		_check(after.urine_rate < before.urine_rate if solute > 1.0 else after.urine_rate > before.urine_rate, "ADH and urine move oppositely")
		_check(absf(after.h - before.h) < 0.01, "ADH is delayed, not an instantaneous jump")
	var fixed: RefCounted = Model.new()
	fixed.set_controls(2, 0, false)
	for index: int in range(100):
		fixed.step()
	_check(absf(fixed.snapshot().urine_rate - fixed.params.u_base) < TOLERANCE, "Fixed mode holds output")
	_check(fixed.snapshot().h > baseline.snapshot().h, "ADH may respond while output is fixed")

func _test_absorption_reset_and_copy() -> void:
	var model: RefCounted = Model.new()
	model.set_controls(0, 3, true)
	var initial: Dictionary = model.snapshot()
	var result: Dictionary = model.step()
	_check(result.pending_water > 0.0 and result.absorbed_water > 0.0, "Intake begins gradual absorption")
	_check(result.absorbed_water < result.consumed_water, "Pending water delays body input")
	var errors: Dictionary = model.conservation_errors()
	_check(absf(errors.absorption) < TOLERANCE, "Consumed = absorbed + pending")
	model.set_controls(0, 0, true)
	var next: Dictionary = model.step()
	_check(next.absorbed_water > result.absorbed_water, "Absorption continues after intake stops")
	_check(initial.time == 0.0 and initial.w_out == 1.0, "Snapshots remain detached from subsequent steps")
	result.w_out = 500.0
	_check(model.snapshot().w_out < 2.0, "Mutating snapshot cannot mutate scientific state")
	model.reset()
	var reset_state: Dictionary = model.snapshot()
	_check(reset_state.time == 0.0 and reset_state.pending_water == 0.0, "Reset clears time and pending absorption")
	_check(reset_state.consumed_water == 0.0 and reset_state.sweat_water == 0.0, "Reset clears ledgers")
	_check(not model.set_controls(-1, 0, true), "Invalid activity is rejected")
	_check(not model.set_controls(0, 4, true), "Invalid drinking selection is rejected")
	var invalid: Resource = Parameters.new()
	invalid.tau_h = 0.0
	_check(not invalid.validate().is_empty(), "Nonpositive lag is invalid")
	invalid.tau_h = 5.0
	invalid.u_max = invalid.u_min
	_check(not invalid.validate().is_empty(), "Degenerate output bounds are invalid")

func _test_limits_and_duration() -> void:
	var short_parameters: Resource = Parameters.new()
	short_parameters.duration = 0.035
	var short_run: RefCounted = Model.new(short_parameters)
	short_run.step()
	var terminal: Dictionary = short_run.step()
	_check(absf(terminal.time - 0.035) < TOLERANCE, "Duration accepts fractional final step")
	_check(terminal.endpoint == "duration", "Duration endpoint is recorded")
	_check(short_run.step() == terminal, "Terminal step cannot advance the model")
	var fast_parameters: Resource = Parameters.new()
	fast_parameters.sweat_rates.assign([0.0, 0.004, 100.0])
	var fast_run: RefCounted = Model.new(fast_parameters)
	fast_run.set_controls(2, 0, true)
	var stopped: Dictionary = fast_run.step()
	_check(not stopped.endpoint.is_empty(), "Excessive output reaches a domain boundary")
	_check(stopped.time < fast_parameters.dt, "Boundary is localized inside the integration step")
	_check(stopped.w_out > 0.0 and stopped.s_out > 0.0, "Donor-limited outputs never produce negative stores")
	var errors: Dictionary = fast_run.conservation_errors()
	_check(absf(errors.water) < TOLERANCE and absf(errors.solute) < TOLERANCE, "Boundary localization conserves quantities")

func _sweep_scenarios() -> void:
	for activity: int in range(3):
		for drinking: int in range(4):
			for automatic: bool in [true, false]:
				var model: RefCounted = Model.new()
				var replay: RefCounted = Model.new()
				var run_parameters: Resource = model.params
				model.set_controls(activity, drinking, automatic)
				replay.set_controls(activity, drinking, automatic)
				var trace: Array[Dictionary] = [model.snapshot()]
				var max_error: float = 0.0
				var valid: bool = true
				var steps: int = 0
				while model.snapshot().endpoint.is_empty() and steps < 4000:
					var sample: Dictionary = model.step()
					replay.step()
					steps += 1
					for error: float in model.conservation_errors().values():
						max_error = maxf(max_error, absf(error))
					for key: String in ["w_out", "w_in", "s_out", "s_in", "c_out", "c_in"]:
						valid = valid and is_finite(sample[key]) and sample[key] > 0.0
					valid = valid and sample.h >= 0.0 and sample.h <= 1.0
					valid = valid and sample.urine_rate >= run_parameters.u_min - TOLERANCE and sample.urine_rate <= run_parameters.u_max + TOLERANCE
					if steps % 50 == 0 or not sample.endpoint.is_empty():
						trace.append(sample)
				var identifier: String = "%d-%d-%s" % [activity, drinking, "automatic" if automatic else "fixed"]
				_check(valid, identifier + ": finite positive stores and bounded feedback")
				_check(max_error < TOLERANCE, identifier + ": conservation ledger")
				_check(not model.snapshot().endpoint.is_empty(), identifier + ": terminates")
				_check(model.snapshot() == replay.snapshot(), identifier + ": deterministic replay")
				scenarios.append({"id": identifier, "parameters": model.params.to_dictionary(), "max_invariant_error": max_error, "endpoint": model.snapshot(), "trace": trace})

func _test_configuration_ownership_and_overflow() -> void:
	var parameters: Resource = Parameters.new()
	var model: RefCounted = Model.new(parameters)
	parameters.initial_w_in = 100.0
	parameters.drinking_rates[3] = 200.0
	_check(model.params.initial_w_in == 2.0 and model.params.drinking_rates[3] == 0.030, "Run owns an independent parameter snapshot")
	var exposed: Resource = model.params
	exposed.initial_w_in = 0.0
	_check(model.snapshot().volume_ratio == 1.0, "Parameter accessor cannot corrupt live derived quantities")
	var exposed_state: Dictionary = model.state
	exposed_state.w_in = -100.0
	_check(model.snapshot().w_in == 2.0, "State accessor cannot corrupt the model")
	var extreme: Resource = Parameters.new()
	extreme.drinking_rates[3] = 1e308
	var overflow: RefCounted = Model.new(extreme)
	overflow.set_controls(0, 3, true)
	var before: Dictionary = overflow.snapshot()
	var after: Dictionary = overflow.step()
	_check(after.endpoint == "numerical_error", "Arithmetic overflow reports numerical failure")
	_check(after.w_out == before.w_out and after.time == before.time, "Numerical failure preserves last finite state")
	_check(not overflow.last_errors.is_empty(), "Numerical failure has diagnostic details")

func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/reports")
	var report: FileAccess = FileAccess.open("res://tests/reports/latest.json", FileAccess.WRITE)
	if report == null:
		_check(false, "Validation report can be written")
		return
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "tolerance": TOLERANCE, "scenarios": scenarios}, "\t"))
	report.close()

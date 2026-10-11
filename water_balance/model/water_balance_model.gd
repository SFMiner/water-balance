# === HEADER COMMENT ===
# Deterministic finite compartments, independent of scene nodes and display clocks.
class_name WaterBalanceModel
extends RefCounted

# === CONSTANTS ===
const Parameters = preload("model_parameters.gd")
const BOUNDARY_ITERATIONS: int = 48

# === PUBLIC VARIABLES ===
var params: Parameters:
	get:
		return _params.duplicate(true) as Parameters
var state: Dictionary:
	get:
		return _state.duplicate(true)
var last_errors: PackedStringArray = []

# === PRIVATE VARIABLES ===
var _params: Parameters
var _state: Dictionary = {}
var _activity: int = 0
var _drinking: int = 0
var _automatic: bool = true
var _drink_type: int = 0

# === LIFECYCLE METHODS ===
func _init(parameters: Parameters = null) -> void:
	_params = parameters.duplicate(true) as Parameters if parameters != null else Parameters.new()
	reset()

# === PUBLIC METHODS ===
func reset() -> void:
	last_errors = _params.validate()
	if not last_errors.is_empty():
		return
	_state = {
		"time": 0.0, "w_out": _params.initial_w_out, "s_out": _params.initial_s_out,
		"w_in": _params.initial_w_in, "s_in": _params.initial_s_in,
		"h": _base_h(), "urine_rate": _params.u_base, "endpoint": "",
		"pending_water": 0.0, "consumed_water": 0.0, "absorbed_water": 0.0, "absorbed_solute": 0.0,
		"sweat_water": 0.0, "sweat_solute": 0.0, "urine_water": 0.0, "urine_solute": 0.0,
	}

func set_controls(activity: int, drinking: int, automatic: bool = true, drink_type: int = 0) -> bool:
	if activity < 0 or activity >= _params.sweat_rates.size() or drinking < 0 or drinking >= _params.drinking_rates.size():
		return false
	if drink_type < 0 or drink_type >= _params.drink_solute.size():
		return false
	_activity = activity
	_drinking = drinking
	_automatic = automatic
	_drink_type = drink_type
	return true

func step() -> Dictionary:
	if _state.is_empty() or not String(_state.endpoint).is_empty():
		return snapshot()
	last_errors = _params.validate()
	if not last_errors.is_empty():
		return snapshot()
	if _activity >= _params.sweat_rates.size() or _drinking >= _params.drinking_rates.size():
		last_errors.append("Current controls are unavailable in the parameter set")
		return snapshot()
	var reason: String = _boundary(_state)
	if not reason.is_empty():
		_state.endpoint = reason
		return snapshot()
	var interval: float = minf(_params.dt, _params.duration - float(_state.time))
	if interval <= 0.0:
		_state.endpoint = "duration"
		return snapshot()
	var candidate: Dictionary = _advance(_state, interval)
	reason = String(candidate.endpoint)
	if reason == "nonfinite_state" or reason == "numerical_error":
		return _numerical_failure()
	if not reason.is_empty():
		# Recompute every transfer from the same prior state: never interpolate ledgers
		# or clamp a finished compartment to make the boundary look correct.
		# The bracket assumes a single first crossing as the trial interval grows.
		# Arbitrarily retuned rates still require step-refinement validation.
		var low: float = 0.0
		var high: float = interval
		for iteration: int in range(BOUNDARY_ITERATIONS):
			var middle: float = (low + high) * 0.5
			var trial: Dictionary = _advance(_state, middle)
			if String(trial.endpoint) == "nonfinite_state" or String(trial.endpoint) == "numerical_error":
				return _numerical_failure()
			if String(trial.endpoint).is_empty():
				low = middle
			else:
				high = middle
		candidate = _advance(_state, high)
		if String(candidate.endpoint) == "nonfinite_state" or String(candidate.endpoint) == "numerical_error":
			return _numerical_failure()
	elif interval >= _params.duration - float(_state.time):
		candidate.time = _params.duration
		candidate.endpoint = "duration"
	_state = candidate
	return snapshot()

func snapshot() -> Dictionary:
	if _state.is_empty():
		return {}
	var result: Dictionary = _state.duplicate(true)
	result.c_out = _concentration(_state.s_out, _state.w_out)
	result.c_in = _concentration(_state.s_in, _state.w_in)
	result.volume_ratio = float(_state.w_in) / _params.initial_w_in
	result.activity = _activity
	result.drinking = _drinking
	result.automatic = _automatic
	result.drink_type = _drink_type
	result.model_version = _params.model_version
	return result

func conservation_errors() -> Dictionary:
	if _state.is_empty():
		return {}
	return {
		"water": float(_state.w_out) + float(_state.w_in) - (_params.initial_w_out + _params.initial_w_in + float(_state.absorbed_water) - float(_state.sweat_water) - float(_state.urine_water)),
		"solute": float(_state.s_out) + float(_state.s_in) - (_params.initial_s_out + _params.initial_s_in + float(_state.absorbed_solute) - float(_state.sweat_solute) - float(_state.urine_solute)),
		"absorption": float(_state.consumed_water) - float(_state.absorbed_water) - float(_state.pending_water),
	}

# === PRIVATE METHODS ===
func _numerical_failure() -> Dictionary:
	# Preserve the last accepted finite quantities and ledgers for inspection.
	_state.endpoint = "numerical_error"
	last_errors.append("Numerical arithmetic failed; no transfer from this step was accepted")
	return snapshot()

func _stop_at_stage_boundary(candidate: Dictionary) -> bool:
	if not String(candidate.endpoint).is_empty():
		return true
	candidate.endpoint = _boundary(candidate)
	return not String(candidate.endpoint).is_empty()

func _base_h() -> float:
	return 1.0 - (_params.u_base - _params.u_min) / (_params.u_max - _params.u_min)

func _advance(previous: Dictionary, interval: float) -> Dictionary:
	var next: Dictionary = previous.duplicate(true)
	next.time = float(previous.time) + interval
	var intake: float = _params.drinking_rates[_drinking]
	# Exact constant-input solution of dP/dt = intake - P/tau conserves delayed water.
	var consumed: float = intake * interval
	var pending: float = float(previous.pending_water) * exp(-interval / _params.absorption_tau) + intake * _params.absorption_tau * (1.0 - exp(-interval / _params.absorption_tau))
	var absorbed: float = float(previous.pending_water) + consumed - pending
	next.pending_water = pending
	next.consumed_water += consumed
	next.absorbed_water += absorbed
	next.w_out += absorbed
	# A drink's solute is absorbed with its water (at the drink type in force now).
	var solute_in: float = absorbed * _params.drink_solute[_drink_type] * _params.initial_s_out / _params.initial_w_out
	next.absorbed_solute += solute_in
	next.s_out += solute_in
	# Check each split stage so a later transfer cannot hide an earlier limit.
	if _stop_at_stage_boundary(next):
		return next
	_remove_output(next, _params.sweat_rates[_activity] * interval, _params.sweat_fraction, "sweat")
	if _stop_at_stage_boundary(next):
		return next
	var concentration: float = _concentration(next.s_out, next.w_out)
	var raw_target: float = _base_h() + _params.g_c * (concentration - 1.0) + _params.g_w * (1.0 - float(next.w_out))
	if not is_finite(raw_target):
		next.endpoint = "numerical_error"
		return next
	var target_h: float = clampf(raw_target, 0.0, 1.0)
	next.h = float(previous.h) + (target_h - float(previous.h)) * (1.0 - exp(-interval / _params.tau_h))
	next.urine_rate = _params.u_min + (_params.u_max - _params.u_min) * (1.0 - float(next.h)) if _automatic else _params.u_base
	if _stop_at_stage_boundary(next):
		return next
	_remove_output(next, float(next.urine_rate) * interval, _params.urine_fraction, "urine")
	if _stop_at_stage_boundary(next):
		return next
	_apply_osmosis(next, interval)
	_stop_at_stage_boundary(next)
	return next

func _remove_output(next: Dictionary, water: float, fraction: float, prefix: String) -> void:
	var solute: float = water * fraction * _concentration(next.s_out, next.w_out)
	if not is_finite(water) or not is_finite(solute):
		next.endpoint = "numerical_error"
		return
	var scale: float = 1.0
	if water > 0.0:
		scale = minf(scale, float(next.w_out) / water)
	if solute > 0.0:
		scale = minf(scale, float(next.s_out) / solute)
	water *= scale
	solute *= scale
	next.w_out -= water
	next.s_out -= solute
	next[prefix + "_water"] += water
	next[prefix + "_solute"] += solute

func _apply_osmosis(next: Dictionary, interval: float) -> void:
	var total_solute: float = float(next.s_in) + float(next.s_out)
	if total_solute <= 0.0:
		return
	var transfer: float = _params.k * (_concentration(next.s_in, next.w_in) - _concentration(next.s_out, next.w_out)) * interval
	var equalizing: float = (float(next.s_in) * float(next.w_out) - float(next.s_out) * float(next.w_in)) / total_solute
	if not is_finite(transfer) or not is_finite(equalizing) or not is_finite(total_solute):
		next.endpoint = "numerical_error"
		return
	if transfer >= 0.0:
		transfer = minf(transfer, minf(float(next.w_out), maxf(0.0, equalizing)))
	else:
		transfer = maxf(transfer, maxf(-float(next.w_in), minf(0.0, equalizing)))
	next.w_in += transfer
	next.w_out -= transfer

func _concentration(solute: float, water: float) -> float:
	return solute / water if water > 0.0 else INF

func _boundary(candidate: Dictionary) -> String:
	for key: String in candidate:
		if candidate[key] is float and not is_finite(float(candidate[key])):
			return "nonfinite_state"
	if float(candidate.w_out) <= _params.initial_w_out * _params.min_water_fraction:
		return "outside_water_minimum"
	if float(candidate.w_in) <= _params.initial_w_in * _params.min_water_fraction:
		return "inside_water_minimum"
	var outside: float = _concentration(candidate.s_out, candidate.w_out)
	var inside: float = _concentration(candidate.s_in, candidate.w_in)
	if outside <= _params.min_concentration:
		return "outside_concentration_minimum"
	if outside >= _params.max_concentration:
		return "outside_concentration_maximum"
	if inside <= _params.min_concentration:
		return "inside_concentration_minimum"
	if inside >= _params.max_concentration:
		return "inside_concentration_maximum"
	var volume: float = float(candidate.w_in) / _params.initial_w_in
	if volume <= _params.min_volume_ratio:
		return "volume_minimum"
	if volume >= _params.max_volume_ratio:
		return "volume_maximum"
	return ""

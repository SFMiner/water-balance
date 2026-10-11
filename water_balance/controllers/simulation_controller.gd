class_name WaterBalanceController
extends Node

signal snapshot_updated(snapshot: Dictionary)
signal run_state_changed(state: String)

const Model = preload("../model/water_balance_model.gd")
const STEP: float = 0.02
const SAMPLE_INTERVAL: float = 0.25
const EPSILON: float = 0.000000001

var run_state: String = "ready"
var guided: bool = false
var activity: int = 0
var drinking: int = 0
var automatic: bool = true
var drink_type: int = 0
var prediction: String = ""
var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []

var _model: RefCounted = Model.new()
var _accumulator: float = 0.0
var _started: bool = false
var _sample_index: int = 1
var _previous: Dictionary = {}
var _current: Dictionary = {}
var _initial: Dictionary = {}
var _saved: Dictionary = {}

func _init() -> void:
	restart()

func _process(delta: float) -> void:
	advance(delta)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause()

func start() -> void:
	if run_state != "ready" and run_state != "paused":
		return
	_started = true
	_set_state("running")

func pause() -> void:
	if run_state == "running":
		_set_state("paused")
		_previous = _current.duplicate(true)
		snapshot_updated.emit(snapshot())

func restart() -> void:
	_model.reset()
	_model.set_controls(activity, drinking, automatic, drink_type)
	_accumulator = 0.0
	_started = false
	_sample_index = 1
	prediction = ""
	events.clear()
	_current = _model.snapshot()
	_previous = _current.duplicate(true)
	_initial = _current.duplicate(true)
	samples = [_current.duplicate(true)]
	_set_state("ready")
	snapshot_updated.emit(snapshot())

func configure(next_activity: int, next_drinking: int, next_automatic: bool, next_drink_type: int = 0) -> bool:
	if (guided and _started) or run_state == "finished":
		return false
	if not _model.set_controls(next_activity, next_drinking, next_automatic, next_drink_type):
		return false
	var changed: bool = activity != next_activity or drinking != next_drinking or automatic != next_automatic or drink_type != next_drink_type
	activity = next_activity
	drinking = next_drinking
	automatic = next_automatic
	drink_type = next_drink_type
	_current = _model.snapshot()
	_previous = _current.duplicate(true)
	if _started and changed:
		events.append({"time": float(_current.time), "activity": activity, "drinking": drinking, "automatic": automatic, "drink_type": drink_type})
	elif not _started:
		_initial = _current.duplicate(true)
		samples[0] = _current.duplicate(true)
	snapshot_updated.emit(snapshot())
	return true

func set_guided_mode(value: bool) -> void:
	if run_state == "ready":
		guided = value

func advance(real_delta: float) -> void:
	if run_state != "running" or not is_finite(real_delta) or real_delta <= 0.0:
		return
	_accumulator += real_delta
	while _accumulator + EPSILON >= STEP and run_state == "running":
		_accumulator = maxf(0.0, _accumulator - STEP)
		_previous = _current.duplicate(true)
		_current = _model.step()
		_record_samples()
		if not String(_current.endpoint).is_empty():
			_record_terminal()
			_accumulator = 0.0
			_previous = _current.duplicate(true)
			_set_state("finished")
	snapshot_updated.emit(snapshot())

func snapshot() -> Dictionary:
	return _current.duplicate(true)

func visual_snapshot() -> Dictionary:
	if run_state != "running":
		return snapshot()
	return _interpolate(_previous, _current, clampf(_accumulator / STEP, 0.0, 1.0))

func keep_run(slot: String) -> bool:
	if slot not in ["A", "B"] or not _started:
		return false
	var trace: Array[Dictionary] = samples.duplicate(true)
	if absf(float(trace[-1].time) - float(_current.time)) > EPSILON:
		trace.append(snapshot())
	else:
		trace[-1] = snapshot()
	_saved[slot] = {
		"initial_state": _initial.duplicate(true), "parameters": _model.params.to_dictionary(),
		"model_version": String(_current.model_version), "guided": guided,
		"settings": {"activity": int(_initial.activity), "drinking": int(_initial.drinking), "automatic": bool(_initial.automatic), "drink_type": int(_initial.drink_type)},
		"prediction": prediction, "samples": trace, "events": events.duplicate(true),
		"endpoint": String(_current.endpoint), "endpoint_time": float(_current.time), "final_state": snapshot(),
	}
	return true

func saved_run(slot: String) -> Dictionary:
	return Dictionary(_saved.get(slot, {})).duplicate(true)

func clear_comparisons() -> void:
	_saved.clear()

func leave_view() -> void:
	pause()

func enter_view() -> void:
	restart()

func _set_state(value: String) -> void:
	run_state = value
	run_state_changed.emit(value)

func _record_samples() -> void:
	var target: float = _sample_index * SAMPLE_INTERVAL
	while target <= float(_current.time) + EPSILON:
		var span: float = float(_current.time) - float(_previous.time)
		var fraction: float = (target - float(_previous.time)) / span if span > 0.0 else 1.0
		var observation: Dictionary = _interpolate(_previous, _current, clampf(fraction, 0.0, 1.0))
		observation.time = target
		samples.append(observation)
		_sample_index += 1
		target = _sample_index * SAMPLE_INTERVAL

func _record_terminal() -> void:
	if absf(float(samples[-1].time) - float(_current.time)) <= EPSILON:
		samples[-1] = snapshot()
	else:
		samples.append(snapshot())

func _interpolate(before: Dictionary, after: Dictionary, fraction: float) -> Dictionary:
	var result: Dictionary = before.duplicate(true)
	for key: String in before:
		if before[key] is float:
			result[key] = lerpf(float(before[key]), float(after[key]), fraction)
	# Ratios are derived from interpolated quantities, never blended independently.
	result.c_out = float(result.s_out) / float(result.w_out)
	result.c_in = float(result.s_in) / float(result.w_in)
	result.volume_ratio = float(result.w_in) / float(_initial.w_in)
	return result

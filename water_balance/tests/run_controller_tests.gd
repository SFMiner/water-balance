extends SceneTree

const Controller = preload("../controllers/simulation_controller.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_test_lifecycle()
	_test_guided()
	_test_frame_rates()
	_test_boundary()
	print("Controller checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _test_lifecycle() -> void:
	var controller: Node = Controller.new()
	_check(controller.samples.size() == 1 and controller.snapshot().time == 0.0, "Initial sample")
	_check(not controller.keep_run("A"), "Cannot keep unstarted run")
	_check(controller.configure(2, 1, false), "Valid settings")
	controller.prediction = "Cells shrink"
	controller.start()
	controller.advance(0.26)
	controller.pause()
	var paused: Dictionary = controller.snapshot()
	controller.advance(10.0)
	_check(controller.snapshot() == paused, "Paused model stays frozen")
	_check(controller.visual_snapshot() == paused, "Pause snaps visuals")
	_check(controller.samples.size() == 2 and controller.samples[1].time == 0.25, "Exact quarter sampling")
	_check(is_equal_approx(controller.samples[1].c_out, controller.samples[1].s_out / controller.samples[1].w_out), "Sample concentration derives from stores")
	controller.configure(1, 2, true)
	_check(controller.events.size() == 1 and is_equal_approx(controller.events[0].time, 0.26), "Free change timestamp")
	_check(controller.keep_run("A"), "Keep started run")
	var saved: Dictionary = controller.saved_run("A")
	saved.samples[0].w_out = 999.0
	saved.parameters.drinking_rates[0] = 999.0
	_check(controller.saved_run("A").samples[0].w_out == 1.0, "Saved trace defensive copy")
	_check(controller.saved_run("A").parameters.drinking_rates[0] == 0.0, "Saved parameter defensive copy")
	controller.restart()
	_check(controller.activity == 1 and controller.drinking == 2 and controller.automatic, "Restart retains controls")
	_check(controller.prediction == "" and controller.events.is_empty() and controller.samples.size() == 1, "Restart clears transient evidence")
	_check(not controller.saved_run("A").is_empty(), "Restart keeps comparisons")
	controller.start()
	controller.advance(0.03)
	var actual: Dictionary = controller.snapshot()
	var visual: Dictionary = controller.visual_snapshot()
	_check(visual.time < actual.time and controller.snapshot() == actual, "Visual interpolation cannot mutate model")
	controller.leave_view()
	_check(controller.run_state == "paused", "Leave pauses")
	controller.enter_view()
	_check(controller.run_state == "ready" and controller.snapshot().time == 0.0, "Enter resets")
	controller.clear_comparisons()
	_check(controller.saved_run("A").is_empty(), "Clear comparisons")
	controller.free()

func _test_guided() -> void:
	var controller: Node = Controller.new()
	controller.set_guided_mode(true)
	controller.start()
	_check(not controller.configure(1, 1, false), "Guided running controls lock")
	controller.pause()
	controller.set_guided_mode(false)
	_check(controller.guided and not controller.configure(1, 1, false), "Guided paused controls lock")
	controller.restart()
	_check(controller.configure(1, 1, false), "Restart unlocks guided controls")
	controller.start()
	controller.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(controller.run_state == "paused", "Focus loss pauses")
	controller.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(controller.run_state == "paused", "Focus return does not resume")
	controller.free()

func _test_frame_rates() -> void:
	var slow: Node = Controller.new()
	var fast: Node = Controller.new()
	slow.configure(2, 0, true)
	fast.configure(2, 0, true)
	slow.start()
	fast.start()
	for index: int in range(1800):
		slow.advance(1.0 / 30.0)
	for index: int in range(3600):
		fast.advance(1.0 / 60.0)
	_check(slow.snapshot() == fast.snapshot(), "Frame rates preserve scientific state")
	_check(slow.samples == fast.samples, "Frame rates preserve sampled evidence")
	_check(slow.run_state == "finished" and slow.snapshot().time == 60.0, "Exact duration endpoint")
	_check(slow.samples.size() == 241 and slow.samples[-1] == slow.snapshot(), "Terminal sample exact and not duplicated")
	_check(slow.visual_snapshot() == slow.snapshot(), "Terminal visuals exact")
	slow.free()
	fast.free()

func _test_boundary() -> void:
	var controller: Node = Controller.new()
	# A deliberately nearby software boundary exercises fractional termination.
	var parameters: Resource = preload("../model/model_parameters.gd").new()
	parameters.min_concentration = 0.99
	controller.set("_model", preload("../model/water_balance_model.gd").new(parameters))
	controller.restart()
	controller.configure(0, 3, false)
	controller.start()
	controller.advance(60.0)
	_check(controller.run_state == "finished" and controller.snapshot().endpoint != "duration", "Model limit terminal")
	_check(controller.samples[-1] == controller.snapshot(), "Fractional terminal preserved")
	var ordered: bool = true
	for index: int in range(1, controller.samples.size()):
		ordered = ordered and controller.samples[index].time > controller.samples[index - 1].time
	_check(ordered, "No duplicated timestamps")
	controller.free()

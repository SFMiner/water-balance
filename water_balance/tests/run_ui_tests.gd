# Drink type in the model, and the classroom screen: controls, keyboard exit, Space, kept runs.
extends SceneTree

const Parameters = preload("res://model/model_parameters.gd")
const Model = preload("res://model/water_balance_model.gd")
const TOLERANCE: float = 1e-8
## Pace (2) + amount (3) + race length (3) + drink (2) toggles, then Run, Restart, Speed, Keep, Clear.
const EXPECTED_STOPS: int = 15

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_test_drink_type()
	await _test_screen()
	print("UI checks: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		push_error(label)


func _race(activity: int, drinking: int, drink_type: int) -> Dictionary:
	var model: RefCounted = Model.new()
	_check(model.set_controls(activity, drinking, true, drink_type), "controls accepted")
	var worst: float = 0.0
	var snap: Dictionary = model.snapshot()
	while String(snap.endpoint).is_empty():
		snap = model.step()
		var errors: Dictionary = model.conservation_errors()
		for key: String in errors:
			worst = maxf(worst, absf(float(errors[key])))
	snap.worst_error = worst
	return snap


func _test_drink_type() -> void:
	var model: RefCounted = Model.new()
	_check(not model.set_controls(0, 0, true, 2), "an unknown drink type is rejected")
	_check(not model.set_controls(0, 0, true, -1), "a negative drink type is rejected")
	for activity: int in range(2):
		for drinking: int in range(1, 3):
			var water: Dictionary = _race(activity, drinking, 0)
			var sports: Dictionary = _race(activity, drinking, 1)
			_check(float(sports.c_out) > float(water.c_out), "sports drink keeps blood saltier than water (pace %d, amount %d)" % [activity, drinking])
			_check(float(sports.absorbed_solute) > 0.0 and float(water.absorbed_solute) == 0.0, "only the sports drink adds salt (pace %d, amount %d)" % [activity, drinking])
			_check(float(sports.worst_error) < TOLERANCE, "sports drink run conserves water and salt (pace %d, amount %d)" % [activity, drinking])
	# The anchor phenomenon: lots of plain water at a run dilutes the blood below the normal range;
	# none at all concentrates it above. (Illustrative scale: 140 x outside concentration.)
	_check(140.0 * float(_race(1, 2, 0).c_out) < 135.0, "Run + lots of water ends below 135 mEq/L")
	_check(140.0 * float(_race(1, 0, 0).c_out) > 145.0, "Run + no drink ends above 145 mEq/L")
	var medium: float = 140.0 * float(_race(1, 1, 0).c_out)
	_check(medium > 135.0 and medium < 145.0, "Run + medium water ends in the normal range (%.1f)" % medium)
	# Model 0.3.0+: ADH feedback lets the kidneys clear a moderate surplus; only Lots overwhelms them.
	var stop_medium: Dictionary = _race(0, 1, 0)
	var run_medium: Dictionary = _race(1, 1, 0)
	_check(140.0 * float(stop_medium.c_out) > 134.0, "Stop + medium water ends near normal (%.1f)" % (140.0 * float(stop_medium.c_out)))
	_check(float(run_medium.sweat_solute) > 2.0 * float(stop_medium.sweat_solute) and float(run_medium.c_out) > float(stop_medium.c_out),
			"the runner sweats out more salt than the resting runner yet ends with saltier blood")
	var stop_lots: Dictionary = _race(0, 2, 0)
	_check(float(stop_lots.c_out) < float(_race(1, 2, 0).c_out), "with lots of water, stopping ends more diluted than running")
	_check(float(stop_lots.h) < 0.05 and 140.0 * float(stop_lots.c_out) < 125.0, "Stop + lots: ADH is off and the blood is still diluted")


func _key(code: Key, shift: bool = false) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.keycode = code
	press.physical_keycode = code
	press.shift_pressed = shift
	press.pressed = true
	get_root().push_input(press)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	get_root().push_input(release)
	await process_frame


func _test_screen() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var nav: Node = main.keyboard
	_check(main.controller.run_state == "ready", "the race starts paused, ready")
	_check(main.pace_buttons[1].button_pressed and main.amount_buttons[1].button_pressed and main.drink_buttons[0].button_pressed,
			"defaults: Run, Medium, Water are shown chosen")

	# Tab from nothing focused walks every control, then leaves
	var stops: Array[Control] = []
	var before: int = nav.leave_count
	for i: int in range(EXPECTED_STOPS + 3):
		await _key(KEY_TAB)
		var f: Control = get_root().gui_get_focus_owner()
		if f == null:
			break
		stops.append(f)
	_check(stops.size() == EXPECTED_STOPS, "Tab reaches %d controls (got %d)" % [EXPECTED_STOPS, stops.size()])
	_check(nav.leave_count == before + 1, "Tab past the last control leaves the game")
	before = nav.leave_count
	var back: int = 0
	for i: int in range(EXPECTED_STOPS + 3):
		await _key(KEY_TAB, true)
		if get_root().gui_get_focus_owner() == null:
			break
		back += 1
	_check(back == EXPECTED_STOPS, "Shift+Tab walks the same controls backwards (got %d)" % back)
	_check(nav.leave_count == before + 1, "Shift+Tab before the first control leaves the game")
	main.run_button.grab_focus()
	before = nav.leave_count
	await _key(KEY_ESCAPE)
	_check(nav.leave_count == before + 1 and get_root().gui_get_focus_owner() == null, "Escape leaves the game")

	# Space with nothing focused starts and pauses the race
	await _key(KEY_SPACE)
	_check(main.controller.run_state == "running", "Space starts the race")
	await _key(KEY_SPACE)
	_check(main.controller.run_state == "paused", "Space again pauses it")

	# Toggles change the model's controls
	main.drink_buttons[1].emit_signal("pressed")
	main.amount_buttons[2].emit_signal("pressed")
	main.pace_buttons[0].emit_signal("pressed")
	_check(main.controller.drink_type == 1 and main.controller.drinking == 2 and main.controller.activity == 0, "toggles set drink, amount and pace")
	_check(main.drink_buttons[1].button_pressed and not main.drink_buttons[0].button_pressed, "only the chosen drink shows as chosen")

	# A whole race, kept, then compared
	main.controller.restart()
	main.toggle_run()
	main.controller.advance(70.0)
	_check(main.controller.run_state == "finished", "the race finishes")
	_check(main.run_button.text == "Run again", "the run button offers to run again")
	var end: Dictionary = main.controller.snapshot()
	_check(main.tally_cells[1][1].text == "-" + main.percent(float(end.sweat_solute)) and main.tally_cells[0].size() == 3,
			"the tally shows salt lost in sweat, as a percentage of the start, with no blood column")
	_check(main.percent(0.674) == "67%" and main.percent(1.75) == "175%", "amounts show as whole percentages")
	_check(main.saltiness.text.contains("%.2f" % float(end.c_out)), "the saltiness line shows salt / water")
	main.keep_run()
	_check(not main.controller.saved_run("A").is_empty() and not main.clear_button.disabled, "Keep this run stores the run")
	main.toggle_run()
	_check(main.controller.run_state == "running" and main.controller.samples.size() < 10, "Run again starts a fresh race")
	main.clear_kept()
	_check(main.controller.saved_run("A").is_empty() and main.clear_button.disabled, "Clear kept run removes it")
	_check(main.race_clock(30.0) == "2:00" and main.race_clock(15.0) == "1:00", "race clock maps model time to hours")
	main.set_length(2)
	_check(is_equal_approx(main.controller.duration(), 120.0) and is_equal_approx(main.sodium_graph.duration, 120.0)
			and is_equal_approx(main.sodium_graph.hours, 8.0) and main.length_buttons[2].button_pressed, "8 hours sets the race and the graph to 8 hours")
	_check(main._status.text.contains("of 8:00"), "the status shows an 8-hour race")
	main.set_pace(1)
	main.set_amount(2)
	main.set_drink(0)
	main.controller.start()
	main.controller.advance(120.0 * 1.2)
	_check(main.controller.run_state == "finished" and is_equal_approx(float(main.controller.snapshot().time), 120.0), "an 8-hour race runs to model time 120")
	_check(SodiumGauge.to_meq(float(main.controller.snapshot().c_out)) <= 120.0 and not main._status.text.contains("collapsed"),
			"8 hours running + Lots of water reaches the lesson's 120 mEq/L without collapsing")
	main.set_amount(0)
	main.controller.start()
	main.controller.advance(120.0 * 1.2)
	_check(String(main.controller.snapshot().endpoint).begins_with("collapse_") and float(main.controller.snapshot().time) < 120.0
			and main._status.text.contains("The runner collapsed") and main._observation.text.begins_with("The runner collapsed"),
			"8 hours running with no drink: the runner collapses and the screen says why")
	main.set_length(0)
	_check(main.controller.run_state == "ready" and is_equal_approx(main.controller.duration(), 60.0), "choosing 4 hours after the finish starts a fresh 4-hour race")
	main.queue_free()
	await process_frame

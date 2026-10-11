# Internal investigation prototype; full curriculum supports follow numerical sign-off.
extends Control

signal return_requested

const Controller = preload("../controllers/simulation_controller.gd")
const Graph = preload("evidence_graph.gd")
const Diagram = preload("body_diagram.gd")

var cell_renderer_script: Script
var controller: Node
var _activity: OptionButton
var _drinking: OptionButton
var _kidney: OptionButton
var _prediction: OptionButton
var _run: Button
var _status: Label
var _observations: Label
var _feedback: Label
var _saved: Label
var _diagram: Control
var _concentration_graph: Control
var _volume_graph: Control
var _compare: bool = false
var _help: AcceptDialog

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Color("101e2c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	margin.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var heading: Label = _label("WATER BALANCE · Investigation prototype", 24)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_button(header, "Help", _show_help)
	_button(header, "Return to Osmosis", func() -> void: return_requested.emit())
	column.add_child(_label("Free Explore · Provisional model parameters · Relative units, not medical measurements", 15))
	var controls: HFlowContainer = HFlowContainer.new()
	column.add_child(controls)
	_activity = _choice(controls, "Activity", ["Rest", "Jog", "Run"])
	_drinking = _choice(controls, "Drinking", ["None", "Low", "Medium", "High"])
	_kidney = _choice(controls, "Kidney response", ["Automatic", "Fixed output"])
	_prediction = _choice(controls, "Prediction (optional)", ["Not selected", "Swells", "Shrinks", "Near starting size"])
	for choice: OptionButton in [_activity, _drinking, _kidney]:
		choice.item_selected.connect(_change_controls)
	_prediction.item_selected.connect(_change_prediction)
	_status = _label("Ready · model time 0", 18)
	column.add_child(_status)
	_diagram = Diagram.new()
	_diagram.cell_renderer_script = cell_renderer_script
	column.add_child(_diagram)
	_observations = _label("", 17)
	column.add_child(_observations)
	_feedback = _label("", 17)
	column.add_child(_feedback)
	var views: HFlowContainer = HFlowContainer.new()
	column.add_child(views)
	var graph_choice: OptionButton = _choice(views, "Show graphs", ["Both", "Concentration", "Cell volume"])
	graph_choice.item_selected.connect(_select_graph)
	var graphs: HBoxContainer = HBoxContainer.new()
	column.add_child(graphs)
	_concentration_graph = Graph.new()
	_concentration_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphs.add_child(_concentration_graph)
	_volume_graph = Graph.new()
	_volume_graph.quantity = "volume_ratio"
	_volume_graph.heading = "Cell volume"
	_volume_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphs.add_child(_volume_graph)
	var actions: HFlowContainer = HFlowContainer.new()
	column.add_child(actions)
	_run = _button(actions, "Run", _toggle_run)
	_button(actions, "Restart run", _restart)
	_button(actions, "Keep A", func() -> void: _keep("A"))
	_button(actions, "Keep B", func() -> void: _keep("B"))
	_button(actions, "Compare / Live", _toggle_compare)
	_button(actions, "Clear comparisons", _clear)
	_saved = _label("A/B are empty. Saved runs clear when this page is refreshed or closed.", 14)
	column.add_child(_saved)
	_help = AcceptDialog.new()
	_help.title = "About this prototype"
	_help.dialog_text = "Change one condition between runs, keep A and B, then compare concentration and cell volume.\n\nGold outline: starting cell size. The graph uses actual model volume; the diagram exaggerates radius changes.\n\nADH is an abstract signal. More signal reduces urine water loss. Fixed output is a comparison model, not kidney failure.\n\nSpace toggles Run/Pause when a control has not consumed it. All current visuals are static apart from model-driven updates.\n\nGuided investigations, classroom tokens, causal flowcharts, and sourced medical data are not implemented in this prototype."
	add_child(_help)
	controller = Controller.new()
	controller.snapshot_updated.connect(_update_snapshot)
	controller.run_state_changed.connect(_update_run_state)
	add_child(controller)
	_update_snapshot(controller.snapshot())
	set_process(true)

func enter_view() -> void:
	if controller != null:
		controller.enter_view()
		_prediction.select(0)

func leave_view() -> void:
	if controller != null:
		controller.leave_view()

func _process(_delta: float) -> void:
	if controller != null:
		_diagram.show_snapshot(controller.visual_snapshot())

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_toggle_run()
		get_viewport().set_input_as_handled()

func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _choice(parent: Control, caption: String, items: Array[String]) -> OptionButton:
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = 160
	parent.add_child(column)
	column.add_child(_label(caption, 14))
	var choice: OptionButton = OptionButton.new()
	choice.custom_minimum_size.y = 44
	for item: String in items:
		choice.add_item(item)
	column.add_child(choice)
	return choice

func _change_controls(_index: int) -> void:
	controller.configure(_activity.selected, _drinking.selected, _kidney.selected == 0)

func _change_prediction(index: int) -> void:
	controller.prediction = "" if index == 0 else _prediction.get_item_text(index)

func _toggle_run() -> void:
	if controller.run_state == "running":
		controller.pause()
	else:
		controller.start()

func _restart() -> void:
	controller.restart()
	_prediction.select(0)
	_compare = false
	_update_snapshot(controller.snapshot())

func _keep(slot: String) -> void:
	controller.keep_run(slot)
	_update_snapshot(controller.snapshot())

func _toggle_compare() -> void:
	_compare = not _compare
	_update_snapshot(controller.snapshot())

func _clear() -> void:
	controller.clear_comparisons()
	_compare = false
	_update_snapshot(controller.snapshot())

func _select_graph(index: int) -> void:
	_concentration_graph.visible = index != 2
	_volume_graph.visible = index != 1

func _show_help() -> void:
	controller.pause()
	_help.popup_centered(Vector2i(720, 380))

func _update_run_state(value: String) -> void:
	_run.text = "Pause" if value == "running" else "Run / Resume"

func _update_snapshot(value: Dictionary) -> void:
	if value.is_empty():
		return
	_status.text = "%s · %.2f model time" % [controller.run_state.capitalize(), value.time]
	if not String(value.endpoint).is_empty() and value.endpoint != "duration":
		_status.text += " · Model stopped: " + String(value.endpoint).replace("_", " ")
	var gap: float = float(value.c_in) - float(value.c_out)
	var tonicity: String = "isotonic" if absf(gap) < 0.001 else ("hypotonic" if gap > 0 else "hypertonic")
	var direction: String = "balanced" if absf(gap) < 0.001 else ("into the cell" if gap > 0 else "out of the cell")
	_observations.text = "Outside %s relative to the current cell · Net water movement: %s\nOutside concentration %.3f · Inside %.3f · Cell volume %.1f%% of start" % [tonicity, direction, value.c_out, value.c_in, value.volume_ratio * 100.0]
	_feedback.text = "ADH signal %.1f%% → Kidney %s → Urine water output %.4f model units/time" % [value.h * 100.0, "adjusts water retention" if value.automatic else "response held fixed", value.urine_rate]
	var traces: Array[Dictionary] = []
	var labels: Array[String] = []
	for slot: String in ["A", "B"]:
		var record: Dictionary = controller.saved_run(slot)
		if not record.is_empty():
			labels.append(slot + ": kept")
			if _compare:
				traces.append({"samples": record.samples, "color": Color("f3ce78") if slot == "A" else Color("af9eeb"), "dashed": slot == "B"})
	if not _compare:
		traces.append({"samples": controller.samples, "color": Color("6ed5eb"), "dashed": false})
	_concentration_graph.traces = traces
	_volume_graph.traces = traces
	_concentration_graph.queue_redraw()
	_volume_graph.queue_redraw()
	_saved.text = ("Comparing A (gold solid) / B (purple dashed). " if _compare else "Live run. ") + ", ".join(labels) + " · Kept runs clear on page refresh/close. Keeping a slot replaces its previous run."

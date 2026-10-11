# === HEADER COMMENT ===
# Marathon Runner: Water Balance. One screen built in code: race controls, the runner's body (drink, sweat,
# blood, ADH, kidneys), a body cell, the blood-sodium gauge, two graphs over race time and the medical card.
# The model runs in WaterBalanceController; this view only reads its snapshots and sends control changes.
class_name MainView
extends Control

# === CONSTANTS ===
const Controller = preload("../controllers/simulation_controller.gd")
const BASE_SIZE: Vector2 = Vector2(1280.0, 720.0)
## Smallest UI scale in CSS px per base px: text never drops below about 85% in a small frame.
const MIN_UI_SCALE: float = 0.85
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
const RACE_HOURS: float = 4.0
const PACES: Array[String] = ["Walk", "Jog", "Run"]
const AMOUNTS: Array[String] = ["None", "A little", "Medium", "Lots"]
const DRINKS: Array[String] = ["Water", "Sports drink"]
const BG: Color = Color(0.06, 0.1, 0.15)
const PANEL: Color = Color(0.09, 0.14, 0.2)
const WATER_TEXT: Color = Color(0.5, 0.75, 1.0)
const SALT_TEXT: Color = Color(1.0, 0.85, 0.35)
const DIM_TEXT: Color = Color(0.6, 0.68, 0.76)
## Columns of the water and salt tally (amounts relative to the blood's starting water and salt, 1.00 each).
const TALLY_COLUMNS: Array[String] = ["So far", "Drunk", "Sweat", "Urine", "Blood now"]

# === PUBLIC VARIABLES ===
var controller: Controller
var keyboard: KeyboardNav
var pace_buttons: Array[Button] = []
var amount_buttons: Array[Button] = []
var drink_buttons: Array[Button] = []
var run_button: Button
var restart_button: Button
var speed_button: Button
var keep_button: Button
var clear_button: Button
var body: BodyView
var cell: CellView
var gauge: SodiumGauge
var sodium_graph: RaceGraph
var size_graph: RaceGraph
## Tally values: [row][column - 1], rows water then salt; columns drunk, sweat, urine, blood now.
var tally_cells: Array[Array] = []
var saltiness: Label

# === PRIVATE VARIABLES ===
var _speed_index: int = 0
var _status: Label
var _observation: Label
var _applying_scale: bool = false


# === LIFECYCLE METHODS ===
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controller = Controller.new()
	controller.name = "Controller"
	add_child(controller)
	# The view drives time itself, so the speed button can run several model steps per frame
	controller.set_process(false)
	controller.activity = 2
	controller.drinking = 2
	controller.restart()
	_build()
	controller.snapshot_updated.connect(_on_snapshot)
	controller.run_state_changed.connect(_on_run_state)
	get_tree().root.size_changed.connect(_apply_scale)
	_apply_scale()
	_sync_toggles()
	_on_run_state(controller.run_state)
	_on_snapshot(controller.snapshot())


func _process(delta: float) -> void:
	controller.advance(delta * SPEEDS[_speed_index])


# === PUBLIC METHODS ===
func race_clock(model_time: float, duration: float) -> String:
	var hours: float = model_time / duration * RACE_HOURS
	var whole: int = int(hours)
	return "%d:%02d" % [whole, int((hours - float(whole)) * 60.0)]


func toggle_run() -> void:
	if controller.run_state == "running":
		controller.pause()
	elif controller.run_state == "finished":
		controller.restart()
		controller.start()
	else:
		controller.start()


func set_pace(index: int) -> void:
	_configure(index, controller.drinking, controller.drink_type)


func set_amount(index: int) -> void:
	_configure(controller.activity, index, controller.drink_type)


func set_drink(index: int) -> void:
	_configure(controller.activity, controller.drinking, index)


func keep_run() -> void:
	if controller.keep_run("A"):
		_refresh_graphs()
		clear_button.disabled = false


func clear_kept() -> void:
	controller.clear_comparisons()
	clear_button.disabled = true
	_refresh_graphs()


# === PRIVATE METHODS ===
func _configure(activity: int, drinking: int, drink_type: int) -> void:
	# After the race ends, a new choice starts a fresh race with it
	if controller.run_state == "finished":
		controller.restart()
	controller.configure(activity, drinking, true, drink_type)
	_sync_toggles()


func _sync_toggles() -> void:
	for i: int in range(pace_buttons.size()):
		pace_buttons[i].set_pressed_no_signal(i == controller.activity)
	for i: int in range(amount_buttons.size()):
		amount_buttons[i].set_pressed_no_signal(i == controller.drinking)
	for i: int in range(drink_buttons.size()):
		drink_buttons[i].set_pressed_no_signal(i == controller.drink_type)
	var params: ModelParameters = ModelParameters.new()
	body.drink_rate = params.drinking_rates[controller.drinking]
	body.drink_type = controller.drink_type
	body.sweat_rate = params.sweat_rates[controller.activity]
	body.pace = controller.activity
	body.max_urine_rate = params.u_max
	body.max_drink_rate = params.drinking_rates[params.drinking_rates.size() - 1]


func _on_run_state(state: String) -> void:
	run_button.text = "Pause" if state == "running" else ("Run again" if state == "finished" else ("Resume" if controller.samples.size() > 1 else "Start race"))
	keep_button.disabled = controller.samples.size() <= 1


func _on_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	var shown: Dictionary = controller.visual_snapshot()
	body.show_snapshot(shown)
	cell.show_snapshot(shown)
	gauge.show_snapshot(shown)
	var duration: float = ModelParameters.new().duration
	var state_text: String = {"ready": "Ready", "running": "Racing", "paused": "Paused", "finished": "Race over"}.get(controller.run_state, "")
	_status.text = "Race clock %s of %d:00  ·  %s" % [race_clock(float(snap.time), duration), int(RACE_HOURS), state_text]
	_observation.text = _observe(shown)
	_show_tally(shown)
	keep_button.disabled = controller.samples.size() <= 1
	_refresh_graphs()


## Plain-language description of what the model is doing now.
func _observe(snap: Dictionary) -> String:
	var c: float = float(snap.get("c_out", 1.0))
	var blood: String = "Blood is saltier than at the start" if c > 1.005 else ("Blood is more diluted than at the start" if c < 0.995 else "Blood is about as salty as at the start")
	var flow: String = CellView.net_water(snap)
	var cells: String = "water moves into the cells, so they swell" if flow == "in" else ("water moves out of the cells, so they shrink" if flow == "out" else "no net water moves into or out of the cells")
	var h: float = float(snap.get("h", 0.0))
	var kidneys: String = "ADH is high, so the kidneys keep water (little urine)" if h > 0.85 else ("ADH is low, so the kidneys release water (more urine)" if h < 0.5 else "ADH is medium")
	if h < 0.05 and c < 0.97:
		kidneys = "ADH is off and the kidneys are at their limit: she drinks more than they can remove"
	return "%s; %s. %s." % [blood, cells, kidneys]


## Water and salt in and out so far, and blood saltiness as salt / water: a runner can lose more salt
## than a walker and still have saltier blood, because sweat carries out even more water.
func _show_tally(snap: Dictionary) -> void:
	var rows: Array[Array] = [
		[float(snap.get("absorbed_water", 0.0)), float(snap.get("sweat_water", 0.0)), float(snap.get("urine_water", 0.0)), float(snap.get("w_out", 1.0))],
		[float(snap.get("absorbed_solute", 0.0)), float(snap.get("sweat_solute", 0.0)), float(snap.get("urine_solute", 0.0)), float(snap.get("s_out", 1.0))],
	]
	for r: int in range(rows.size()):
		for c: int in range(4):
			var v: float = float(rows[r][c])
			var cell_label: Label = tally_cells[r][c]
			if c == 3:
				cell_label.text = "%.2f" % v
			elif v < 0.005:
				cell_label.text = "0"
			else:
				cell_label.text = ("+%.2f" if c == 0 else "-%.2f") % v
	var w: float = float(snap.get("w_out", 1.0))
	var s: float = float(snap.get("s_out", 1.0))
	saltiness.text = "Blood saltiness = salt / water = %.2f / %.2f = %.2f  (start: 1.00)" % [s, w, s / w]


func _refresh_graphs() -> void:
	var kept: Array[Dictionary] = []
	var saved: Dictionary = controller.saved_run("A")
	if not saved.is_empty():
		kept.assign(saved.samples)
	sodium_graph.set_samples(controller.samples, kept)
	size_graph.set_samples(controller.samples, kept)


## Keeps text readable in a small frame (an iframe 360 px tall, a phone): the base view grows instead of
## shrinking below MIN_UI_SCALE, the panels wrap (HFlowContainer) and the page scrolls.
func _apply_scale() -> void:
	if _applying_scale:
		return
	_applying_scale = true
	var win: Window = get_window()
	var window_size: Vector2 = Vector2(win.size)
	if window_size.x >= 1.0 and window_size.y >= 1.0:
		var fit: float = minf(window_size.x / BASE_SIZE.x, window_size.y / BASE_SIZE.y)
		var s: float = maxf(fit, MIN_UI_SCALE * DisplayServer.screen_get_scale())
		win.content_scale_size = Vector2i((window_size / s).floor())
	_applying_scale = false


func _label(text: String, font_size: int = 15) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _button(text: String, toggle: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 15)
	return b


func _toggle_row(parent: Control, title: String, names: Array[String], into: Array[Button], handler: Callable) -> void:
	parent.add_child(_label(title))
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in range(names.size()):
		var b: Button = _button(names[i], true)
		b.button_group = group
		# The chosen option is filled in a bright colour, unlike the dark default pressed look
		var chosen: StyleBoxFlat = StyleBoxFlat.new()
		chosen.bg_color = Color(0.2, 0.55, 0.75)
		chosen.set_corner_radius_all(4)
		chosen.set_border_width_all(2)
		chosen.border_color = Color(0.75, 0.9, 1.0)
		for state: String in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, chosen)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		b.pressed.connect(handler.bind(i))
		row.add_child(b)
		into.append(b)


func _panel(min_size: Vector2) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", style)
	p.custom_minimum_size = min_size
	return p


func _build_tally(parent: Control) -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = TALLY_COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 0)
	parent.add_child(grid)
	for title: String in TALLY_COLUMNS:
		var head: Label = _label(title, 13)
		head.add_theme_color_override("font_color", DIM_TEXT)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if title != "So far" else HORIZONTAL_ALIGNMENT_LEFT
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(head)
	tally_cells.clear()
	for row: Array in [["Water", WATER_TEXT], ["Salt", SALT_TEXT]]:
		var name_label: Label = _label(String(row[0]), 15)
		name_label.add_theme_color_override("font_color", row[1])
		grid.add_child(name_label)
		var cells: Array[Label] = []
		for c: int in range(4):
			var value: Label = _label("", 15)
			value.add_theme_color_override("font_color", row[1])
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(value)
			cells.append(value)
		tally_cells.append(cells)
	saltiness = _label("", 13)
	saltiness.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	saltiness.custom_minimum_size = Vector2(340, 0)
	parent.add_child(saltiness)


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	scroll.add_child(margin)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	var header: HFlowContainer = HFlowContainer.new()
	page.add_child(header)
	var title: Label = _label("Marathon Runner: Water Balance", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var hint: Label = _label("Space: start / pause   ·   Tab: buttons   ·   Esc: leave", 13)
	hint.modulate = Color(1, 1, 1, 0.75)
	header.add_child(hint)

	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	page.add_child(row)

	# Controls
	var controls_panel: PanelContainer = _panel(Vector2(330, 0))
	controls_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(controls_panel)
	var controls: VBoxContainer = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	controls_panel.add_child(controls)
	_toggle_row(controls, "Pace", PACES, pace_buttons, set_pace)
	_toggle_row(controls, "How much the runner drinks", AMOUNTS, amount_buttons, set_amount)
	_toggle_row(controls, "What the runner drinks", DRINKS, drink_buttons, set_drink)
	var run_row: HBoxContainer = HBoxContainer.new()
	controls.add_child(run_row)
	run_button = _button("Start race")
	run_button.pressed.connect(toggle_run)
	run_row.add_child(run_button)
	restart_button = _button("Restart")
	restart_button.pressed.connect(controller.restart)
	run_row.add_child(restart_button)
	speed_button = _button("Speed 1x")
	speed_button.pressed.connect(_on_speed)
	run_row.add_child(speed_button)
	var keep_row: HBoxContainer = HBoxContainer.new()
	controls.add_child(keep_row)
	keep_button = _button("Keep this run")
	keep_button.tooltip_text = "Keep this run's graph lines to compare with the next run"
	keep_button.pressed.connect(keep_run)
	keep_row.add_child(keep_button)
	clear_button = _button("Clear kept run")
	clear_button.disabled = true
	clear_button.pressed.connect(clear_kept)
	keep_row.add_child(clear_button)
	_status = _label("", 15)
	controls.add_child(_status)

	# Body diagram and what is happening
	var body_panel: PanelContainer = _panel(Vector2(380, 0))
	body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body_panel)
	var body_box: VBoxContainer = VBoxContainer.new()
	body_panel.add_child(body_box)
	body = BodyView.new()
	body.custom_minimum_size = Vector2(360, 230)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.add_child(body)
	_build_tally(body_box)
	_observation = _label("", 15)
	_observation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_observation.custom_minimum_size = Vector2(340, 44)
	body_box.add_child(_observation)

	# Cell, sodium gauge and the curriculum's medical data
	var right_panel: PanelContainer = _panel(Vector2(330, 0))
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right_panel)
	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right_panel.add_child(right)
	cell = CellView.new()
	cell.custom_minimum_size = Vector2(310, 200)
	right.add_child(cell)
	gauge = SodiumGauge.new()
	gauge.custom_minimum_size = Vector2(310, 98)
	right.add_child(gauge)
	var card: Label = _label("Medical data: normal blood sodium is 135-145 mEq/L (New Visions Biology, Marathon Runner). Compare the runner's Medical Tent Data.", 13)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.custom_minimum_size = Vector2(310, 0)
	right.add_child(card)

	# Graphs over race time
	var graphs: HFlowContainer = HFlowContainer.new()
	graphs.add_theme_constant_override("h_separation", 8)
	graphs.add_theme_constant_override("v_separation", 8)
	page.add_child(graphs)
	var duration: float = ModelParameters.new().duration
	sodium_graph = RaceGraph.new()
	sodium_graph.title = "Blood sodium (mEq/L, illustrative)"
	sodium_graph.key = "c_out"
	sodium_graph.scale_value = SodiumGauge.START_MEQ
	sodium_graph.y_min = 110.0
	sodium_graph.y_max = 170.0
	sodium_graph.y_ticks.assign([120.0, 140.0, 160.0])
	sodium_graph.start_value = SodiumGauge.START_MEQ
	sodium_graph.band = Vector2(SodiumGauge.NORMAL_LOW, SodiumGauge.NORMAL_HIGH)
	sodium_graph.band_label = "normal 135-145"
	sodium_graph.duration = duration
	sodium_graph.custom_minimum_size = Vector2(380, 190)
	sodium_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphs.add_child(sodium_graph)
	size_graph = RaceGraph.new()
	size_graph.title = "Cell size (% of start)"
	size_graph.key = "volume_ratio"
	size_graph.scale_value = 100.0
	size_graph.y_min = 80.0
	size_graph.y_max = 120.0
	size_graph.y_ticks.assign([80.0, 100.0, 120.0])
	size_graph.start_value = 100.0
	size_graph.duration = duration
	size_graph.custom_minimum_size = Vector2(380, 190)
	size_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphs.add_child(size_graph)

	var note: Label = _label("A simplified model: its numbers and the 4-hour race clock are illustrative, not medical measurements.", 13)
	note.modulate = Color(1, 1, 1, 0.7)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)

	keyboard = KeyboardNav.new()
	keyboard.name = "KeyboardNav"
	add_child(keyboard)
	var order: Array[Control] = []
	for list: Array[Button] in [pace_buttons, amount_buttons, drink_buttons]:
		order.append_array(list)
	order.append_array([run_button, restart_button, speed_button, keep_button, clear_button])
	keyboard.setup(order)
	keyboard.space_pressed.connect(toggle_run)


func _on_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	speed_button.text = "Speed %dx" % int(SPEEDS[_speed_index])

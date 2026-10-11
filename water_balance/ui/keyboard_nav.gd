# === HEADER COMMENT ===
# Keyboard use and the keyboard exit for sims.mr-miner.com (sims-site SPEC section 6): Tab walks the controls
# in order; Tab past the last, Shift+Tab before the first, or Escape leave the game. With no control focused,
# Space runs or pauses the race. Lives in the main view.
class_name KeyboardNav
extends Node

# === SIGNALS ===
signal space_pressed

# === CONSTANTS ===
const FOCUS_COLOR: Color = Color(1.0, 0.85, 0.2)

# === PUBLIC VARIABLES ===
## Times the keyboard left the game; read by tests/run_ui_tests.gd.
var leave_count: int = 0

# === PRIVATE VARIABLES ===
var _controls: Array[Control] = []
var _ring: StyleBoxFlat


# === LIFECYCLE METHODS ===
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# === PUBLIC METHODS ===
## Controls in Tab order; each gets a bright focus outline. Call after the layout is final:
## focus_next / focus_previous are relative NodePaths and break if a control is moved afterwards.
func setup(controls: Array[Control]) -> void:
	_ring = StyleBoxFlat.new()
	_ring.draw_center = false
	_ring.border_color = FOCUS_COLOR
	_ring.set_border_width_all(3)
	_ring.set_corner_radius_all(4)
	_ring.set_expand_margin_all(2.0)
	_controls = controls
	for i: int in range(_controls.size()):
		var c: Control = _controls[i]
		c.focus_mode = Control.FOCUS_ALL
		c.focus_next = c.get_path_to(_controls[(i + 1) % _controls.size()])
		c.focus_previous = c.get_path_to(_controls[(i - 1 + _controls.size()) % _controls.size()])
		c.add_theme_stylebox_override("focus", _ring)


## Drops focus and asks the sims site's play page to take the keyboard back. On its own page there is no parent.
func leave_game() -> void:
	get_viewport().gui_release_focus()
	leave_count += 1
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
				"if (window.parent !== window) window.parent.postMessage({type: 'sims:leave-game'}, location.origin)")


# === PRIVATE METHODS ===
func _input(event: InputEvent) -> void:
	# In _input, not _unhandled_input: the GUI takes Tab for its own focus movement before that.
	if _controls.is_empty() or not (event is InputEventKey and event.pressed):
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	var leave: bool = false
	if event.is_action_pressed("ui_cancel"):
		leave = true
	# Exact match (third argument): without it ui_focus_next also matches Shift+Tab
	elif event.is_action_pressed("ui_focus_next", true, true):
		if focus == null:
			_controls[0].grab_focus()
			get_viewport().set_input_as_handled()
			return
		leave = focus == _controls[-1]
	elif event.is_action_pressed("ui_focus_prev", true, true):
		if focus == null:
			_controls[-1].grab_focus()
			get_viewport().set_input_as_handled()
			return
		leave = focus == _controls[0]
	if leave:
		leave_game()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	# A focused button takes Space itself (presses it), so this only runs with nothing focused
	if key != null and key.pressed and not key.echo and key.keycode == KEY_SPACE:
		space_pressed.emit()
		get_viewport().set_input_as_handled()

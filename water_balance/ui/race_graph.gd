# === HEADER COMMENT ===
# A line graph over race time: the current run as a solid line, a kept run as a dashed line, an optional
# shaded band (the normal blood-sodium range) and a dotted starting-value line. Reads samples; never steps.
class_name RaceGraph
extends Control

# === CONSTANTS ===
const PLOT_MARGIN_LEFT: float = 44.0
const PLOT_MARGIN_RIGHT: float = 12.0
const PLOT_MARGIN_TOP: float = 26.0
const PLOT_MARGIN_BOTTOM: float = 22.0
const LINE_COLOR: Color = Color(0.45, 0.8, 1.0)
const KEPT_COLOR: Color = Color(1.0, 0.75, 0.35)
const GRID_COLOR: Color = Color(1, 1, 1, 0.12)
const TEXT_COLOR: Color = Color(0.85, 0.9, 0.95)
const BAND_COLOR: Color = Color(0.35, 0.85, 0.45, 0.16)

# === PUBLIC VARIABLES ===
var title: String = ""
var key: String = "c_out"
## Converts a model value to the number shown on the axis (e.g. 140 x concentration for mEq/L).
var scale_value: float = 1.0
var y_min: float = 0.0
var y_max: float = 1.0
var y_ticks: Array[float] = []
var tick_format: String = "%.0f"
var start_value: float = 1.0
var band: Vector2 = Vector2.ZERO
var band_label: String = ""
var duration: float = 60.0
var hours: float = 4.0

# === PRIVATE VARIABLES ===
var _samples: Array[Dictionary] = []
var _kept: Array[Dictionary] = []
var _font: Font


# === LIFECYCLE METHODS ===
func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# === PUBLIC METHODS ===
func set_samples(samples: Array[Dictionary], kept: Array[Dictionary]) -> void:
	_samples = samples
	_kept = kept
	queue_redraw()


# === PRIVATE METHODS ===
func _plot_rect() -> Rect2:
	return Rect2(PLOT_MARGIN_LEFT, PLOT_MARGIN_TOP, maxf(10.0, size.x - PLOT_MARGIN_LEFT - PLOT_MARGIN_RIGHT),
			maxf(10.0, size.y - PLOT_MARGIN_TOP - PLOT_MARGIN_BOTTOM))


func _to_point(rect: Rect2, time: float, value: float) -> Vector2:
	var x: float = rect.position.x + rect.size.x * clampf(time / duration, 0.0, 1.0)
	var y: float = rect.end.y - rect.size.y * clampf((value - y_min) / (y_max - y_min), 0.0, 1.0)
	return Vector2(x, y)


func _line_points(rect: Rect2, samples: Array[Dictionary]) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for s: Dictionary in samples:
		points.append(_to_point(rect, float(s.time), float(s[key]) * scale_value))
	return points


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.12, 0.18, 0.95))
	var rect: Rect2 = _plot_rect()
	draw_string(_font, Vector2(8.0, 18.0), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, 15, TEXT_COLOR)
	if band != Vector2.ZERO:
		var top: Vector2 = _to_point(rect, 0.0, band.y)
		var bottom: Vector2 = _to_point(rect, 0.0, band.x)
		draw_rect(Rect2(rect.position.x, top.y, rect.size.x, bottom.y - top.y), BAND_COLOR)
		draw_string(_font, Vector2(rect.position.x + 6.0, top.y - 4.0), band_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.6, 0.95, 0.65))
	for tick: float in y_ticks:
		var p: Vector2 = _to_point(rect, 0.0, tick)
		draw_line(Vector2(rect.position.x, p.y), Vector2(rect.end.x, p.y), GRID_COLOR, 1.0)
		draw_string(_font, Vector2(2.0, p.y + 5.0), tick_format % tick, HORIZONTAL_ALIGNMENT_RIGHT, PLOT_MARGIN_LEFT - 6.0, 12, TEXT_COLOR)
	# Starting value: dotted
	var start_y: float = _to_point(rect, 0.0, start_value).y
	draw_dashed_line(Vector2(rect.position.x, start_y), Vector2(rect.end.x, start_y), Color(1, 1, 1, 0.35), 1.0, 3.0)
	# Hour marks along the time axis
	for h: int in range(int(hours) + 1):
		var x: float = rect.position.x + rect.size.x * float(h) / hours
		draw_line(Vector2(x, rect.end.y), Vector2(x, rect.end.y + 4.0), TEXT_COLOR, 1.0)
		draw_string(_font, Vector2(x - 20.0, rect.end.y + 17.0), "%d h" % h, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, TEXT_COLOR)
	draw_rect(rect, Color(1, 1, 1, 0.25), false, 1.0)
	# Kept run: dashed, labelled at its end (so it is not told apart by colour alone)
	if _kept.size() >= 2:
		var kept_points: PackedVector2Array = _line_points(rect, _kept)
		for i: int in range(kept_points.size() - 1):
			if i % 2 == 0:
				draw_line(kept_points[i], kept_points[i + 1], KEPT_COLOR, 2.0)
		var end: Vector2 = kept_points[kept_points.size() - 1]
		draw_string(_font, end + Vector2(-58.0, -6.0), "kept run", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, KEPT_COLOR)
	if _samples.size() >= 2:
		draw_polyline(_line_points(rect, _samples), LINE_COLOR, 2.5, true)
		var newest: Dictionary = _samples[_samples.size() - 1]
		draw_circle(_to_point(rect, float(newest.time), float(newest[key]) * scale_value), 4.0, LINE_COLOR)

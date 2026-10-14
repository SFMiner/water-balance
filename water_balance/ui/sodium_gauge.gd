# === HEADER COMMENT ===
# Blood sodium on an illustrative mEq/L scale: 140 x the model's outside concentration (the start is 140).
# The shaded band is the curriculum's normal range, 135-145 mEq/L. The model's numbers are not medical data.
class_name SodiumGauge
extends Control

# === CONSTANTS ===
const START_MEQ: float = 140.0
const NORMAL_LOW: float = 135.0
const NORMAL_HIGH: float = 145.0
## Covers the collapse stops (110 and 170 mEq/L in model 0.5.0) with a margin.
const SCALE_MIN: float = 100.0
const SCALE_MAX: float = 180.0
const INK: Color = Color(0.88, 0.92, 0.96)
const BAND: Color = Color(0.35, 0.85, 0.45, 0.35)

# === PRIVATE VARIABLES ===
var _meq: float = START_MEQ
var _font: Font


# === LIFECYCLE METHODS ===
func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# === PUBLIC METHODS ===
static func to_meq(c_out: float) -> float:
	return START_MEQ * c_out


static func describe(meq: float) -> String:
	if meq < NORMAL_LOW:
		return "below the normal range"
	if meq > NORMAL_HIGH:
		return "above the normal range"
	return "in the normal range"


func show_snapshot(snap: Dictionary) -> void:
	_meq = to_meq(float(snap.get("c_out", 1.0)))
	queue_redraw()


# === PRIVATE METHODS ===
func _x(meq: float, bar: Rect2) -> float:
	return bar.position.x + bar.size.x * clampf((meq - SCALE_MIN) / (SCALE_MAX - SCALE_MIN), 0.0, 1.0)


func _draw() -> void:
	draw_string(_font, Vector2(0, 18.0), "Blood sodium: %d mEq/L" % int(round(_meq)), HORIZONTAL_ALIGNMENT_LEFT, size.x, 16, INK)
	draw_string(_font, Vector2(0, 38.0), describe(_meq).capitalize().substr(0, 1) + describe(_meq).substr(1),
			HORIZONTAL_ALIGNMENT_LEFT, size.x, 14, Color(0.6, 0.95, 0.65) if describe(_meq) == "in the normal range" else Color(1.0, 0.8, 0.5))
	var bar: Rect2 = Rect2(8.0, 58.0, size.x - 16.0, 18.0)
	draw_rect(bar, Color(0.12, 0.18, 0.26))
	draw_rect(Rect2(_x(NORMAL_LOW, bar), bar.position.y, _x(NORMAL_HIGH, bar) - _x(NORMAL_LOW, bar), bar.size.y), BAND)
	draw_rect(bar, INK, false, 1.0)
	for tick: float in [100.0, 120.0, 140.0, 160.0, 180.0]:
		var x: float = _x(tick, bar)
		draw_line(Vector2(x, bar.end.y), Vector2(x, bar.end.y + 4.0), INK, 1.0)
		draw_string(_font, Vector2(x - 15.0, bar.end.y + 17.0), "%d" % int(tick), HORIZONTAL_ALIGNMENT_CENTER, 30.0, 11, INK)
	draw_string(_font, Vector2(_x(NORMAL_HIGH, bar) + 4.0, bar.position.y - 3.0), "normal 135-145", HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, 11, Color(0.6, 0.95, 0.65))
	# Marker: a triangle pointer and a line (position, not colour, carries the reading)
	var mx: float = _x(_meq, bar)
	draw_line(Vector2(mx, bar.position.y - 2.0), Vector2(mx, bar.end.y + 2.0), Color.WHITE, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(mx, bar.position.y + 2.0), Vector2(mx - 7.0, bar.position.y - 9.0), Vector2(mx + 7.0, bar.position.y - 9.0)]), Color.WHITE)

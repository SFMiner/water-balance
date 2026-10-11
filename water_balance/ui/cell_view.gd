# === HEADER COMMENT ===
# One body cell next to the blood: a dashed outline of its starting size, the cell now (size changes drawn
# 2x larger than modelled, as the label says), its fixed salt, and arrows for the net water movement.
class_name CellView
extends Control

# === CONSTANTS ===
const INK: Color = Color(0.88, 0.92, 0.96)
const DIM: Color = Color(0.6, 0.68, 0.76)
const WATER: Color = Color(0.35, 0.65, 1.0)
const SALT: Color = Color(1.0, 0.85, 0.25)
const SALT_EDGE: Color = Color(0.25, 0.2, 0.05)
const EXAGGERATION: float = 2.0
## Inside and outside concentrations closer than this count as balanced.
const BALANCE_TOLERANCE: float = 0.002

# === PRIVATE VARIABLES ===
var _snapshot: Dictionary = {}
var _font: Font


# === LIFECYCLE METHODS ===
func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# === PUBLIC METHODS ===
func show_snapshot(next: Dictionary) -> void:
	_snapshot = next
	queue_redraw()


## "in", "out" or "balanced": where water is moving, from the inside/outside concentrations.
static func net_water(snap: Dictionary) -> String:
	var difference: float = float(snap.get("c_in", 1.0)) - float(snap.get("c_out", 1.0))
	if difference > BALANCE_TOLERANCE:
		return "in"
	if difference < -BALANCE_TOLERANCE:
		return "out"
	return "balanced"


# === PRIVATE METHODS ===
func _draw() -> void:
	if _snapshot.is_empty():
		return
	draw_string(_font, Vector2(0, 20.0), "A body cell", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, INK)
	var center: Vector2 = Vector2(size.x * 0.5, 30.0 + (size.y - 70.0) * 0.5)
	var r0: float = minf(size.x, size.y - 70.0) * 0.28
	var volume: float = float(_snapshot.get("volume_ratio", 1.0))
	var r: float = r0 * maxf(0.2, 1.0 + EXAGGERATION * (sqrt(volume) - 1.0))
	draw_circle(center, r, Color(0.25, 0.4, 0.55))
	draw_arc(center, r, 0.0, TAU, 64, INK, 2.5, true)
	# Starting size, dashed
	var segments: int = 40
	for i: int in range(segments):
		if i % 2 == 0:
			draw_arc(center, r0, TAU * float(i) / float(segments), TAU * float(i + 1) / float(segments), 4, Color(1, 1, 1, 0.55), 1.5)
	# The cell's salt never leaves; the same diamonds spread out or crowd together
	var count: int = 10
	for i: int in range(count):
		var angle: float = TAU * float(i) / float(count) + 0.3
		var p: Vector2 = center + Vector2(cos(angle), sin(angle)) * r * (0.35 + 0.3 * float(i % 2))
		var pts: PackedVector2Array = PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)])
		draw_colored_polygon(pts, SALT)
		pts.append(pts[0])
		draw_polyline(pts, SALT_EDGE, 1.0)
	# Net water movement arrows
	var flow: String = net_water(_snapshot)
	if flow != "balanced":
		for angle: float in [PI, 0.0, -PI * 0.5]:
			var dir: Vector2 = Vector2(cos(angle), sin(angle))
			var outer: Vector2 = center + dir * (r + 34.0)
			var inner: Vector2 = center + dir * (r + 6.0)
			var from: Vector2 = outer if flow == "in" else inner
			var to: Vector2 = inner if flow == "in" else outer
			draw_line(from, to, WATER, 4.0)
			var d: Vector2 = (to - from).normalized()
			var side: Vector2 = Vector2(-d.y, d.x) * 7.0
			draw_colored_polygon(PackedVector2Array([to, to - d * 11.0 + side, to - d * 11.0 - side]), WATER)
	var status: String = "Water moving into the cell" if flow == "in" else ("Water moving out of the cell" if flow == "out" else "No net water movement")
	var size_text: String = "Cell size %d%% of start" % int(round(volume * 100.0))
	draw_string(_font, Vector2(0, size.y - 34.0), status, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, INK)
	draw_string(_font, Vector2(0, size.y - 16.0), size_text + "  (size change drawn 2x)", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, DIM)

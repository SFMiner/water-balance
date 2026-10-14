# === HEADER COMMENT ===
# The runner's body as a flow diagram: drink in, sweat out, blood (fluid outside cells) with its water and
# salt, the brain's ADH signal and the kidneys' urine. Drawn from a model snapshot; never changes the model.
# Laid out in a 600 x 380 design space and scaled to fit.
class_name BodyView
extends Control

# === CONSTANTS ===
const DESIGN: Vector2 = Vector2(600.0, 380.0)
const WATER: Color = Color(0.35, 0.65, 1.0)
const SALT: Color = Color(1.0, 0.85, 0.25)
const SALT_EDGE: Color = Color(0.25, 0.2, 0.05)
const ADH: Color = Color(0.75, 0.5, 1.0)
const INK: Color = Color(0.88, 0.92, 0.96)
const DIM: Color = Color(0.6, 0.68, 0.76)
const COLLAPSED: Color = Color(1.0, 0.55, 0.45)
const BLOOD_RECT: Rect2 = Rect2(200.0, 150.0, 230.0, 160.0)
## Salt diamonds drawn per unit of outside solute (the starting blood has 1 unit).
const SALT_PER_UNIT: float = 22.0

# === PUBLIC VARIABLES ===
var snapshot: Dictionary = {}
var drink_rate: float = 0.0
var drink_type: int = 0
var sweat_rate: float = 0.0
var pace: int = 0
var max_urine_rate: float = 0.012
var max_drink_rate: float = 0.021

# === PRIVATE VARIABLES ===
var _font: Font
var _salt_spots: Array[Vector2] = []


# === LIFECYCLE METHODS ===
func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fixed scatter, so salt diamonds do not jump around between frames
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in range(80):
		_salt_spots.append(Vector2(rng.randf(), rng.randf()))


# === PUBLIC METHODS ===
func show_snapshot(next: Dictionary) -> void:
	snapshot = next
	queue_redraw()


# === PRIVATE METHODS ===
func _text(pos: Vector2, text: String, font_size: int = 15, color: Color = INK, width: float = -1.0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_font, pos, text, align, width, font_size, color)


func _diamond(center: Vector2, r: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])
	draw_colored_polygon(pts, SALT)
	pts.append(pts[0])
	draw_polyline(pts, SALT_EDGE, 1.0)


func _drop(center: Vector2, r: float) -> void:
	draw_circle(center, r, WATER)


## Arrow whose dashes move along it while the race runs (by model time, so pause freezes it).
func _flow_arrow(from: Vector2, to: Vector2, strength: float, color: Color) -> void:
	if strength <= 0.0:
		draw_dashed_line(from, to, Color(color, 0.25), 2.0, 6.0)
		return
	var width: float = 2.0 + 8.0 * clampf(strength, 0.0, 1.0)
	var dir: Vector2 = (to - from).normalized()
	var length: float = from.distance_to(to)
	var phase: float = fmod(float(snapshot.get("time", 0.0)) * 12.0, 16.0)
	var d: float = phase - 16.0
	while d < length - 12.0:
		var a: float = maxf(d, 0.0)
		var b: float = minf(d + 9.0, length - 12.0)
		if b > a:
			draw_line(from + dir * a, from + dir * b, color, width)
		d += 16.0
	var tip: Vector2 = to
	var side: Vector2 = Vector2(-dir.y, dir.x) * (width + 5.0)
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 14.0 + side, tip - dir * 14.0 - side]), color)


func _draw() -> void:
	if snapshot.is_empty():
		return
	var k: float = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	var offset: Vector2 = (size - DESIGN * k) * 0.5
	draw_set_transform(offset, 0.0, Vector2(k, k))
	_draw_runner()
	_draw_drink()
	_draw_sweat()
	_draw_blood()
	_draw_brain_and_adh()
	_draw_kidney()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_runner() -> void:
	# A simple runner: legs swing while running (pace 1) and stand still when stopped (pace 0)
	var t: float = float(snapshot.get("time", 0.0))
	var collapsed: bool = String(snapshot.get("endpoint", "")).begins_with("collapse_")
	var swing: float = sin(t * 6.0) * 0.65 if pace > 0 and not collapsed else 0.0
	var hip: Vector2 = Vector2(95.0, 205.0)
	var neck: Vector2 = Vector2(100.0, 120.0)
	draw_circle(Vector2(103.0, 95.0), 22.0, INK)
	draw_line(neck, hip, INK, 9.0)
	for s: float in [swing, -swing]:
		var knee: Vector2 = hip + Vector2(sin(s) * 40.0, cos(s) * 40.0)
		draw_line(hip, knee, INK, 8.0)
		draw_line(knee, knee + Vector2(sin(s - 0.5) * 38.0, cos(s - 0.5) * 38.0), INK, 7.0)
		var elbow: Vector2 = neck + Vector2(10.0, 8.0) + Vector2(-sin(s) * 30.0, cos(s) * 30.0)
		draw_line(neck + Vector2(0, 8), elbow, INK, 7.0)
		draw_line(elbow, elbow + Vector2(18.0, -16.0), INK, 6.0)
	var label: String = "Runner (collapsed)" if collapsed else ("Runner (running)" if pace > 0 else "Runner (stopped)")
	_text(Vector2(20.0, 345.0), label, 16, COLLAPSED if collapsed else INK, 150.0, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_drink() -> void:
	# Cup at the top; arrow into the blood
	var cup: Rect2 = Rect2(250.0, 20.0, 34.0, 44.0)
	draw_colored_polygon(PackedVector2Array([cup.position, cup.position + Vector2(cup.size.x, 0), cup.end, Vector2(cup.position.x + 4.0, cup.end.y)]),
			Color(0.8, 0.85, 0.9, 0.9))
	draw_rect(Rect2(cup.position + Vector2(3, 14), Vector2(28, 26)), WATER)
	if drink_type == 1:
		_diamond(cup.position + Vector2(17, 27), 5.0)
	var label: String = "Drinking: " + ("none" if drink_rate <= 0.0 else ("sports drink" if drink_type == 1 else "water"))
	_text(Vector2(295.0, 40.0), label, 15)
	if drink_rate > 0.0:
		_text(Vector2(295.0, 60.0), "water" + (" + a little salt" if drink_type == 1 else " only"), 13, DIM)
	_flow_arrow(Vector2(267.0, 70.0), Vector2(267.0, BLOOD_RECT.position.y - 4.0), drink_rate / max_drink_rate, WATER)


func _draw_sweat() -> void:
	# Sweat leaves through the skin: water and some salt
	var strength: float = sweat_rate / 0.008
	_flow_arrow(Vector2(BLOOD_RECT.position.x - 6.0, 250.0), Vector2(150.0, 285.0), strength, WATER)
	var t: float = float(snapshot.get("time", 0.0))
	var drops: int = 1 + int(round(strength * 3.0))
	for i: int in range(drops):
		var y: float = 230.0 + fmod(t * 20.0 + float(i) * 23.0, 70.0)
		_drop(Vector2(150.0 - float(i) * 9.0, y), 4.0)
	_diamond(Vector2(132.0, 300.0), 5.0)
	_text(Vector2(110.0, 325.0), "Sweat: water + salt", 13, DIM, 150.0, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_blood() -> void:
	var r: Rect2 = BLOOD_RECT
	draw_rect(r, Color(0.12, 0.18, 0.26))
	# Water level follows the amount of water (starting blood fills 60% of the box)
	var w: float = float(snapshot.get("w_out", 1.0))
	var level: float = clampf(0.6 * w, 0.05, 0.98)
	var water_rect: Rect2 = Rect2(r.position.x, r.end.y - r.size.y * level, r.size.x, r.size.y * level)
	draw_rect(water_rect, Color(WATER, 0.45))
	# Salt diamonds: their number follows the amount of salt, so crowding shows concentration
	var count: int = mini(_salt_spots.size(), int(round(float(snapshot.get("s_out", 1.0)) * SALT_PER_UNIT)))
	for i: int in range(count):
		var spot: Vector2 = _salt_spots[i]
		_diamond(water_rect.position + Vector2(8.0 + spot.x * (water_rect.size.x - 16.0), 8.0 + spot.y * maxf(water_rect.size.y - 16.0, 1.0)), 5.0)
	draw_rect(r, INK, false, 2.0)
	_text(r.position + Vector2(0, 20.0), "Blood (fluid outside cells)", 15, INK, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_brain_and_adh() -> void:
	# Brain (in the runner's head) sends the ADH signal to the kidneys
	draw_circle(Vector2(108.0, 90.0), 9.0, Color(0.95, 0.6, 0.75))
	var h: float = float(snapshot.get("h", 0.0))
	var meter: Rect2 = Rect2(460.0, 30.0, 26.0, 110.0)
	draw_rect(meter, Color(0.15, 0.12, 0.22))
	draw_rect(Rect2(meter.position.x, meter.end.y - meter.size.y * h, meter.size.x, meter.size.y * h), ADH)
	draw_rect(meter, INK, false, 1.5)
	_text(Vector2(430.0, 22.0), "ADH signal", 14, ADH, 90.0, HORIZONTAL_ALIGNMENT_CENTER)
	var level: String = "high" if h > 0.85 else ("medium" if h > 0.5 else "low")
	_text(Vector2(495.0, 80.0), level, 14, ADH)
	# Signal path: brain to kidney, purple dashes (a message, not water or salt)
	draw_dashed_line(Vector2(122.0, 86.0), Vector2(455.0, 86.0), Color(ADH, 0.7), 2.0, 5.0)
	draw_dashed_line(Vector2(473.0, 145.0), Vector2(473.0, 222.0), Color(ADH, 0.7), 2.0, 5.0)


func _draw_kidney() -> void:
	var c: Vector2 = Vector2(490.0, 250.0)
	draw_circle(c + Vector2(-9, 0), 20.0, Color(0.7, 0.35, 0.35))
	draw_circle(c + Vector2(9, 0), 20.0, Color(0.7, 0.35, 0.35))
	draw_circle(c + Vector2(14, 0), 9.0, Color(0.12, 0.18, 0.26))
	_text(c + Vector2(-60.0, -30.0), "Kidneys", 15, INK, 120.0, HORIZONTAL_ALIGNMENT_CENTER)
	_flow_arrow(Vector2(BLOOD_RECT.end.x + 4.0, 250.0), c + Vector2(-32.0, 0.0), 0.25, Color(0.6, 0.6, 0.6))
	var urine: float = float(snapshot.get("urine_rate", 0.0)) / max_urine_rate
	_flow_arrow(c + Vector2(0, 24.0), c + Vector2(0, 92.0), urine, Color(0.95, 0.9, 0.4))
	var amount: String = "a lot" if urine > 0.6 else ("some" if urine > 0.2 else "a little")
	_text(c + Vector2(-70.0, 112.0), "Urine: " + amount, 14, INK, 140.0, HORIZONTAL_ALIGNMENT_CENTER)

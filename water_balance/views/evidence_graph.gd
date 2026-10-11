# Shared axes preserve comparisons when students isolate one quantity.
extends Control

var quantity: String = "c_out"
var heading: String = "Outside concentration"
var traces: Array[Dictionary] = []
var duration: float = 60.0

func _ready() -> void:
	custom_minimum_size = Vector2(300, 145)
	resized.connect(queue_redraw)

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var plot: Rect2 = Rect2(44, 30, maxf(40, size.x - 58), maxf(40, size.y - 58))
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	draw_string(font, Vector2(12, 20), heading + " · relative units", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c9e8f0"))
	for level: float in [0.5, 1.0, 1.5]:
		var y: float = plot.end.y - (level - 0.5) * plot.size.y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color("344f60"))
		draw_string(font, Vector2(8, y + 5), "%.1f" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, Vector2(plot.position.x, size.y - 5), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, Vector2(plot.end.x - 115, size.y - 5), "%.0f model time" % duration, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(font, Vector2(plot.position.x + 4, plot.get_center().y - 4), "Starting value", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9cb0bd"))
	for trace: Dictionary in traces:
		var samples: Array = trace.samples
		var color: Color = trace.color
		for index: int in range(1, samples.size()):
			var a: Vector2 = _point(samples[index - 1], plot)
			var b: Vector2 = _point(samples[index], plot)
			if trace.dashed:
				draw_dashed_line(a, b, color, 2.0, 4.0)
			else:
				draw_line(a, b, color, 2.0, true)

func _point(sample: Dictionary, plot: Rect2) -> Vector2:
	return Vector2(plot.position.x + float(sample.time) / duration * plot.size.x, plot.end.y - (float(sample[quantity]) - 0.5) * plot.size.y)

func _background() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("172b3c")
	style.corner_radius_top_left = 8
	style.corner_radius_bottom_right = 8
	return style

# Visual only: quantities always come from the conserved model snapshot.
extends Control

var current: Dictionary = {}
var cell_renderer_script: Script
var _legacy_cell: Node2D

func _ready() -> void:
	custom_minimum_size = Vector2(600, 245)
	if cell_renderer_script != null:
		_legacy_cell = cell_renderer_script.new() as Node2D
		add_child(_legacy_cell)
	resized.connect(queue_redraw)

func show_snapshot(value: Dictionary) -> void:
	current = value
	queue_redraw()
	if _legacy_cell != null:
		_legacy_cell.position = Vector2(size.x * 0.76, 125)
		_legacy_cell.call("set_neutral_size", 62.0, true)
		_legacy_cell.call("update_state", _radius(), 0.0, current.c_in, current.c_out)

func _radius() -> float:
	return 62.0 * (1.0 + 2.0 * (pow(float(current.volume_ratio), 1.0 / 3.0) - 1.0))

func _draw() -> void:
	if current.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var reservoir: Rect2 = Rect2(size.x * 0.07, 65, size.x * 0.33, 140)
	draw_rect(reservoir, Color("243e50"))
	var fill: float = clampf(float(current.w_out) / 2.0, 0.0, 1.0) * reservoir.size.y
	draw_rect(Rect2(reservoir.position.x, reservoir.end.y - fill, reservoir.size.x, fill), Color("286e8b"))
	draw_rect(reservoir, Color("79b7c8"), false, 2.0)
	draw_string(font, Vector2(reservoir.position.x, 48), "Fluid outside cells", HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
	draw_string(font, Vector2(reservoir.position.x, 100), "Water %.3f" % current.w_out, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	draw_string(font, Vector2(reservoir.position.x, 125), "Solute %.3f" % current.s_out, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	draw_string(font, Vector2(reservoir.position.x, 230), "Amounts in teaching units", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var center: Vector2 = Vector2(size.x * 0.76, 125)
	if _legacy_cell == null:
		draw_circle(center, _radius(), Color("244759"))
		draw_arc(center, _radius(), 0, TAU, 80, Color("5ac7d8"), 3.0, true)
		draw_arc(center, 62, 0, TAU, 80, Color("edc36f"), 2.0, true)
		draw_circle(center + Vector2(-10, -5), _radius() * 0.2, Color("9581bc"))
	draw_string(font, center + Vector2(-80, -90), "Representative cell", HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
	draw_string(font, center + Vector2(-110, 100), "Size changes exaggerated 2×", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var gap: float = float(current.c_in) - float(current.c_out)
	var left: Vector2 = Vector2(reservoir.end.x + 20, 140)
	var right: Vector2 = Vector2(center.x - 95, 140)
	draw_line(left, right, Color("86d8ed"), 3.0)
	if absf(gap) >= 0.001:
		var tip: Vector2 = right if gap > 0.0 else left
		var direction: float = -1.0 if gap > 0.0 else 1.0
		draw_line(tip, tip + Vector2(direction * 12, -8), Color("86d8ed"), 3.0)
		draw_line(tip, tip + Vector2(direction * 12, 8), Color("86d8ed"), 3.0)

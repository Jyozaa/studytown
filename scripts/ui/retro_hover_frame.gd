extends Control

var hovered := false
var selected := false

var base_color := Color("#203f72")
var selected_color := Color("#f7f7f7")
var runner_color := Color("#8fd4ff")

var border_width := 3.0
var phase := 0.0
var speed := 0.42


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_hovered(value: bool) -> void:
	if hovered == value:
		return

	hovered = value
	queue_redraw()


func set_selected(value: bool) -> void:
	if selected == value:
		return

	selected = value
	queue_redraw()


func _process(delta: float) -> void:
	if not hovered and not selected:
		return

	phase = fmod(
		phase + delta * speed,
		1.0
	)
	queue_redraw()


func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return

	var inset := border_width * 0.5 + 1.0
	var rect := Rect2(
		Vector2(inset, inset),
		size - Vector2(inset * 2.0, inset * 2.0)
	)

	draw_rect(
		rect,
		base_color,
		false,
		border_width,
		false
	)

	if selected:
		var pulse := 0.72 + sin(phase * TAU) * 0.16
		var selected_tint := selected_color
		selected_tint.a = pulse

		draw_rect(
			Rect2(
				rect.position + Vector2(3.0, 3.0),
				rect.size - Vector2(6.0, 6.0)
			),
			selected_tint,
			false,
			2.0,
			false
		)

	if not hovered:
		return

	var perimeter := (
		rect.size.x * 2.0
		+ rect.size.y * 2.0
	)

	if perimeter <= 0.0:
		return

	var start_distance := phase * perimeter
	var runner_length := minf(
		118.0,
		perimeter * 0.19
	)

	var step := 4.0
	var current := 0.0

	while current < runner_length:
		var p1 := _point_on_perimeter(
			start_distance + current,
			rect
		)

		var p2 := _point_on_perimeter(
			start_distance + current + step,
			rect
		)

		if p1.distance_to(p2) <= 8.0:
			draw_line(
				p1,
				p2,
				runner_color,
				5.0,
				false
			)

		current += step


func _point_on_perimeter(
	distance: float,
	rect: Rect2
) -> Vector2:
	var width := rect.size.x
	var height := rect.size.y
	var perimeter := width * 2.0 + height * 2.0

	if perimeter <= 0.0:
		return rect.position

	var d := fposmod(
		distance,
		perimeter
	)

	if d <= width:
		return rect.position + Vector2(d, 0.0)

	d -= width

	if d <= height:
		return rect.position + Vector2(width, d)

	d -= height

	if d <= width:
		return rect.position + Vector2(
			width - d,
			height
		)

	d -= width

	return rect.position + Vector2(
		0.0,
		height - d
	)

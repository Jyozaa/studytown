extends Control

# Small vector badges; no downloaded flag or reference artwork.
var country := "GB"


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("F4F5F7"))
	match country:
		"GB":
			draw_rect(rect, Color("315AA5"))
			draw_line(Vector2.ZERO, size, Color.WHITE, 4)
			draw_line(Vector2(size.x, 0), Vector2(0, size.y), Color.WHITE, 4)
			draw_rect(Rect2(0, size.y * 0.35, size.x, size.y * 0.3), Color.WHITE)
			draw_rect(Rect2(size.x * 0.38, 0, size.x * 0.24, size.y), Color.WHITE)
			draw_rect(Rect2(0, size.y * 0.43, size.x, size.y * 0.14), Color("DA5662"))
			draw_rect(Rect2(size.x * 0.45, 0, size.x * 0.1, size.y), Color("DA5662"))
		"FR":
			draw_rect(Rect2(0, 0, size.x / 3, size.y), Color("315AA5"))
			draw_rect(Rect2(size.x * 2 / 3, 0, size.x / 3, size.y), Color("DA5662"))
		"JP":
			draw_circle(size / 2, size.y * 0.29, Color("DA5662"))
		"DE":
			draw_rect(Rect2(0, 0, size.x, size.y / 3), Color("24242B"))
			draw_rect(Rect2(0, size.y / 3, size.x, size.y / 3), Color("DA5662"))
			draw_rect(Rect2(0, size.y * 2 / 3, size.x, size.y / 3), Color("EAB554"))
		"CA":
			draw_rect(Rect2(0, 0, size.x / 4, size.y), Color("DA5662"))
			draw_rect(Rect2(size.x * 0.75, 0, size.x / 4, size.y), Color("DA5662"))
			draw_circle(size / 2, size.y * 0.19, Color("DA5662"))
		"US":
			for i in 7:
				draw_rect(Rect2(0, i * size.y / 7, size.x, size.y / 14), Color("DA5662"))
			draw_rect(Rect2(0, 0, size.x * 0.42, size.y * 0.56), Color("315AA5"))

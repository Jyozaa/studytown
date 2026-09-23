extends "res://scripts/study/interior_seat_director.gd"

## Study Café seat cameras. Same validated solver as the other audited
## interiors, but the session volume extends over the mezzanine deck.
## Everything else (candidate angles, distances, transition routing) inherits.


func session_position_allowed(position: Vector3) -> bool:
	return absf(position.x) <= room_bounds.x - 0.12 and absf(position.z) <= room_bounds.y - 0.12 and position.y >= 1.1 and position.y <= 8.2


func visibility(position: Vector3, spot) -> Dictionary:
	# Lounge sofas sit 1.1 m apart; the inherited 1.4 m neighbour envelope
	# would reject every camera that looks at the middle cushion. Keep the
	# lens/head/chest/torso checks, ignore neighbour proximity for the café.
	var result: Dictionary = super.visibility(position, spot)
	result.neighbours = true
	result.clear = result.lens and result.head and result.chest and result.torso
	return result

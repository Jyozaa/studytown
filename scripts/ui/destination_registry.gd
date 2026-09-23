extends RefCounted
## Destination registry — data-driven StudyTown locations for the Map.
## Add future destinations here without rewriting the Map UI.

const DESTINATIONS := [
	{
		"id": "library",
		"room_index": 0,
		"room_name": "Grand Library",
		"display_name": "Grand Library",
		"description": "Tall glass hall in the evening forest. Communal tables, lounges, window bar.",
		"population": "24 studying",
		"accent": Color("#8A63C7"),
		"map_slot": 0,
	},
	{
		"id": "cafe",
		"room_index": 1,
		"room_name": "Garden Café",
		"display_name": "Garden Café",
		"description": "Sunset courtyard café. Round tables, window counter, mezzanine.",
		"population": "18 studying",
		"accent": Color("#E97838"),
		"map_slot": 1,
	},
	{
		"id": "train",
		"room_index": 2,
		"room_name": "Scenic Train",
		"display_name": "Scenic Train",
		"description": "Quiet carriage through the hills. Window booths both sides.",
		"population": "12 studying",
		"accent": Color("#45A0C4"),
		"map_slot": 2,
	},
]


static func all() -> Array:
	return DESTINATIONS.duplicate()


static func for_room_index(index: int) -> Dictionary:
	for destination in DESTINATIONS:
		if int(destination.room_index) == index:
			return destination
	return {}


static func for_id(destination_id: String) -> Dictionary:
	for destination in DESTINATIONS:
		if str(destination.id) == destination_id:
			return destination
	return {}

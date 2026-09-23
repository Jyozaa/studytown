class_name RoomDefinitions
extends RefCounted

const ROOMS := {
	0: {
		"id": "library",
		"size": Vector2(44.0, 32.0),
		"spawn": Vector3(0.0, 0.65, 10.0),
		"bounds": Vector2(21.2, 15.2),

		# Grand Library exploration camera.
		#
		# Slightly farther/higher than the previous framing so the two communal
		# tables, west-side stacks, fireplace destination, and east-window study
		# side can read together without making the player feel tiny.
		"camera_offset": Vector3(2.8, 8.5, 11.8),
		"camera_look_height": 1.55,
		"camera_fov": 41.0,
		"camera_damping": 7.2,
	},
	1: {
		"id": "garden",
		"size": Vector2(32.0, 24.0),
		"spawn": Vector3(0.0, 0.65, 9.0),
		"bounds": Vector2(15.5, 11.5),

		# Study Café exploration camera (replaces Garden; internal id kept
		# as "garden" so seat directors, previews and tests keep working).
		# Close intimate framing: the old outdoor offset left the player tiny.
		"camera_offset": Vector3(1.8, 6.8, 9.2),
		"camera_look_height": 1.50,
		"camera_fov": 40.0,
		"camera_damping": 7.5,
	},
	2: {
		"id": "train",
		"size": Vector2(11.0, 42.0),
		"spawn": Vector3(0.0, 0.65, 16.0),
		"bounds": Vector2(4.8, 20.2),
		# Lower over-the-shoulder trailing view (explicit user request differs
		# from Garden/Library here): stays behind the player while walking
		# the carriage, high enough to clear booths and NPC heads.
		"camera_offset": Vector3(1.4, 3.6, 6.4),
		"camera_look_height": 1.50,
		"camera_fov": 42.0,
		"camera_damping": 7.0,
	},
	3: {
		"id": "japanese",
		"size": Vector2(38.0, 30.0),
		"spawn": Vector3(0.0, 0.65, 10.0),
		"bounds": Vector2(18.2, 14.2),
		"camera_offset": Vector3(3.35, 7.5, 10.1),
		"camera_look_height": 1.52,
		"camera_fov": 38.0,
		"camera_damping": 7.5,
	},
}


static func get_room(index: int) -> Dictionary:
	return ROOMS.get(index, ROOMS[0]).duplicate(true)

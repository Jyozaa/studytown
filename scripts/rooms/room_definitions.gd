class_name RoomDefinitions
extends RefCounted

const ROOMS := {
	0: {
		"id": "library",
		"size": Vector2(44.0, 32.0),
		"spawn": Vector3(0.0, 0.65, 10.0),
		"bounds": Vector2(21.2, 15.2),
		"camera_offset": Vector3(3.6, 7.6, 10.3),
		"camera_look_height": 1.55,
		"camera_fov": 38.0,
		"camera_damping": 7.5,
	},
	1: {
		"id": "garden",
		"size": Vector2(52.0, 38.0),
		"spawn": Vector3(0.0, 0.65, 12.0),
		"bounds": Vector2(25.2, 18.2),

		# Cozy Garden exploration camera.
		#
		# Old:
		#   Vector3(3.9, 8.0, 11.0), FOV 39
		#
		# The smaller X moves the camera viewpoint slightly left.
		# The extra height/distance + 42° FOV pull the framing back enough to
		# show more of the Garden and its new forest edge without feeling tiny.
		"camera_offset": Vector3(2.2, 8.6, 12.4),
		"camera_look_height": 1.50,
		"camera_fov": 42.0,
		"camera_damping": 7.0,
	},
	2: {
		"id": "train",
		"size": Vector2(11.0, 42.0),
		"spawn": Vector3(0.0, 0.65, 16.0),
		"bounds": Vector2(4.8, 20.2),
		"camera_offset": Vector3(2.25, 6.0, 9.4),
		"camera_look_height": 1.50,
		"camera_fov": 38.0,
		"camera_damping": 8.2,
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

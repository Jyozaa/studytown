extends Node

const PRODUCT_NAME := "StudyTown"
const SAVE_PATH := "user://studytown_save.json"
const ROOMS := ["Grand Library", "Garden Café", "Scenic Train", "Japanese Study Room"]

var selected_character := 0
var selected_room := 0
var focus_coins := 0
var total_focus_minutes := 0
var completed_sessions := 0
var recent_sessions: Array = []

func _ready() -> void:
	load_save()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	selected_character = clampi(int(data.get("selected_character", 0)), 0, 2)
	selected_room = clampi(int(data.get("selected_room", 0)), 0, ROOMS.size() - 1)
	focus_coins = maxi(0, int(data.get("focus_coins", 0)))
	total_focus_minutes = maxi(0, int(data.get("total_focus_minutes", 0)))
	completed_sessions = maxi(0, int(data.get("completed_sessions", 0)))
	recent_sessions = data.get("recent_sessions", [])

func save() -> void:
	var data := {
		"selected_character": selected_character,
		"selected_room": selected_room,
		"focus_coins": focus_coins,
		"total_focus_minutes": total_focus_minutes,
		"completed_sessions": completed_sessions,
		"recent_sessions": recent_sessions.slice(0, 9),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))

func award_session(task: String, minutes: int, room_name: String) -> int:
	var reward := maxi(1, minutes) + (5 if minutes >= 25 else 0)
	focus_coins += reward
	total_focus_minutes += maxi(0, minutes)
	completed_sessions += 1
	recent_sessions.push_front({"task": task, "minutes": minutes, "room": room_name, "at": Time.get_unix_time_from_system()})
	save()
	return reward


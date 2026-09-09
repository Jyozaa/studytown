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
var onboarding_complete := false
var profile: Dictionary = {
	"name": "You", "username": "study_buddy", "subject": "Independent study", "country": "GB"
}
var preferences: Dictionary = {"vibe": "Lo-fi", "notifications": false, "deep_focus": false}
var tags: Array = ["Study", "Reading", "Work", "Creative"]
var current_focus := ""
var current_tag := "Study"
var persistence_enabled := true


func _ready() -> void:
	load_save()


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	selected_character = maxi(0, int(data.get("selected_character", 0)))
	selected_room = clampi(int(data.get("selected_room", 0)), 0, ROOMS.size() - 1)
	focus_coins = maxi(0, int(data.get("focus_coins", 0)))
	total_focus_minutes = maxi(0, int(data.get("total_focus_minutes", 0)))
	completed_sessions = maxi(0, int(data.get("completed_sessions", 0)))
	recent_sessions = data.get("recent_sessions", [])
	onboarding_complete = bool(data.get("onboarding_complete", false))
	profile.merge(data.get("profile", {}), true)
	preferences.merge(data.get("preferences", {}), true)
	tags.assign(data.get("tags", ["Study", "Reading", "Work", "Creative"]))
	if tags.is_empty():
		tags.append("Study")
	current_focus = str(data.get("current_focus", "")).left(120)
	current_tag = str(data.get("current_tag", tags[0]))
	if not tags.has(current_tag):
		current_tag = str(tags[0])


func save() -> void:
	if not persistence_enabled:
		return
	var data := {
		"onboarding_complete": onboarding_complete,
		"profile": profile,
		"preferences": preferences,
		"tags": tags,
		"current_focus": current_focus,
		"current_tag": current_tag,
		"selected_character": selected_character,
		"selected_room": selected_room,
		"focus_coins": focus_coins,
		"total_focus_minutes": total_focus_minutes,
		"completed_sessions": completed_sessions,
		"recent_sessions": recent_sessions.slice(0, 9),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))


func projected_reward(minutes: int) -> int:
	return maxi(0, minutes) + (5 if minutes >= 25 else 0)


func reset_onboarding() -> void:
	onboarding_complete = false
	save()


func streak_days() -> int:
	var days: Array[int] = []
	for session in recent_sessions:
		if int(session.get("minutes", 0)) > 0:
			var day := int(float(session.get("at", 0)) / 86400.0)
			if not days.has(day):
				days.append(day)
	days.sort()
	days.reverse()
	var expected := int(Time.get_unix_time_from_system() / 86400.0)
	if not days.is_empty() and days[0] == expected - 1:
		expected -= 1
	var streak := 0
	for day in days:
		if day != expected:
			break
		streak += 1
		expected -= 1
	return streak


func award_session(task: String, minutes: int, room_name: String, finished := true) -> int:
	var reward := projected_reward(minutes)
	focus_coins += reward
	total_focus_minutes += maxi(0, minutes)
	completed_sessions += 1 if finished else 0
	recent_sessions.push_front(
		{
			"task": task,
			"tag": current_tag,
			"minutes": minutes,
			"room": room_name,
			"completed": finished,
			"at": Time.get_unix_time_from_system()
		}
	)
	save()
	return reward

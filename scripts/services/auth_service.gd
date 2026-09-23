extends RefCounted
## AuthService — clean abstraction for StudyTown authentication.
##
## There is NO production authentication backend in this project. The only
## bundled adapter is an explicitly labelled LOCAL DEV adapter that stores a
## salted SHA-256 password hash in user:// (never plaintext, never logged).
## DO NOT treat dev-adapter credentials as a production account system.
## A future production adapter (if ever approved) implements this same
## interface: connect_adapter(), create_account(), sign_in(), sign_out().

const DEV_STORE := "user://studytown_auth_dev.json"

var last_error := ""


static func is_valid_email(email: String) -> bool:
	var cleaned := email.strip_edges()
	if cleaned.length() < 5 or cleaned.length() > 120:
		return false
	var parts := cleaned.split("@")
	if parts.size() != 2 or parts[0].is_empty() or parts[1].is_empty():
		return false
	return parts[1].contains(".") and not cleaned.contains(" ")


static func is_valid_password(password: String) -> bool:
	return password.length() >= 6


func _load_store() -> Dictionary:
	if not FileAccess.file_exists(DEV_STORE):
		return {}
	var file := FileAccess.open(DEV_STORE, FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if typeof(data) == TYPE_DICTIONARY else {}


func _save_store(data: Dictionary) -> bool:
	var file := FileAccess.open(DEV_STORE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


func _hash(password: String, salt: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(salt.to_utf8_buffer())
	context.update(password.to_utf8_buffer())
	return context.finish().hex_encode()


func create_account(email: String, password: String) -> Dictionary:
	last_error = ""
	var cleaned := email.strip_edges().to_lower()
	if not is_valid_email(cleaned):
		last_error = "Enter a valid email."
		return {}
	if not is_valid_password(password):
		last_error = "Password is too short."
		return {}
	var store := _load_store()
	if store.has(cleaned):
		last_error = "That email already has an account. Try logging in."
		return {}
	var salt := str(randi()) + str(Time.get_unix_time_from_system())
	store[cleaned] = {"salt": salt, "hash": _hash(password, salt), "dev": true}
	if not _save_store(store):
		last_error = "Couldn't create account. Try again."
		return {}
	# NOTE: password is never logged, printed, or persisted.
	return {"email": cleaned, "dev": true}


func sign_in(email: String, password: String) -> Dictionary:
	last_error = ""
	var cleaned := email.strip_edges().to_lower()
	if not is_valid_email(cleaned):
		last_error = "Enter a valid email."
		return {}
	if password.is_empty():
		last_error = "Enter your password."
		return {}
	var store := _load_store()
	if not store.has(cleaned):
		last_error = "No account found for that email."
		return {}
	var entry: Dictionary = store[cleaned]
	if _hash(password, str(entry.get("salt", ""))) != str(entry.get("hash", "")):
		last_error = "Wrong password. Try again."
		return {}
	return {"email": cleaned, "dev": true}


func sign_out() -> void:
	last_error = ""

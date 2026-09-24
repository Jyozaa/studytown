extends Node

## Café furniture availability highlight (no floor markers).
##
## Each available café seat brightens its OWN chair/stool/couch mesh via a
## shared translucent-white material_overlay. Base KayKit materials are never
## touched; only instance-level overlay assignment changes, and only when a
## seat's display state changes. One shared dim + one shared bright material
## breathe globally (~2 s sine); per-seat cost is a few Variant reads.
##
## Non-café seats are ignored here: their legacy disc glow (in
## seat_availability_glow.gd) keeps working exactly as before.

const FAR_CUTOFF := 14.0

var main_ref = null
var cafe_spots: Array = []
var spot_index := {}
# mesh instance id -> {"mesh": MeshInstance3D, "spots": Array}
var entries := {}
# mesh instance id -> last applied state (0 none, 1 dim, 2 bright)
var applied := {}
var dim_mat: StandardMaterial3D
var bright_mat: StandardMaterial3D

const DENY_SUBSTRINGS := [
	"table", "counter", "fridge", "stove", "shelf", "lamp", "menu", "mug",
	"laptop", "book", "plate", "jar", "pot", "dish", "sink", "rug", "candle",
	"glass", "beam", "railing", "stair", "step", "stringer", "wall", "floor",
	"ceiling", "couch_pillows_decor", "plant", "cactus", "bush", "tree",
	"rock", "grass", "car", "building", "road", "hydrant", "trash",
	"box", "dumpster", "bush", "pendant", "shade", "bulb", "cord", "beam",
	"sconce", "extractor", "hood", "cabinet", "island",
]


func setup(main_node) -> void:
	main_ref = main_node
	dim_mat = StandardMaterial3D.new()
	dim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dim_mat.albedo_color = Color(1, 1, 1, 0.14)
	bright_mat = StandardMaterial3D.new()
	bright_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bright_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bright_mat.albedo_color = Color(1, 1, 1, 0.32)
	for spot in main_ref.study_spots:
		var sid := str(spot.seat_id)
		if sid.begins_with("cafe-") or sid.begins_with("library-") or sid.begins_with("train-") or sid.begins_with("japanese-"):
			cafe_spots.append(spot)
	for spot in cafe_spots:
		var meshes := _resolve_seat_meshes(spot)
		for mesh: MeshInstance3D in meshes:
			var key: int = mesh.get_instance_id()
			if not entries.has(key):
				entries[key] = {"mesh": mesh, "spots": []}
			(entries[key]["spots"] as Array).append(spot)
	spot_index.clear()
	for i in (main_ref.study_spots as Array).size():
		spot_index[(main_ref.study_spots as Array)[i].get_instance_id()] = i
	print("SeatHighlightDriver: ", cafe_spots.size(), " furniture spots on ", entries.size(), " meshes")


func _seat_test_point(spot) -> Vector3:
	var facing: Vector3 = Basis(Vector3.UP, float(spot.facing_yaw)) * Vector3(0, 0, -1)
	return spot.sitting_position - facing * 0.25


func _mesh_denied(mi: MeshInstance3D) -> bool:
	var node: Node = mi
	while node != null and node != main_ref.world_root:
		if node is NPCController:
			return true
		if node is StudySpot:
			return true
		if node is Camera3D:
			return true
		var nm := str(node.name).to_lower()
		if nm == "available SeatCushion".to_lower() or nm == "availabilityglow":
			return true
		if "collisiondebug" in nm or "xray" in nm or "debugvisual" in nm or "debug" in nm:
			return true
		node = node.get_parent()
	var mn := str(mi.name).to_lower()
	for token in DENY_SUBSTRINGS:
		if token != "" and token in mn:
			return true
	return false


func _resolve_seat_meshes(spot) -> Array:
	var found := []
	var best_vol := INF
	var test: Vector3 = _seat_test_point(spot)
	for mi in main_ref.world_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi as MeshInstance3D
		if mesh.mesh == null:
			continue
		if not mesh.is_inside_tree():
			continue
		if _mesh_denied(mesh):
			continue
		var aabb := mesh.mesh.get_aabb()
		var t: Transform3D = mesh.global_transform
		var mn := Vector3(1e9, 1e9, 1e9)
		var mx := Vector3(-1e9, -1e9, -1e9)
		for c in 8:
			var corner := aabb.position + Vector3(aabb.size.x if c & 1 else 0.0, aabb.size.y if c & 2 else 0.0, aabb.size.z if c & 4 else 0.0)
			var w: Vector3 = t * corner
			mn = mn.min(w)
			mx = mx.max(w)
		# Small tolerance so sitters exactly on an edge still bind.
		if test.x < mn.x - 0.05 or test.x > mx.x + 0.05:
			continue
		if test.y < mn.y - 0.05 or test.y > mx.y + 0.05:
			continue
		if test.z < mn.z - 0.05 or test.z > mx.z + 0.05:
			continue
		var vol := (mx - mn).length()
		if vol < best_vol:
			best_vol = vol
			found = [mesh]
	return found


func mesh_spots(mesh: MeshInstance3D) -> Array:
	var key := mesh.get_instance_id()
	if entries.has(key):
		return entries[key]["spots"]
	return []


func bound_mesh(spot) -> MeshInstance3D:
	for key in entries:
		if spot in (entries[key]["spots"] as Array):
			return entries[key]["mesh"]
	return null


func report() -> Array:
	var lines := []
	for spot in cafe_spots:
		var mesh := bound_mesh(spot)
		lines.append("%s mesh=%s@%s sit=%s avail=%s" % [
			spot.seat_id,
			mesh.name if is_instance_valid(mesh) else "NONE",
			str(mesh.global_position) if is_instance_valid(mesh) else "-",
			str(spot.sitting_position),
			str(spot.is_available()),
		])
	return lines


func _highlights_visible() -> bool:
	# Single authoritative state owned by main.gd (setting + seated + suspended).
	# Interaction itself never depends on this.
	if main_ref.has_method("seat_highlights_allowed"):
		return main_ref.seat_highlights_allowed()
	if not bool(GameState.preferences.get("seat_availability_view", true)):
		return false
	if main_ref.get("seat_highlights_suspended") == true:
		return false
	return main_ref.get("active_study_spot") == null


func _clear_all() -> void:
	for key in entries:
		if applied.get(key, -1) == 0:
			continue
		applied[key] = 0
		var mesh: MeshInstance3D = entries[key]["mesh"]
		if is_instance_valid(mesh):
			mesh.material_overlay = null


func _process(_delta: float) -> void:
	if main_ref == null or not is_instance_valid(main_ref):
		return
	if not _highlights_visible():
		_clear_all()
		return
	# Global soft pulse (~2.1 s sine, never off, never flashing).
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 6.2831853 / 2100.0)
	dim_mat.albedo_color = Color(1, 1, 1, 0.16 + 0.12 * pulse)
	bright_mat.albedo_color = Color(1, 1, 1, 0.34 + 0.26 * pulse)
	var player_pos := Vector3(0, -100, 0)
	if is_instance_valid(main_ref.player):
		player_pos = (main_ref.player as Node3D).global_position
	var nearest := -1
	if main_ref.get("nearest_spot") != null:
		nearest = int(main_ref.get("nearest_spot"))
	for key in entries:
		var mesh: MeshInstance3D = entries[key]["mesh"]
		if not is_instance_valid(mesh):
			continue
		var state := 0
		for spot in entries[key]["spots"] as Array:
			if not is_instance_valid(spot) or not spot.is_available():
				continue
			if player_pos.distance_to(spot.sitting_position) > FAR_CUTOFF:
				continue
			state = maxi(state, 1)
			var idx := int(spot_index.get(spot.get_instance_id(), -1))
			if idx == nearest and idx >= 0:
				state = 2
		if applied.get(key, -1) == state:
			continue
		applied[key] = state
		if state == 2:
			mesh.material_overlay = bright_mat
		elif state == 1:
			mesh.material_overlay = dim_mat
		else:
			mesh.material_overlay = null

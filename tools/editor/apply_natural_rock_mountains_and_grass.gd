extends SceneTree

# StudyTown Garden mountain + grass cleanup.
#
# Safe one-time updater for the CURRENT editable garden.tscn.
#
# It does NOT change the current sunset WorldEnvironment or lights.
#
# It does:
#   - remove all old GardenGrassTile* visual meshes from the playable Garden
#   - create ONE PlayableGardenGrass mesh covering the full 52 x 38 m Garden
#   - assign the exact SAME Material resource used by ExtendedForestGround
#   - replace only the generated mountain children under GardenNaturalWorld/Mountains
#     with the three new Blender-built rock-shell mountain variants
#
# Existing props, fence, paths, pool, café, NPCs, study spots, lakes, waterfalls,
# forest trees, rocks and sunset lighting are left untouched.

const GARDEN_SCENE_PATH := "res://assets/dev_local/room_layouts/garden.tscn"
const BACKUP_DIR := "res://assets/dev_local/room_layouts/backups"

const OUTER_GROUND_NAME := "ExtendedForestGround"
const PLAYABLE_GRASS_NAME := "PlayableGardenGrass"
const NATURAL_WORLD_NAME := "GardenNaturalWorld"

const MOUNTAIN_PATHS := [
    "res://assets/dev_local/blender_generated/runtime/natural_rock_mountain_a.glb",
    "res://assets/dev_local/blender_generated/runtime/natural_rock_mountain_b.glb",
    "res://assets/dev_local/blender_generated/runtime/natural_rock_mountain_c.glb",
]

const PLAYABLE_GRASS_SIZE := Vector3(52.0, 0.10, 38.0)
const PLAYABLE_GRASS_Y := -0.045


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    print("")
    print("# STUDYTOWN — NATURAL ROCK MOUNTAINS + UNIFIED GRASS")
    print("")

    if not FileAccess.file_exists(GARDEN_SCENE_PATH):
        _fail("Editable garden.tscn does not exist.")
        return

    for path: String in MOUNTAIN_PATHS:
        if not ResourceLoader.exists(path):
            _fail(
                "Missing generated mountain asset: %s. Run the Blender mountain generator first."
                % path
            )
            return

    var packed := load(GARDEN_SCENE_PATH) as PackedScene
    if packed == null:
        _fail("Could not load garden.tscn.")
        return

    var garden_root := packed.instantiate()
    if garden_root == null or not (garden_root is Node3D):
        if garden_root != null:
            garden_root.free()
        _fail("Garden root is not Node3D.")
        return

    var backup_path := _backup_original()
    if backup_path.is_empty():
        garden_root.free()
        _fail("Could not create Garden backup.")
        return

    var outer_ground := _find_node_recursive(
        garden_root,
        OUTER_GROUND_NAME
    )

    if outer_ground == null or not (outer_ground is MeshInstance3D):
        garden_root.free()
        _fail("ExtendedForestGround was not found.")
        return

    var outer_material := _get_mesh_material(
        outer_ground as MeshInstance3D
    )

    if outer_material == null:
        garden_root.free()
        _fail("Could not read ExtendedForestGround material.")
        return

    var old_grass_nodes: Array[Node] = []
    _collect_old_playable_grass(
        garden_root,
        old_grass_nodes
    )

    # Also replace a previous run's single unified grass if present.
    var previous_unified := garden_root.get_node_or_null(
        PLAYABLE_GRASS_NAME
    )
    if previous_unified != null:
        old_grass_nodes.append(previous_unified)

    var removed_grass := 0
    for node: Node in old_grass_nodes:
        if not is_instance_valid(node):
            continue
        var parent := node.get_parent()
        if parent != null:
            parent.remove_child(node)
        node.free()
        removed_grass += 1

    var playable_grass := MeshInstance3D.new()
    playable_grass.name = PLAYABLE_GRASS_NAME
    playable_grass.position = Vector3(0.0, PLAYABLE_GRASS_Y, 0.0)
    playable_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    playable_grass.set_meta("studytown_single_playable_grass", true)
    playable_grass.set_meta("shares_outer_grass_material", true)

    var grass_mesh := BoxMesh.new()
    grass_mesh.size = PLAYABLE_GRASS_SIZE
    grass_mesh.material = outer_material
    playable_grass.mesh = grass_mesh

    garden_root.add_child(playable_grass)
    playable_grass.owner = garden_root

    var natural_world := garden_root.get_node_or_null(
        NATURAL_WORLD_NAME
    )
    if natural_world == null:
        garden_root.free()
        _fail("GardenNaturalWorld was not found. Run the natural-world pass first.")
        return

    var mountains := natural_world.get_node_or_null("Mountains")
    if mountains == null or not (mountains is Node3D):
        garden_root.free()
        _fail("GardenNaturalWorld/Mountains was not found.")
        return

    # Remove only the generated mountain children. Everything else in the world is retained.
    var removed_mountains := 0
    for child: Node in mountains.get_children():
        mountains.remove_child(child)
        child.free()
        removed_mountains += 1

    var mountain_scenes: Array[PackedScene] = []
    for path: String in MOUNTAIN_PATHS:
        mountain_scenes.append(load(path) as PackedScene)

    # Fewer, broader formations with intentional gaps so the Garden no longer looks like a crater.
    var placements := [
        [Vector3(-58.0, -0.35, -55.0), Vector3(2.15, 1.75, 1.80), 0.20, 0],
        [Vector3(-19.0, -0.35, -66.0), Vector3(2.45, 2.00, 1.90), -0.14, 1],
        [Vector3(31.0, -0.35, -62.0), Vector3(2.10, 1.72, 1.76), 0.10, 2],
        [Vector3(72.0, -0.35, -12.0), Vector3(2.30, 1.82, 1.82), -0.28, 1],
        [Vector3(50.0, -0.35, 60.0), Vector3(2.25, 1.78, 1.90), 0.16, 0],
        [Vector3(-6.0, -0.35, 70.0), Vector3(2.55, 2.08, 1.95), -0.09, 2],
        [Vector3(-66.0, -0.35, 43.0), Vector3(2.20, 1.80, 1.82), 0.31, 1],
    ]

    var created_mountains := 0

    for index in range(placements.size()):
        var data = placements[index]
        var variant_index := int(data[3])
        var scene := mountain_scenes[variant_index]

        if scene == null:
            continue

        var instance := scene.instantiate()
        if instance == null or not (instance is Node3D):
            if instance != null:
                instance.free()
            continue

        var mountain := instance as Node3D
        mountain.name = "NaturalRockMountain_%02d" % (index + 1)
        mountain.position = data[0] as Vector3
        mountain.scale = mountain.scale * (data[1] as Vector3)
        mountain.rotation.y = float(data[2])
        mountain.set_meta("studytown_natural_rock_mountain", true)

        mountains.add_child(mountain)
        mountain.owner = garden_root
        created_mountains += 1

    var repacked := PackedScene.new()
    var pack_error := repacked.pack(garden_root)

    if pack_error != OK:
        garden_root.free()
        _fail(
            "PackedScene.pack failed with error %d. Backup: %s"
            % [pack_error, backup_path]
        )
        return

    var save_error := ResourceSaver.save(
        repacked,
        GARDEN_SCENE_PATH
    )
    garden_root.free()

    if save_error != OK:
        _fail(
            "ResourceSaver.save failed with error %d. Backup: %s"
            % [save_error, backup_path]
        )
        return

    print("Old playable grass nodes removed: ", removed_grass)
    print("Single playable grass created:    true")
    print("Exact outer material shared:      true")
    print("Old mountains removed:            ", removed_mountains)
    print("Natural rock mountains created:   ", created_mountains)
    print("Backup:                           ", backup_path)
    print("")
    print("DONE")
    print("Sunset Environment/lights were NOT changed.")
    print("")
    quit(0)


func _collect_old_playable_grass(
    node: Node,
    result: Array[Node]
) -> void:
    if (
        node is MeshInstance3D
        and str(node.name).begins_with("GardenGrassTile")
    ):
        result.append(node)

    for child: Node in node.get_children():
        _collect_old_playable_grass(
            child,
            result
        )


func _get_mesh_material(
    mesh_instance: MeshInstance3D
) -> Material:
    if mesh_instance.material_override != null:
        return mesh_instance.material_override

    if mesh_instance.mesh == null:
        return null

    if mesh_instance.mesh is PrimitiveMesh:
        var primitive := mesh_instance.mesh as PrimitiveMesh
        if primitive.material != null:
            return primitive.material

    if mesh_instance.mesh.get_surface_count() > 0:
        return mesh_instance.mesh.surface_get_material(0)

    return null


func _find_node_recursive(
    node: Node,
    target_name: String
) -> Node:
    if str(node.name) == target_name:
        return node

    for child: Node in node.get_children():
        var found := _find_node_recursive(
            child,
            target_name
        )
        if found != null:
            return found

    return null


func _backup_original() -> String:
    var absolute_backup_dir := ProjectSettings.globalize_path(
        BACKUP_DIR
    )

    var make_error := DirAccess.make_dir_recursive_absolute(
        absolute_backup_dir
    )

    if make_error != OK and make_error != ERR_ALREADY_EXISTS:
        return ""

    var timestamp := Time.get_datetime_string_from_system()
    timestamp = timestamp.replace(":", "-")
    timestamp = timestamp.replace("T", "_")

    var backup_path := (
        BACKUP_DIR
        + "/garden_before_natural_rock_mountains_"
        + timestamp
        + ".tscn"
    )

    var copy_error := DirAccess.copy_absolute(
        ProjectSettings.globalize_path(GARDEN_SCENE_PATH),
        ProjectSettings.globalize_path(backup_path)
    )

    if copy_error != OK:
        return ""

    return backup_path


func _fail(message: String) -> void:
    push_error(message)
    print("")
    print("ABORTED — ", message)
    print("No Garden scene changes were saved by this run.")
    print("")
    quit(1)

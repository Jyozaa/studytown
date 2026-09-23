extends RefCounted

## Central, deliberately small set of visual-only budgets. Authored resources
## and gameplay geometry are never saved or removed by a preset.
const PRESETS := {
	"high": {"particles": 1.0, "forest_density": 1.0, "shadow_distance": 75.0, "point_shadows": 6, "decorative_lights": 100, "scenery_range": 0.0, "lod": 2.0, "water": 1.0},
	"medium": {"particles": 0.8, "forest_density": 0.85, "shadow_distance": 60.0, "point_shadows": 4, "decorative_lights": 6, "scenery_range": 190.0, "lod": 3.0, "water": 0.75},
	"web": {"particles": 0.6, "forest_density": 0.7, "shadow_distance": 48.0, "point_shadows": 2, "decorative_lights": 64, "scenery_range": 170.0, "lod": 5.0, "water": 0.5},
}

static func selected() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			var value := arg.trim_prefix("--quality=")
			return value if PRESETS.has(value) else "high"
	return "web" if OS.has_feature("web") else "high"

static func settings() -> Dictionary: return PRESETS[selected()]

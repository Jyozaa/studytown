class_name ForestLightFlicker
extends OmniLight3D

@export var base_energy := 1.0
@export var energy_variation := 0.08
@export var speed := 2.7
@export var phase := 0.0

var _time := 0.0


func _ready() -> void:
	base_energy = light_energy


func _process(delta: float) -> void:
	_time += delta

	var wave_a := sin(
		_time * speed
		+ phase
	)

	var wave_b := sin(
		_time * speed * 2.17
		+ phase * 1.71
	)

	var variation := (
		wave_a * 0.65
		+ wave_b * 0.35
	) * energy_variation

	light_energy = maxf(
		0.0,
		base_energy + variation
	)

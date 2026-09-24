class_name PixelTransition
extends Control
## Stepped diagonal pixel wipe (original StudyTown transition).
## Cells turn black based on (x - y) + progress: a staircase front sweeps
## the screen, holds black while the room swaps, then reveals.
## Compatibility-safe Control._draw; reduced-motion uses a quick dip.

signal finished

var cell := 36.0
var progress := 0.0
var covering := true
var running := false
var _t := 0.0
var _phase := 0  # 0 cover, 1 hold, 2 reveal, 3 done
var _reduced := false

const COVER_TIME := 0.24
const HOLD_TIME := 0.07
const REVEAL_TIME := 0.24


static func play(tree: SceneTree, reduced_motion: bool, on_covered: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	tree.root.add_child(layer)
	var fx := PixelTransition.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(fx)
	fx.start(tree, reduced_motion, on_covered)


func start(tree: SceneTree, reduced_motion: bool, on_covered: Callable) -> void:
	_reduced = reduced_motion
	running = true
	_t = 0.0
	_phase = 0
	if _reduced:
		_phase = 1
		progress = 1.0
		queue_redraw()
		await tree.create_timer(HOLD_TIME).timeout
		await on_covered.call()
		_phase = 3
		running = false
		get_parent().queue_free()
		finished.emit()
		return
	var t0 := Time.get_ticks_msec()
	while _phase < 3 and is_instance_valid(self):
		await tree.process_frame
		var dt := float(Time.get_ticks_msec() - t0) / 1000.0
		t0 = Time.get_ticks_msec()
		_t += dt
		if _phase == 0:
			progress = clampf(_t / COVER_TIME, 0.0, 1.0)
			if progress >= 1.0:
				_phase = 1
				_t = 0.0
				await on_covered.call()
		elif _phase == 1:
			if _t >= HOLD_TIME:
				_phase = 2
				_t = 0.0
		elif _phase == 2:
			progress = 1.0 - clampf(_t / REVEAL_TIME, 0.0, 1.0)
			if progress <= 0.0:
				_phase = 3
		queue_redraw()
	if is_instance_valid(self):
		get_parent().queue_free()
	running = false
	finished.emit()


func _draw() -> void:
	if not running and _phase != 1:
		return
	var diag := size.x + size.y
	var nx := int(ceil(size.x / cell)) + 1
	var ny := int(ceil(size.y / cell)) + 1
	for ix in nx:
		for iy in ny:
			var edge: float = (float(ix) * cell - float(iy) * cell + size.y) / (diag + cell)
			if edge < progress:
				draw_rect(Rect2(ix * cell, iy * cell, cell + 1.0, cell + 1.0), Color.BLACK)

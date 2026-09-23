extends RefCounted
## Bar-sweep scene transition (lofi.town-inspired rhythm, StudyTown skin):
## black bars sweep left-to-right staggered until covered, the scene swaps,
## then bars sweep on to reveal. Input blocked throughout.

const BAR_COUNT := 6
const BAR_WIDTH := 240.0
const STAGGER := 0.09
const SWEEP := 0.45


static func bar_wipe(layer: Node, tree: SceneTree, mid: Callable) -> void:
	var bars: Array[ColorRect] = []
	for i in BAR_COUNT:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.size = Vector2(BAR_WIDTH, 720)
		bar.position = Vector2(-BAR_WIDTH - 40.0, 0)
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		layer.add_child(bar)
		bars.append(bar)
		var tw := bar.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_interval(STAGGER * float(i))
		tw.tween_property(bar, "position:x", 1280.0 + 40.0, SWEEP)
	var cover_time := STAGGER * float(BAR_COUNT - 1) + SWEEP
	await tree.create_timer(cover_time).timeout
	if mid.is_valid():
		await mid.call()
	for i in BAR_COUNT:
		var bar2: ColorRect = bars[i]
		if not is_instance_valid(bar2):
			continue
		# Bars already crossed; slide a fresh set through to reveal.
		bar2.position.x = -BAR_WIDTH - 40.0
		var tw2 := bar2.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw2.tween_interval(STAGGER * float(i))
		tw2.tween_property(bar2, "position:x", 1280.0 + 40.0, SWEEP)
		tw2.tween_callback(bar2.queue_free)
	await tree.create_timer(STAGGER * float(BAR_COUNT - 1) + SWEEP + 0.05).timeout

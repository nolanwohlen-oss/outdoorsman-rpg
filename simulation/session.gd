extends RefCounted
## Runtime gate. No process uptime, foreground flag, or run switch is saved.

const Kernel = preload("res://simulation/kernel.gd")
const MAX_FRAME_US := 1000000

var kernel: Kernel
var running: bool = false
var blocked: Dictionary = {}
var last_sample_us: int = -1

func _init(value: Kernel) -> void:
	kernel = value

func set_running(value: bool) -> void:
	running = value and blocked.is_empty()
	last_sample_us = -1

func suspend(reason: String) -> void:
	blocked[reason] = true
	set_running(false)

func resume(reason: String) -> void:
	blocked.erase(reason)
	# Always return paused; require an explicit Run tap after focus/resume.
	set_running(false)

func sample(monotonic_us: int) -> Dictionary:
	if not running or not blocked.is_empty():
		last_sample_us = -1
		return {"ok": true, "advanced_ms": 0}
	if last_sample_us < 0:
		last_sample_us = monotonic_us
		return {"ok": true, "advanced_ms": 0}
	var elapsed := monotonic_us - last_sample_us
	last_sample_us = monotonic_us
	if elapsed < 0 or elapsed > MAX_FRAME_US:
		set_running(false)
		return {"ok": false, "message": "Clock paused after a long frame. Tap Run to continue."}
	var result := kernel.advance_real_us(elapsed)
	if not result.ok:
		set_running(false)
	return result

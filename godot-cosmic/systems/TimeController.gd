class_name TimeController
extends RefCounted

var running: bool = true
var speed: float = GravitySolver.DAY
var pending: float = 0.0

func accumulate(real_delta: float) -> void:
	if running and is_finite(real_delta) and real_delta > 0.0:
		pending = minf(pending + minf(real_delta, 5.0) * speed, speed * 5.0)
	else:
		pending = 0.0

func take_request() -> float:
	var value: float = pending if running else 0.0
	pending = 0.0
	return value

func set_running(value: bool) -> void:
	running = value
	pending = 0.0

extends OmniLight3D
## Organic firelight flicker.
var _base := 0.0
var _seed := 0.0
func _ready() -> void:
	_base = light_energy
	_seed = randf() * 100.0
func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() * 0.001 + _seed
	light_energy = _base * (0.82 + 0.1 * sin(t * 7.3) + 0.06 * sin(t * 13.1 + 1.7) + 0.04 * sin(t * 23.0))

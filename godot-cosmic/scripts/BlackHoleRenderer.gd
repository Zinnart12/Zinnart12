class_name BlackHoleRenderer
extends Node3D

@onready var surface: MeshInstance3D = $Surface
var material: ShaderMaterial

func _ready() -> void:
	material = surface.material_override.duplicate()
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.extra_cull_margin = 40.0

func update_view(body: CelestialBody, sim_time: float, quality: int) -> void:
	material.set_shader_parameter("center_position",global_position)
	material.set_shader_parameter("rs_scene",scale.x)
	material.set_shader_parameter("sim_time",sim_time / maxf(body.radius/BlackHoleSystem.C,1e-9))
	material.set_shader_parameter("disk_enabled",body.disk_enabled)
	material.set_shader_parameter("ray_steps",[112,192,320][quality])
	material.set_shader_parameter("step_precision",[0.12,0.08,0.045][quality])
	material.set_shader_parameter("disk_temperature",body.temperature)

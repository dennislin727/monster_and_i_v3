class_name FxTemplateLibrary
extends RefCounted

const FX_TEMPLATE_RESOURCE_PATH := "res://resources身分證/skill_fx_templates/FxTemplateResource.gd"

static func has_template(template_id: String) -> bool:
	return not _build(template_id).is_empty()

static func make_template(template_id: String) -> Resource:
	var cfg := _build(template_id)
	if cfg.is_empty():
		return null
	var res := Resource.new()
	res.set_script(load(FX_TEMPLATE_RESOURCE_PATH))
	for k in cfg.keys():
		res.set(k, cfg[k])
	return res

static func _build(template_id: String) -> Dictionary:
	match template_id:
		"warning_circle":
			return {"template_id":"warning_circle","display_name":"Warning Circle","fx_kind":0,"duration":0.45,"size":52.0,"width":4.0,"color_primary":Color(1,0.2,0.2,0.40),"color_secondary":Color(1,0.6,0.4,0.7)}
		"warning_line":
			return {"template_id":"warning_line","display_name":"Warning Line","fx_kind":1,"duration":0.38,"length":120.0,"width":8.0,"color_primary":Color(1,0.2,0.2,0.42),"color_secondary":Color(1,0.8,0.5,0.9)}
		"fissure":
			return {"template_id":"fissure","display_name":"Fissure","fx_kind":2,"duration":0.42,"length":110.0,"width":10.0,"color_primary":Color(0.45,0.3,0.22,0.8),"color_secondary":Color(0.2,0.15,0.12,0.75)}
		"fan_wave":
			return {"template_id":"fan_wave","display_name":"Fan Wave","fx_kind":3,"duration":0.32,"size":72.0,"angle_deg":70.0,"color_primary":Color(0.8,0.95,1,0.5),"color_secondary":Color(0.95,1,1,0.8)}
		"smoke":
			return {"template_id":"smoke","display_name":"Smoke","fx_kind":4,"duration":0.65,"size":44.0,"particle_count":20,"particle_size_px":3.0,"color_primary":Color(0.42,0.42,0.45,0.45),"color_secondary":Color(0.58,0.58,0.62,0.35)}
		"fire":
			return {"template_id":"fire","display_name":"Fire","fx_kind":5,"duration":0.8,"size":38.0,"particle_count":22,"particle_size_px":2.0,"color_primary":Color(1,0.45,0.1,0.75),"color_secondary":Color(1,0.8,0.15,0.65)}
		"golden_motes":
			return {"template_id":"golden_motes","display_name":"Golden Motes","fx_kind":6,"duration":1.2,"size":56.0,"particle_count":14,"drift_speed":10.0,"particle_size_px":2.0,"color_primary":Color(1,0.9,0.35,0.78),"color_secondary":Color(1,0.98,0.75,0.45)}
		"falling_leaves":
			return {"template_id":"falling_leaves","display_name":"Falling Leaves","fx_kind":7,"duration":1.0,"size":68.0,"particle_count":12,"drift_speed":22.0,"particle_size_px":3.0,"color_primary":Color(0.62,0.84,0.42,0.72),"color_secondary":Color(0.85,0.58,0.3,0.62)}
		"rain":
			return {"template_id":"rain","display_name":"Rain","fx_kind":8,"duration":0.9,"size":70.0,"particle_count":24,"drift_speed":64.0,"width":2.0,"color_primary":Color(0.5,0.7,1,0.7),"color_secondary":Color(0.8,0.9,1,0.55)}
		"afterimage_trail":
			return {"template_id":"afterimage_trail","display_name":"Afterimage Trail","fx_kind":9,"duration":0.26,"length":72.0,"width":20.0,"color_primary":Color(0.7,0.7,0.9,0.35),"color_secondary":Color(0.9,0.9,1,0.2)}
		"purple_trail":
			return {"template_id":"purple_trail","display_name":"Purple Trail","fx_kind":10,"duration":0.45,"length":88.0,"particle_count":16,"particle_size_px":2.0,"color_primary":Color(0.7,0.35,0.95,0.62),"color_secondary":Color(0.86,0.6,1,0.45)}
		"water_column":
			return {"template_id":"water_column","display_name":"Water Column","fx_kind":11,"duration":0.62,"size":36.0,"length":92.0,"width":20.0,"color_primary":Color(0.35,0.72,1,0.58),"color_secondary":Color(0.82,0.95,1,0.44)}
		"projectile_tail":
			return {"template_id":"projectile_tail","display_name":"Projectile Tail","fx_kind":12,"duration":0.28,"length":54.0,"width":14.0,"color_primary":Color(1,0.58,0.2,0.75),"color_secondary":Color(1,0.9,0.5,0.55)}
		_:
			return {}

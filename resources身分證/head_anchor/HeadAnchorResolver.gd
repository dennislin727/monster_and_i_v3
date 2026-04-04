# res://resources身分證/head_anchor/HeadAnchorResolver.gd
## 頭飾錨點：第三層 frame_offsets（含同幀最後一列、零 offset 時沿用前幀非零）與第二層 anim_offsets 的共用解析。
## Dictionary／head_anchor／Resource 後備由各呼叫端處理。
class_name HeadAnchorResolver
extends RefCounted

const KEY_OK := "ok"
const KEY_OFFSET := "offset"
const KEY_SOURCE := "source"
const KEY_ENTRY_ANIM := "entry_anim"
const KEY_ENTRY_FRAME := "entry_frame"

const SRC_FRAME := "frame_offsets"
const SRC_FRAME_PREV := "frame_offsets_prev"
const SRC_FRAME_INHERIT := "frame_offsets_inherit"
const SRC_ANIM := "anim_offsets"

## 與 MonsterResource.resolve_head_anchor_offset 相同；供 @tool 節點只讀 Resource 屬性並解析，避免對編輯器 placeholder 呼叫實例方法。
const MONSTER_RESOURCE_DEFAULT_HEAD_ANCHOR := Vector2(0, -40)


static func candidate_animation_keys(animation_name: StringName) -> Array[String]:
	var anim_key := String(animation_name)
	var keys: Array[String] = [anim_key]
	var last_sep := anim_key.rfind("_")
	if last_sep > 0 and last_sep < anim_key.length() - 1:
		var suffix := anim_key.substr(last_sep + 1)
		if suffix.is_valid_int():
			keys.append(anim_key.substr(0, last_sep))
	var lower := anim_key.to_lower()
	if lower.begins_with("attack_") and lower != "attack":
		keys.append("attack")
	if lower.begins_with("hit_") and lower != "hit":
		keys.append("hit")
	return keys


static func has_exact_frame_row(
	frame_offsets: Array,
	anim_key_norm: String,
	frame_index: int
) -> bool:
	var fi := int(frame_index)
	for i in range(frame_offsets.size()):
		var e: FrameAnchorEntry = frame_offsets[i] as FrameAnchorEntry
		if e == null:
			continue
		if String(e.anim_name) != anim_key_norm:
			continue
		if int(e.frame) != fi:
			continue
		return true
	return false


static func find_previous_nonzero_frame_offset(
	frame_offsets: Array,
	anim_key_norm: String,
	up_to_frame: int
) -> Vector2:
	var d: Dictionary = _find_previous_nonzero_frame_details(frame_offsets, anim_key_norm, up_to_frame)
	if d.get("ok", false):
		return d.get("offset", Vector2.ZERO) as Vector2
	return Vector2.ZERO


static func _last_exact_frame_entry(
	frame_offsets: Array,
	cand: String,
	fi: int
) -> FrameAnchorEntry:
	var last: FrameAnchorEntry = null
	for i in range(frame_offsets.size()):
		var e: FrameAnchorEntry = frame_offsets[i] as FrameAnchorEntry
		if e == null:
			continue
		if String(e.anim_name) != cand:
			continue
		if int(e.frame) != fi:
			continue
		last = e
	return last


static func _find_previous_nonzero_frame_details(
	frame_offsets: Array,
	cand: String,
	up_to_frame: int
) -> Dictionary:
	var cap := int(up_to_frame)
	var best_f := -1
	var best_off := Vector2.ZERO
	var best_anim := ""
	for i in range(frame_offsets.size()):
		var e: FrameAnchorEntry = frame_offsets[i] as FrameAnchorEntry
		if e == null:
			continue
		if String(e.anim_name) != cand:
			continue
		var f := int(e.frame)
		if f >= cap:
			continue
		if e.offset == Vector2.ZERO:
			continue
		if f > best_f:
			best_f = f
			best_off = e.offset
			best_anim = String(e.anim_name)
	if best_f < 0:
		return {"ok": false}
	return {"ok": true, "offset": best_off, "anim": best_anim, "frame": best_f}


static func _result_tab(
	ok: bool,
	offset: Vector2,
	source: String,
	entry_anim: String,
	entry_frame: int
) -> Dictionary:
	return {
		KEY_OK: ok,
		KEY_OFFSET: offset,
		KEY_SOURCE: source,
		KEY_ENTRY_ANIM: entry_anim,
		KEY_ENTRY_FRAME: entry_frame,
	}


static func resolve_frame_and_anim_tables(
	frame_offsets: Array,
	anim_offsets: Array,
	animation_name: StringName,
	frame_index: int
) -> Dictionary:
	var fi := int(frame_index)
	var candidates: Array[String] = candidate_animation_keys(animation_name)
	var empty: Dictionary = _result_tab(false, Vector2.ZERO, "", "", -99999)

	for cand in candidates:
		var exact: FrameAnchorEntry = _last_exact_frame_entry(frame_offsets, cand, fi)
		if exact != null:
			if exact.offset != Vector2.ZERO:
				return _result_tab(true, exact.offset, SRC_FRAME, String(exact.anim_name), fi)
			var inh: Dictionary = _find_previous_nonzero_frame_details(frame_offsets, cand, fi)
			if inh.get("ok", false):
				return _result_tab(
					true,
					inh.get("offset", Vector2.ZERO) as Vector2,
					SRC_FRAME_INHERIT,
					str(inh.get("anim", cand)),
					int(inh.get("frame", -1))
				)
		else:
			var prev: Dictionary = _find_previous_nonzero_frame_details(frame_offsets, cand, fi)
			if prev.get("ok", false):
				return _result_tab(
					true,
					prev.get("offset", Vector2.ZERO) as Vector2,
					SRC_FRAME_PREV,
					str(prev.get("anim", cand)),
					int(prev.get("frame", -1))
				)

	for cand in candidates:
		for j in range(anim_offsets.size()):
			var a: AnimAnchorEntry = anim_offsets[j] as AnimAnchorEntry
			if a == null:
				continue
			if String(a.anim_name) != cand:
				continue
			if a.offset == Vector2.ZERO:
				continue
			return _result_tab(true, a.offset, SRC_ANIM, cand, fi)

	return empty


static func try_resolve_frame_anchor_overrides(
	frame_anchor_overrides: Dictionary,
	candidate_keys: Array[String],
	fi: int,
	frame_key: String
) -> Variant:
	for cand in candidate_keys:
		if not frame_anchor_overrides.has(cand):
			continue
		var per_frame: Variant = frame_anchor_overrides[cand]
		if not per_frame is Dictionary:
			continue
		var d: Dictionary = per_frame
		if d.has(fi):
			var v: Variant = d[fi]
			if v is Vector2:
				return v
		if d.has(frame_key):
			var v2: Variant = d[frame_key]
			if v2 is Vector2:
				return v2
	return null


static func try_resolve_animation_anchor_overrides(
	animation_anchor_overrides: Dictionary,
	candidate_keys: Array[String]
) -> Variant:
	for cand in candidate_keys:
		if not animation_anchor_overrides.has(cand):
			continue
		var v: Variant = animation_anchor_overrides[cand]
		if v is Vector2:
			return v
	return null


static func resolve_head_anchor_monster_exports(
	frame_offsets: Array,
	anim_offsets: Array,
	animation_name: StringName,
	frame_index: int,
	frame_anchor_overrides: Dictionary,
	animation_anchor_overrides: Dictionary,
	head_anchor_offset: Vector2,
	accessory_offset: Vector2,
	fallback_offset: Vector2,
	monster_default_head: Vector2 = MONSTER_RESOURCE_DEFAULT_HEAD_ANCHOR
) -> Vector2:
	var fi := int(frame_index)
	var candidate_keys := candidate_animation_keys(animation_name)
	var frame_key := str(fi)
	var tab: Dictionary = resolve_frame_and_anim_tables(
		frame_offsets,
		anim_offsets,
		animation_name,
		frame_index
	)
	if tab.get(KEY_OK, false):
		return tab.get(KEY_OFFSET, Vector2.ZERO) as Vector2
	var dict_frame: Variant = try_resolve_frame_anchor_overrides(
		frame_anchor_overrides,
		candidate_keys,
		fi,
		frame_key
	)
	if dict_frame is Vector2:
		return dict_frame
	var dict_anim: Variant = try_resolve_animation_anchor_overrides(
		animation_anchor_overrides,
		candidate_keys
	)
	if dict_anim is Vector2:
		return dict_anim
	if head_anchor_offset != monster_default_head or accessory_offset == monster_default_head:
		return head_anchor_offset
	if accessory_offset != monster_default_head:
		return accessory_offset
	return fallback_offset

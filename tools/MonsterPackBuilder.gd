# res://tools/MonsterPackBuilder.gd
# 與 EditorScript 共用；命令列：godot --headless --path <專案根> -s res://tools/run_monster_pack_cli.gd
# 刻意不用 class_name，以便 -s 啟動時可正常 compile。
#
# 【重要】BUILD_SPECS 裡每一筆，每次跑 bat 都會「從圖檔資料夾重建」對應的 *_spriteframes.tres，
# 會覆寫你在 Godot 裡手調的動畫 Speed（FPS 感）等。已落地的怪請從本列表移除，只加「還要產檔」的新怪。
# 哥布林已落地，故已移除；若要因改圖重新產哥布林，暫時加回一筆即可（注意會蓋掉手調 FPS）。
extends RefCounted

const BUILD_SPECS: Array[Dictionary] = [
	# 範例：下一隻蘑菇在此加一筆 Dictionary（勿與已完成的怪同時重複建置，除非你接受覆寫）
]


## 回傳成功筆數；列表為空回傳 0（略過）；有列但全失敗回傳 -1。
func run_all() -> int:
	if BUILD_SPECS.is_empty():
		print("MonsterPackBuilder: BUILD_SPECS 為空，略過建置（已落地的怪請勿留在列表，以免覆寫手調 SpriteFrames）。")
		return 0
	var ok_count := 0
	for spec in BUILD_SPECS:
		if build_one(spec):
			ok_count += 1
	print("MonsterPackBuilder: 完成 %d / %d 筆。" % [ok_count, BUILD_SPECS.size()])
	return ok_count if ok_count > 0 else -1


func build_one(spec: Dictionary) -> bool:
	var id: String = str(spec.get("id", "")).strip_edges()
	var tex_root: String = str(spec.get("tex_root", "")).strip_edges()
	if id.is_empty() or tex_root.is_empty():
		push_error("MonsterPackBuilder: spec 缺少 id 或 tex_root：%s" % spec)
		return false

	var out_sf := "res://resources身分證/monster/%s_spriteframes.tres" % id
	var out_pet := "res://resources身分證/pet/%s_pet.tres" % id
	var out_monster := "res://resources身分證/monster/%s.tres" % id

	var sf := build_sprite_frames_from_folders(tex_root)
	if sf == null:
		push_error("MonsterPackBuilder: [%s] 無法建立 SpriteFrames，路徑：%s" % [id, tex_root])
		return false
	if ResourceSaver.save(sf, out_sf) != OK:
		push_error("MonsterPackBuilder: [%s] 儲存失敗 %s" % [id, out_sf])
		return false
	print("已寫入: ", out_sf)

	var pet := make_pet(spec, tex_root)
	if ResourceSaver.save(pet, out_pet) != OK:
		push_error("MonsterPackBuilder: [%s] 儲存失敗 %s" % [id, out_pet])
		return false
	print("已寫入: ", out_pet)

	var pet_loaded: PetResource = load(out_pet) as PetResource
	var mr := make_monster(spec, sf, pet_loaded)
	if ResourceSaver.save(mr, out_monster) != OK:
		push_error("MonsterPackBuilder: [%s] 儲存失敗 %s" % [id, out_monster])
		return false
	print("已寫入: ", out_monster)
	return true


func build_sprite_frames_from_folders(tex_root: String) -> SpriteFrames:
	var d := DirAccess.open(tex_root)
	if d == null:
		return null
	var sf := SpriteFrames.new()
	d.list_dir_begin()
	var sub := d.get_next()
	while sub != "":
		if sub.begins_with("."):
			sub = d.get_next()
			continue
		if not d.current_is_dir():
			sub = d.get_next()
			continue
		var anim_name: String = sub
		var folder := "%s/%s" % [tex_root, anim_name]
		var textures := load_sorted_pngs(folder)
		if textures.is_empty():
			sub = d.get_next()
			continue
		if sf.has_animation(anim_name):
			sf.remove_animation(anim_name)
		sf.add_animation(anim_name)
		for tex in textures:
			sf.add_frame(anim_name, tex)
		sf.set_animation_loop(anim_name, want_loop(anim_name))
		sf.set_animation_speed(anim_name, anim_speed(anim_name))
		sub = d.get_next()
	d.list_dir_end()
	if sf.get_animation_names().is_empty():
		return null
	return sf


func load_sorted_pngs(folder: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var ad := DirAccess.open(folder)
	if ad == null:
		return out
	var names: PackedStringArray = []
	ad.list_dir_begin()
	var f := ad.get_next()
	while f != "":
		if f.ends_with(".png") and not f.ends_with(".import"):
			names.append(f)
		f = ad.get_next()
	ad.list_dir_end()
	var arr: Array = Array(names)
	arr.sort()
	for n in arr:
		var path := "%s/%s" % [folder, n]
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			out.append(tex)
	return out


func want_loop(anim_name: String) -> bool:
	var a := anim_name.to_lower()
	return a.begins_with("idle") or a.begins_with("run")


func anim_speed(anim_name: String) -> float:
	var a := anim_name.to_lower()
	if a.begins_with("run"):
		return 12.0
	if a.begins_with("idle"):
		return 8.0
	if a.begins_with("attack"):
		return 11.0
	if a == "hit":
		return 14.0
	if a == "spell":
		return 10.0
	if a == "happy":
		return 8.0
	return 8.0


func make_pet(spec: Dictionary, tex_root: String) -> PetResource:
	var pet := PetResource.new()
	var id: String = str(spec.get("id", ""))
	pet.pet_id = id
	pet.instance_id = ""
	pet.pet_name = str(spec.get("monster_name", id))
	pet.nickname = str(spec.get("nickname", pet.pet_name))
	var icon_rel := str(spec.get("icon_subpath", "idle_down/frame0000.png"))
	var icon_path := "%s/%s" % [tex_root, icon_rel]
	if ResourceLoader.exists(icon_path):
		pet.icon = load(icon_path) as Texture2D
	pet.level = 1
	pet.experience = 0
	pet.story = str(spec.get("story", ""))
	pet.skills = pet_skills_from_paths(spec.get("pet_skill_paths", []))
	pet.follow_distance = float(spec.get("pet_follow_distance", 60.0))
	pet.follow_speed_mult = float(spec.get("pet_follow_speed_mult", 1.1))
	pet.max_hp = int(spec.get("pet_max_hp", 0))
	pet.heal_amount = int(spec.get("pet_heal_amount", 15))
	pet.heal_cooldown = float(spec.get("pet_heal_cooldown", 10.0))
	pet.luck_bonus_rate = float(spec.get("pet_luck_bonus_rate", 0.0))
	return pet


func pet_skills_from_paths(paths_variant: Variant) -> Array[PetSkillEntry]:
	var out: Array[PetSkillEntry] = []
	if paths_variant is Array:
		for p in paths_variant as Array:
			var path := str(p).strip_edges()
			if path.is_empty() or not ResourceLoader.exists(path):
				continue
			var sk := load(path)
			if not (sk is SkillResource):
				continue
			var entry := PetSkillEntry.new()
			entry.skill = sk
			entry.skill_level = 1
			out.append(entry)
	return out


func monster_skills_from_paths(paths_variant: Variant) -> Array[SkillResource]:
	var out: Array[SkillResource] = []
	if paths_variant is Array:
		for p in paths_variant as Array:
			var path := str(p).strip_edges()
			if path.is_empty() or not ResourceLoader.exists(path):
				continue
			var sk := load(path)
			if sk is SkillResource:
				out.append(sk)
	return out


func make_monster(spec: Dictionary, sf: SpriteFrames, pet: PetResource) -> MonsterResource:
	var b: Dictionary = spec.get("balance", {})
	var mr := MonsterResource.new()
	mr.monster_name = str(spec.get("monster_name", spec.get("id", "")))
	mr.max_hp = int(b.get("max_hp", 100))
	mr.move_speed = float(b.get("move_speed", 60.0))
	mr.chase_speed = float(b.get("chase_speed", 90.0))
	mr.attack_multiplier = float(b.get("attack_multiplier", 1.0))
	mr.attack_cooldown = float(b.get("attack_cooldown", 1.2))
	mr.attack_range = float(b.get("attack_range", 45.0))
	if bool(b.get("aggro_aggressive", false)):
		mr.aggro_type = MonsterResource.AggroType.AGGRESSIVE
	else:
		mr.aggro_type = MonsterResource.AggroType.PASSIVE
	mr.participates_in_combat = bool(b.get("participates_in_combat", true))
	mr.detection_range = float(b.get("detection_range", 180.0))
	mr.actions_before_spell = int(b.get("actions_before_spell", 3))
	mr.capture_rate = float(b.get("capture_rate", 0.5))
	mr.skills = monster_skills_from_paths(spec.get("monster_skill_paths", []))
	var drop_path := str(spec.get("drop_item", "")).strip_edges()
	if not drop_path.is_empty() and ResourceLoader.exists(drop_path):
		mr.drop_item = load(drop_path) as ItemResource
	mr.drop_chance = float(b.get("drop_chance", 0.5))
	mr.gold_reward = int(b.get("gold_reward", 0))
	mr.xp_reward = int(b.get("xp_reward", 0))
	mr.sprite_frames = sf
	var ho: Variant = b.get("head_anchor_offset", null)
	if ho is Vector2:
		mr.head_anchor_offset = ho
	else:
		mr.head_anchor_offset = MonsterResource.DEFAULT_HEAD_ANCHOR_OFFSET
	var cs := str(b.get("combat_style", "melee")).to_lower()
	if cs == "ranged_kiter":
		mr.combat_style = MonsterResource.CombatStyle.RANGED_KITER
	else:
		mr.combat_style = MonsterResource.CombatStyle.MELEE
	mr.kite_retreat_below = float(b.get("kite_retreat_below", 100.0))
	mr.kite_chase_above = float(b.get("kite_chase_above", 360.0))
	mr.pet_data = pet
	return mr

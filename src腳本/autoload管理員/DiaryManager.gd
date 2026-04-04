# res://src腳本/autoload管理員/DiaryManager.gd
extends Node

signal mood_notes_changed
signal career_changed

## 心情筆記：{ "id", "created_unix", "title", "body" }
var _mood_notes: Array[Dictionary] = []
## 生涯成就 id -> { "unix": int }
var _career_unlocked: Dictionary = {}

## 資料驅動標題（新增成就時在此登記）
const CAREER_TITLES: Dictionary = {
	"career_smith_first_stone": "湖邊鐵匠送了第一顆小石頭",
	"career_smith_training_axe": "獲得史萊姆學徒的練習斧",
	"career_first_pet_dudu": "請多指教！獲得第一隻寵物「嘟嘟」",
}


func try_unlock_career(milestone_id: String) -> void:
	var mid := milestone_id.strip_edges()
	if mid.is_empty():
		return
	if not CAREER_TITLES.has(mid):
		push_warning("[DiaryManager] 未定義的生涯 id：%s" % mid)
	if _career_unlocked.has(mid):
		return
	_career_unlocked[mid] = {"unix": Time.get_unix_time_from_system()}
	career_changed.emit()


func get_career_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in _career_unlocked.keys():
		var kid := str(k)
		var title: String = str(CAREER_TITLES.get(kid, kid))
		var ent: Variant = _career_unlocked[k]
		var ux := 0
		if ent is Dictionary:
			ux = int((ent as Dictionary).get("unix", 0))
		out.append({"id": kid, "title": title, "unix": ux})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("unix", 0)) > int(b.get("unix", 0))
	)
	return out


func add_mood_note() -> String:
	var id := "note_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	var d := {"id": id, "created_unix": Time.get_unix_time_from_system(), "title": "", "body": ""}
	_mood_notes.append(d)
	mood_notes_changed.emit()
	return id


func update_mood_note(note_id: String, title: String, body: String, notify: bool = false) -> void:
	var nid := note_id.strip_edges()
	for n in _mood_notes:
		if str(n.get("id", "")) == nid:
			n["title"] = title
			n["body"] = body
			if notify:
				mood_notes_changed.emit()
			return


func remove_mood_note(note_id: String) -> void:
	var nid := note_id.strip_edges()
	for i in range(_mood_notes.size()):
		if str(_mood_notes[i].get("id", "")) == nid:
			_mood_notes.remove_at(i)
			mood_notes_changed.emit()
			return


func get_mood_notes() -> Array[Dictionary]:
	return _mood_notes.duplicate(true)


func format_note_date_line(created_unix: int, title: String) -> String:
	var t := Time.get_datetime_dict_from_unix_time(created_unix) as Dictionary
	var y := int(t.get("year", 0))
	var mo := int(t.get("month", 0))
	var day := int(t.get("day", 0))
	var head := "%d/%d/%d" % [y, mo, day]
	var tl := title.strip_edges()
	if tl.is_empty():
		return head
	return "%s　（%s）" % [head, tl]


func get_save_snapshot() -> Dictionary:
	return {
		"mood_notes": _duplicate_mood_notes_for_save(),
		"career": _career_unlocked.duplicate(true),
	}


func _duplicate_mood_notes_for_save() -> Array:
	var a: Array = []
	for n in _mood_notes:
		if n is Dictionary:
			a.append((n as Dictionary).duplicate(true))
	return a


func apply_save_snapshot(data: Dictionary) -> void:
	_mood_notes.clear()
	var mn: Variant = data.get("mood_notes", [])
	if mn is Array:
		for x in mn as Array:
			if x is Dictionary:
				_mood_notes.append((x as Dictionary).duplicate(true))
	_career_unlocked.clear()
	var cr: Variant = data.get("career", {})
	if cr is Dictionary:
		for k in (cr as Dictionary).keys():
			var v: Variant = (cr as Dictionary)[k]
			if v is Dictionary:
				_career_unlocked[str(k)] = (v as Dictionary).duplicate(true)
			else:
				_career_unlocked[str(k)] = {"unix": int(v)}
	mood_notes_changed.emit()
	career_changed.emit()

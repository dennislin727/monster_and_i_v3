# res://resources身分證/dialogue/dialogue_graph_resource.gd
class_name DialogueGraphResource
extends Resource

const CLOSE_SENTINEL := "__CLOSE__"

@export var start_node_id: String = "start"
@export var nodes: Array[DialogueNodeResource] = []

func get_node_by_id(id: String) -> DialogueNodeResource:
	var clean := id.strip_edges()
	if clean.is_empty():
		return null
	for n in nodes:
		if n and n.node_id == clean:
			return n
	return null


## Phase 9 延伸：對話圖表格式匯出（TSV 友善）
func export_table_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for n in nodes:
		if n == null:
			continue
		var line_texts: PackedStringArray = PackedStringArray()
		for l in n.lines:
			if l == null:
				continue
			line_texts.append(l.text.strip_edges())
		if n.choices.is_empty():
			rows.append({
				"node_id": n.node_id,
				"choice_text": "",
				"target_node_id": "",
				"conditions": "",
				"lines": " / ".join(line_texts),
			})
			continue
		for ch in n.choices:
			if ch == null:
				continue
			var conds: Array[String] = []
			if ch.min_affinity > 0:
				conds.append("min_affinity=%d" % ch.min_affinity)
			if not ch.require_grant_once_pending.strip_edges().is_empty():
				conds.append("pending=%s" % ch.require_grant_once_pending.strip_edges())
			if not ch.require_grant_once_done.strip_edges().is_empty():
				conds.append("done=%s" % ch.require_grant_once_done.strip_edges())
			if ch.require_party_non_empty:
				conds.append("require_party_non_empty")
			if ch.require_party_empty:
				conds.append("require_party_empty")
			if ch.require_in_homestead:
				conds.append("require_in_homestead")
			rows.append({
				"node_id": n.node_id,
				"choice_text": ch.text,
				"target_node_id": ch.target_node_id,
				"conditions": ",".join(conds),
				"lines": " / ".join(line_texts),
			})
	return rows


func export_table_tsv() -> String:
	var out: PackedStringArray = PackedStringArray()
	out.append("node_id\tchoice_text\ttarget_node_id\tconditions\tlines")
	for r in export_table_rows():
		out.append("%s\t%s\t%s\t%s\t%s" % [
			str(r.get("node_id", "")),
			str(r.get("choice_text", "")),
			str(r.get("target_node_id", "")),
			str(r.get("conditions", "")),
			str(r.get("lines", "")),
		])
	return "\n".join(out)

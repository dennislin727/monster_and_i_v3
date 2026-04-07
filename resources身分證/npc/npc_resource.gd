# res://resources身分證/npc/npc_resource.gd
class_name NpcResource
extends Resource

@export var npc_id: String = ""
@export var display_name: String = "村民"
@export_multiline var prompt_line: String = "……"
## >=0 且 prompt_line_high_affinity 非空時：好感達門檻改用第二句提示
@export var prompt_affinity_threshold: int = -1
@export_multiline var prompt_line_high_affinity: String = ""
## 對應 DialogueManager `_GRAPH_PATH_BY_KEY` 註冊的圖鍵
@export var dialogue_graph_key: String = ""

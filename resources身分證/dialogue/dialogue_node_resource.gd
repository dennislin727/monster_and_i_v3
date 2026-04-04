# res://resources身分證/dialogue/dialogue_node_resource.gd
class_name DialogueNodeResource
extends Resource

@export var node_id: String = ""
@export var lines: Array[DialogueLineBlock] = []
@export var choices: Array[DialogueChoiceEntry] = []
@export var on_enter_effects: Array[DialogueEffectEntry] = []

# res://resources身分證/dialogue/dialogue_line_block.gd
class_name DialogueLineBlock
extends Resource

enum Speaker { NPC, PLAYER_THOUGHT }

@export var speaker: Speaker = Speaker.NPC
@export_multiline var text: String = ""

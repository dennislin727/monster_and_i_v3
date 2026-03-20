# res://src腳本/entities/monsters/MonsterBase.gd (通用怪物腳本)
extends CharacterBody2D

@export var data: MonsterResource # 🔴 直接拉入 .tres

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var state = "idle"
var timer = 0.0

func _ready():
	if data:
		anim.sprite_frames = data.sprite_frames # 自動穿上動畫
		anim.play("idle")

func _physics_process(delta):
	timer -= delta
	if timer <= 0:
		# 隨機決定下一秒要 待機 還是 亂走
		state = "run" if randf() > 0.5 else "idle"
		timer = randf_range(1.0, 3.0)
		
		if state == "run":
			velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * data.move_speed
		else:
			velocity = Vector2.ZERO

	move_and_slide()
	# 根據 velocity 播放動畫 (這部分邏輯可以跟主角共用)

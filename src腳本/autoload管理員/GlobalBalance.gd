# res://src腳本/autoload管理員/GlobalBalance.gd
extends Node

# --- [第一區：主角基準線] ---
var PLAYER_SPEED = 210.0
var PLAYER_DASH_DIST = 160.0
var PLAYER_ATTACK_RECOVERY = 0.35 
var PLAYER_BASE_DAMAGE = 45
var PLAYER_FRICTION = 40.0          # 🕵️ 遺漏人口 A

# --- [第二區：環境與採集] ---
var HARVEST_DAMAGE_MULTIPLIER = 1.5 

# --- [第三區：怪物體感校準] ---
var MONSTER_BASE_DAMAGE = 10        # 🕵️ 遺漏人口 A
var MONSTER_LUNGE_DIST = 40.0       # 🕵️ 遺漏人口 A
var KNOCKBACK_FORCE = 30.0          # 🕵️ 遺漏人口 A
var AI_STOP_DISTANCE = 35.0         # 🕵️ 遺漏人口 C (追多近才停)

# --- [第四區：封印平衡] ---
var SEAL_BASE_TIME = 2.5            
var SEAL_WEAK_THRESHOLD = 0.3       
var SEAL_WEAK_SPEED_BONUS = 2.0     

# --- [第五區：掉寶與獎勵] ---
var GLOBAL_DROP_CHANCE_MODIFIER = 1.0 
var GLOBAL_DROP_QUANTITY_BONUS = 1

# --- [第六區：視覺節奏 (選配)] ---
var UI_TEXT_FADE_TIME = 0.8         # 🕵️ 遺漏人口 B
var SHADOW_MAX_HEIGHT = 120.0       # 🕵️ 遺漏人口 B

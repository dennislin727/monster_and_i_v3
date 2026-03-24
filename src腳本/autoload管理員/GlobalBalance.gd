# res://src腳本/autoload管理員/GlobalBalance.gd
extends Node

# --- [第一區：主角基準線] ---
var PLAYER_SPEED = 210.0
var PLAYER_DASH_DIST = 160.0
var PLAYER_ATTACK_RECOVERY = 0.35 
var PLAYER_BASE_DAMAGE = 45
var PLAYER_FRICTION = 40.0

# --- [第二區：環境互動節奏] ---
var HARVEST_DAMAGE_MULTIPLIER = 1.5 

# --- [第三區：怪物體感校準] ---
var MONSTER_HP_SCALAR = 1.0         
var MONSTER_SPEED_SCALAR = 1.0
var MONSTER_BASE_DAMAGE = 10
var MONSTER_LUNGE_DIST = 40.0
var KNOCKBACK_FORCE = 30.0
var AI_STOP_DISTANCE = 35.0

# --- [第四區：封印平衡 (這裡最重要，漏掉就會閃退)] ---
var SEAL_BASE_TIME = 2.5            # 壓制所需總秒數
var SEAL_DECAY_RATE = 0.8           # 封印流失率
var SEAL_WEAK_THRESHOLD = 0.3       # 虛弱門檻
var SEAL_WEAK_SPEED_BONUS = 2.0     # 虛弱加速倍率

# --- [第五區：掉寶與獎勵] ---
var GLOBAL_DROP_CHANCE_MODIFIER = 1.0 
var GLOBAL_DROP_QUANTITY_BONUS = 1

# --- [第六區：視覺節奏] ---
var UI_TEXT_FADE_TIME = 0.8    # 數字停留多久才消失
var SHADOW_MAX_HEIGHT = 120.0
var DAMAGE_RISE_DIST = 110.0   # 數字往上飄的高度
var DAMAGE_BOUNCE_TIME = 0.1   # 數字彈跳的縮放時間

# --- [第七區：預留寵物模組 (下次任務用)] ---
var PET_HEAL_COOLDOWN = 10.0
var PET_HEAL_AMOUNT = 15

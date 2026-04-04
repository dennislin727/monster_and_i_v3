# res://src腳本/autoload管理員/GlobalBalance.gd
extends Node

# --- [第一區：主角基準線] ---
var PLAYER_SPEED = 150.0
var PLAYER_DASH_DIST = 80.0
var PLAYER_ATTACK_RECOVERY = 0.35 
var PLAYER_BASE_DAMAGE = 45
var PLAYER_FRICTION = 40.0

# --- [第二區：環境互動節奏] ---
var HARVEST_DAMAGE_MULTIPLIER = 1.5 
## `LakeSideLevel` 直接摆的 `BabyBirdMonster` 隻數；須與場景實例＋`lake_ambient_save_slot` 0..TOTAL-1 對齊。
const LAKE_AMBIENT_BABY_BIRD_TOTAL := 2
## Phase 10：滑掃採收同一幀最多入包株數（低階機保護）
const HARVEST_MAX_ITEMS_PER_FRAME := 10
## 家園：翻土後作物成熟秒數（MVP；日後可改 Resource／離線表）
const HOMESTEAD_CROP_GROW_SEC := 1.5
## 入包回饋：主角 happy 動畫最小間隔（毫秒）
const PLAYER_COLLECT_HAPPY_COOLDOWN_MS := 400

## 區域標題（地圖名浮字）：主角顯示名暫定，日後接存檔／取名系統
const PLAYER_DISPLAY_NAME := "冠冠"
## 底欄採收／封印鈕與區域名浮字：漸顯／漸隱秒數一致（愈大愈慢）
const HUD_FADE_IN_SEC := 0.6
const HUD_FADE_OUT_SEC := 0.6
## 區域標題動畫（供 AreaTitleBanner；duration_sec≤0 時 fade 用下列常數，與 HUD_FADE_* 對齊）
const AREA_TITLE_FADE_IN_SEC := HUD_FADE_IN_SEC
const AREA_TITLE_HOLD_SEC := 2.0
const AREA_TITLE_FADE_OUT_SEC := HUD_FADE_OUT_SEC

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
## 主場景底欄 `UILayer/bottom` 高度須與此一致（見 ARCHITECTURE「底欄 63px」）；PetUI／InventoryUI 面板以此為 Panel.offset_bottom。
const UI_BOTTOM_BAR_HEIGHT_PX := 63
## `LevelContainer` 若開 `y_sort_enabled`，關卡根節點 Y=0 會讓「整張關卡」與主角比排序；主角／怪物／寵物等應設較高 z_index（目前場景用 5）以免走到地圖北方時被 Polygon2D 蓋住。
const LEVEL_SORTED_ENTITY_Z_INDEX := 5
## 前景樹冠（`FgTree_*`）須與主角／怪／寵物**同層**此值，才能與 `LevelContainer.y_sort` 互相遮擋；勿另拉高 z，否則樹會永遠壓住角色。
## 手機特效預算：同屏主動技能特效上限與粒子目標（供 EffectManager / SkillFxResource 使用）
const FX_MAX_ACTIVE_SKILL_FX := 6
const FX_PARTICLE_SOFT_CAP := 60
var DAMAGE_RISE_DIST = 110.0   # 數字往上飄的高度
var DAMAGE_BOUNCE_TIME = 0.1   # 數字彈跳的縮放時間
var SEAL_SWORD_WAIT_TIME = 0.5  # 🟢 Manager 暫停等待的時間 (秒)

# --- [第七區：寵物協戰] ---
var PET_HEAL_COOLDOWN = 8.0
var PET_HEAL_AMOUNT = 15
var PET_MELEE_DAMAGE = 22
var PET_MAX_HP = 80
var PET_FOLLOW_SPEED = 150.0
## 與主角距離超過此值時瞬移回跟隨錨點（避免卡地形／路徑）
const PET_TELEPORT_PULL_DIST := 250.0
## 出戰三槽跟隨／黏怪移速倍率（槽 1→3 遞減；同寵物個體的 follow_speed_mult 仍由各 PetResource 乘上）
const PET_PARTY_SLOT0_FOLLOW_MULT := 1.0
## 第二槽：故意放慢，起跑／尾隨與第一隻錯開
const PET_PARTY_SLOT1_FOLLOW_MULT := 0.68
const PET_PARTY_SLOT2_FOLLOW_MULT := 0.76
## 麵包屑取樣再延後：主角起跑時各槽不會同時開跑（數值愈大起跑愈晚）
const PET_PARTY_SLOT0_TRAIL_LAG_SEC := 0.0
const PET_PARTY_SLOT1_TRAIL_LAG_SEC := 0.55
const PET_PARTY_SLOT2_TRAIL_LAG_SEC := 0.4
## 出戰寵物地面陰影偏移（PetCompanion／ShadowComponent）；湖畔環境寶寶（AmbientBabyBirdMonster）亦套用此值以對齊視覺。
const PET_COMPANION_SHADOW_BASE_OFFSET := Vector2(-0.665, 20.715)
## 與 ShadowComponent 預設一致；Pet 場景未覆寫 shadow_scale 時即為此值。
const PET_COMPANION_SHADOW_SCALE := Vector2(0.8, 0.4)
## 寶寶低空飛行：與目標距離愈遠，本體 `AnimatedSprite2D` 愈上移（影子留在地面）；PetCompanion 與 AmbientBabyBirdMonster 共用。
## MIN 拉高＝要離主角較遠才開始明顯起飛；MAX 略拉開讓滿高度仍有一段距離感
const BABY_BIRD_FLIGHT_DIST_MIN := 64.0
const BABY_BIRD_FLIGHT_DIST_MAX := 158.0
## 飛行期間本體上移上限（像素級，對齊精靈 offset）
const BABY_BIRD_FLIGHT_Y_MAX := 198.0
## 飛行高度：爬升較慢、下降可稍快（短距離不易瞬間拉滿高度）
const BABY_BIRD_FLIGHT_LERP_UP := 2.65
const BABY_BIRD_FLIGHT_LERP_DOWN := 6.0
## 環境寶寶鳥等仍用單一係數時，取與下降接近的體感
const BABY_BIRD_FLIGHT_LERP := BABY_BIRD_FLIGHT_LERP_DOWN
## 跟隨目標距離平滑（愈大愈跟手、愈不易因麵包屑抖動造成高度亂跳）
const BABY_BIRD_FLIGHT_DIST_SMOOTH_SPEED := 6.0
## 移動中、即使已貼近跟隨點仍保留的最低飛行比例（0..1，乘上 Y_MAX＝貼身懸空高度下限）
const BABY_BIRD_FLIGHT_MOVE_ALT_FLOOR := 0.30
## 主角「從站定變起跑」後這段秒數內，起飛意願漸強（0＝關閉）
const BABY_BIRD_LAZY_TAKEOFF_SEC := 0.72
## 懶散起飛剛開始時，目標高度再乘上此係數（很小＝先黏低空再拉高）
const BABY_BIRD_LAZY_ALT_START_MULT := 0.22
## 寶寶鳥非戰鬥、主角在動且與跟隨點距離超過門檻時，跟隨速度乘此（靈巧追上）
const BABY_BIRD_CHASE_SPEED_MULT := 1.48
const BABY_BIRD_CHASE_SPEED_DIST := 54.0
## 跟隨錨點額外往「頭頂」抬（世界座標 Y 負值＝畫面上方）
const BABY_BIRD_FOLLOW_HEAD_Y_OFFSET := -28.0
## 頭頂兩側輕盤旋（橢圓半徑，像素級）
const BABY_BIRD_ORBIT_RX := 22.0
const BABY_BIRD_ORBIT_RY := 14.0
const BABY_BIRD_ORBIT_SPEED := 0.88
## 目標高度微擺盪（疊在距離曲線上，避免死板）
const BABY_BIRD_ALT_WOBBLE_AMP := 7.0
const BABY_BIRD_ALT_WOBBLE_SPEED := 2.5
## 主角停步後長段下降：`flight_y` 以 run 拍翅朝向 0 的 lerp 係數（愈小愈像漫不經心飄下來）
const BABY_BIRD_DESCENT_LERP := 3
## 剩餘飛行高度 ≤ 此值時才播 `run_*_1` 著陸（愈小愈晚播、近地才收翅）
const BABY_BIRD_LANDING_FINAL_HEIGHT := 0.7
## 出戰寵物：可停留區＝攝影機可視矩形**再往外擴**（世界座標）；超出才加速拉回，減少貼邊跳針又不易整隻失蹤
## 設 0＝貼齊畫面邊；約 80～140 讓修正多半發生在畫外
const PET_SCREEN_BOUNDARY_OUTSET_PX := 108.0
const PET_SCREEN_EDGE_RETURN_ENABLED := true
const PET_SCREEN_RETURN_ACCEL := 360.0
const PET_SCREEN_RETURN_MAX_PUSH := 240.0

# --- [經驗／寵物上限] ---
const PET_MAX_LEVEL := 20

## 主角從 current_level 升下一等所需累積 XP（填入 player_xp 條後扣減）。
func xp_needed_for_player_next_level(current_level: int) -> int:
	return maxi(1, 12 * maxi(1, current_level))


## 寵物從 current_level 升下一等所需累積 XP（寵物 `experience` 欄位）。
func xp_needed_for_pet_next_level(current_level: int) -> int:
	return maxi(1, 10 * maxi(1, current_level))


## 戰鬥技能顯示階：寵物每 5 級 +1（刻意用浮點除再 int，避免 INTEGER_DIVISION 警告）。
func combat_skill_display_level_from_pet_level(pet_level: int) -> int:
	var lv := maxi(1, pet_level)
	return 1 + int((lv - 1) / 5.0)


## 家園翻土等同時土格上限：Lv.1=5，每級 +1（搭配 is_homestead_till_skill 顯示）。
func homestead_soil_cap_from_pet_level(pet_level: int) -> int:
	return 5 + maxi(0, pet_level - 1)

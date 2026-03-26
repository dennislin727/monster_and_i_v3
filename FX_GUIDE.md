# 怪物與我 v3：2D 手機特效指南（靈感 + 落地手冊）

> 用途：
> - 你：當成怪物設計/互動靈感清單
> - 我：後續可批次落地技能特效的流程手冊
> - 原則：先可讀、再華麗；先穩定、再擴展

---

## 1) 先決策：什麼做烘焙、什麼做運算

### 優先用 `AnimatedSprite2D`（烘焙幀圖）
- 固定外觀、重複播放：補血、劍氣、落劍衝擊、爆炸、命中火花
- 像素風美術主導的特效（你手繪的那種）
- 低風險、低維護、手機穩定

### 再用運算（Shader/程序）
- 需要互動變形：範圍即時縮放、方向即時扇形、地面跟隨脈衝
- 需要少量參數化：顏色切換、強度變化、進度顯示

### 專案建議
- 同一招可混合：`烘焙主體 + 運算外圈/預警`
- 先做烘焙版可玩，再補運算層做質感

---

## 2) 從影片轉 2D 可用特效庫（按用途分類）

## A. 預警（Telegraph）
- 地面圓圈（半透明、脈衝）
- 扇形方向提示（怪物朝向）
- 直線落點條（衝刺/斬擊）
- 節拍閃爍（0.2s 間隔，2~3 次）

## B. 施放（Cast）
- 施法光暈（短 4~6 幀）
- 武器蓄力閃（白閃 + 顏色染）
- 地面符文啟動（由淡到亮）

## C. 命中（Impact）
- 命中火花（3~5 幀）
- 地面裂紋（停留 0.3~0.8s）
- 衝擊波環（由小到大淡出）

## D. 殘留（Aftermath）
- 灰塵/煙霧（低 alpha）
- 危險區殘留（毒圈/冰圈）
- 收束光點（往中心吸回）

## E. 移動類（Dash/Projectile）
- 殘影拖尾（2~3 片）
- 軌跡粒子（低量）
- 彈體尾焰（短循環）

---

## 3) 怪物技能模板（設計時直接套）

每個技能統一四段：
1. 預警（可躲）  
2. 施放（可判讀）  
3. 命中（有爽感）  
4. 殘留（有後果）

### 範例：史萊姆治療圈
- 預警：腳下淡綠圈 0.2s
- 施放：史萊姆 spell 動畫 + 小光點聚集
- 命中：角色頭上 +Heal 跳字
- 殘留：綠色微光 0.25s 後消失

### 範例：落劍重擊
- 預警：紅圈 + 中央十字 0.35s
- 施放：劍影下落
- 命中：白閃 + 地裂
- 殘留：塵霧 0.5s

---

## 4) 手機效能預算（本專案建議）

- 同屏主動技能特效：<= `GlobalBalance.FX_MAX_ACTIVE_SKILL_FX`（目前 6）
- 粒子目標：<= `GlobalBalance.FX_PARTICLE_SOFT_CAP`（目前 60）
- 單特效幀數：4~8 幀（超過 12 幀要有理由）
- 單特效透明大面積圖層：盡量 <= 2 層
- 優先 atlas 合圖，避免頻繁材質切換

---

## 5) 錄製/烘焙教學（Route A：SubViewport 透明逐幀）

工具檔案：
- `scenes場景/tools工具/FrameBakeTool.tscn`
- `src腳本/tools工具/FrameBakeTool.gd`

### 使用步驟
1. 開 `FrameBakeTool.tscn`
2. 在 Inspector 指定 `effect_scene`
3. 設 `viewport_size`, `frame_count`, `capture_fps`
4. 按 `Enter` 開始烘焙（`ui_accept`）
5. 輸出在 `user://fx_bake`，檔名 `frame0000.png...`

### 推薦參數
- 小特效：256x256 / 8 幀 / 24~30 fps
- 中特效：512x512 / 12~16 幀 / 30 fps

### 注意
- 烘焙前先讓特效根節點置中（工具會把節點放在 viewport 中心）
- 若首幀太早，調大 `warmup_frames`

---

## 6) 命名與資料規範（避免日後混亂）

### 檔名
- `fx_<category>_<name>_<phase>.tres`
- 例：`fx_slime_heal_telegraph.tres`

### 動畫命名
- `telegraph`, `cast`, `impact`, `loop`, `end`

### 資料腳本
- `SkillFxResource.gd`：三段式特效資料
- 由 `EffectManager.play_skill_fx()` 播放（telegraph -> cast -> impact）

---

## 7) 量產日（Batch Day）建議流程

1. 先列 10 招技能清單（只寫「四段文字」）
2. 先做每招 `telegraph`（全部可讀）
3. 再補 `impact`（打擊感）
4. 最後補 `cast/aftermath`（錦上添花）
5. 每做完 3 招就上手機測一次 FPS

---

## 8) 怪物設計靈感清單（可直接抽選）

- 史萊姆：
  - 黏液擴散圈（殘留減速）
  - 分裂前預警閃
- 石像怪：
  - 地面裂縫直線衝擊
  - 抬手震地扇形波
- 幽靈：
  - 短距瞬移殘影
  - 吸氣收束再爆發
- 機械怪：
  - 掃描線預警
  - 連段光彈（節拍型）

---

## 9) 版本化與維護

- 每新增一招特效，補一行到本檔「靈感清單」或另開對照表
- 每次大改特效風格前，先 commit（方便 rollback）
- 若要新增規範，優先同步 `ARCHITECTURE.md` 的相關章節

---

## 10) 現在就能做的下一步（建議）

1. 先做 `slime_heal` 的完整三段（telegraph/cast/impact）
2. 把 `落劍` 拆成三段重組（你已有素材，最省）
3. `劍氣` 做 1 套模板，之後怪物共用只換色

---

## 11) 程序化 FX 模板（v3）

### 模板資源與播放入口
- 模板資源：`src腳本/resources身分證/FxTemplateResource.gd`
- 預設模板庫：`src腳本/resources身分證/skill_fx_templates/FxTemplateLibrary.gd`
- 播放節點：`src腳本/components積木/ProceduralFxNode.gd`
- 世界層入口：`EffectManager.play_template_fx_by_id(template_id, world_pos, parent, facing)`

### 13 個可重用模板 ID
- `warning_circle`：預警圓形
- `warning_line`：預警直線
- `fissure`：裂地
- `fan_wave`：扇形波
- `smoke`：煙霧
- `fire`：火焰（火把/營火共用）
- `golden_motes`：金色光點（螢火蟲）
- `falling_leaves`：落葉
- `rain`：下雨
- `afterimage_trail`：殘影拖尾
- `purple_trail`：紫色軌跡粒子（可換色）
- `water_column`：灌下來水柱
- `projectile_tail`：彈體尾焰

### 技能串接方式（Signal-only UI 不變）
- 在 `SkillResource` 填三段欄位：
  - `telegraph_fx_template_id`
  - `cast_fx_template_id`
  - `impact_fx_template_id`
- `MonsterSpellState` 會在詠唱流程自動播放三段模板，不經 UI 腳本。

### 編輯器內逐招製作（推薦）
- 警示圈母場景：`scenes場景/tools工具/fx_authoring/warning_circle.tscn`
- 火焰／營火母場景：`scenes場景/tools工具/fx_authoring/fire.tscn`
- 這兩個都是 `@tool`，可在 2D 視圖直接看效果與調 Inspector，不用先 F6 進遊戲。
- 建議流程：複製母場景 -> 調參到位 -> 用 `FrameBakeTool` 烘焙 -> 匯入 `SpriteFrames` -> 接技能三段。

---

## 12) 目前進度（2026-03）

### 已完成（可直接使用）
- `heal spell`：長動畫版已完成（既有素材 + 內建粒子）
- `落劍`：演出與節奏已完成（播完後才慢慢顯示 UI）
- `FrameBakeTool`：可將任何 Node2D 特效場景輸出為透明 PNG 序列
- `SkillFxResource` / `EffectManager`：三段式播放 MVP 已在專案中
- 程序化模板系統已建立（13 種模板 + 可參數化）
- 編輯器內 Authoring 場景已建立：
  - `warning_circle`（警示圈骨架）
  - `fire`（營火骨架）

### 目前骨架狀態（你已確認方向）
- 哥布林警示圈：已做「淡紅圈 + 中心能量往外擴 + 接近結尾 flash」骨架
- 營火：已做「底部大顆重疊、上升後隨機縮小與透明消失」粒子行為

---

## 13) 使用方式（新版工作流）

### 三層場景分工（都要留）
- `FxAuthoring*.tscn`：逐技能精修（主工作場）
- `FxPreview.tscn`：模板總覽與風格一致性檢查
- `FrameBakeTool.tscn`：最終輸出烘焙幀圖

### 一招技能的標準流程（5 步）
1. 複製最接近的 `FxAuthoring` 母場景，命名成技能專用場景  
2. 在 2D 視圖 + Inspector 調到「可讀 + 像素風 + 手機負擔可接受」  
3. 開 `FrameBakeTool.tscn`，將 `effect_scene` 指到該技能場景並烘焙  
4. 匯入為 `SpriteFrames`，掛回 `SkillFxResource` 或技能流程  
5. 進遊戲測「可躲判讀、命中回饋、FPS」後再收斂參數

---

## 14) 技能特效調整方向清單（逐項執行）

> 原則：先做「可讀性」，再做「細節華麗度」。

1) 預警圓形（warning circle）
- 先確保半透明外圈在 0.1~0.2s 內可被看見
- 中心能量外擴速度要與施法 trigger 對齊（例：0.8s 到圈邊）
- 接近觸發點加短 flash，但不可蓋掉敵我角色輪廓

2) 預警直線（warning line）
- 線寬需對齊最終傷害判定寬度
- 線頭與線尾保持像素對齊，避免抖動
- 可用節拍閃爍提示「即將斬出」

3) 裂地（fissure）
- 中央主裂紋清楚，支裂紋少量點綴
- 先重可讀輪廓，再補塵點
- 持續 0.25~0.45s 為主，避免拖太久干擾戰場資訊

4) 扇形波（fan wave）
- 扇形角度與怪物朝向一致（命中判讀優先）
- 內圈到外圈 alpha 漸層，避免整片過白
- 扇形邊緣保持乾淨，少噪點

5) 煙霧（smoke）
- 粒子顆數控制在低量，避免畫面霧化
- 生命末端偏透明，留輪廓但不遮角色
- 風格偏手繪方塊，不做過多柔化

6) 火焰（fire，火把/營火共用）
- 底部大顆重疊、上層顆粒漸小（已有骨架）
- 上升後透明衰減 + 隨機縮小
- 亮芯只佔火焰下半部，避免整柱過亮

7) 金色光點（golden motes / 螢火蟲）
- 慢速漂移、低顆數、低對比閃爍
- 優先「呼吸感」而非快速閃動
- 建議作為環境層，不干擾戰鬥可讀

8) 落葉（falling leaves）
- 下降 + 橫向小幅擺動
- 葉片尺寸與速度做 2~3 組隨機
- 顏色低飽和，避免搶 UI 焦點

9) 下雨（rain）
- 線段短、方向一致、速度明確
- 控制總量，手機先保 FPS
- 地面命中可加極短小濺點（可選）

10) 殘影拖尾（afterimage trail）
- 主體殘影 2~3 層即可
- 透明遞減要明顯，避免像卡頓
- 時長短（0.15~0.30s）更有瞬移感

11) 紫色軌跡粒子（purple trail，可換色）
- 尾線與粒子同方向，避免噪訊散亂
- 保留可換色參數（怪物共用）
- 建議作為 dash / slash 附層，不單獨搶戲

12) 灌下來水柱（water column）
- 柱體寬度對齊判定寬度
- 核心亮區 + 外層淡色，形體要清楚
- 末端消散要快，避免戰場殘像

13) 彈體尾焰（projectile tail）
- 方向必須貼齊彈體速度向量
- 尾長與彈速成正比（快彈更長）
- 保持低顆數，避免彈幕時過載


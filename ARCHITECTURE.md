# 《怪物與我 v3》開發規範與架構聖經（專案內固定版）

這份文件是「固定規範」：用來確保專案長期一致、可維護、可擴充。

- 你的 Google Sheet 可以持續寫日記/進度/數值/靈感（活文件）
- 但**任何會影響程式架構的規則**，以本文件為準（版本控制、避免對話 context 滿後遺忘）

> 如果你在對話裡跟 AI 說「照 `ARCHITECTURE.md` 做」，AI 應該以此文件為最高優先級的專案規範。

---

## 開工前置作業（先對齊需求，再寫程式）

本專案採用「**先討論 → 再落地**」的節奏，避免快速寫完才發現想像不一致，導致大改與士氣消耗。

### 每個功能點的必答 QA（最少回答到能寫程式）

1. **玩家體驗一句話（Player fantasy）**
   - 玩家做了什麼？看到什麼？聽到什麼？得到什麼回饋？

2. **觸發條件（Trigger）**
   - 何時會發生？誰發起（UI/世界/怪物）？是否可取消？

3. **成功/失敗/中斷（Outcomes）**
   - 成功怎樣、失敗怎樣、玩家離太遠/死亡/切場景怎樣？

4. **資料流（Data flow）**
   - 這件事會新增/更新哪些資料？寫入哪個 `Manager`？透過哪些 `SignalBus` 事件通知？

5. **邊界與禁區（Non-goals）**
   - 本次不做什麼？避免 scope creep（例如「先不做等級/技能樹/坐騎」）

6. **最小可玩版本（MVP）**
   - 什麼算完成？用哪個最短路徑先把「手感」跑起來？

> 規範：只要 QA 沒對齊，本專案寧可先討論，也不要急著寫檔案。

---

## 核心五大鐵則（不可破）

1. **純訊號驅動（Signal-Only UI）**
   - UI 嚴禁直接控制 `Player` 或 `Monster`（不直接讀寫玩家/怪物屬性、不 `get_node("../Player")` 去改速度等）
   - UI 只能透過 `SignalBus` 發射/監聽訊號
   - 世界層（Player/Monster/Manager）才可以做邏輯與狀態切換

2. **組件化（Component-first）**
   - 互動/封印/受傷/特效等以「積木」形式存在（`components積木/`）
   - 怪物封印相關必須集中在 `SealingComponent`（避免把封印塞進 UI 或 MonsterBase 亂長）

3. **狀態機節點化（State Machine as nodes）**
   - 玩家/怪物行為以狀態機節點管理（`states狀態機/`）
   - 新行為先想「狀態」再想「if else」

4. **資料驅動（Data-driven）**
   - 任何可調參數優先放 `Resource(.tres/.res)`（例如 `MonsterResource`、`PetResource`）
   - 禁止在程式寫「某怪物特例」：例如 `if monster_name == "Slime": ...`

5. **視覺控制權（Animation/Art > Code Position）**
   - 複雜互動動畫（擁抱、法陣碎裂、收縮旋轉等）優先使用美術/動畫資源
   - 程式只負責觸發、串接、與資料流，不要用大量位移計算硬做演出

---

## 命名規範（Naming Conventions）

### 檔案/資料夾
- **snake_case**（小寫+底線）為主，但本專案部分資料夾已採中文；新增時請遵循既有結構，不要混亂擴散。

### 類別（`class_name`）與節點（Node）
- **PascalCase**
- 例：`class_name PlayerController`、節點 `StateMachine`、`Sprite2D`

### 變數/函數
- **snake_case**
- 例：`move_speed`、`get_dir()`

### 常量
- **UPPER_CASE**
- 例：`MAX_HEALTH`、`ITEMS_PATH`

### 訊號（Signals）
- **過去式（past tense）**：代表「事件已發生」
- 例：`item_collected`、`dash_requested`

---

## 專案目錄結構（Directory Structure）

保持 `res://` 根目錄整潔，核心分類如下（以目前專案實際為準）：

- `assets圖片_字體_音效/`：美術/字體/音效資源（不可放邏輯）
- `scenes場景/`：所有場景 `.tscn`（UI、entities、levels）
- `src腳本/`：所有邏輯腳本（以功能分類）
  - `autoload管理員/`：全域單例（`SignalBus`、`DataManager`、`GlobalBalance`、`PetManager`、`InventoryManager`）
  - `components積木/`：可重用組件（`SealingComponent`、`HealthComponent`…）
  - `entities/`：實體行為（玩家、怪物、`entities/pets/` 出戰跟班與 Spawner 腳本）
  - `resources身分證/`：資料藍圖（`.gd` 定義 + `.tres` 資料）
  - `states狀態機/`：狀態機與狀態節點

---

## SignalBus 規範（Omni-Protocol）

`SignalBus.gd` 是「電台」，**只負責信號宣告**，禁止放任何邏輯運算。

### 原則
- **UI → SignalBus.emit → Manager/Entity 接收**
- **Manager/Entity → SignalBus.emit → UI/FX 接收**
- 避免互相直接呼叫造成循環、耦合、難測試

### 常用事件分層（建議）
- **Input/Request（請求型）**：UI 發射，世界層接收  
  例：`dash_requested`、`seal_mode_toggled`
- **Result/State（結果型）**：世界層發射，UI/資料層接收  
  例：`player_health_changed`、`seal_attempt_finished`、`pet_captured`

---

## 封印系統（Sealing）協議摘要

封印屬於「儀式型互動」，請嚴格保持 UI 與世界層分離。

### 流程（概念）
1. UI 透過 `SignalBus.seal_mode_toggled` 啟動儀式
2. `SealManager` 控制「畫圈 → 轉場 → 長壓」
3. `SealingComponent` 控制怪物封印進度、掙扎視覺、成功/失敗演出
4. 結算由 `SealManager` 發射 `SignalBus.seal_attempt_finished(success, monster_data)`

### 結算事件（非常重要）
- **封印成功/失敗**都應該只用「事件」往外通知
- 任何 UI 更新、資料寫入、生成演出，都應該由監聽者處理

---

## Phase 4：寵物 Resource 定義與轉化流程（已落地）

### 目標
「封印成功」能把怪物資料轉成寵物資料，並可供後續 UI/召喚/互動使用。

### Resource 定義

#### `MonsterResource`
- 新增欄位：`pet_data: PetResource`
- 讓每隻怪物 `.tres` 可資料驅動指定「封印後變成哪隻寵物」

#### `PetResource`
已落地欄位（建立 `.tres` 時請優先填滿，避免場上/UI 缺資料）：
- **身分**：`pet_id`、`pet_name`、`nickname`（清單與抬頭顯示用小名；封印入庫若為空，`PetManager` 會用 `pet_name` 補預設）
- **視覺**：`icon`、`sprite_frames`（多數沿用怪物；入庫與出戰時見下方「視覺繼承」）
- **成長/敘事**：`level`、`story`（多行）、`skills: Array[PetSkillEntry]`
- **跟隨/戰鬥基準**：`follow_distance`、`follow_speed_mult`、`max_hp`
- **支援**：`heal_amount`、`heal_cooldown`（寵物邏輯仍會參考；細部施法節奏可再配合 `SkillResource`）

#### `PetSkillEntry` / `SkillResource`（寵物技能列）
- `PetSkillEntry`：`skill: SkillResource`、`skill_level: int`
- `SkillResource` 除 `skill_name`、`cooldown`、`animation_name` 外，已支援 `description`（多行）；**癒系等需對齊動畫幀**時，以 `trigger_delay`（及其他時序欄）為準，避免效果早於演出

### 轉化與資料流

#### 結算事件
- `SealManager` 發射：`SignalBus.seal_attempt_finished(success, monster_data)`

#### 接收與轉化
- `PetManager`（autoload）監聽 `seal_attempt_finished`
  - success 才處理
  - 優先使用 `monster_data.pet_data`
  - **個體化**：模板 `pet_data` 必須 `duplicate(true)` 再入庫，避免同一 `.tres` 重複捕捉共用同一 `Resource` 參考（曾導致「一隻出戰、清單全顯示出戰」）
  - 入庫時若 `pet_data` 缺 `sprite_frames`，由當次封印的怪物繼承視覺（見 `_ensure_pet_inherits_monster_visual`）
  - 若未設定 `pet_data`，用 fallback 由怪物資料組合出一個 `PetResource`（最小可用）
  - 成功後發射 `SignalBus.pet_captured(pet_data)`、`pet_roster_changed`

#### `PetManager` 狀態（與 UI/世界對齊）
- `captured_pets: Array[PetResource]`：倉庫清單（每隻應為獨立實例）
- `active_pet`：目前 UI 選取、準備出戰/查看詳情的那隻
- `deployed_pet: PetResource`：**真正場上出戰**的那隻；`is_deployed` 與其一致（`deployed_pet != null`）
- 出戰/收回：`pet_deploy_requested(pet)`、`pet_recall_requested()` → 廣播 `pet_deployed_changed`

### 寵物列表 UI（已落地，持續視覺微調中）
- `scenes場景/ui介面/PetUI.*`
  - **左側**：`ScrollContainer` → `PetListRows`（`VBoxContainer`），每列為扁平 `Button` 內嵌 `HBox`：**名稱**字級 14、右側 **Lv 與 `·[戰]`** 字級 11（僅 `deployed_pet` 顯示 `[戰]`）；選列透過 `pet_active_requested` 同步 `active_pet`，列高亮以 `StyleBoxFlat` 區分。
  - **右側**：`HeaderRow`（圖示 + `NameBlock`：`Name`／`編號`／`Level`）、`Buttons`（出戰／坐騎／放生）、`DetailsScroll`（故事 + 技能，技能動態生成）。
  - **字級策略**：面板內文原則 **14**（清單右欄 meta 除外）；`nickname`／`pet_name` 顯示於名稱列；**`pet_id` 顯示為「編號」**（內部／存檔用，與玩家自訂綽號欄位 `nickname` 分開）。
  - **放生**：`ReleaseButton` → `ConfirmDialog`（`DialogLayer`/`CanvasLayer` 避免被主面板擋輸入）→ 確認後 `pet_release_requested`；`PetManager` 同步 `deployed_pet`／`active_pet`／`pet_roster_changed`。
  - **按鈕**：`DeployButton`（出戰/休息）、`MountButton`（`pet_mount_requested`）；與出戰互斥邏輯在 `PetUI` 內 **`pet_mount_requested` 仍為全域 bool**，尚未綁定「哪一隻坐騎」。
  - 監聽：`pet_captured`、`pet_roster_changed`、`pet_active_changed`、`pet_deployed_changed`（**部署變更時會整表 `_refresh`**，避免標籤不同步）
  - 出戰/休息只發 `SignalBus`（`pet_deploy_requested`、`pet_recall_requested`），不直接操作場景寵物節點
  - **版面與 HUD**：主場景 `UILayer/bottom`（底欄裝飾）高度與 **`GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX`**（預設 63）一致；`PetUI`／`InventoryUI` 的 **Panel `offset_bottom`** 於執行期套用 **`-UI_BOTTOM_BAR_HEIGHT_PX`**，不蓋底欄；**根節點 `mouse_filter = IGNORE`**、僅內容 `Panel` 擋滑鼠，以便底欄 **寵物／背包** 互切。無獨立「關閉」鈕，**同一入口鈕再按關閉**；互斥關閉見下方 `SignalBus`。

### 寵物場上實體（已落地）
- **主場景**：`LevelContainer/PetCompanionSpawner`（`PetCompanionSpawner.gd`）
- **生成時機**：監聽 `pet_deployed_changed(true)`、`pet_active_changed`（且 `PetManager.is_deployed`）；`call_deferred("_spawn")` 避免訊號內同步 `add_child` 邊角案例。
- **實體場景**：`scenes場景/entities主角_怪物_寵物/寵物/PetCompanion.tscn` + `src腳本/entities/pets/PetCompanion.gd`
- **行為摘要**：跟隨與戰鬥黏著（主角游擊時仍可鎖敵至距離過遠再脫離）、`SignalBus.player_melee_hit` 觸發協攻、週期治療（施法動畫長度與補血觸發與 `SkillResource` 時序對齊）、怪物攻擊同距離可打 `deployed_pet` 群組；血量歸零會 `pet_recall_requested`。
- **影子**：`PetCompanion.tscn` 使用 `ShadowComponent`；其 `_process` 會自 `AnimatedSprite2D` 同步 `sprite_frames` 並檢查動畫名，避免主體換圖後陰影撥到空字串或不存在動畫。
- **`PetResource` 必備視覺**：`.tres` 若只填 `icon`、沒填 `sprite_frames`，場上會透明。封印成功入庫時，若怪物已內嵌 `pet_data` 但缺 `sprite_frames`，`PetManager` 會從當次封印的怪物繼承其 `sprite_frames`。出戰時 `PetCompanion` 再解析：先用 `PetResource.sprite_frames`，缺則載入 `resources身分證/monster/<pet_id>.tres` 取該怪物的 `sprite_frames`；`pet_id` 空或無對應檔時，最後備援 `monster/slime_green.tres`。

### 相關 SignalBus（本階段常碰到）
- `pet_deploy_requested` / `pet_recall_requested` / `pet_release_requested` / `pet_deployed_changed` / `pet_active_changed`（`Variant`，清單空則 `null`）/ `pet_captured` / `pet_mount_requested`
- **UI 互斥（僅轉發，無邏輯）**：`pet_ui_close_requested`、`inventory_ui_close_requested`（開啟一邊面板時請另一邊 UI 關閉，避免全螢幕遮擋底欄按鈕）
- `player_melee_hit(melee_target: Variant)`：主角近戰**結算幀**通知；參數為當下命中的 `HurtboxComponent`，無目標則 `null`（型別用 `Variant` 避免執行期嚴格型別與 `null` 不相容）。實作上由 `PlayerAttackState` 在揮擊開頭快照目標，並以固定延遲觸發 `hit_current_target(override)`，避免動畫先結束導致協攻漏發。
- `seal_sword_fall_finished`：大劍動畫結束（與 `SealHudLocker` 緩慢恢復 HUD 有關）

---

## Phase 5：背包、放生確認、底欄與 HUD（已落地）

### 道具背包（簡易版）
- **`InventoryManager`**（autoload）：監聽 `item_collected`，以 `item_id` 堆疊；`get_item_tab_entries()`＝非 `ItemResource.ItemType.EQUIPMENT`；`get_headwear_tab_entries()`＝`EQUIPMENT`（日後可改專用頭飾 Resource）。
- **`InventoryUI`**（`scenes場景/ui介面/InventoryUI.*`）：底欄 **「背包」** 開關；`Tab`（`ButtonGroup`）切換道具／頭飾；與 `PetUI` 同 **`GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX` 預留**、**互斥訊號**、無獨立關閉鈕。
- **`DataManager`** 仍負責掃描 `ItemResource` 資料庫目錄；實際入庫堆疊在 `InventoryManager`。

### 可重用確認框
- **`ConfirmDialog`**（`scenes場景/ui介面/ConfirmDialog.tscn` + `.gd`）：`present(title, body_bbcode, confirm, cancel)`；`confirmed` / `cancelled`。掛在 **`PetUI/DialogLayer`**（高 `layer`）以免被主面板吃掉輸入；其他 UI 可 **instance 同場景** 複用。

### 封印儀式與底欄按鈕
- **`SealHudLocker.gd`**：`seal_ui_requested(true)` 時隱藏並避免誤觸 **血條、瞬移、寵物開啟鈕、背包開啟鈕**；結束／大劍落下後依延遲與淡入邏輯恢復（見腳本常數）。

### 主場景底欄
- **`Main.tscn` → `UILayer/bottom`**：`Panel`，錨點靠底，**高度**須與 **`GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX`** 一致（預設 `offset_top = -63`）；與 `PetUI`/`InventoryUI` 面板底緣對齊，避免遮擋 **寵物／背包**。

---

## Phase 6：技能特效模板化（進行中，約 75%）

### 目前狀態
- 已完成模板基底與流程接線，整體進度約 **75%**
- 剩餘 25% 為「逐技能細修視覺」與「觸發時機對齊（可躲判讀）」

### 已落地內容
- `FrameBakeTool`：特效場景透明逐幀輸出
- 程序化模板系統（13 類）：`warning_circle`、`warning_line`、`fissure`、`fan_wave`、`smoke`、`fire`、`golden_motes`、`falling_leaves`、`rain`、`afterimage_trail`、`purple_trail`、`water_column`、`projectile_tail`
- `FxPreview.tscn`：模板總覽與巡覽驗收
- `fx_authoring` 場景：可在 2D 視圖直接調參（`warning_circle`、`fire` 先落地）
- 技能欄位支援模板 ID（三段）：`telegraph_fx_template_id` / `cast_fx_template_id` / `impact_fx_template_id`

### 現階段策略（固定）
- 既有完成演出（如 heal 長動畫、落劍）優先沿用，不強制套模板
- 新怪物/環境技能優先用模板快速建立可玩版本
- 量產節奏：`fx_authoring` 精修 -> `FrameBakeTool` 烘焙 -> `SpriteFrames` 接回技能

---

## Phase 7：頭飾系統（進行中）

### 設計目標
- 支援玩家與怪物共用頭飾系統
- 優先低維護、可量產，不走全幀手工標記
- 保持資料驅動與 Signal-Only UI

### 核心策略（90/10）
- **90%**：角色資源級錨點（`head_anchor_offset`）作為主解
- **10%**：特例動畫補正（`animation_anchor_overrides`）
- 極少數才使用幀級覆寫（`frame_anchor_overrides`），避免資料爆量

### 錨點取值優先序（高到低）
1. `frame_anchor_overrides[animation][frame]`
2. `animation_anchor_overrides[animation]`
3. `head_anchor_offset`（角色預設）
4. 全域 fallback（保底）

### 架構原則
- 真相放在 `Resource`（玩家/怪物資料），scene 只作顯示與 fallback
- 禁止為單一怪物寫 if 特例，頭飾位置完全走資料
- 所有手調成功值要回寫資源，不留在臨時場景偏移

### 第 1 步落地現況（已完成：欄位 + 讀取規範）
- **怪物（Resource 驅動）**
  - `MonsterResource` 已新增：`head_anchor_offset`、`animation_anchor_overrides`、`frame_anchor_overrides`
  - 提供 `resolve_head_anchor_offset(animation_name, frame_index, fallback_offset)`，固定依序取值：幀覆寫 -> 動畫覆寫 -> 基準 offset -> fallback
  - `MonsterBase.gd` 每幀以目前 `AnimatedSprite2D` 的 `animation/frame` 更新 `AccessoryPoint` 位置（供頭飾顯示節點直接讀取）
- **主角（單一角色，腳本 + 節點）**
  - 因目前無 `PlayerResource`，先在 `PlayerController.gd` 落地同名三欄位與同優先序解析函式
  - `Player.tscn` 新增 `AccessoryPoint`，並由 `PlayerController.gd` 同步更新位置
- **相容策略**
  - 怪物既有 `accessory_offset` 暫保留，作過渡相容；新資料以 `head_anchor_offset` 三層覆寫規範為準

### 實作順序（更新）
1. ✅ 新增資源欄位與讀取規範（先不動 UI）
2. 先全角色填 `head_anchor_offset`，達到可用基準
3. 列出穿幫動畫清單，只補動畫級覆寫
4. 僅對極少數動作加幀級覆寫
5. 最後才接背包「裝備頭飾」流程與顯示切換

### 驗收標準
- 靜止、移動、常用攻擊三類動畫頭飾都穩定
- 不因換怪物/換皮膚造成明顯漂移
- 手機效能不因頭飾系統出現額外明顯負擔

---

## 下一階段（文件錨點，供新對話接手）

以下為**接續本 repo 現狀**的優先項；實作時維持「Signal-Only UI」與本文件鐵則。

1. **影子（細修）**  
   - **`ShadowComponent`**（玩家／怪物／`PetCompanion` 等）：與主體 `AnimatedSprite2D` 的動畫／縮放／翻面一致；寵物換 `sprite_frames` 後陰影不撥空動畫（既有邏輯可再調參數與美術對齊）。  
   - 相關場景：`PetCompanion.tscn`、怪物與玩家 prefab 上的影子節點。

2. **道具與寵物頁「視覺 polish」（不改資料流）**  
   - **`PetUI`**：清單列對齊、捲動區、右欄 `DetailsScroll` 間距／字重／色票統一；確認框文案／色碼若再調，維持 BBCode 於 `PetUI.gd` 的 `present` 字串。  
   - **`InventoryUI`**：分頁與清單密度、空狀態文案、與底欄 **`bottom`** 的視覺銜接。  
   - **底欄 63px**：單一數值定義於 **`GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX`**（`PetUI`／`InventoryUI` 於 `_ready` 套用至 `Panel.offset_bottom`）；**主場景** `Main.tscn` → `UILayer/bottom` 的 **`offset_top = -63`** 須手動與該常數一致（改高度時三處一起改）。

3. **家園（預留敘事，尚未系統）**  
   - 放生確認框已用「家園陪媽媽」作**世界觀占位**；實作家園時應改為 **`SignalBus` + `PetManager`／專用 `HomeManager`（名稱待定）** 資料流（例如請求型 `pet_sent_to_home_requested`、狀態型 `pet_home_roster_changed`），**禁止**在 `SignalBus.gd` 寫業務邏輯。  
   - **存檔語意**：隨身清單 `captured_pets` 與「家園駐留」應以清楚欄位或分表區分，避免同一陣列混兩種狀態。  
   - **敘事**：家園場景落地後，占位文案可改為與任務／NPC 對齊的實際台詞，仍只經 UI 字串與 `ConfirmDialog`，不偷跑資料寫入。

4. **可選擴充**  
   - 背包道具使用／裝備頭飾的請求型訊號與 UI。  
   - `pet_mount_requested` 與單一寵物／`mounted_pet` 綁定。

---

## 寵物出戰策略

本專案採用「**先收集、後出戰**」：封印成功只寫入 `PetManager` 並廣播；玩家在寵物頁按出戰後，**`PetCompanionSpawner`** 在玩家旁生成 **`PetCompanion`**。

### 封印成功（資料層）
- `PetManager.captured_pets` 增加、`active_pet`（若尚未設定）指向新寵物、發射 `pet_captured`。
- **不**在封印成功當下自動生成場上寵物（除非你日後另加開關）。

### 可選（尚未做）：封印成功後自動出戰
- 若要做，須在監聽成功結算處額外觸發與 `pet_deploy_requested` 等價的世界層邏輯，且仍保留清單資料一致。

---

## 開發節奏建議（降低翻車率）

- 每完成一個「功能點」就做一次 git commit（當作可回復存檔點）
- 大改動先開新分支（例如 `phase5-pet-ui`）
- 如遇到資料夾移動/改名：
  - 盡量在 Godot Editor 內移動（讓引用更新）
  - 移動後立刻跑一次遊戲看輸出是否紅字

### 與《開發總誌_v4.xlsx》同步規則（固定）

- 每次 `ARCHITECTURE.md` 有實質更新時，必同步更新總誌頁籤：`02`、`03`、`07`、`100`
- `02_專案架構聖經_同步版`：第一列放本次 `ARCHITECTURE.md` 最新快照（摘要）
- `03_Phase7與未來佇列`：更新當前優先級、依賴、完成定義
- `07_已完成里程碑`：記錄本次「有變更 / 無變更」的歷程（含原因與影響）
- `100_靈感牆`：收錄本次衍生但未定案的想法，待升格

#### `04_數值中心` 特別規範
- `04` 是「目前有效值查閱總表」，**不是**歷程日記
- 只有在數值實際變更時才更新 `04`
- 若本次無數值變更：`04` 不動，改在 `07` 記一條「本次無數值變更」

---

## 常見地雷（請避免）

- UI 直接抓 Player/Monster 改屬性（破壞解耦）
- 在 `SignalBus.gd` 寫邏輯（破壞電台）
- 用「特例 if」硬寫某怪物/某寵物（破壞資料驅動）
- 移動/改名資源檔但沒同步引用（容易變成「只剩 `.uid`」或丟失 `.tres`）


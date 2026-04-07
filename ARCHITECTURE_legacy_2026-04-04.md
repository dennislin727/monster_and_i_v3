> **【凍結快照 2026-04-04 — 僅歷史對照，勿當主聖經、勿持續編輯】** 本檔為整理**開始前**之 **`ARCHITECTURE.md` 複本**，只供 diff／「整理前原文」查詢。**現行規範與結構一律以倉庫根目錄 `ARCHITECTURE.md`（已 2026-04 分批整理）為準**；若與本檔矛盾，**以主檔為準**。盤點與批次紀錄見 **`docs/ARCHITECTURE_INVENTORY_2026-04-04.md`**。

# 《怪物與我 v3》開發規範與架構聖經（專案內固定版）

這份文件是「固定規範」：用來確保專案長期一致、可維護、可擴充。

- 你的 Google Sheet 可以持續寫日記/進度/數值/靈感（活文件）
- 但**任何會影響程式架構的規則**，以本文件為準（版本控制、避免對話 context 滿後遺忘）

> 如果你在對話裡跟 AI 說「照 `ARCHITECTURE.md` 做」，AI 應該以此文件為最高優先級的專案規範。

**引擎速查**：本專案以 **Godot 4.4** 為準（見 `project.godot` → `[application]` → `config/features`，目前含 `4.4` 與 `Mobile`）。聖經裡的編輯器步驟、節點／選單名稱皆依此版本描述；本機安裝的編輯器**小版號**可略新於 4.4，但若選單與文件不符，以專案能無誤開啟為準。

> **文件整理（2026-04-01）**：僅新增 **「文件導覽」**、美術快速入口、與少數**互補說明**（不重複貼全文）；**未刪減**既有技術段落。長假或新對話回來可先讀下方導覽再進各 Phase。

---

## 文件導覽（讀我）

### 美術／企劃快速入口（不用先讀完整份）

| 你想做的事 | 先跳這裡 |
|------------|----------|
| 從資料夾產怪／寵物 `SpriteFrames`、`.tres`，**調完 FPS 別被建置洗掉** | **Phase 4** →「怪物／寵物批次建置工作流」＋同節「節奏（重要）」 |
| 遠程怪：**普攻 vs 大絕**、落地紅圈 vs 攝影機橫掃、翻轉／跑動跳幀 | **Phase 4** →「怪物動畫／遠程普攻 vs Spell／鬼影位移」 |
| 落石／線掃「飄走」、**世界 FX 與 UI 層** | 同上節 →「世界 FX 勿掛在 `CanvasLayer`」；程式上已改掛 **`level_container`** |
| UI 色票、帳簿風、血條像素圓角 | **願景佇列** →「Phase 8 UI 視覺風格協議」 |
| 家園：**看家寵物站位**不跟綠區走、只看到 log 有 spawn | **常見地雷** →「家園站點與 2D 變換鏈」；根因常是 **`HomesteadStationRoot` 誤用純 `Node`**，應為 **`Node2D`**，`StationMarkers` 再對齊美術區域 |
| 湖畔／城鎮／洞窟／Boss 換關、`y_sort`、**電影淡換關**、**城鎮落葉粒子** | **湖畔關卡** 整章＋**§5**（換關已落地）、**§8**（四圖、**§8.6**）、**城鎮田園**、**Phase 10**「2026-04 補記」、**`ShopManager` 留線** |
| 右側 **翻滾 + 戰技（兩鈕）**、**指揮系統**（**已落地 2026-04-05**；盤查／避坑／**§5**／**§6**） | **`## Phase 12：指揮系統（Command System）`**（**§2.4**：碰撞 idle **飄移已修**；封印／技能後面向仍留線） |

### 章節索引（`##` 主標一覽）

1. 開工前置作業（QA） → 2. 核心五大鐵則 → 3. 命名規範 → 4. 專案目錄結構 → 5. SignalBus 規範 → 6. 封印系統協議摘要  
7. **Phase 4**（寵物轉化、批次建置、**怪物戰鬥／FX 聖經級**、PetManager／寵物 UI／場上寵物；**手動技能小節**為歷史規格草稿，**以 Phase 12 為準**）  
8. **Phase 5**（背包／底欄 HUD）→ 9. **Phase 11**（日記／存檔）→ 10. **Phase 6**（技能特效模板）→ 11. **Phase 7**（頭飾）  
12. **Phase 9**（NPC 對話）→ 13. **湖畔關卡 LakeSideLevel** → 14. **Phase 10**（家園採收）→ 15. **Phase 12**（**指揮系統** — **2026-04-05 已落地**，見該章 **§6**）  
16. 待辦與未實作清單 → 17. 下一階段（錨點）→ 18. 願景佇列（含 Phase 8 UI 協議）→ 19. 寵物出戰策略 → 20. 開發節奏與總誌同步 → 21. **常見地雷** → 22. AI 溝通詞彙表  

**易重複閱讀區**：「待辦」「下一階段」「願景佇列」三處有交叉引用，**單一真相以願景佇列的長線順序＋待辦表狀態為準**；**指揮系統主線**已結案 — 見 **Phase 12 §6**。**§2.4**：**碰撞後 idle 飄移**已程式修復（2026-04）；**封印／技能後面向／run 錯亂**仍為獨立體驗債。戰鬥／座標細節以 Phase 4 內「怪物動畫…」為準，**常見地雷**補全域與編輯器坑。

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
  - `autoload管理員/`：全域單例（`SignalBus`、`DataManager`、`GlobalBalance`、`SaveGameManager`、`DiaryManager`、`PetManager`（含 **`party_heal_pending_*`**：多寵補血預約，減同目標溢補）、`InventoryManager`、`ProgressionManager`、`NpcInteractionManager`、`NpcStateManager`、`DialogueManager`、`HomesteadStationDialogue`、`HomeManager`、`PlayerHintCatalog`；**留線**：**`ShopManager`**（NPC 商店：金幣↔道具，見 **湖畔章 §8.4**）— 落地後再註冊 `project.godot`；採收模式／家園關卡切換之業務集中於 `HomeManager`，`SignalBus` 僅宣告對應訊號；情境提示文案集中於 `PlayerHintCatalog`；**單槽存檔**集中於 `SaveGameManager`，**日記／生涯成就**集中於 `DiaryManager`，**玩家／寵物戰鬥經驗分攤**集中於 `ProgressionManager`）
  - `components積木/`：可重用組件（`SealingComponent`、`HealthComponent`…）
  - `entities/`：實體行為（玩家、怪物、`entities/pets/` 出戰跟班與 Spawner 腳本、`entities/npcs/` 場上 NPC 互動、**`entities/homestead/`** 家園區域／作物／傳送門腳本〔傳送 API 保留〕）
  - `resources身分證/`：資料藍圖（`.gd` 定義 + `.tres` 資料；含 `dialogue/`、`npc/` 對話與 NPC 身分）
  - `ui/`（`src腳本/ui/`）：跨 UI 共用的小型樣式／工具（例：`DialogueLedgerButtonStyle`）
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

### Phase 9 NPC／對話（已宣告之訊號，電台仍無邏輯）
- **狀態／展示**：`npc_interaction_prompt_changed(visible, npc_id, prompt_text, anchor_global)`、`dialogue_presented(visible, body_bbcode, choice_labels)`、`dialogue_blocking_changed(blocked)`、`npc_affinity_changed(npc_id, new_value)`（由 `NpcStateManager` 廣播）
- **請求**：`npc_dialogue_requested(npc_id)`、`dialogue_choice_selected(choice_index)`、`dialogue_close_requested`、`inventory_grant_requested(item_id, amount)`（與採集 `item_collected` **分流**，由 `InventoryManager` 堆疊）
- **對話獎勵 FX（請求）**：`dialogue_reward_vfx_requested(start_world_pos)` → `EffectManager` 播**靈魂球同款**資源，**拋物線落向螢幕下方**（不綁背包欄位）；與 **`PlayerController.play_dialogue_reward_happy(with_camera_punch)`** 搭配（見 **`## Phase 9` →「實作補記（2026-03-31，Phase 9／寵物／底欄／近戰）」**）。

### Phase 10 家園／採收（第一階已落地；電台仍無邏輯）

| 訊號 | 誰 emit | 誰 connect（主要） |
|------|---------|-------------------|
| `harvest_mode_toggled(enabled)` | `HarvestToggleButton` | `HomeManager` |
| `harvest_mode_changed(active)` | `HomeManager` | `HarvestHudLocker`、`HarvestSwipeCapture`、`PlayerController`（移動鎖） |
| `player_in_homestead_changed(in_homestead)` | `HomeManager` | `HarvestToggleButton`、`DialogueHudLocker`、`HarvestHudLocker` |
| `player_world_hint_changed(hint_id, show_hint, payload)` | `HomeManager`（家園採收教學）、**`DialogueManager`**（選項觸發）等 | `HarvestModeHint`；無 payload **`emit(..., null)`**；Dictionary＝**`instant_text`／`hold_sec`／`fade_out_sec`**（單行白字）**或** 家園打字序列 **`typing_intro`／`final_text`** 等（鍵見 Phase 10／HarvestModeHint 註解） |
| `area_title_show_requested(title, duration_sec)` | `HomeManager`（進區／`request_area_title`） | `AreaTitleBanner` |
| `area_title_hide_requested` | `HomeManager`（離區） | `AreaTitleBanner` |
| `item_collected`／`request_effect_collect` | `HomesteadCrop`（採收）等 | `InventoryManager`、`EffectManager` |

> `duration_sec`≤0 時 `AreaTitleBanner` 使用 `GlobalBalance.AREA_TITLE_*` 節奏。

### 日記／單槽存檔（2026-03-30 已落地；電台仍無邏輯）

| 訊號 | 誰 emit | 誰 connect（主要） |
|------|---------|-------------------|
| `game_save_requested` | `SaveGameButton`（`Main.tscn`／`UILayer`） | `SaveGameManager`（寫檔）、`SaveProgressOverlay`（全螢幕提示） |
| `game_save_finished(success)` | `SaveGameManager`（寫檔結束，含最短顯示時間） | `SaveProgressOverlay`（收起） |

---

## 封印系統（Sealing）協議摘要

封印屬於「儀式型互動」，請嚴格保持 UI 與世界層分離。

### 流程（概念）
1. UI 透過 `SignalBus.seal_mode_toggled` 啟動儀式
2. `SealManager` 控制「畫圈 → 轉場 → 長壓」
3. `SealingComponent` 控制怪物封印進度、掙扎視覺、成功/失敗演出
4. 結算由 `SealManager` 發射 `SignalBus.seal_attempt_finished(success, monster_data, sealed_body)`（`sealed_body`＝當下目標怪根節點，無則 `null`；**湖畔多隻環境寶寶鳥**分槽存檔用）

### 結算事件（非常重要）
- **封印成功/失敗**都應該只用「事件」往外通知
- 任何 UI 更新、資料寫入、生成演出，都應該由監聽者處理

### 與 Phase 9 的銜接（輸入）
- **`SealManager`** 畫圈依 **`_unhandled_input`**；**`SealUI` 根節點**須 **`mouse_filter = IGNORE`**（`Filter` 亦為 IGNORE），避免 `PanelContainer` 預設 STOP 擋線。對話／HUD 隱藏搖桿時須關 **`VirtualJoystick` 的 `set_process_input`**，見 **Phase 9**「曾出現問題」。

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

### 怪物／寵物批次建置工作流（`MonsterPackBuilder`，已落地）

從美術資料夾產出 `SpriteFrames`、`resources身分證/monster/{id}.tres`、`resources身分證/pet/{id}_pet.tres`，與編輯器手動建置二選一；本專案採 **`tools/MonsterPackBuilder.gd`** 集中設定 **`BUILD_SPECS`**（`Array[Dictionary]`，一筆一隻怪）。

| 步驟 | 說明 |
|------|------|
| 圖檔 | `assets圖片_字體_音效/怪物/<資料夾>/` 下，**子資料夾名 = 動畫名**（如 `idle_down`、`run_side`），內放 `frame*.png`。 |
| 設定 | 在 `BUILD_SPECS` 新增一筆：`id`、`tex_root`、`monster_name`、`story`、`pet_skill_paths`、`monster_skill_paths`、`balance` 等（見腳本內既有範例與註解）。 |
| 執行 | 雙擊 **`tools/run_monster_pack.bat`**（預設本機 Godot 路徑），或 `godot --headless --path <專案根> -s res://tools/run_monster_pack_cli.gd`。編輯器亦可執行 **`tools/BuildMonsterPackFromFolder.gd`**（`EditorScript` → Run）。 |
| 預覽 | `MonsterBase` 場景將 **`data`** 指到產生的 `{id}.tres`；動畫 Speed／頭飾錨點多在 **`{id}_spriteframes.tres`** 與 **`{id}.tres`**（`MonsterResource`）調整。 |

### 怪物動畫／遠程普攻 vs Spell／鬼影位移（聖經級，2026-04）

#### 遠程「普攻」與「Spell 大絕」怎麼分（別再混成同一招）

| | **遠程普攻（例：齊勒斯投石）** | **Spell 大絕（例：攝影機對角滾石）** |
|---|-------------------------------|-------------------------------------|
| **狀態機** | `MonsterAttackState` | `MonsterSpellState` |
| **美術動畫** | `attack_*`（方向由 `play_monster_animation("attack")` 解析） | `spell`（`SkillResource.animation_name`） |
| **資料從哪來** | `MonsterResource.ranged_basic_skill` → `SkillResource`（落地圈參數） | `MonsterResource.skills[]` 內的 `SkillResource` |
| **冷卻** | `MonsterResource.attack_cooldown` | 各技能的 `SkillResource.cooldown`（`skill_cds`） |
| **命中邏輯** | `aoe_use_ground_target = true` → **`GroundSlamAoE`**（鎖施法瞬間地面位置，可走位） | `aoe_use_ground_target = false` → **`LineSweepAoE`**（沿視窗對角橫掃，畫面中心感） |
| **威脅感** | 與走位、普攻 CD 綁在一起，壓力較低 | 全畫面掃線，單獨當大絕調 CD／傷害 |

- **AI 優先序**（`MonsterChaseState`）：先判定 **`get_available_skill()`**（`skills` 裡大絕好了）→ **`Spell`**；否則再判定 **`attack_cd_timer`** 與 **`ranged_basic_min_dist`** → **`Attack`** 普攻。兩者不要塞進同一個「只走 Spell」的技能欄，否則動畫與 CD 語意會打架。
- **`SkillResource.type`** 的 `AOE_ATTACK` 只是「範圍攻擊資料」，**不是**「這是普攻還是大絕」；**誰來施放**看的是 **狀態**（Attack vs Spell）與 **欄位**（`ranged_basic_skill` vs `skills`）。

#### 移動動畫常踩雷（已反覆發生，請對照程式）

- **`get_dir_string` 邊界抖動**：斜向速度在 `side`／`up`／`down` 閾值附近每幀切換 → `run_*` 像跳幀。**作法**：`MonsterBase._dir_smooth_ref` 平滑＋略放寬垂直／水平比。
- **`flip_h`（Chase）**：遠程 **拉開** 時若仍用「朝向主角」算翻轉，側跑會與速度相反；**Flee** 用 `velocity.x` 才對。**作法**：`RANGED_KITER` 且 **背離主角** 時改以 **`velocity.x`** 決定翻轉（見 `MonsterBase.play_monster_animation`）。
- **風箏門檻抖動**：在 `kite_retreat_below` 附近來回切拉開／靠近。**作法**：`MonsterChaseState` **闩鎖＋遲滯**。
- **封印長壓 `hit`**：勿只認 `hit_down`；改 **`play_monster_animation("hit")`**（`SealingComponent`）。
- **落地圈 vs 線掃**：`aoe_use_ground_target` 填錯會變成「永遠打不中」或「以為是普攻其實是全畫掃線」——與上表一起查。

#### `perform_ghost_dash` 與埋伏標記（與動畫地雷一樣重要）

- **用途**：瞬間位移到「背離主角扇形」內 **`move_and_collide` 合法**的終點（史萊姆鬼影、或 **`SkillResource.dash_before_skill`**）。
- **標記**：關卡內 **`Marker2D`／`Node2D`** 加入群組 **`monster_ambush_point`** → 掃向時對「朝向最近有效標記」的方向**加權**，仍不穿牆；**無標記**時維持舊行為（純最遠終點）。
- **與動畫的關係**：位移後速度／朝向突變若沒配好 **`get_dir_string`／`flip_h`**，下一幀仍會看起來「跑錯邊」——調位移點時請一併用上面「移動動畫常踩雷」檢查。

#### 世界 FX 勿掛在 `CanvasLayer`（落石／線掃／地板警示「飄走」的根因）

- **`EffectManager` 節點在 `Main.tscn` 裡掛在 `UILayer`（`CanvasLayer`）下**。在此樹下的 **`Node2D.global_position` 使用視窗／畫布空間**，與 **`LevelContainer`** 內主角、怪物的**世界座標**不是同一套；相機跟隨主角捲動或 zoom 後，看起來就像「特效固定在螢幕某處、與場景脫勾」（與家園／放置寵物若曾遇過的偏移同源類型問題）。
- **作法**：`EffectManager` 內對**世界座標**的 FX（**`GroundSlamAoE`**、**`LineSweepAoE`**、**`play_template_fx` 的程序特效**、**非螢幕空間的 `play_skill_fx`**）改 **`add_child` 到 `groups` → `level_container`**（無則 **`current_scene`**）。跳字／UI 仍可用 **`get_viewport().get_canvas_transform() * world_pos`** 或維持在 Canvas 下。
- **GDScript**：區域變數勿命名 **`tr`**（與 **`Object.tr()`** 翻譯衝突，報 `SHADOWED_VARIABLE_BASE_CLASS`）。

**節奏（重要）**：`BUILD_SPECS` 裡的每一筆，每次跑建置都會**從圖檔重建**對應的 `*_spriteframes.tres`，會**覆寫**你在 Godot 裡手調的動畫 **Speed（FPS 感）** 等。**每做好一隻怪並調完動畫／錨點後，就從 `BUILD_SPECS` 刪掉該筆**，列表只保留「下一隻待產檔」的怪，維持乾淨狀態量產世界；已產生的 `{id}.tres` / `{id}_pet.tres` / `{id}_spriteframes.tres` **仍留在 `resources身分證/`，不會因列表清空而消失**。若 **`BUILD_SPECS` 為空**，建置腳本**略過**、不報錯（方便日常只開遊戲不誤跑覆寫）。若因**換圖**必須重產某隻，可暫時把該隻加回列表再跑一次（須接受 SpriteFrames 被重算、手調 FPS 需重設或事後備份）。

### 轉化與資料流

#### 結算事件
- `SealManager` 發射：`SignalBus.seal_attempt_finished(success, monster_data, sealed_body)`

#### 接收與轉化
- `PetManager`（autoload）監聽 `seal_attempt_finished`
  - success 才處理
  - 優先使用 `monster_data.pet_data`
  - **湖畔環境寶寶鳥（多隻）**：`pet_id == baby_bird` 且 **`monster_data.participates_in_combat == false`** 時，若 **`sealed_body`** 具 **`get_lake_ambient_save_slot()`**，則 **`ProgressionManager.register_lake_ambient_baby_bird_slot_cleared(slot)`** 更新 **`lake_ambient_baby_bird_cleared_mask`**；下次載入 **`AmbientBabyBirdMonster._ready`** 依槽位已清則 **`queue_free()`**。場景 **`lake_ambient_save_slot`**（0 起、同圖不重複）須與 **`GlobalBalance.LAKE_AMBIENT_BABY_BIRD_TOTAL`**（湖畔直接實例隻數）對齊。
  - **個體化**：模板 `pet_data` 必須 `duplicate(true)` 再入庫，避免同一 `.tres` 重複捕捉共用同一 `Resource` 參考（曾導致「一隻出戰、清單全顯示出戰」）
  - 入庫時若 `pet_data` 缺 `sprite_frames`，由當次封印的怪物繼承視覺（見 `_ensure_pet_inherits_monster_visual`）
  - 若未設定 `pet_data`，用 fallback 由怪物資料組合出一個 `PetResource`（最小可用）
  - 成功後發射 `SignalBus.pet_captured(pet_data)`、`pet_roster_changed`

#### `PetManager` 狀態（與 UI/世界對齊，**2026-03-30：三槽編隊**）
- **`party_heal_pending_*`（2026-03-31）**：以 **`HealthComponent` 之 `instance_id`** 累加「詠唱中、尚未結算」補量；**`PetCompanion`** 選補目標時納入預約，**`_cast_heal_spell`** 全程釋放，減多寵同灌一隻溢補。
- `captured_pets: Array[PetResource]`：倉庫清單（每隻應為獨立實例）
- `active_pet`：目前 UI 選取、準備出戰／查看詳情的那隻
- **`party_slots`**：固定 **3** 格（`PetManager.PARTY_SLOT_COUNT`），元素為 `PetResource` 或 `null`。**新出戰**一律填入**第一個空槽**，**不遞補**（某槽收回後該格留空，下一隻仍從槽 1 起找空位）。
- **`is_deployed`**：任一格非空即為真；**`deployed_pet`**（向後相容讀取）：**第一個非空槽**的寵物（舊腳本／頭飾 fallback 仍可用）。
- **出戰**：`pet_deploy_requested(pet)` → 若有空槽則放入並廣播 **`pet_deployed_changed`**、**`pet_party_changed`**
- **收回**：`pet_recall_requested()` 只清 **目前 `active_pet` 所在槽**；**`pet_party_slot_recall_requested(slot_index)`** 清指定槽（槽位 HUD 點擊）
- **順序語意（2026-03-31）**：出戰「休息／收回」僅影響 `party_slots`，**不改 `captured_pets` 順序**（寵物仍視為在背包內）。
- **家園收回語意（2026-03-31）**：`unstation_pet_to_roster_tail(instance_id)` 代表「從駐留回背包＝重新入列」，會把該寵移到 `captured_pets` 尾端；僅移動陣列位置，**`instance_id` 與物件綁定不變**。
- **API 摘要**：`is_pet_on_party`、`find_first_empty_party_slot`、`get_party_slot_binding_key`、`get_deployed_party_entries`、`get_owner_key_slot_label`（頭飾 UI 顯示「槽1／槽2…」）
- **開局種子（無存檔時）**：`STARTER_PET_PATHS`（`PetManager.gd`）可**重複同一 `.tres` 路徑**多次，每次 `duplicate(true)` 成獨立個體（不同 `instance_id`）。若某路徑在清單中出現**超過一次**，種子時**不以 `pet_id` 去重**，並將暱稱標成 **`原名·1`／`·2`／`·3`** 以利列表辨識；路徑**僅列一次**時仍沿用舊規則（已有同 `pet_id` 則跳過，避免重複種）。**已有 `SaveGameManager` 待讀存檔時不會執行種子**，背包內容以 JSON 為準。

### 寵物列表 UI（已落地；**互動與資料流本階段已結案**；帳簿風與 Phase 8 協議對齊，後續僅跟新美術迭代）
- `scenes場景/ui介面/PetUI.*`
  - **左側**：`ScrollContainer` → `PetListRows`（`VBoxContainer`），每列為扁平 `Button` 內嵌 `HBox`：**名稱**字級 14、右側 **Lv 與 `·[戰]`** 字級 11（**在編隊內**即顯示 `[戰]`，以 `PetManager.is_pet_on_party` 判定）；選列透過 `pet_active_requested` 同步 `active_pet`，列高亮以 `StyleBoxFlat` 區分。
  - **右側**：`HeaderRow`（圖示 + `NameBlock`：`Name`／`編號`／`Level`）、`Buttons`（出戰／坐騎／**看家**＋放生）、`DetailsScroll`（故事 + 技能，技能動態生成）。**看家**：家園內駐留當前寵（按鈕文案，原「放置家園」）。
  - **字級策略**：面板內文原則 **14**（清單右欄 meta 除外）；`nickname`／`pet_name` 顯示於名稱列；**`pet_id` 顯示為「編號」**（內部／存檔用，與玩家自訂綽號欄位 `nickname` 分開）。
  - **放生**：`ReleaseButton` → `ConfirmDialog`（標題／確認鍵 **放生**；`DialogLayer`/`CanvasLayer`）→ `pet_release_requested`；`PetManager` 先自 **`party_slots` 移除該寵** 再同步 `active_pet`／`pet_roster_changed`。
  - **按鈕**：`DeployButton`（出戰／休息：**已在編隊則只收回該隻**；**三槽皆滿且當前寵未出戰**時鎖定出戰）、`MountButton`（`pet_mount_requested`）；與出戰互斥邏輯在 `PetUI` 內 **`pet_mount_requested` 仍為全域 bool**，尚未綁定「哪一隻坐騎」。
  - 監聽：`pet_captured`、`pet_roster_changed`、`pet_active_changed`、`pet_deployed_changed`、**`pet_party_changed`**（部署變更時會整表 `_refresh`**，避免標籤不同步）
  - 出戰／休息只發 `SignalBus`（`pet_deploy_requested`、`pet_recall_requested`），不直接操作場景寵物節點
  - **`pet_nickname_changed(pet_data)`**：簽名帶 `PetResource`；接聽端須有對應參數（例：`PetPartySlotHud` 用 `_on_pet_nickname_changed` 轉呼叫 `_refresh_labels`，不可直接連無參方法，否則 Godot 4 執行期報 callable 錯誤）。
  - **版面與 HUD**：主場景 `UILayer/bottom` 高度與 **`GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX`**（預設 63）一致；`PetUI`／`InventoryUI`／**`DiaryUI`** 的 **Panel `offset_bottom`** 為 **`-UI_BOTTOM_BAR_HEIGHT_PX`**；**根節點 `mouse_filter = IGNORE`**。底欄 **背包／寵物／日記** 為 **`toggle_mode`**，開面板時 **`set_pressed_no_signal(true)`** 維持 pressed（橘色）態，關閉或互斥時 **false**。無獨立關閉鈕；互斥見 `SignalBus`。

### 槽位捷徑 HUD（**2026-03-30 已落地**）
- **`scenes場景/ui介面/PetPartySlotHud.tscn` + `PetPartySlotHud.gd`**，掛於 **`Main.tscn` → `UILayer`**（`z_index` 與頂列 HUD 同級思維）。
- **版面**：三槽**同一列 Y**——槽1 與存檔鈕同水平錨點（0.101）置中寬 41px；槽2 與 **`PlayerHealthBar`** 左緣對齊；槽3 在槽2**右側**（間距 `_COL_GAP`）。**僅當該槽有寵物時顯示該鈕**（空槽不占位按鈕）。
- **視覺**：深褐底、咖啡框、**白字**（與帳簿淺底提示鈕區隔）；字級 10、尺寸對齊系統鈕寬。
- **漸顯／漸隱**：全隊無出戰時 `modulate.a = 0` 且 `visible = false`；**第一次有寵物出戰**時依 **`GlobalBalance.HUD_FADE_IN_SEC`** 漸顯；**最後一槽清空**後漸隱再隱藏，避免透明層誤觸。
- **互動**：點擊有寵之槽 → `pet_party_slot_recall_requested(slot_index)`。**`SealHudLocker`**、**`HarvestHudLocker`** 須隱藏本 HUD（與血條／採收一致），見各自 `UILayer` 節點表。

### 寵物場上實體（已落地，**多寵同步更新**）
- **主場景**：`LevelContainer/PetCompanionSpawner`（`PetCompanionSpawner.gd`）
- **生成時機**：監聽 **`pet_party_changed`** 與 **`pet_deployed_changed`**，`call_deferred("_sync_party")`；依 **`PetManager.party_slots`** 差分生成／回收，每槽最多一隻 **`PetCompanion`**（`instance_id` 對齊才保留同一節點）。
- **實體場景**：`scenes場景/entities主角_怪物_寵物/寵物/PetCompanion.tscn` + `src腳本/entities/pets/PetCompanion.gd`
- **`setup(pet_data, party_slot_index)`**：槽位決定 **生成點偏移**、**麵包屑額外延遲**（起跑錯開）、**`GlobalBalance.PET_PARTY_SLOT*_FOLLOW_MULT`** 跟隨／黏怪移速倍率。
- **行為摘要**：跟隨與戰鬥黏著；**`player_melee_hit`** 協攻（目標怪 **`MonsterBase.is_seal_magic_circle_active()`** 為真時**不協攻、不進戰鬥黏著**，避免長壓封印中被寵物圍毆）；週期治療與 **`SkillResource`** 時序對齊；怪物 **`MonsterChaseState`／`MonsterAttackState`** 以 **`get_nearest_hostile_target_global()`** 在主角與 **`deployed_pet` 群組**內取最近目標，飛撲可命中**範圍內多隻寵物**。
- **遠離瞬移**：與主角距離 ≥ **`GlobalBalance.PET_TELEPORT_PULL_DIST`** 時瞬移至 **`主角位置 + 該槽跟隨錨點偏移`** 並重設麵包屑（減少卡地形）。
- **死亡**：該寵 → **`pet_party_slot_recall_requested(該槽)`**，不整隊清空。
- **影子**：`PetCompanion.tscn` 使用 `ShadowComponent`；其 `_process` 會自 `AnimatedSprite2D` 同步 `sprite_frames` 並檢查動畫名，避免主體換圖後陰影撥到空字串或不存在動畫。
- **戰鬥移動動畫（2026-03-30）**：戰鬥黏著時**不再**將 `_dist_to_follow_slot` 設為固定大值（曾導致 `_visual_is_running` 全程為 true、**黏怪原地播 `run_*`**）。改為每幀以與 **`_combat_target_pos()`** 的實際距離寫入 `_dist_to_follow_slot`，與跟隨模式共用同一套 run／idle 遲滯門檻。
- **跟隨節奏與槽位節奏（2026-03-30 定調）**：各槽 **`GlobalBalance.PET_PARTY_SLOT0/1/2_FOLLOW_MULT`** 與 **`PET_PARTY_SLOT*_TRAIL_LAG_SEC`**（麵包屑取樣再延後）疊在 **`PetResource.follow_speed_mult`** 上；現行預設約為 **槽1：mult 1.0、lag 0**；**槽2：0.68、0.55s**；**槽3：0.76、0.4s**——第二隻刻意慢跑、晚起跑，三隻同種測試時差異明顯。`PetCompanion` 內若未讀到 `GlobalBalance`，fallback 與上述一致。
- **卡牆仍播 run（已修）**：跟隨用 **`velocity.lerp(...)`** 累加速度，**勿**以 `move_and_slide` 前 `velocity.length()` 當「意圖移動」閾值（會長期偏低、卡牆判定不成立）。改以本幀 **`_motion_intent_vel`**（目標 `dir * spd`）結合 **`_seek_point`**：實際位移小且**朝目標方向前進分量（dot）**過低時累積計時，達 **`STUCK_VISUAL_HOLD_SEC`** 則動畫改 **idle**，與主角 MoveState 以速度切 run／idle 的 spirit 對齊而不必共用整段位移管線。
- **`PetResource` 必備視覺**：`.tres` 若只填 `icon`、沒填 `sprite_frames`，場上會透明。封印成功入庫時，若怪物已內嵌 `pet_data` 但缺 `sprite_frames`，`PetManager` 會從當次封印的怪物繼承其 `sprite_frames`。出戰時 `PetCompanion` 再解析：先用 `PetResource.sprite_frames`，缺則載入 `resources身分證/monster/<pet_id>.tres` 取該怪物的 `sprite_frames`；`pet_id` 空或無對應檔時，最後備援 `monster/slime_green.tres`。

#### 飛行類寵物（寶寶鳥，`pet_id == baby_bird`，2026-04 已落地）

- **腳本**：`PetCompanion.gd` 於 `pet_id == baby_bird` 時啟用：**本體 `AnimatedSprite2D` Y 偏移**模擬飛高（**`GlobalBalance.BABY_BIRD_FLIGHT_Y_MAX`** 等），**影子**留在地面（`ShadowComponent` + **`PET_COMPANION_SHADOW_*`**）。
- **跟隨體感**：距離驅動目標高度（**`BABY_BIRD_FLIGHT_DIST_MIN`／`MAX`**、**`MOVE_ALT_FLOOR`**）、**懶散起飛**（**`LAZY_TAKEOFF_SEC`**）、遠距 **追趕加速**（**`CHASE_SPEED_MULT`／`CHASE_SPEED_DIST`**）、頭頂 **橢圓盤旋**（**`ORBIT_*`**）；**非戰鬥**時攝影機軟邊界 **外擴拉回**（**`PET_SCREEN_BOUNDARY_OUTSET_PX`** 等），避免窄螢硬切。
- **降落**：主角停步後 **長段下降**（播一般 **`run_*`**）→ 近地才播 **`run_*_1` 著陸**（**`LANDING_FINAL_HEIGHT`／`DESCENT_LERP`**）；著陸動畫 **原速**，不與整段下降綁慢動。
- **場景鐵則**：**`PetCompanion.tscn` 的 `AnimatedSprite2D` 勿序列化 `animation = …`**（須由 `_apply_pet_resource` 後再 `play`），否則 `instantiate()` 可能報不存在動畫名——見 **常見地雷**「`AnimatedSprite2D` 空／不存在動畫名」。
- **慶祝**：`_play_celebrate` 以 **`_pet_sprite_has_playable_anim`** 檢查 **`happy`／`spell`** 等，避免圖集缺軌時硬播。

### 手動寵物技能（歷史草稿：齒輪 UI）（規格草稿 2026-04；**乾淨重做請讀 Phase 12**）

> **狀態（2026-04-05）**：**指揮主線已落地** — 見 **`## Phase 12` → §6**。**產品版面（右側兩鈕：戰技＋翻滾）、契約、避坑與分線**仍以 **`## Phase 12`** 為**單一真相**（**2026-04-04** 起**廢止獨立齒輪鈕**）。**歷史**：曾有一輪齒輪實作**未達主打可靠度**而啟動重做敘述；本小節保留**早期文字**（含齒輪展開設想），供對照技能形態與訊號方向。

> **目標**：補「**玩家意圖管線**」——不必先近戰，也能指揮寵物遠距離施放技能（投石預覽圈、一鍵補血、日後控場／DoT）；與既有 **`player_melee_hit` 協攻**、**`party_damaged_by_monster` 還手**、**`_resolve_combat_aoe_skill` 自動戰鬥技**並存。

#### 版面與互動（右側行動區）

- **定案（請讀 Phase 12 §1）**：**翻滾**（永遠）＋ **寵物戰技**（**僅**槽 1 有寵且出戰時顯示，**在翻滾上方**），**垂直對齊**、同級尺寸；**無齒輪開關層**。
- **歷史草稿（曾設想齒輪）**：**翻滾** + **齒輪** 兩顆 → 後曾延伸為三鈕；**已不再採用**。
- **戰技與翻滾、HUD locker 同步**：凡 **翻滾鈕所屬 UI 被隱藏**時（與 **`SealHudLocker`**、採收／對話等 **HUD locker** 一致），**已顯示之戰技鈕一併隱藏**；建議 **同一父節點或同一腳本** 驅動。
- **槽 1 為空或未出戰**（`PetManager.party_slots[0] == null` 或該槽無場上寵）：**不顯示**戰技鈕（**非**半透明擋點；直接消失以免誤觸與語意混淆）。
- **戰技鈕文案**：**槽位 1** 當前寵物之**單一手動戰技** — 顯示 **`SkillResource.skill_name`**（如「治癒」「投石」）；圖示為可選擴充。

#### 指揮範圍（已定案）

- **僅 `party_slots[0]`（編隊槽 1）** 響應手動指令；槽 2／3 維持全自動，不在此面板出現。

#### 技能形態（分期）

| 形態 | 玩家操作 | 寵物端（概念） |
|------|-----------|----------------|
| **第一期** | **一鍵** | **治癒**：沿用 **`PetCompanion`** 既有選補／`party_heal_pending_*` 邏輯。 |
| **第一期** | **拖曳紅圈預覽 → 鬆手** | **投石**：世界座標結算，語意對齊 **`GroundSlamAoE`**／**`SkillResource`**（半徑、`aoe_use_ground_target`）；施法者為該槽 **`PetCompanion`**，走 **`EffectManager.play_ground_slam_aoe_from_skill`**（`hurt_player_side = false`）。 |
| **教學／後續** | **一鍵** | **撕咬**等：**寵物端在攻擊距離內自選敵方 `HurtboxComponent`** 再出傷；資料可掛 **`PetResource.skills`** 或專用指令型 **`SkillResource`**（實作時再定欄位）。 |

#### 架構鐵則

- **UI 只發 `SignalBus` 請求**（建議新增如 **`pet_manual_skill_requested(...)`**，參數含 **槽索引（固定 0）**、**技能辨識**、可選 **世界座標／取消瞄準**；精確簽名於實作時寫入 **`SignalBus.gd`**），**禁止**在 UI 結算傷害或治療。
- **`PetCompanion`（槽 1 實例）** 訂閱請求並負責：**CD**、**動畫鎖**、與 **封印／採收／對話／封印畫圈** 的 **互斥**（擴充既有 locker／輸入矩陣，與 `SealManager._unhandled_input` 不打架）。
- **自動 vs 手動 CD**：手動投石／治療與既有 **自動大技** 是否 **共用同一 `SkillResource.cooldown` 語意**待實作定案（**建議共用**，避免雙倍輸出）。

#### 新手教學（敘事錨點，非本節程式需求）

- **首次離城至湖畔**（敘事錨點待依定案改寫）：引導 **槽 1 出戰** 後 **戰技鈕出現** → **「撕咬」等一鍵** 先發制人（**不再**依賴齒輪展開）。觸發可掛 **區域切換**、**`PlayerHintCatalog`** 或 **對話圖**，**一次性 flag** 防重播。

### 相關 SignalBus（本階段常碰到）
- `pet_deploy_requested` / `pet_recall_requested` / **`pet_party_slot_recall_requested(slot_index)`** / `pet_release_requested` / `pet_deployed_changed` / **`pet_party_changed`** / `pet_active_changed`（`Variant`，清單空則 `null`）/ `pet_captured` / `pet_mount_requested`
- **UI 互斥（僅轉發，無邏輯）**：`pet_ui_close_requested`、`inventory_ui_close_requested`、`diary_ui_close_requested`（開啟背包／寵物／日記任一面板時互關另兩類面板；**僅** `diary_ui_close_requested` 負責收起日記，寵物／背包腳本**不**監聽此訊號以免誤關）。開話前 **`DialogueManager`** 亦發三則關閉訊號（含日記）。
- `player_melee_hit(melee_target: Variant)`：主角近戰**結算幀**通知；參數為當下命中的 `HurtboxComponent`，無目標則 `null`（型別用 `Variant` 避免執行期嚴格型別與 `null` 不相容）。實作上由 `PlayerAttackState` 在揮擊開頭快照目標，並以固定延遲觸發 `hit_current_target(override)`，避免動畫先結束導致協攻漏發。
- `seal_sword_fall_finished`：大劍動畫結束（與 `SealHudLocker` 緩慢恢復 HUD 有關）
- **手動戰技請求**：精確訊號名與簽名以 **`SignalBus.gd`** 為準（**Phase 12 §6** 已落地）；語意：右側 **戰技鈕** → **`PetCommandManager`** → **槽 1 `PetCompanion`**。

### 頭飾與多隻出戰（**已銜接**）
- **`InventoryManager._resolve_owner_node`**：依 `pet:<instance_id>` 在 **`deployed_pet` 群組內**逐節點比對 **`get_headwear_binding_key()`**，精準對應場上複數寵物。
- **`InventoryUI`**：裝頭飾選單為 **主角 + 各出戰槽「槽N 名稱」**（`get_deployed_party_entries`）；背包列表持有者標籤用 **`get_owner_key_slot_label`**。

---

## Phase 5：背包、寵物頁 UI、放生確認、底欄與 HUD（已落地；**道具／寵物頁互動本階段已結案**）

### 道具背包（簡易版）
- **`InventoryManager`**（autoload）：監聽 `item_collected`，以 `item_id` 堆疊；`get_item_tab_entries()`＝非 `ItemResource.ItemType.EQUIPMENT`；`get_headwear_tab_entries()`＝`EQUIPMENT`（日後可改專用頭飾 Resource）。
- **`InventoryUI`**（`scenes場景/ui介面/InventoryUI.*`）：底欄 **「背包」** 開關；`Tab`（`ButtonGroup`）切換道具／頭飾；與 `PetUI` 同 **`GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX` 預留**、**互斥訊號**、無獨立關閉鈕。
- **格子實作摘要（供維護／新對話對齊）**：清單區為 **`ScrollContainer` + `GridContainer`**，每格 **`Button`**（`toggle_mode` + 槽位專用 `ButtonGroup`）。`toggled` 以 **`func(p): _on_slot_toggled(p, b)`** 綁定，避免 `Callable.bind` 與訊號參數順序錯位。`InventoryManager.inventory_changed` 接 **`_refresh_list.call_deferred()`**，避免在 **`toggled` 回呼內同步 `queue_free` 觸發鈕**（曾導致裝備流程異常）。欄寬用 **`int((inner - total_sep) / float(cols))`** 消除整數除法警告（GDScript 的 `//` 為註解，不可用）。`GRID_COLUMNS` 目前為 **3**（與下方 Phase 8 帳簿風稿「4 欄」不同者，以程式常數為準）。
- **`DataManager`** 仍負責掃描 `ItemResource` 資料庫目錄；實際入庫堆疊在 `InventoryManager`。

### 可重用確認框
- **`ConfirmDialog`**（`scenes場景/ui介面/ConfirmDialog.tscn` + `.gd`）：`present(title, body_bbcode, confirm, cancel)`；`confirmed` / `cancelled`。掛在 **`PetUI/DialogLayer`**（高 `layer`）以免被主面板吃掉輸入；其他 UI 可 **instance 同場景** 複用。

### 封印儀式與底欄按鈕
- **`SealHudLocker.gd`**：`seal_ui_requested(true)` 時隱藏並避免誤觸 **血條、瞬移、寵物開啟鈕、背包開啟鈕、日記開啟鈕**（`DiaryUI/OpenButton`）、**存檔鈕**（`SaveGameButton`）、**`PetPartySlotHud`（編隊槽捷徑）**；結束／大劍落下後依延遲與淡入邏輯恢復（見腳本常數）。
- **指揮兩鈕（戰技／翻滾）**：已與 **`RightActionGroup`**、各 **HUD locker** 同組隱藏規則落地 — 見 **`## Phase 12` → §6**（歷史齒輪草稿仍見 Phase 4 同標題小節）。

### 主場景底欄
- **`GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX`（預設 63）**：**語意是「底緣互動留白」**，供 **`PetUI`／`InventoryUI`／`DiaryUI`** 主面板 **`offset_bottom`**、**`HarvestSwipeCapture`** 底緣不蓋底欄三鈕等腳本對齊——**不等於**主場景灰底 `Panel` 的實際像素高度。
- **`Main.tscn` → `UILayer/bottom`（灰底 `Panel`）**：**單一真相以場景序列化為準**（AI 勿擅自改回「全寬 63px 粗條」假設）。**現況設計（2026-04）**：灰條**高度收矮**，把**上方區域讓給虛擬搖桿**；**寬度為左右鋪滿畫面**（錨點 `0`～`1`、必要時 `offset_left/right = 0`）。透明度等視覺見該節點 `modulate`。
- **虛擬搖桿**：同 **`Main.tscn` → `UILayer/Virtual Joystick`**；錨點與 offset 可能隨「搖桿可拖區」調整，**勿**與本節舊描述強綁。

### 底欄三鈕與頂列 HUD（2026-03-30；**2026-03-31 開啟態視覺**）
- **底欄版面**：**背包**（`InventoryUI/OpenButton`，錨點約 **0.18**）— **寵物**（`PetUI/OpenButton`，**0.5**）— **日記**（`DiaryUI/OpenButton`，**0.82**）；帳簿風樣式與 `PetUI`／`InventoryUI` 一致。
- **翻滾與封印邊距（2026-04 現況）**：**`DashButton`** 錨點約 **水平 0.901**（`Main.tscn`），與左側 **`SealToggleButton` 約 0.101** 形成**肉眼對稱的離邊距**；數值以場景為準，聖經不強制還原舊版位置。
- **開啟中 pressed 態**：三鈕皆 **`toggle_mode`**；`_show_panel`／`_hide_panel` 與 **`set_pressed_no_signal`** 同步，使**開啟中**維持橘色 pressed、切換或關閉恢復。
- **頂列**：**存檔**（`SaveGameButton`，與封印鈕同級尺寸／錨點列 **0.101**、字級 13）＋**血條**（`PlayerHealthBar`，錨點右移避免與存檔鈕重疊）。**日記／存檔完整規格**見下方 **`## Phase 11：日記與單槽存檔（2026-03-30 已落地）`**。
- **互斥**：開啟背包／寵物／日記任一面板時經 **`SignalBus`** 關閉另兩方（`pet_ui_close_requested`／`inventory_ui_close_requested`／`diary_ui_close_requested`）。

---

## Phase 11：日記與單槽存檔（2026-03-30 已落地）

### 目標
- **心情筆記**：玩家自訂條目（日期＋標題摘要＋內文），清單**由下往上累加**（新筆在清單最下方）；`DiaryManager.update_mood_note(..., notify:=false)` 避免每次鍵入整表重建。
- **生涯成就**：系統解鎖、不重複；條目標題表 **`DiaryManager.CAREER_TITLES`**（資料驅動 id → 顯示字串）。
- **單槽存檔**：本機 **`user://monster_and_i_save_v1.json`**（內含 **`version`**），覆寫式；UI 仿 GB／GBA「記錄保存中，請勿關閉電源…」全螢幕提示。

### Autoload 與啟動順序
- **`SaveGameManager`**（在 **`PetManager`／`InventoryManager` 之前**註冊）：`_ready` 時若檔案存在則讀入待套用資料；**`has_pending_save()`** 為真時，`InventoryManager`／`PetManager` **略過**開局種子（測試道具／初始寵物等），改由讀檔覆寫。存檔路徑：**`user://monster_and_i_save_v1.json`**（實際檔案位於 Godot **使用者資料目錄**下專案資料夾，見 Editor 專案設定／OS 的 `user://` 對應路徑）。
- **`DiaryManager`**：執行期持有 `_mood_notes`、`_career_unlocked`；**`get_save_snapshot`／`apply_save_snapshot`** 供 `SaveGameManager` 序列化。
- **`Main.gd`**（掛於 `Main.tscn` 根）：`_ready` 內 **`await SaveGameManager.apply_pending_save_if_any()`**，確保整棵 `Main` 子樹 `_ready` 完成後再套用讀檔（含非同步換關）。

### 序列化範圍（單一 JSON）
- **`NpcStateManager`**：好感、`grant_once` 字典。
- **`InventoryManager`**：`stacks`（含 **`res_path`** 以利還原 **`HeadwearResource`** 等非 `DataManager` 道具）、`headwear_owners`；讀檔後 **`apply_saved_equipment_to_world()`** 同步主角／出戰寵物頭飾視覺（延遲數幀以配合 `PetCompanionSpawner`）。
- **`PetManager`**：寵物陣列（模板路徑＋個體欄位、`skills` 路徑）、`active_instance_id`、**`party_instance_ids`（三槽，`null` 表空槽）**；舊存檔 **`deployed_instance_id`** 會遷移到槽 0；`id_counter`。
- **`DiaryManager`**：心情筆記、生涯解鎖時間戳。
- **關卡與玩家**：目前 **`loaded_level` 之 `scene_file_path`**、玩家 **global_position**、**`HealthComponent` 血量**；必要時 **`await HomeManager.switch_to_lake_async`／`switch_to_homestead_async`**（與傳送門用的同步 `switch_to_*` 並存）。

### 對話與生涯解鎖（資料驅動）
- **`DialogueEffectEntry`** 新增 **`career_milestone_id`**（可與 **`GIVE_ITEM`**、`grant_once` 並用）；**`DialogueManager._run_enter_effects`** 在實際發放後呼叫 **`DiaryManager.try_unlock_career`**。
- **歷史範例**：測試期「湖畔鐵匠」對話圖曾示範 **`career_smith_first_stone`**、**`career_smith_training_axe`**（標題字串仍留在 **`DiaryManager.CAREER_TITLES`**，舊存檔日記相容）；該圖與 NPC 資源已移除，**新對話圖**仍可依同欄位掛生涯解鎖。

### UI 檔案
- **`DiaryUI.tscn`／`DiaryUI.gd`**：分頁 **心情筆記**／**生涯成就**，tab chrome 幾何與 **`InventoryUI`**（頭飾／道具列）對齊；**`SaveProgressOverlay.gd`**、**`SaveGameButton.gd`**。

### 怪物掉落（與寵物協攻的釐清）
- **寵物**與**主角**皆透過 **`HurtboxComponent.take_damage` → `HealthComponent` → `died` → `MonsterDieState._spawn_loot()`**；**沒有**「寵物最後一下不掉落」的特規。若感覺少掉寶，多為 **`MonsterResource.drop_chance`** 機率（例：綠史萊姆 **0.5**）或誤判最後一刀來源。

---

## Phase 12：指揮系統（Command System）— 全面盤查與乾淨重做（2026-04；**產品版面 2026-04-04 定案：右側兩鈕**；**主線 2026-04-05 已落地**）

> **編號**：**Phase 11** 已用於**日記／單槽存檔**；本節為**指揮系統**專用占位，**不**佔用 Phase 11。  
> **現況（2026-04-05）**：依 **§1／§1.1／§5** 之**右側兩鈕＋薄 Manager＋訊號契約**已**落地**（細節與遇錯見 **§6**）。本節仍保留 **§2 盤點避坑**與 **§4 歷史因果**，供日後擴充技能或除錯時對照。  
> **歷史**：曾有一輪「齒輪／手動寵物技」實作與多輪補丁**未達主打可靠度**，因而定調**乾淨重做**；下列「曾觸及檔案」（§4）僅供理解因果，**現行實作以 §6 與 repo 為準**。

### 1. 產品願景（與企劃對齊後的定案）

- **主打**：**單一入口**的**玩家指揮管線**（與自動協攻／自動大技並存），體感對齊 **MOBA 手遊**「右側技能柱」：**一顆寵物戰技**為 MVP，管線仍須**可擴充**、**狀態可測**，避免 UI 與各 Manager 各猜各的。
- **右側行動區**：**最多兩顆鈕**，**同級尺寸**（與翻滾鈕一致）、**垂直對齊**（**上**／**下**以場景為準；企劃定調為 **戰技在翻滾上方**）：
  1. **寵物戰技** — **僅當**編隊 **槽 1**（`PetManager.party_slots[0]`）**有寵且已出戰在場**時顯示；鈕上顯示 **`SkillResource.skill_name`**（或日後小圖示＋短字，不改管線）。現階段 **每隻寵物對應此鈕的僅一招**（見下方 **§1.1**「哪一筆技能」）；點擊後進入對應流程（地面技 → 瞄準／預覽／確認；瞬發技 → 直接請求結算）。
  2. **翻滾** — **永遠存在**（與既有 `DashButton` 一致）。
- **取消獨立「齒輪」鈕**：不再用展開／收合層；**有槽 1 出戰寵 → 戰技鈕出現；收回槽 1 或槽 1 為空 → 戰技鈕消失**。替換槽 1 寵物時，**標籤與冷卻顯示**應隨 **`pet_party_changed`／`pet_deployed_changed`** 與**單一真相**更新，無需第三顆開關鈕。
- **隱藏規則**：凡 **HUD locker** 需隱藏翻滾時（對話阻擋、封印儀式、採收模式等，與 **Phase 9／10** 一致），**已顯示的戰技鈕與翻滾同步**隱藏／恢復；建議**同一父節點或同一腳本**驅動，避免只藏其一。
- **指揮範圍（已定案）**：手動指令**僅**針對 **`party_slots[0]`（編隊槽 1）** 在場之 **`PetCompanion`**；槽 2／3 **全自動**，不佔右側戰技鈕。**顯示戰技鈕的條件**與**實際接受請求的寵物**必須**同一條件**，避免「槽 1 空、槽 2 有寵卻出現戰技鈕」等體感與除錯災難。若日後要改成「第一隻非空槽承接戰技」，須**另開契約段落**並改資料流，**不可**由 UI 側推斷。

### 1.1 核心契約（架構思想；2026-04-04 與企劃對齊）

- **純訊號 UI**：戰技鈕**只** `emit` **`SignalBus`** 請求（名稱／簽名實作時寫入 **`SignalBus.gd`**，例如沿用 **`pet_manual_skill_requested(...)`** 或更窄語意）；**禁止**在 UI 結算傷害／治療／播世界 FX。
- **單一真相來源**：由 **`PetManager`、薄 Autoload 或專用模組**（名稱可為 `PetCommand*` 等）在**部署／讀檔／入庫後**解析並廣播或可查快照，例如：**是否允許指揮輸入**、**被指揮之 `instance_id`**、**已解析的單一 `SkillResource`（或明確無）**。**禁止**在戰技鈕腳本內拼 eligibility、**`duplicate(true)` 子資源路徑修復**或快取鍵不含穩定實例辨識 — 對照 **§2.1 避坑**。
- **哪一筆技能（資料規則，擇一寫死並入 `.tres` 規範）**：例如 **`PetResource.skills` 第一筆**為手動戰技，或 **`SkillResource` 上明確欄位**標記「手動戰技」；**禁止** `if pet_id == "某某"`。
- **執行與互斥**：**槽 1 `PetCompanion`**（或集中轉發之執行端）訂閱請求並負責 **CD**、**動畫鎖**、與 **封印／採收／對話／畫圈** 的 **互斥**（與 `SealManager._unhandled_input` 不打架）。
- **自動 vs 手動 CD**：**建議共用**同一 **`SkillResource.cooldown` 語意**（手動與自動大技不各算一套），避免雙倍輸出與玩家困惑。
- **地面技輸入**：**瞄準模式**必為明確 **FSM**（觸控 **down／drag／up／cancel** 與取消路徑統一）；每次離開（成功／取消／locker 打斷）**必定**清狀態並可重入 — 對照 **§2.3**。
- **體驗對齊 MOBA**：右側單鍵進入「指向／確認」或瞬發，與 **激鬥峽谷／傳說對決** 同類**管線精簡版**；細部相機、指示器美術可後補，**契約與 FSM 先穩**。

### 2. 上一輪實作盤點 — 已觀測問題（避坑清單）

#### 2.1 架構與資料流（核心痛點）

- **現象**：**封印／取得新寵後**，齒輪常**整組不可用**；有時連**既有出戰寵（如史萊姆）**也無法點齒輪。
- **推因（摘要）**：**沒有單一真相** — `PetResource` **`duplicate(true)`** 後子資源 **`SkillResource.resource_path` 可能為空**、UI **快取鍵**未含穩定實例辨識、**編隊槽**與 **`PetManager.active_pet`**、場上 **`PetCompanion`** 綁定、**locker_blocked**／**visibility** 恢復時機等，靠多處**事後正規化**與 **if 補洞**串連，易在「抓寵／換寵／讀檔」任一路徑漏接。
- **重做原則**：在架構上新增可辨識的 **「指揮系統」區塊**（名稱可為 `PetCommand*`、`ManualCommand*` 等，實作時再定）：對外只暴露少數狀態，例如：**是否允許指揮輸入**、**當前被指揮的寵物實例 id**、**已解析的單一手動戰技資源**（或明確的「無」）。**UI 只訂閱**；**禁止**在右側戰技／指揮 UI 腳本內拼 eligibility 與路徑修復。

#### 2.2 地面技 — 預覽與實招演出

- **現象 A**：點選投石後，**地上立即出現**瞄準／預覽的降落警示，但**半徑／外觀**與**實際技能**的警示**不一致**。
- **現象 B**：玩家**點地確認**後，預覽**消失**，寵物**attack 動畫播完一段**後才出現**真正的**落地警示 → 中間**空窗**，體感像兩段不相干的技能。
- **重做原則**：**同一組數值與外觀來源**（半徑、`SkillResource`／模板 ID、或**同一個世界節點**的預覽／實戰兩模式）；時間軸上明確設計 **「瞄準 → 確認 → 寵物演出 → 結算」**，可選 **拉前寵物 telegraph** 或 **延長預覽橋接**，但**前提**是兩段警示**看起來是同一個圈**。

#### 2.3 輸入與狀態機

- **現象 A**：預覽態下**拖曳瞄準後放開** → **不施放**（僅點擊路徑偶發可用）。
- **現象 B**：**點擊**施放**第一次成功**後，**再點同一位置** → **第二次不會出石**。
- **推因（摘要）**：**滑鼠／觸控**的 **down / drag / up / cancel** 未統一走同一條「確認施放」；結束後**未保證回到 idle**，旗標或訂閱殘留。
- **重做原則**：為**瞄準模式**做明確 **FSM**；每次離開（成功／取消／被 locker 打斷）**必定**清理狀態並可重入。

#### 2.4 物理與動畫（與指揮分線；**飄移已修，其餘仍留線**）

以下**不**與指揮核心同捆；與 Phase 12 指揮契約**分開驗收**。

- **~~碰撞後 idle 飄移~~** → **已修（2026-04）**：無輸入／跟隨到站後 **`velocity` 殘留**與 **`move_and_slide` 滑移**導致 idle 仍緩漂。**作法摘要**：`PlayerController` 無輸入且速限以下每幀 slide 後 **清零**；`PetCompanion` **`_snap_stationary_velocity_after_slide()`**；`MonsterBase` 在 **`Idle`**（及 **`Chase` 播 idle 貼身等 CD**）於 **`move_and_slide()` 後**清零殘速。若回歸請對照上述三檔與 **§6** 索引。
- **封印或施放技能後的面向／run 錯亂**（**仍開放**）：**怪物**與**寵物**在**封印流程**或**技能施放結束**後，**方向**或 **run 動畫**與實際移動意圖**不一致**；需**全面巡檢**各狀態 `exit`／`transition` 是否還原 **face**、**動畫鎖**、**速度**與**狀態機優先權**。

### 3. 建議重做順序（實作優先級）

1. ✅ **指揮系統契約** + **單一真相來源**（薄 `PetCommandManager` + `SignalBus` 僅傳遞事件 — 見 **§6**）。
2. ✅ **地面技**：**共用 telegraph**（`GroundSlamAoE.preview_mode`）+ **瞄準輸入 FSM**（`PetCommandHud`）— 見 **§6**。
3. ✅ **右側兩鈕 UI**（`RightActionGroup`：戰技／翻滾；戰技隨槽 1 出戰顯隱）與 **locker 同步隱藏** — 見 **§6**。
4. ✅ **碰撞 idle 飄移** — **已修**（**§2.4**、見 **§6** 程式索引）。⏳ **封印／技能後面向／run** — **仍獨立排期**（**§2.4**）。

### 4. 與本文件其他章節的關係

- **`## Phase 4` →「手動寵物技能（歷史草稿：齒輪 UI）」**：保留為**早期規格草稿**（曾含齒輪展開、拖曳紅圈等）。**版面與互動的最終想像**以**本節 §1／§1.1** 為準（**右側最多兩鈕：戰技＋翻滾；無獨立齒輪**）。
- **曾觸及、備分前可能存在的實作線索**（僅供因果理解）：`PetManualSkillGear.gd`、`Main.tscn` 內 **`PetManualSkillHud`**、`SignalBus` 的 **`pet_manual_skill_requested`** 等、`PetCompanion` 手動技分支、`PetManager` 技能路徑正規化／補齊、`SkillResource` 的 **`allow_manual_command`**／**`is_eligible_for_manual_pet_gear()`**、各 **`HudLocker`** 對手動指揮層的隱藏。重做時**勿假設**上述仍存在或路徑不變。

### 5. 實作合併備註（2026-04-04；**以外部工程師 A 方案為主**，B 可選補強）

下列為**落地時優先採納的技術選型**，與 **§1.1 核心契約**、**§2 避坑**對齊；與 **§3** 順序不衝突（契約／地面技 FSM／兩鈕殼／locker 仍依 §3）。

1. **薄 Autoload（名稱可為 `PetCommandManager` 等）**  
   - 持有 **指揮 FSM 狀態**（例如 **IDLE／AIMING／EXECUTING**）。  
   - **被指揮寵物**：以 **`instance_id` 向場上查找**對應 **`PetCompanion`**，**避免長快取 Node 參考**以致換寵／離樹失效。  
   - **當前解析好之 `SkillResource`**：在 **`pet_party_changed`**（及必要時讀檔／入庫後同一時機）**一次解析並快取**；**禁止** UI 在每次按下時自行爬 `party_slots[0].skills`（對照 **§2.1** `duplicate(true)` 子資源 `resource_path` 為空問題）。

2. **預覽圈與實招同一套**  
   - 複用既有 **`GroundSlamAoE`**（或同等落地圈節點），新增 **`preview_mode: bool`**：**`true`** 僅顯示警示／跟隨瞄準、**不結算傷害**；確認施放後改 **`false`** 並走既有 **`EffectManager.play_ground_slam_aoe_from_skill`** 等結算路徑。  
   - 視覺上可再做「變色／加深」銜接（外部討論 B 想法），**前提**仍是**同一節點、同一組半徑與資料來源**（**§2.2**）。

3. **瞄準輸入 FSM 放置處**  
   - 放在 **`PetCommandHud.gd`**（或等價右側指揮 UI 腳本），優先使用 **`_input`**。  
   - **僅當** Manager 處於 **AIMING**（或等價「瞄準中」）時才處理拖曳／確認／取消；**非瞄準時不搶輸入**，以降低與 **`SealManager._unhandled_input`**（畫圈）之衝突，**不必**依賴厚重互斥表。

4. **寵物執行端**  
   - **`PetCompanion`** 新增公開方法（例：**`execute_manual_skill(world_pos: Vector2) -> void`**），內部走既有 **`_resolve_combat_aoe_skill`** 等路徑，**目標世界座標**改為參數傳入（取代「自動選最近敵」之語意若適用）。  
   - **CD** 沿用既有 **`skill_cds`**（或專案內既對應字典），**不另開平行計時器**（對照 **§1.1** 建議與自動技共用 CD 語意）。

5. **Locker 整合**  
   - **`Main.tscn`**（或 `UILayer`）將 **翻滾鈕與戰技鈕**包在同一父節點（例：**`RightActionGroup`**）；**`SealHudLocker`／`HarvestHudLocker`／`DialogueHudLocker`** 等僅對該父節點 **`hide`／`show`**（或等價 **group**），**勿**各 locker 各列戰技鈕路徑，以免漏藏。

6. **虛擬搖桿與瞄準同時觸控**  
   - 進入 **AIMING** 時對 **`VirtualJoystick`**：**`_reset()` + `set_process_input(false)`**；離開 AIMING 使用既有 **`restore_after_blocking_overlay()`**（與對話阻擋同款），避免拖瞄準時搖桿仍 **`set_input_as_handled()`** 吃掉事件或帶動主角位移。

**可選補強（外部工程師 B；不取代上列主軸）**  
- 戰技鈕可加入既有 **`joystick_touch_exclusion`**（或專案同等）群組，**減少**左右手誤觸連動。  
- 若不用「`skills` 陣列第一筆」規則，可於 **`SkillResource`** 增 **布林欄**（例 **`is_manual_cast`**）標記手動戰技，與 **§1.1「擇一寫死」**併列為資料定案時二選一。  
- **不必**為瞄準每秒廣播多則 `SignalBus` 訊號；**優先** HUD ↔ Manager ↔ 槽 1 寵物之**窄路徑**；若仍走電台，**遵守**「**`SignalBus.gd` 無業務邏輯**」鐵則。

### 6. 落地紀錄與遇錯摘要（2026-04-05）

> **狀態**：本節為**主線已驗收**之索引；細部檔名以 repo 為準。與 **§2**「曾觀測問題」對讀可看出**哪些坑已在重做時避開**；**§2.4** 之 **idle 飄移**已另案修復，**封印／技能後動畫**仍留線。

- **已落地（對齊 §1／§1.1／§5）**  
  - **`PetCommandManager`**（Autoload）：指揮 **FSM**（IDLE／AIMING／EXECUTING）、槽 1 出戰寵 **`instance_id` 查場**、手動戰技 **`SkillResource` 單次解析**（隨 `pet_party_changed` 等刷新）。  
  - **`PetCommandHud`** + **`Main.tscn` → `RightActionGroup`**：戰技鈕與翻滾同組；**`SealHudLocker`／`HarvestHudLocker`／`DialogueHudLocker`** 對父節點統一隱藏。  
  - **`GroundSlamAoE`**：`preview_mode` 預覽圈與實招**同一節點／同一套半徑**；確認後走既有結算路徑。  
  - **`PetCompanion.execute_manual_skill(world_pos)`**（及對應 **CD／互斥**）：地面技座標由指揮管線傳入，**不**由 UI 結算。  
  - **`SignalBus`**：新增／沿用窄參數請求與狀態廣播（實作以 `SignalBus.gd` 為準）；**電台無業務公式**。  
  - **主角指揮姿態**：施放／瞄準相關時機與 **`PlayerController`／移動狀態機**銜接（例如 **seal／指揮手勢**與輸入鎖協調 — 以 repo 為準）。  
  - **戰技鈕視覺**：與編隊槽 **默契深色底＋咖啡色框**對齊（見 **Phase 8 → 口語用色「默契深色」**）；冷卻遮罩為 **shader 圓角矩形**等（細節見場景 `StyleBoxFlat_pet_skill_bg_*` 與 CD material）。

- **落地過程中曾出現／已克服的錯誤（摘要）**  
  - **齒輪輪資料與快取**：`duplicate(true)` 後子資源 **`resource_path` 空**、UI 快取鍵不含 **`instance_id`** — 對照 **§2.1**；重做改為 **Manager 單次解析 + 訂閱編隊變更**。  
  - **瞄準輸入**：滑鼠／觸控 **down／drag／up** 未統一、離開瞄準未清旗標 — 對照 **§2.3**；以 **FSM + 離開必 cleanup** 收斂。  
  - **預覽圈 vs 實招**：半徑或時間軸不一致、中間空窗 — 對照 **§2.2**；以 **`preview_mode` 同一 `GroundSlamAoE`** 收斂。  
  - **locker 漏藏戰技**：各 locker 分別列節點易漏 — 對照 **§5.5**；改 **`RightActionGroup` 單父節點**。  
  - **搖桿與瞄準搶輸入**：AIMING 時未停搖桿 — 對照 **§5.6**；**`_reset` + `set_process_input(false)`**，離開呼叫 **`restore_after_blocking_overlay()`**。  
  - **色票用語混淆**：戰技鈕曾用近黑或 **帳簿懸浮底 `#969183`**，與「寵物槽配色／默契深色」語意不符 — 已改對齊 **Phase 8「默契深色」**定義（**非**程式行為變更，純視覺契約釐清見該章）。

- **刻意未併入本 Phase 主線／後續另案**  
  - **碰撞後 idle 飄移**：已於 **2026-04** 由 **`PlayerController`／`PetCompanion`／`MonsterBase`** 修復（見 **§2.4**）。  
  - **封印或技能後面向／run 錯亂** — 仍屬 **§2.4** 開放項；獨立排期，避免與指揮 FSM 同捆擴張半徑。

---

## Phase 6：技能特效模板化（**管線已落地**；視覺逐技能擴充中）

### 目前狀態
- **模板管線與接線已完成**，遊戲內可正常引用模板 ID；所謂「約 **75%**」指的是 **逐技能美術細修與演出對齊**，**不阻塞**新怪／新技能接 `SkillResource`。
- 剩餘工作多為「逐技能細修視覺」與「觸發時機對齊（可躲判讀）」

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

## Phase 7：頭飾系統（進行中，已可預覽）

### 設計目標
- 支援玩家、怪物、出戰寵物共用頭飾系統
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
  - 提供 `resolve_head_anchor_offset(animation_name, frame_index, fallback_offset)`（內部委派 `HeadAnchorResolver.resolve_head_anchor_monster_exports`，與 Inspector `@tool` 預覽相容）
  - `MonsterBase.gd` 每幀以目前身體 `AnimatedSprite2D` 的 `animation/frame` 讀取錨點時，**直接呼叫上述靜態解析＋只讀 `data` 欄位**（避免編輯器 placeholder 上呼叫實例方法），並更新 `AccessoryPoint`（供頭飾節點讀取）
- **主角（單一角色，腳本 + 節點）**
  - 因目前無 `PlayerResource`，先在 `PlayerController.gd` 落地同名三欄位與同優先序解析函式
  - `Player.tscn`：`AccessoryPoint`（`Marker2D`，僅供錨點座標）；**`AccessorySprite` 為 `Player` 直接子節點**，場景樹排在 **`AnimatedSprite2D` 之後**，`_update_accessory_anchor` 內 **`accessory_sprite.position = accessory_point.position`** 對齊頭部
- **相容策略**
  - 怪物既有 `accessory_offset` 暫保留，作過渡相容；新資料以 `head_anchor_offset` 三層覆寫規範為準

### 實作順序（更新）
1. ✅ 新增資源欄位與讀取規範（先不動 UI）
2. 先全角色填 `head_anchor_offset`，達到可用基準
3. ✅ 列出穿幫動畫清單，只補動畫級覆寫（同系列動畫可共用 key，例如 `attack_side`）
4. 針對極少數動作加幀級覆寫
5. ✅ 接背包「裝備頭飾」最小流程與顯示切換（手機單擊）

### 目前已落地（截至本次）
- `HeadwearResource` 已建立（`headwear_id`、`display_name`、`description`、`icon`、`sprite_frames`）
- 玩家 / 怪物 / 出戰寵物都有 **`AccessoryPoint`**（錨點）**＋`AccessorySprite`**（頭飾圖）與 **`equipped_headwear`**；腳本以 **`get_node_or_null("AccessorySprite")`** 取頭飾（**非** `AccessoryPoint/AccessorySprite`）。
- 頭飾動畫最小規範採 `idle_down` / `idle_side` / `idle_up`；其餘動作以方向映射到這三個動畫
- **頭飾與身體、前景樹的 z／排序（2026-03-29 後定版）**  
  - **`Player` 根節點不要開 `y_sort_enabled`**：若開啟，子節點會依各自 Y 排序，**頭（Y 較小）會被身體（Y 較大）蓋住**。  
  - 頭飾 **勿**用 **`z_index` 相對 +1** 抬到有效 **6**：會壓過 **`LevelContainer` 同層 z=5 的前景樹**，變成「頭飾永遠在樹上」。  
  - **作法**：頭飾與身體維持**同層 z（相對 0，有效 5）**，靠**場景樹順序**（`AccessorySprite` 排在 `AnimatedSprite2D` 之後）＋錨點同步，讓頭飾畫在身體上；**前景樹 `FgTree_*` 亦須 z=5**，才能與主角一起做 **`LevelContainer.y_sort`**（可走進樹前／後）。  
  - 寵物／怪：`PetCompanion.tscn`、`MonsterBase.tscn` 同樣 **`AccessorySprite` 為根下獨立節點**（非掛在 `AccessoryPoint` 下），並在各自 `_update_accessory_anchor` 同步 `accessory_sprite.position = accessory_point.position`。
- 背包頭飾頁已可單擊裝備；若有出戰寵物，會先選「裝給主角 / 裝給出戰寵物」
- `slime_hat.tres` 已作為開發期預設頭飾注入背包（替代 NPC/寶箱尚未完成流程）
- `resources身分證` 已移至 `res://resources身分證/`；程式路徑已對齊新位置

### 曾出現問題（已於 Phase 7.5 解決／對照）
以下為開發中期曾記錄的痛點；**現況已對應**，與上一節「Phase 7.5 收尾」一致。

1. ✅ **toggle 卸下**：已裝備目標再次點同一頂頭飾可「脫下」（`InventoryUI` + `InventoryManager.unequip_headwear_by_id`）。
2. ✅ **Popup 取消不卡死**：頭飾目標選單點空白取消後，下次再點頭飾可正常反應（`popup_hide`／committed 旗標與 `_pending_headwear` 清理）。
3. ✅ **唯一所有權**：同一 `headwear_id` 不可同時掛在主角與出戰寵物；換人戴會自舊主清除（`InventoryManager._headwear_owner_by_id` + `equip_headwear_to_owner`）。
4. ✅ **出戰個體綁定（多槽已落地）**：裝備目標鍵為 `player:main` 或 `pet:<instance_id>`（`PetCompanion.get_headwear_binding_key()`），以 **`instance_id`** 區分同 `pet_id` 多隻；`InventoryUI` 以槽位＋暱稱顯示選單（見 Phase 4「頭飾與多隻出戰」）。

### Phase 7.5 本次收尾紀錄（已更新）
- ✅ 裝備流程穩定化已落地：toggle 脫下、Popup 取消不卡死、同一頂唯一所有權（主角/出戰寵物互斥）、寵物綁定 key 改為 `pet:<instance_id>`。
- ✅ 主角/寵物預設錨點基準已歸零，並可在編輯器即時預覽調整。
- ✅ 主角錨點欄位改為 Inspector 友善流程：`anim_offsets` / `frame_offsets`（免鉛筆新增列）。
- ✅ 已完成 runtime 命中追蹤（`animation/frame/entry/source`）並確認 `hit` 幀級覆寫可命中生效。
- ✅ 修正主角 `frame_offsets` 資料穩定性：改用強型別 `FrameAnchorEntry`，避免場景 `SubResource` 欄位被洗掉導致永遠 fallback。
- ✅ 幀級命中規則已收斂為「嚴格同幀」，不再使用 `+1` 寬鬆命中。
- 📝 文檔運營備註：本專案開發總誌檔名以 `Monster_DevLog_v4.xlsx` 為準（原中文檔名別名不再使用）。

### 驗收標準
- 靜止、移動、常用攻擊三類動畫頭飾都穩定
- 不因換怪物/換皮膚造成明顯漂移
- 手機效能不因頭飾系統出現額外明顯負擔
- 三層規則實測通過：`head_anchor_offset` / `animation_anchor_overrides` / `frame_anchor_overrides`
- 背包裝備流程可逆（裝上/卸下/改裝）且取消互動不鎖 UI

---

## Phase 9：NPC 對話／互動（MVP 地基已落地）

> **狀態**：資料流與 Manager／`SignalBus` 邊界已依「純訊號 UI」落地；主場景預設關卡為**城鎮**（**`FallenLeafTown`**）。**對話框帳簿風視覺、左右欄對齊**已落地（見 **`DialogueLedgerButtonStyle`、`DialoguePanel`** 與下方「實作補記」）。  
> **備註**：`Monster_DevLog_v4.xlsx` 之 **`02`／`03`／`07`／`100`** 已與架構文件一併備援（含湖畔地圖定版等批次）；往後 **`ARCHITECTURE.md` 有實質更新**時請執行對應備援腳本（例如 **`_sync_devlog_architecture.py`**、**`_sync_devlog_phase10_architecture.py`**、**`_sync_devlog_diary_save_2026_03_30.py`**、**`_sync_devlog_pet_party_architecture_2026_03_30.py`**、**`_sync_devlog_architecture_todo_closed_2026_03_30.py`**）或依團隊慣例手動補總誌（見文末「與總誌同步」）。

### 備註：湖畔鐵匠（測試期格式範例，已自場景移除）

- **定位**：驗證 **`NpcResource`／對話圖／`NpcFieldAgent`／`DialogueEffectEntry`**（含道具、好感、**`career_milestone_id`**）的**接線範本**，非正式劇情角色。
- **現況**：**`LakesideSmithNpc.tscn`** 與對應 **`npc`／`dialogue` 資源**已刪；**`DialogueManager`** 的 **`_NPC_PATH_BY_ID`**、**`_GRAPH_PATH_BY_KEY`** 目前為空表，**新增 NPC 時**各補一筆路徑即可沿用同一套管線，相當於**加速後續 NPC 的橋樑**。
- **之後**：湖畔若要做教學／功能性 NPC（例如進洞窟前的頭飾照明），**重新建**場景與資源即可，無需沿用舊鐵匠 id。

### 目標與範圍（已滿足之 MVP）
- 場上 NPC：**idle** 動畫 + **`NpcFieldAgent`** 靠近提示 + **`DialoguePanel`**（舊有史萊姆鐵匠僅為上述測試範例，已移除）。
- **靠近** → `NpcInteractionManager` 廣播提示；**點提示** → 下方 **`DialoguePanel`** + 右側選項；圖檔以**自訂結束文案**（`target_node_id = __CLOSE__`）關閉為主；若節點無任何可見選項，**`DialogueManager`** 才補 **「待會再來」** 後備選項。
- **分支末端**：已接 **`inventory_grant_requested`** → `InventoryManager.grant_item_stack_by_id`（與 **`item_collected` 採集分流**）。
- **UI 不直連 Player**；移動鎖定由 **`dialogue_blocking_changed`** → `PlayerController.dialogue_movement_locked`。

### 資料模型（Resource）
- **對話圖**：`DialogueGraphResource`、`DialogueNodeResource`、`DialogueLineBlock`（`Speaker`: NPC／主角內心）、`DialogueChoiceEntry`（`target_node_id` 可為 `DialogueGraphResource.CLOSE_SENTINEL`；可選 **`min_affinity`**、`require_grant_once_pending`／`require_grant_once_done`；**選取時回饋**：`on_select_play_player_happy`、`on_select_world_hint_instant_text` → **`DialogueManager`** 觸發 **`play_dialogue_reward_happy(with_camera_punch)`**（僅當有 instant 文案時 **punch**；採集／採收 **不** 走此路）＋ **`player_world_hint_changed`**＋條件符合時 **`dialogue_reward_vfx_requested`**）、`DialogueEffectEntry`（`GIVE_ITEM` + `item_id`／`amount`；可選 **`grant_once_id`** 防重複發放；**`ADD_AFFINITY`** + `affinity_delta`）。
- **NPC 身分**：`NpcResource`（`npc_id`、`display_name`、`prompt_line`、可選 **`prompt_affinity_threshold`／`prompt_line_high_affinity`**、`dialogue_graph_key`）；於 **`DialogueManager._NPC_PATH_BY_ID`** 註冊 id → `.tres`，對話圖鍵於 **`_GRAPH_PATH_BY_KEY`** 註冊（見上節「湖畔鐵匠」備註）。
- **對話圖檔**：`DialogueManager` 依 **`_GRAPH_PATH_BY_KEY`** 載入純 **`resources身分證/dialogue/*.tres`** 註冊；不必改 `SignalBus`。

### Autoload 與執行流程
- **`NpcInteractionManager`**：單一「當前可互動」槽（**多 NPC 並存時預留**改為距離／優先權）；對話開啟時抑制提示；監聽 `dialogue_blocking_changed`。**關閉對話後**若玩家**仍在** `InteractionArea` 內，**不**立刻恢復靠近提示；須 **`body_exited` → `clear_proximity_if_match`** 後再進入，才再度 **`set_active_proximity`**（避免關窗瞬間又跳「下一段對話」）。
- **`NpcStateManager`**：每名 NPC **好感**（`affinity`）與 **`grant_once_id` 完成紀錄**（執行期字典；存檔可日後接同一資料）；**不含**在 `SignalBus` 內寫業務。`NpcFieldAgent` 以 **`resolve_prompt_line(NpcResource)`** 決定靠近提示；好感變更時若玩家仍在範圍內會重推提示。
- **`DialogueManager`**：監聽 `npc_dialogue_requested`、`dialogue_choice_selected`、`dialogue_close_requested`；解析 NPC／圖、依條件**過濾選項**、執行 `on_enter_effects`、廣播 `dialogue_presented`／`dialogue_blocking_changed`；開話前發 **`pet_ui_close_requested`**、**`inventory_ui_close_requested`**（與 Phase 5 互斥一致）。
- **場上**：`NpcFieldAgent`（`Area2D` `collision_mask` 對主角預設層）掛於 NPC 場景；`PromptAnchor` 世界座標供提示換算；對話結束後提示是否出現由 **`NpcInteractionManager`** 上列「須先離開再靠近」規則決定（`NpcFieldAgent` 仍可在解封時 **`set_active_proximity`** 以刷新快取文案）。

### UI 與版面要點
- **`NpcInteractionPrompt`**：`DialogueLedgerButtonStyle` 與 **`DialoguePanel` 右欄選項鈕**同一套長條樣式（**橘米底＋咖啡字**；**pressed**＝深色底＋白字，見下「實作補記」）；**根節點 `mouse_filter = IGNORE`**，僅 **`PromptButton`** 接觸控，避免隱形層擋底欄／寵物頁。
- **`DialoguePanel`**：關閉時 **`z_index` 低於 `PetUI`／`InventoryUI`（20）**（預設隱藏 `z_index = 8`），開啟時抬高，避免關閉後仍攔截輸入；底緣 **`GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX`**；`viewport.size_changed` 時重算主文最小寬。
- **`DialogueHudLocker`**：對話中隱藏瞬移／封印鈕；**虛擬搖桿**須 **`_reset()` + `set_process_input(false)` + `hide()`**（見下「曾出現問題」），結束對話後 **`set_process_input(true)`** 並 **`show()`**（延續「對話完搖桿回來」體感）。
- **`SealUI`**：根節點 **`mouse_filter = IGNORE`**，畫圈依賴 `SealManager._unhandled_input`，避免 `PanelContainer` 預設 STOP 擋線。

### 關卡與主場景
- **`scenes場景/levels/lake_side/LakeSideLevel.tscn`**：`LevelContainer` 子實例；**大地圖美術、地形碰撞、家園區、撒点生成**等**完整編排規格**見下方 **`## 湖畔關卡（LakeSideLevel）地圖與場景編排（實作定版）`**。關內 **`ForegroundDecor`**（前景樹 + **`ForegroundCanopyHoist.gd`**）執行期改掛 **`level_container`**，與主角同層比 Y。
- **`scenes場景/levels/town/FallenLeafTown.tscn`**：預設開局城鎮；田園 **`HomesteadBundle`**、傳送點、**`ForegroundDecor`**（可照湖畔方式加樹蔭／柵欄）；**`Art/Ambience`**＋**`LeafZones`／`Marker2D`**＋**`TownLeafAmbientVfx.gd`**（楓葉色緩落 **`CPUParticles2D`**，結構比照湖畔螢火蟲區）。
- **`Main.tscn`**：`LevelContainer`：**`FallenLeafTown`**（或讀檔換關後之關卡）、**`Player`**、**`PetCompanionSpawner`**…（**與主角同層**排序者須為 `LevelContainer` 直接子節點，或由 **`MarkersPropSpawner`／`ForegroundCanopyHoist`** 達成等價）。**石頭／史萊姆**由關卡內 **`MarkersPropSpawner`** 生成。**勿**在 `Main` 對 **`Player` 實例覆寫 `y_sort_enabled = true`**（會與頭飾排序衝突，見 Phase 7）。

### 曾出現問題（對照，避免回歸）
1. **對話後寵物頁／背包卡死、無法關閉、出戰鈕失效**  
   - **原因**：全螢幕 **`DialoguePanel`** 關閉後 **`z_index` 仍高於** `PetUI`／`InventoryUI`，或提示根節點 **`mouse_filter = STOP`** 擋住底欄。  
   - **作法**：關閉對話 **`z_index` 降到 8**、開啟時 28；**提示根 IGNORE、僅鈕 STOP**。
2. **對話前後封印畫圈「線有連到」卻無法落大劍**  
   - **原因**：`DialogueHudLocker` 僅 **`visible = false`** 虛擬搖桿，**未** `set_process_input(false)`；搖桿 **`_input` 仍 `set_input_as_handled()`**，吃掉 **`ScreenTouch` 放開**（`SealManager.finish_drawing` 依賴放開）。  
   - **作法**：對話阻擋時與封印流程一致：**`_reset()`、`set_process_input(false)`、`hide()`**；結束後恢復 **`set_process_input(true)`**。另 **`SealUI` 根 IGNORE**，避免 GUI 層擋 `SealManager` 的 unhandled 畫線。
3. **湖畔關卡無怪物**  
   - **現況（2026-03-29）**：`LakeSideLevel` 已內建 **`ScatteredSlimes`**（10 隻綠史萊姆，`MarkersPropSpawner` + `slime_green.tres`）與 **`ScatteredRocks`**（5 顆石）；封印驗收應有場上目標。若仍 **`fail_and_reset`**，請查圈內是否無 `monsters` 群組、或目標已死亡／離場。
4. **直向 360×640、主角 `Camera2D` zoom ≠ 1**  
   - **作法**：提示錨點以 **`get_canvas_transform() * world`** 換算後 **夾在可視區**並避開底欄高度。

### ~~下一小輪（Phase 9 視覺）~~ → **已併入實作**（2026-03）
- 主文 **`ledger_body_panel_stylebox`、選項長條 `DialogueLedgerButtonStyle`、底欄留白**— 見 **`### 實作補記（2026-03-29）`**「對話／靠近提示長條樣式」與 Phase 8 口語色票。

### 實作補記（2026-03-31，Phase 9／寵物／底欄／近戰）

- **對話獎勵（資料驅動）**：`DialogueChoiceEntry` 的 **`on_select_world_hint_instant_text`** → `HarvestModeHint` 單行白字；**`on_select_play_player_happy`** → **`PlayerController.play_dialogue_reward_happy(item_ack)`**（`item_ack`＝有 instant 文案時 **true** → **`_camera_impact_zoom`**，與封印成功同款節奏；**false** 僅 happy，採集／採收仍只走 **`item_collected`**）。**`item_ack`** 時另發 **`dialogue_reward_vfx_requested`** → **`EffectManager`**：`CollectEffect.start_flying_dialogue_reward_arc`（先彈起再 **二次貝塞爾** 落向螢幕下方，資源同 **`seal_orb`**）。
- **對話圖編排（歷史範例）**：測試期鐵匠圖曾示範首屏不重複「待會再來」、結束向 **`__CLOSE__`**、選項 **`on_select_*` 回饋**；新圖仍可依 **`DialogueGraphResource`** 同款欄位實作。
- **`NpcInteractionManager`**：**`_require_proximity_exit_before_prompt`**（見上「Autoload 與執行流程」）。
- **底欄三鈕**：`InventoryUI`／`PetUI`／`DiaryUI` — **`toggled`** 驅動開關＋**`set_pressed_no_signal`** 同步 pressed 視覺。
- **`PlayerAttackState`**：結算幀前 **`await`** 後若 Hurtbox 已釋放，**不可**把無效參考傳入 **`hit_current_target(HurtboxComponent)`**；先 **`is_instance_valid`** 再傳或傳 **`null`**。
- **`PetManager.party_heal_pending_*` + `PetCompanion`**：詠唱中預約補量；**`_pick_party_heal_target`** 依預估可補空間分流；**`_cast_heal_spell`** 以 **`instance_id`** 釋放預約。
- **`PetCompanion._update_visual`**：戰鬥／遠距跟隨時 **`_last_dir`／`flip_h`** 依移動或戰鬥錨點，貼身閒置才對齊主角面向。
- **UI 技術債已修**：`PetPartySlotHud` 拆出血條後 **`owner = null`**；`HealthBarGradientUtil` 圓角 **`int(round)`**；`GlobalBalance.combat_skill_display_level_from_pet_level` 浮點除避免整除警告。

---

## 湖畔關卡（LakeSideLevel）地圖與場景編排（實作定版 2026-03-29；**世界分線補記 2026-04**）

> **段落目標**：把「**湖畔**／**戰鬥場**」的**場景樹、碰撞、層級、撒点、怪物奧義、換關儀式感**寫成單一真相；並與 **`## 湖畔關卡 → §8`** 之**四圖拓撲**、**城鎮田園**、**`ShopManager`**、**死亡復活家園醒來**、**Boss 後感謝名單／騎虎歸途（§8.6）**對讀。**家園種田／駐寵**以**城鎮圖右上田園**為主（§8.2），湖畔內嵌試作田**淘汰**。

### 1. 場景樹摘要（`LakeSideLevel.tscn`）

| 節點（路徑概念） | 職責 |
|------------------|------|
| **`Art/MapBase/Background`** | `Sprite2D` 大地圖底圖（例：`res://…/環境/湖邊素材/Mountain_Path_01.png`）；**勿**與碰撞兄弟不同 scale 卻假設碰撞會自動跟縮——碰撞描在 **`TerrainCollision` 座標系**（與底圖同層 `MapBase`、scale 一致）最直覺。 |
| **`Art/MapBase/TerrainCollision`** | `StaticBody2D`，`collision_layer = 1`（主角 `CharacterBody2D` 預設撞世界層）。其下 **`North`／`Center`／`South`** 三個 **`CollisionPolygon2D`**（可再增子節點）分段描崖／水際；**已移除**舊試做 **`Walls/*` 矩形牆**。 |
| **`Art/WaterFX/*`** | `Waterfall`、`LakeWater` 等 **`AnimatedSprite2D`**（自行建 `SpriteFrames` 循環）。 |
| **`Art/Flowers/*`** | 貼地小花等；需與主角比前後的樹冠請放關卡內 **`ForegroundDecor`**（**`LakeSideLevel`**／**`FallenLeafTown`** 等），由 **`ForegroundCanopyHoist`** 掛到 **`level_container`**。 |
| **`Art/Ambience/*`** | `FireflyZones` 各 **`Marker2D`**、`Torch_Cave` 等氛圍錨點（粒子／火把由美術在子層補）。 |
| **`TerrainMap`** | 程式化 Tile 占位；**`LakeSideLevelRoot`**：若 **`Background.texture` 有指定** 則 **`TerrainMap.visible = false`** 並跳過鋪磚。 |
| **`HomesteadBundle`（`HomesteadZone`／`Crops` 等）** | **（過渡）** 湖畔內仍留試作田園包；**主線田園**以**城鎮** **`FallenLeafTown`** 為準（見 **§8**）。湖畔包日後可移除或僅留戰鬥／氛圍。 |
| **`ScatteredRocks`／`ScatteredSlimes`** | 皆掛 **`MarkersPropSpawner.gd`**；子節點僅 **`Marker2D`**；`prop_scene` 分別為 **`Rock.tscn`**、**`MonsterBase.tscn`**；史萊姆另設 **`prop_data = slime_green.tres`**（**`add_child` 前**寫入 `MonsterBase.data`）。 |
| **`BabyBirdPerches`／`LakeBabyBird`／`LakeBabyBird2`** | 環境寶寶鳥：**`BabyBirdPerches`** 下 **`Marker2D`** 群組 **`lake_baby_bird_perch`**（離屏再生挑點）；關卡根下 **兩** 個 **`BabyBirdMonster.tscn` 實例**，各 **`lake_ambient_save_slot`** 0／1。詳 **§4c**。 |
| **`ForegroundDecor`** | 前景樹 **`FgTree_*`**（**`z_index = 5`**、`y_sort_enabled`）+ **`ForegroundCanopyHoist.gd`**：執行期子節點改掛 **`level_container`**，與 **Player** 同層比 Y；**樹幹碰撞**例見 **`FgTree_06/TreeTrunk`**。 |

### 2. `MarkersPropSpawner`（石頭／怪／日後作物占位）

- **`_ready` 僅 `call_deferred("_spawn_props")`**：在關卡實例化過程中，父節點仍在建樹時**不可**對 `LevelContainer` 同步 `add_child`（除錯器：`Parent node is busy setting up children`）。
- **`attach_to_level_container`（預設 true）**：實例掛到 **`groups` → `level_container`** 的節點（`Main` 的 `LevelContainer`），與 **Player／NPC 同層 `y_sort`**。
- **`prop_data`（可選）**：若實例為 **`MonsterBase`** 且資源為 **`MonsterResource`**，則指派 **`data`**。

### 3. 前景與 `y_sort`（關卡內 `ForegroundDecor`）

- **`ForegroundDecor`**：`z_index = 5`、`y_sort_enabled`，腳本 **`ForegroundCanopyHoist.gd`**：執行期把子節點**改掛到 `level_container` 群組**（即 **`Main` 的 `LevelContainer`**）並保留 **`global_position`**，再 `queue_free()` 自身——避免「整袋前景與主角只比一個 Y」的排序錯覺。  
  - **`_ready` 僅 `call_deferred("_hoist_children")`**：避免在父節點仍 busy 時對 `LevelContainer` `add_child`（除錯器：`Parent node is busy setting up children`）。
  - **編輯時**樹冠收在 **`LakeSideLevel`／`FallenLeafTown`** 內方便管理；**不必**再於 **`Main.tscn`** 重複一袋前景（舊版已遷入湖畔關卡）。
- **`FgTree_*`（前景樹）**：**必須**與主角／怪／石同等 **`z_index = 5`（`LEVEL_SORTED_ENTITY_Z_INDEX`）**；**不可**另拉高 z（例如 7），否則樹會**永遠**畫在角色上，**失去**與主角的 **`y_sort` 前後遮擋**（無法走到樹「前面」）。
- **路中樹幹碰撞（可選）**：若需擋路，在該樹 `Sprite2D` 下加 **`StaticBody2D` + `CollisionShape2D`／`CollisionPolygon2D`**，`collision_layer = 1`（與 `TerrainCollision` 一致）；與頭飾／繪製順序無關。
- **鐵則不變**：須與主角比前後的實體（怪、石、寵物、NPC）仍為 **`LevelContainer` 直接子節點**（或由上述 hoist／spawner 達成等價結果）。

### 4. 史萊姆奧義「鬼影衝刺／瞬移」（`MonsterBase.perform_ghost_dash`）

- **禁止**隱身結束後 **`global_position += 方向 * 距離`** 硬穿 **`StaticBody2D`**。
- **作法**：在**背離主角**的扇形內掃多個方向，每方向以 **`move_and_collide` 分段推進** 模擬終點；選 **與主角距離平方最大** 的合法終點。參數：`dir_count`、`arc_rad`、`step_px`（見腳本內常數）。

### 4b. 主角擊退／護盾彈開與穿牆（`PlayerController` + `MonsterBase`）

- **勿**對主角 **`Tween` `global_position`** 做擊退（例：史萊姆施法護盾 `play_hit_animation` 彈開玩家）——易卡進 **`StaticBody2D`** 且 **`is_hit_stun` 時若提前 `return` 不呼叫 `move_and_slide()`** 會動彈不得。  
- **作法**：`PlayerController.request_knockback_push(dir, dist)` 佇列位移；**下一幀 `_physics_process`** 開頭 **`_consume_pending_knockback_push()`** 以 **`move_and_collide` 分段**消耗；**`is_hit_stun`／`is_dashing`** 時仍 **`velocity = Vector2.ZERO` + `move_and_slide()`** 以利引擎推出重疊。  
- **施法護盾**：`MonsterBase.play_hit_animation` 內對玩家為 **`Node2D`** 再算 **`Vector2` 彈開方向**，呼叫 **`request_knockback_push`** 後 **`take_damage(0)`**（勿再 Tween 玩家座標）。  
- **備註**：主角 **`perform_dash`** 若仍為 Tween `global_position`，理論上仍可能穿牆；與擊退分案，日後可改碰撞安全位移。
- **怪物受擊擊退（2026-03-29）**：**勿**在 **`MonsterHurtState`** 對怪 **`Tween` `global_position`**（會穿牆）。**作法**：**`MonsterBase.request_knockback_push`／`_consume_pending_knockback_push`**（分段 **`move_and_collide`**），於 **`MonsterBase._physics_process`** 開頭、`move_and_slide()` 前消耗；與主角同一幾何策略。

### 4c. 環境寶寶鳥（專用場景 + 靠近驚飛，2026-04）

- **場景**：`scenes場景/entities主角_怪物_寵物/怪物/BabyBirdMonster.tscn`（**非**泛用 `MonsterBase.tscn` 直接摆）；**腳本**：`src腳本/entities/monsters/AmbientBabyBirdMonster.gd`；**資料**：`resources身分證/monster/baby_bird_monster.tres`（與戰鬥怪 **`participates_in_combat`／鎖敵** 語意分離，由腳本與資源欄位共同約束）。
- **AI 摘要**：棲枝／閒逛；**主角接近**觸發 **驚飛**（加速離開、飛行高度與 **`GlobalBalance.BABY_BIRD_FLIGHT_*`** 對齊出戰寶寶）；可 **離屏後**於棲點附近 **再生**，維持湖畔氛圍而不堆怪。
- **關卡摆法（現行定版）**：`LakeSideLevel.tscn` 根下**直接**放 **兩** 個 **`BabyBirdMonster` 實例**（`LakeBabyBird`／`LakeBabyBird2`），各設 **`lake_ambient_save_slot = 0`／`1`**（與 **`GlobalBalance.LAKE_AMBIENT_BABY_BIRD_TOTAL`** 一致）；`data` 可留空，執行期由腳本補 **`baby_bird_monster.tres`**。**亦可**改用 **`MarkersPropSpawner`** 指到 **`BabyBirdMonster.tscn`** 並覆寫 **`prop_data`**，但須**逐一**指定不重複的 **`lake_ambient_save_slot`** 並同步 **`LAKE_AMBIENT_BABY_BIRD_TOTAL`**。

### 5. 換場與「儀式感」UI（區域名、採收鈕、搖桿）— 設計協議

- **`AreaTitleBanner`／`HarvestToggleButton`／`HarvestHudLocker` 等**掛在 **`Main.tscn` → `UILayer`（`CanvasLayer`）**，**不**在 `LakeSideLevel` 子樹內；**整關替換 `LevelContainer` 子關卡**時，**不必**為了換圖而拆掉這套 UI。
- **整關切換（村外 ↔ 家園全圖等）**節奏**已落地（2026-04）**：**`Main.tscn` → `UILayer/LevelTransitionOverlay`**（群組 **`level_transition_overlay`**，`LevelTransitionOverlay.gd`）全螢幕漸黑／漸透；**`HomeManager._swap_level`** 內 **`await` 淡入黑 → 換 `loaded_level`＋傳送 → `PlayerController.snap_camera_after_warp()`**（`Camera2D.reset_smoothing()`）→ **湖畔／城鎮**呼叫 **`request_area_title`**（**「史萊姆湖畔」**／**「落葉鎮」**；**切到獨立 `HomesteadLevel` 場景**不重複播城鎮標題，避免與進家園浮字打架）→ **`await` 淡出**；時間常數 **`GlobalBalance.LEVEL_TRANSITION_FADE_OUT_SEC`／`LEVEL_TRANSITION_FADE_IN_SEC`**。設計協議原文仍適用於往後洞窟／Boss 等擴充。
- **禁止**：為了「偷換關」而永久捨棄 **`area_title_*`／`player_in_homestead_changed`** 驅動的儀式 UI；若與新模式堆疊衝突，應擴充 **互斥／狀態堆疊**（見 Phase 10「與封印／對話的邊界」），而非刪流程。
- **~~已知待修（儀式感 UI）~~** → **已結案（2026-03）**：**`PetCompanion`** 與世界層 **`collision_layer`／`collision_mask` 對齊**地形；**對話結束後採收鈕**與 **`player_in_homestead_changed`／對話阻擋**狀態對齊；**進出家園虛擬搖桿**與 **`DialogueHudLocker`／`HarvestHudLocker`** 的 **`show`／`hide`＋`set_process_input`** 規則一致。  
- **仍可排入的美術／polish（非阻塞 bug）**  
  - **採集物／場上掉落視效**：若個別物件仍無陰影，可續接 **`ShadowComponent`**（`TEXTURE_FILTER_NEAREST`，與 NPC／怪一致）。  
  - **場景氛圍**：**水／花／螢火蟲／火把**等 **動畫與粒子**（與 `EffectManager`／`FxPreview` 並存；長駐優先場景內節點）。

### 6. 下一張地圖（家園全圖／城鎮圖）注意事項

- **獨立場景檔**：**不要**在 `LakeSideLevel` 內再疊一張完整家園底圖；**長期**以 **落葉鎮關卡場景**（或 **`TownLevel`／`FallenLeafTown.tscn` 等**）+ **`LevelContainer` 換子實例**為主。`HomeManager` 已保留 **`switch_to_homestead`／`switch_to_lake`**；**日後**對稱擴充 **`switch_to_town`（或城鎮即預設出生關）**、**`switch_to_cave`／`switch_to_cave_boss`** 等，見 **§8**。**`HomesteadLevel.tscn`** 可續作純家園演練場，**主線**以**城鎮內嵌田園**為準。
- **城鎮底圖（美術入口）**：**`res://assets圖片_字體_音效/環境/城鎮含家園/hometown_01.png`** — **落葉鎮**單張大地圖；**畫面右上「田園區」**＝**種田＋駐寵＋採收**（**複製／接線**既有 **Phase 10** `HomesteadZone`／`HomesteadCrop`／`HomeManager` 語意，與湖畔試作田**脫鉤**）。**城內建築**＝ **NPC 錨點**（目標 **5～7** 位）。
- **資料與美術分離**：**4 塊翻土 × 每塊 9 株**仍屬 **`HomeManager`**；土格與 **`HomesteadZone`** 錨在**城鎮圖田園區**座標系（**`TerrainCollision` 與底圖 scale 一致**鐵則不變）。
- **複用本節**：`TerrainCollision` 分段多邊形、`MarkersPropSpawner`、前景 hoist、`UILayer` 儀式 UI——**流程與湖畔一致**，只換資源與座標。

### 7. 留線關鍵詞（新對話可貼）

**四張圖拓撲**／**城鎮↔湖畔↔洞窟↔Boss**／**Boss 後劇情**／**感謝名單（可略過）**／**騎虎歸途演出**／**`LakeSideLevel`／`TerrainCollision`／`MarkersPropSpawner`／`ForegroundCanopyHoist`／`BabyBirdMonster`／`AmbientBabyBirdMonster`／`request_knockback_push`／換關儀式感／`hometown_01.png`／落葉鎮／傳送點在進家園前／`ShopManager`／金幣買賣／`HomeManager`／死亡復活家園醒來／perform_ghost_dash／FgTree z=5 與 y_sort**

### 8. 世界分線與傳送留線（2026-04；**世界拓撲定案補記**）

> **企劃定調（現況）**：本階段**只此一城鎮**（**落葉鎮**）；**湖畔**＝**野戰**（史萊姆、寶寶鳥等）；**洞窟**＝**地下城迷宮**（較強怪物）；**洞窟頂**＝**Boss 專圖**。皆以 **`LevelContainer` 換子關卡**＋**儀式感換場**銜接（見 **§5**）。**Boss 戰後**＝劇情 → **可略過之感謝名單** → **騎虎歸途**（洞窟→湖畔→家園與妹妹會合），見 **§8.6**。

#### 8.1 四張圖與傳送方向（單一真相）

| 順序概念 | 關卡／場景（檔名留線） | 傳送／備註 |
|-----------|------------------------|------------|
| **1 城鎮** | **落葉鎮**（底圖 **`hometown_01.png`**） | **右上**＝**田園家園**（種田、駐寵、採收；**複製 Phase 10 田園子系統**至此圖）。**左下**＝通往 **湖畔** 的傳送點（或等價「出城門」區）。 |
| **2 湖畔** | **`LakeSideLevel.tscn`** | 野戰：史萊姆、環境寶寶鳥等。**上方**＝通往 **洞窟** 入口。 |
| **3 洞窟** | 新關卡（留線） | 迷宮／較強怪；**頂端**＝通往 **Boss 戰** 專圖。 |
| **4 Boss** | 新關卡（留線） | Boss 戰專用；戰後流程見 **§8.6**（劇情 → 感謝名單 → 騎虎歸途至家園）。 |

- **湖畔 ↔ 城鎮**：**從湖畔回城**（與**進城後通往湖畔**）之傳送錨點，**設在「進入右上田園家園區之前」**（城鎮側落點在**田園外**／主街或左下城門一帶），避免一進城就直接落在種田區內；實作以場景 **`Marker2D`** 或 **`LevelPortal`** 為準。
- **主線出生／預設關卡（留線）**：企劃以**城鎮**為 hub；**`Main.tscn`** 之 **`LevelContainer` 預設子關卡**日後可改為**落葉鎮**（現仍以 **`LakeSideLevel`** 開發者預設者，遷移時一併改 **`HomeManager` 進場狀態**與區域名）。

#### 8.2 家園與湖畔試作田

- **城鎮田園**：**優先**在**落葉鎮場景**內**複製／接線**既有 **`HomesteadZone`、`HomesteadCrop`、`HomeManager.in_homestead`／採收**管線（與 **Phase 10** 已落地程式對齊），**作為唯一主線家園**。
- **湖畔 `HomesteadZone`／`Crops`**：**移除或停用**（避免兩套田園）；過渡期若需驗收，以「城鎮田園已可玩」為切換點。

#### 8.3 死亡與復活（留線；系統未實作）

- **長期預設**：日後若做**主角死亡**，**復活醒來點**＝**家園**（城鎮**右上田園區**內之床／安全點，錨點名稱待場景定）；**非**湖畔。存檔／`SaveGameManager` 需能記 **`last_wake_homestead` 或等價**（細節待專章）。

#### 8.4 金幣與 `ShopManager`（留線）

- **NPC 商店**：買賣需**集中**在 **`ShopManager`（Autoload 或專用 Node 群組）**：**扣款／入帳金幣**（讀寫 **`InventoryManager`** 既有金幣欄位與存檔）、**檢查背包空間**、**發放道具**（**`InventoryManager.grant_*`／`item_collected`** 等既有路徑）；**定價表**以 **`Resource`／資料表**驅動。
- **`SignalBus`**：僅宣告**窄請求／結果**（例：`shop_purchase_requested`／`shop_result` 等，名稱實作時定）；**禁止**在 **`SignalBus.gd` 寫扣金幣公式或庫存邏輯**（鐵則與 **`InventoryManager`** 一致）。
- **與對話銜接**：`DialogueEffectEntry` 可發 **「開啟某 `shop_id`」** 請求，由 **`DialogueManager`** 轉 **`ShopManager`**，**不**在對話圖內算價。

#### 8.5 落葉鎮內容（延續）

- **無戰鬥怪**：不部署 **`monsters` 群組**鎖敵；可保留**環境生物**、**寶箱**、靜態互動。  
- **主軸**：**NPC**（5～7 位留線）、**任務**、**商店（`ShopManager`）**；金幣已部分落地（擊殺 **`add_gold`**、UI 顯示），**消費迴路**待接 **`ShopManager`**。

- **實作入口**：延續 **`LevelPortal.gd`** 或 **`Area2D`** → **`HomeManager` 或專用 `WorldMapManager`** 請求換關（**`SignalBus` 只轉事件**）。

#### 8.6 Boss 戰後：劇情、感謝名單與「騎虎歸途」（企劃定案，實作留線）

> **體驗目標**：Boss 擊破後先跑**一段劇情**，再進入類**電影感謝名單**（**全程可略過**）。名單／過場期間為**強制觀賞模式**：**玩家不可操作**（無移動、無選單搶焦），純欣賞**一路走來的風景回顧**。

- **演出內容（敘事順序）**  
  1. **主角騎乘老虎**（坐騎視覺留線；可沿用既有 **`pet_mount`** 語意或專用演出用替身節點）。  
  2. **路線**：自 **洞窟** 內外出發 → **下山** → 經過 **湖畔**（玩家曾征戰之野）→ 抵達 **城鎮家園（右上田園）**，與**妹妹**會合（**妹妹**為家園／城鎮錨點 NPC，立繪／場景節點待補）。  
  3. **語意**：總結旅程、情緒收束；與 **§8.1 四圖拓撲** 空間順序一致（洞窟 → 湖畔 → 城鎮家園）。

- **操作與 UI 互斥（實作時對齊）**  
  - **鎖玩家輸入**：`PlayerController` 移動／攻擊／封印／翻滾／戰技等**一律關閉**；**虛擬搖桿**與 **`RightActionGroup`** 建議與 **對話全螢幕阻擋**同款（**`set_process_input(false)`**／父節點隱藏，見既有 **`DialogueHudLocker`** 模式）。  
  - **感謝名單可略過**：提供明確 **Skip**（例如按住／確認鍵）；略過後**直接**切到**可玩狀態**（通常為**家園或城鎮**，與妹妹會合後結束演出）。  
  - **勿**在 `SignalBus.gd` 寫長鏡頭時間軸；建議專用 **`CreditsSequence`**／**`PostBossCinematic`**（或 **`CutsceneManager`**）持有時間軸與換場，經 **`SignalBus`** 僅廣播 **`cinematic_blocking_changed`** 類窄訊號（名稱實作時定）。

- **技術留線（二選一或混用）**  
  - **連續軌道鏡頭**：單一長場景內 **`Path2D`／`AnimationPlayer`／相機遠景跟隨** 主角＋虎，沿途 **Streaming 或子區段啟用** 湖畔／洞窟外觀。  
  - **分段換關**：依序 **`LevelContainer` 換子關卡**（洞窟出口 → 湖畔過場 → 城鎮家園），每段短鏡頭銜接；需統一 **淡入淡出** 與 **同一套 blocking** 旗標，避免玩家在換場瞬間恢復操作。

- **與存檔**：Boss 擊破旗標、`post_boss_credits_seen` 或等價鍵（防重播／二週目略過選項）待與 **`SaveGameManager`** 對齊。

### 9. 家園寵物行為體規格草案（P0，下一串對話優先）

> 目標：把目前「站位代理（可互動）」升級為「家園寵物 agent（可走動/巡遊）」，並支援**數十隻**駐留規模。

- **核心定位**
  - 家園寵物不是站樁 NPC；應有待機巡遊、停留、轉向、避開障礙的最小行為循環。
  - 看家駐留與出戰互斥規則維持不變（同一隻不可同時在 party 與 homestead roster）。

- **資料與狀態來源（單一真相）**
  - 駐留名單：`PetManager.stationed_instance_order`（順序仍有意義）。
  - 行為狀態快照：新增 `HomeManager`（或專用 `HomesteadPetRuntimeState`）保存巡遊目標點、下一次行為切換時間、嘟嘟工作冷卻。
  - `SignalBus` 僅保留請求/結果訊號（不承載巡遊決策邏輯）。

- **生成與上限策略（數十隻）**
  - 目標上限：支援數十隻駐留資料；同時「高頻更新」寵物需分層：
    - `active_agents_cap`（建議 12~16）：完整移動/避障/互動。
    - 其餘進入 `light_agents`：低頻 tick（例如 0.3~0.6 秒）與簡化動畫。
  - 就近啟用：以玩家距離決定 active/light，離太遠可凍結更新但保留可見。
  - 仍保留 `instance_id` 綁定，避免同 `pet_id` 混淆。

- **巡遊與避障（MVP）**
  - 行為節奏：`idle(0.8~2.2s) -> choose_target -> move -> idle`。
  - 目標點來源：家園區域內採樣（可先用矩形/多邊形 bounds + 隨機點）。
  - 避障優先：依既有地形碰撞（`collision_mask=1`）做 `move_and_slide`；卡牆時重抽目標。
  - 防堆疊：同幀抽點時加入與其他 agent 的最小間距（例如 20~32 px）。

- **嘟嘟翻土優先權**
  - 嘟嘟（具 `SkillResource.is_homestead_till_skill`）在巡遊迴圈中插入工作判斷：
    1) 找最近可翻土 `homestead_soil_plot`；
    2) 在工作半徑內優先執行翻土；
    3) 成功後進入技能冷卻再回巡遊。
  - 禁止 `if pet_id == "dudu"` 硬編主邏輯；能力判斷以技能欄位為準（可保留 dudu 作敘事預設）。

- **互動規格**
  - 玩家靠近看家寵仍可互動（餵種子/收回/對話），但互動期間暫停該 agent 巡遊。
  - 多隻重疊時由距離最近者優先提示（沿用 `NpcInteractionManager` 仲裁思路）。

- **存檔與離線**
  - 存檔需含：每隻駐留寵的行為相位、目標點（可選）、冷卻剩餘（嘟嘟翻土）。
  - 離線回來：先套 `HomeManager` 作物離線成長，再恢復 agent 狀態；不可互相覆蓋。

- **驗收定義（本草案）**
  - 20+ 駐留資料下，家園內可見寵物不再全站樁，且不明顯穿牆/疊成一團。
  - 嘟嘟可在家園內週期翻土，並與作物三階段鏈正確銜接。
  - 看家互動（收回/餵種子）不回歸靜默失敗，且 `instance_id` 綁定穩定。

---

## Phase 10：家園與採收（第一階結案；**2026-04 換關／採收體驗／落葉鎮氛圍已補強**）

> **第一階狀態（2026-03-28 結案）**：步行進家園區、採收模式、HUD／搖桿互斥、滑掃成熟作物入包、區域浮字、封印鈕在家園隱藏、主角／NPC／怪／寵物 **`LevelContainer` 同層排序** 等**已落地**。**主角頭上情境提示**：`player_world_hint_changed`＋`PlayerHintCatalog`＋**`HarvestModeHint`**（`instant_text`／`hold_sec`／`fade_out_sec` 或歷史打字 payload）。  
> **2026-04 調整（見下「實作補記」）**：進家園若有成熟株→**一次性**漸顯漸隱提醒（不再長駐「點採收」）；採收中**拖曳教學**僅全遊戲第一次流程，**採滿 2 株**後關閉（**`ProgressionManager`** 持久化）；採光收工改**單句 instant**＋關採收；採收時**半透明暗幕**（**`HarvestWorldDim`**）＋**作物提亮**（土格腳本乘算，避免被成長動畫蓋掉）；**`HarvestHudLocker`** 另藏**存檔鈕**，**不**藏 **`PetUI`**；採收中 **`NpcInteractionManager`** 暫停**近距離 NPC／看家「照顧○○」浮字**；**湖畔↔城鎮**換關**電影淡**＋**區域名**。下列「體驗提要」仍為全 Phase 願景；**作物三階段以外的敘事 polish、洞窟／Boss 換場**等見待辦與 **§8**。

### 第一階已落地：檔案與職責（單一真相索引）

| 類型 | 路徑 | 說明 |
|------|------|------|
| autoload | `src腳本/autoload管理員/HomeManager.gd` | `in_homestead`／`harvest_active`、互斥（對話／封印）、滑掃同幀上限、`set_player_in_homestead`、`request_area_title`；**換關**：`_swap_level`＋**電影淡**＋**區域名**（**`switch_to_lake`／`switch_to_town`／`switch_to_homestead`** 及 `*_async`）；**世界提示**：`_sync_homestead_player_hints`；採光後 **instant 收工一句**＋`_exit_harvest_mode_without_deferred_resync`；**採收提亮**：`apply_crop_harvest_highlight_modulate`、`refresh_homestead_soil_crop_modulates`；**`harvest_mode_changed`** 同步作物 `modulate` |
| autoload | `project.godot` → `HomeManager` | 已註冊 |
| autoload | `src腳本/autoload管理員/PlayerHintCatalog.gd` | `hint_id` → 靜態文案；**`HINT_HOMESTEAD_SWIPE`**＝拖曳教學（僅第一次採收流程，見 **`ProgressionManager`**）；`HINT_HOMESTEAD_NO_CROPS` 等保留相容；預留 `HINT_WORLD_DANGER_SOFT` 等 |
| autoload | `project.godot` → `PlayerHintCatalog` | 已註冊 |
| 區域 | `src腳本/entities/homestead/HomesteadZone.gd` | `Area2D`：進出呼叫 `HomeManager.set_player_in_homestead`；`call_deferred` 初始重疊 |
| 作物 | `src腳本/entities/homestead/HomesteadCrop.gd` | `item_collected` + `request_effect_collect`、`duplicate` 入庫；**`counts_as_mature_available()`**（排除已 `_gathered` 仍佔群組之誤計） |
| 關卡根 | `src腳本/entities/homestead/LevelRoot.gd` | `loaded_level` 群組（換關清場用）；**`LEVEL_YSORT_PROXY_GROUP`**：執行期掛到 `level_container` 的作物／站點視覺等，**`_exit_tree` 集中 `queue_free`**（見 **實作補記 2026-03-31**） |
| 傳送（保留） | `src腳本/entities/homestead/LevelPortal.gd` | `monitoring` 須 `set_deferred`；現行主流程**不綁傳送進家園** |
| 關卡場景 | `scenes場景/levels/lake_side/LakeSideLevel.tscn` | **`Background` 大地圖**、`TerrainCollision`（`CollisionPolygon2D` 北／中／南）、`HomesteadZone`、`Crops`、**`MarkersPropSpawner`**（石／史萊姆）、水／花／氛圍錨點、**`ForegroundDecor`**（前景樹 + **`ForegroundCanopyHoist`** → `level_container`）；**無**內嵌劇情 NPC；細節見 **`## 湖畔關卡（LakeSideLevel）地圖與場景編排（實作定版）`** |
| 關卡場景 | `scenes場景/levels/homestead/HomesteadLevel.tscn` | 整關家園備用；`HomesteadZone` 全圖；無傳送門 |
| 關卡場景 | `scenes場景/levels/town/FallenLeafTown.tscn` | 城鎮底圖、田園 **`HomesteadBundle`**、傳送、**`ForegroundDecor`**（可選）、**`Art/Ambience`＋`TownLeafAmbientVfx`**；預設開局 |
| 主場景 | `scenes場景/Main.tscn` | `LevelContainer`：**`FallenLeafTown`**（預設）、**`Player`**、**`PetCompanionSpawner`**…；`UILayer` 含 **`LevelTransitionOverlay`**、**`HarvestWorldDim`**、**`PetUI`／`InventoryUI`／`DiaryUI`**、**`PetPartySlotHud`**、`HarvestHudLocker`、`HarvestSwipeCapture`、`HarvestToggleButton`、`HarvestModeHint`、`AreaTitleBanner` |
| NPC（場上實例） | 依劇情置入各關卡或 `Main` 之 `LevelContainer` | **`NpcFieldAgent`** + **`NpcResource`**；**`DialogueManager._NPC_PATH_BY_ID`／`_GRAPH_PATH_BY_KEY`** 註冊。舊**湖畔鐵匠**僅測試期**格式範例**（已移除），流程可複製為後續 NPC 的**橋樑** |
| UI 腳本 | `scenes場景/ui介面/HarvestHudLocker.gd` | 採收中隱藏瞬移／封印／血條／XP 列／搖桿／**`PetPartySlotHud`**／**`SaveGameButton`**；**不**隱藏 **`PetUI`**（底欄寵物入口）；還原時若在家園則封印保持隱藏 |
| UI 腳本 | `scenes場景/ui介面/LevelTransitionOverlay.gd` | 換關全螢幕漸黑／漸透；群組 **`level_transition_overlay`** 供 `HomeManager` `await` |
| UI 腳本 | `scenes場景/ui介面/HarvestWorldDim.gd` | 採收模式 **`UILayer`** 半透明暗幕（`ColorRect` alpha～0.52，勿用不透明純黑）；聽 **`harvest_mode_changed`** |
| 關卡腳本 | `src腳本/entities/homestead/TownLeafAmbientVfx.gd` | **落葉鎮**粒子：每 **`LeafZones`／`Marker2D`** 下兩個 **`CPUParticles2D`**（**`#ffbb77`**／**`#aa5d3f`**），**`color_ramp`** 生命週期漸顯漸隱；**Godot 4.1**：`color_ramp` 型別為 **`Gradient`**（**非** `GradientTexture1D`） |
| 土格 | `src腳本/entities/homestead/HomesteadSoilPlot.gd` | 作物顯示色經 **`HomeManager.apply_crop_harvest_highlight_modulate`**，避免採收提亮被 **`_apply_*_visual`** 蓋掉；**`reapply_crop_modulate_for_harvest_mode`** |
| autoload | `src腳本/autoload管理員/NpcInteractionManager.gd` | **`harvest_mode_changed`**：採收中 **`_resolve_and_emit_best_prompt`** 強制不顯示近距離提示（看家「照顧○○」等）；池保留，關採收後可恢復 |
| autoload | `src腳本/autoload管理員/ProgressionManager.gd` | **`homestead_harvest_swipe_tutorial_done`**、**`homestead_harvest_swipe_tutorial_pick_count`**、`bump_homestead_swipe_tutorial_pick()`；存檔 **`progression`** 區塊 |
| UI 腳本 | `scenes場景/ui介面/HarvestSwipeCapture.gd` | 採收中滑掃層 **`offset_bottom = -UI_BOTTOM_BAR_HEIGHT_PX`**（不蓋底欄），避免全螢幕 `STOP` 與 `IGNORE` 根穿透疊加後攔截 **背包／寵物／日記** 按鈕；軌跡仍交 `HomeManager.try_harvest_swipe_world` |
| UI 腳本 | `scenes場景/ui介面/HarvestModeHint.gd` | 監聽 `player_world_hint_changed(..., payload)`：`payload==null` 查 `PlayerHintCatalog`；**Dictionary** 且含 `typing_intro`+`final_text` 時打字→清空→第二句；可選 **`final_hold_sec`／`final_fade_out_sec`** 第二句後漸隱；`_seq_token` 打斷、`emit(..., null)` 與離園清空一致 |
| UI 腳本 | `scenes場景/ui介面/AreaTitleBanner.gd` | 區域名漸顯／漸隱 |
| UI 腳本 | `scenes場景/ui介面/DialogueHudLocker.gd` | 對話阻擋＋**家園時隱藏封印鈕**；監聽 `player_in_homestead_changed` |
| 元件 | `src腳本/components積木/HarvestToggleButton.gd` | 家園內漸顯／離開漸隱；`harvest_mode_toggled` |
| 元件 | `src腳本/components積木/SealManager.gd` | `is_seal_ritual_active()` 供 `HomeManager` 互斥 |
| 主角 | `src腳本/entities/PlayerController.gd` | **`snap_camera_after_warp()`**（換關 **`Camera2D.reset_smoothing()`**）；`harvest_movement_locked`、`item_collected` → `happy` 節流、採收／對話中禁瞬移；**`request_knockback_push`／`_consume_pending_knockback_push`**；**`is_hit_stun`／`is_dashing` 仍 `move_and_slide()`**；**根節點勿 `y_sort_enabled`**（頭飾排序見 Phase 7） |
| 底欄面板 | `PetUI.gd`／`InventoryUI.gd`／`DiaryUI.gd` | **`InventoryUI`**：`item_collected` → 開啟鈕彈跳；三者 **`_show_panel`** 時若 **`HomeManager.harvest_active` 則 `SignalBus.harvest_mode_toggled(false)`**；**`DiaryUI`** 互斥與 **`diary_ui_close_requested`** 見 Phase 5「底欄三鈕與日記 UI」 |
| 資料 | `resources身分證/items/homestead_crop_demo.tres` | 試作作物 `ItemResource`；`DataManager` 掃目錄載入 |
| 平衡 | `src腳本/autoload管理員/GlobalBalance.gd` | `HARVEST_MAX_ITEMS_PER_FRAME`、`PLAYER_COLLECT_HAPPY_COOLDOWN_MS`、`PLAYER_DISPLAY_NAME`、`AREA_TITLE_*`、**`LEVEL_TRANSITION_FADE_OUT_SEC`／`LEVEL_TRANSITION_FADE_IN_SEC`**、`LEVEL_SORTED_ENTITY_Z_INDEX`（**主角／怪／寵物與前景樹 `FgTree_*` 同用 5**，勿另拉高樹 z；註解已說明）；**編隊寵**：`PET_TELEPORT_PULL_DIST`；**槽位跟隨倍率／麵包屑延遲** `PET_PARTY_SLOT0/1/2_FOLLOW_MULT`、`PET_PARTY_SLOT0/1/2_TRAIL_LAG_SEC`（見腳本內數值；變更時宜同步 `PetCompanion.gd` 內無 GlobalBalance 時的 fallback） |

**層級規則（必記）**：`LevelContainer.y_sort_enabled` 時，**整張載入關卡根在 (0,0)** 與主角比排序；主角往北 Y 變小會被整關蓋住。故 **主角／寵物／怪／石頭／NPC** 須為 **`LevelContainer` 直接子節點**（或由 **`MarkersPropSpawner`／`ForegroundCanopyHoist`** 達成等價）且 **`z_index = 5`（或 `LEVEL_SORTED_ENTITY_Z_INDEX`）**，與關卡 `z_index=0` 分開；**經 `ForegroundCanopyHoist` 提升到 `LevelContainer` 的前景樹 `FgTree_*` 亦為 z=5**，與角色**同層**才能 **`y_sort` 互遮**。**勿**把樹單獨拉到更高 z（例如 7），否則樹永遠壓角色。關內 **地形／底圖** 用較低 `z_index`（如湖水 `-2`、綠地 `-1`）；**前景樹冠**請走關卡內 **`ForegroundDecor` + `ForegroundCanopyHoist`**（腳本會掛到 `level_container`），勿整袋與主角只比一個 Y。  
**主角內部**：`Player` 根**不要**開 **`y_sort_enabled`**（會讓頭飾被身體蓋住）；頭飾見 Phase 7「頭飾與身體、前景樹的 z／排序」。

### 體驗提要
- **採收模式**（類封印「儀式」）：專用按鍵進入／退出；進入時隱藏**封印鈕、瞬移鈕、血條、經驗列、編隊槽 HUD、存檔鈕、虛擬搖桿**等（見 **`HarvestHudLocker`** 節點表）；**`PetUI` 底欄鈕**維持可見；可選 **暗幕＋作物提亮**（上表 **`HarvestWorldDim`**／**`HomesteadSoilPlot`**）。主角**不移動**（與 `DialogueHudLocker`／搖桿 `set_process_input` 經驗對齊）。**底欄背包／寵物／日記**仍應可點：**`HarvestSwipeCapture`** 須留出 **`UI_BOTTOM_BAR_HEIGHT_PX`**；開任一面板即退出採收（見上表「底欄面板」列）。
- **滑掃採收**：畫面內**成熟**作物無需主角靠近；手指軌跡與作物碰撞／可採區相交即觸發；可批次掃多株，**多發 `item_collected` + `request_effect_collect`**（注意同幀上限與低階機效能）。
- **回饋**：道具飛入背包時，底欄**背包按鈕彈跳**；主角**不需**隱藏／放大，建議在入包 FX 時觸發 **`happy` 動畫**（宜**節流**，避免十連飛入連播十次）。
- **作物**：**幼苗 → 開花 → 成熟**，以**遊戲時間**推進（先採 **線上時間**；離線是否成長另決）；每品種獨立圖／動畫與對應 **`ItemResource`**，**資料驅動**（`.tres`），禁止單一作物名硬編碼特例。

### 敘事與系統掛鉤（設計意圖）
- **湖畔 NPC → 好感上升 → 取得寵物「嘟嘟」**（既有 `NpcStateManager`／對話／`PetManager` 鏈可銜接，細節實作時定）。
- **嘟嘟技能**：除戰鬥奧義外，具 **「翻土」**；僅在家園內有意義。
- **家園內駐留嘟嘟**：在美術**有碰撞的柵欄**範圍內，依**線上時間**隨機**翻土**；被翻土之區塊進入可種／生長邏輯，長出作物供採收模式掃取。
- **其他寵物**：亦可**駐留家園**（展示或日後加成）；**`PetUI`「放置家園」按鈕尚未製作**——規格：**平時反灰**，**僅當主角人身處家園場景時可點**（由 **`player_in_homestead_changed(in_homestead: bool)`** 類訊號驅動 UI，不直連 `Player` 節點）。

### 資料與 Manager（規劃）
- **`HomeManager`（名稱可定）**：家園子場景狀態、作物格／翻土戳記、駐留寵物與嘟嘟 AI 所需讀寫；**存檔欄位與 `PetManager.captured_pets`、出戰狀態分語意**，避免同一陣列混「隨身／駐留」。
- **寵物技能**：於 **`PetResource`／`SkillResource`（或既有技能表）** 以欄位標記「翻土」等能力，**禁止** `if pet_id == "嘟嘟"`。
- **採收模式狀態**：**已併入 `HomeManager`**（第一階）；若日後邏輯膨脹再拆 `HarvestModeManager`。

### 訊號（`SignalBus.gd`：已宣告者仍無邏輯）

> 下列維持請求／結果分層與現有採集協議一致。

- **模式／場景**：`harvest_mode_toggled(enabled: bool)`（請求，UI → `HomeManager`）；`harvest_mode_changed(active: bool)`（狀態廣播）；`player_in_homestead_changed(in_homestead: bool)`。
- **地圖浮字（可重用）**：`area_title_show_requested(title: String, duration_sec: float)`（`duration_sec`≤0 則 UI 用 `GlobalBalance` 預設節奏）；`area_title_hide_requested`（離開區域等）；由 `AreaTitleBanner` 監聽。
- **主角頭上情境提示**（口語可稱「世界提示」）：`player_world_hint_changed(hint_id, show_hint, payload)`（**signal 不可寫參數預設值**，無 payload 必 **`emit(..., null)`**）。**payload（Dictionary）**：**`instant_text`**＋可選 **`hold_sec`／`fade_out_sec`**（單行白字漸隱）；或歷史 **`typing_intro`／`final_text`** 等多鍵打字序列（見 **`HarvestModeHint`**）。**家園採收（2026-04）**：進家園有成熟株→**每趟進入**一次 **`instant` 提醒**（可採收）；採收中→**第一次流程**才顯示拖曳教學（**`ProgressionManager`**，掃 **2 株**後關）；採光→**單句收工**＋關採收；離開家園 `emit("", false, null)` 收起。
- **駐留**：`pet_homestead_station_requested(pet: PetResource)`（請求）；`pet_home_roster_changed`（結果／狀態廣播，參數形別實作時定）。
- **既有沿用**：入庫 **`item_collected`**、演出 **`request_effect_collect`**、背包 UI 可監聽 **`inventory_changed`**（或更細的結果訊號，若日後拆分）。

### 與封印／對話的邊界
- **採收模式、封印模式、對話阻擋**不得同時搶用觸控與 HUD；需**互斥**或**單一 blocking 堆疊**（參 Phase 9「曾出現問題」：搖桿 `set_input_as_handled`、全螢幕 `Control` `z_index`）。

### 建議最小落地順序
1. ~~家園場景雛形 + **採收模式**開關與 HUD 隱藏 + **單品種**成熟作物 + **滑掃** + `item_collected`／`request_effect_collect` + 背包鈕彈跳／`happy` 節流。~~ **【第一階已結案】**  
2. 作物 **三階段時間軸**、再生／冷卻。  
3. **嘟嘟駐留** + 柵欄內翻土 + 格子狀態寫入 **`HomeManager`**（或等價存檔）；**嘟嘟／技能 Resource 資料驅動**（禁止 `pet_id` 硬編碼）。  
4. **`PetUI` 放置家園鈕** + `player_in_homestead_changed` + 存檔遷移。

### 風險與待定 QA
- 離線成長與時區；單次掃描最大株數；放生／家園敘事文案與實際 `HomeManager` 語意對齊時機。

### 留線（給下一輪對話／日誌）
- **關鍵詞**：`Phase10 slice2`、`作物時間軸`、`嘟嘟`、`翻土`、`PetUI 放置家園`、`HomeManager 存檔欄位`、`DiaryUI`、`HarvestSwipeCapture` 底欄留白、`diary_ui_close_requested`。  
- **湖畔地圖段落**：**已定版**（2026-03-29）— 見 **`## 湖畔關卡（LakeSideLevel）地圖與場景編排（實作定版）`**；**2026-04 補記**：**§8** **四圖**、**傳送點在進家園前**、`hometown_01.png`、**城鎮複製田園**、**`ShopManager`**、**死亡復活家園醒來**、**§8.6 Boss 後劇情／感謝名單（可略過）／騎虎歸途至家園與妹妹**；湖畔內測試田園**淘汰**。**落葉鎮**：**換關電影淡**、**區域名（湖畔↔鎮）**、**落葉粒子**、**採收體驗 polish** 已落地（見 Phase 10 表＋**實作補記 2026-04**）。下一工作包：**洞窟／Boss 場景**、**過場與感謝名單演出**、**商店與金幣消費**、其餘場景 **動畫與粒子 polish**；**換場與儀式感 UI（電影淡＋標題）** 主線**已補強**（該章 **§5**）。
- **世界提示擴充**：`player_world_hint_changed`、`PlayerHintCatalog`、`HarvestModeHint`；寶箱／危險／其他教學＝**新 `hint_id`＋文案或 payload**，原則**不重複宣告訊號**；若需多段演出可複用 payload 鍵或再增欄位（與 `HarvestModeHint` 約定即可）。

### 實作補記（2026-04：落葉鎮氛圍、電影淡換關、採收體驗）

> 濃縮本輪對話落地項，供 context 重置後接續；細節以程式為準。

- **換關**：`HomeManager._swap_level` 串 **`LevelTransitionOverlay.run_fade`**（黑幕期換關＋傳送）、**`PlayerController.snap_camera_after_warp`**、**`request_area_title`**（僅 **湖畔／城鎮** 檔路徑對應之中文名；**`HomesteadLevel` 獨關**不重複播鎮名）。常數 **`GlobalBalance.LEVEL_TRANSITION_*`**。
- **採收 HUD／互動**：**`HarvestWorldDim`**（`UILayer` 半透明暗色；作物在 **`HomesteadSoilPlot`** 經 **`apply_crop_harvest_highlight_modulate`** 維持提亮）；**`HarvestHudLocker`** 含 **`SaveGameButton`**、不含 **`PetUI`**；**`NpcInteractionManager`** 於 **`harvest_active`** 時不顯示 **`npc_interaction_prompt_changed`**（看家浮字仍用 proximity pool，關採收後重解）。
- **教學／存檔**：**`ProgressionManager`** 採收拖曳教學進度；**`try_harvest_swipe_world`** 成功掃株時 **`bump_homestead_swipe_tutorial_pick`**。
- **落葉鎮粒子**：**`TownLeafAmbientVfx.gd`**；**`LakeSideAmbientVfx`** 螢火蟲 **scale 1.0～2.5** 為落葉尺寸對照基準。**引擎差異**：**4.1** 的 **`CPUParticles2D.color_ramp`** 指派 **`Gradient`**；**4.2+** 若改為 `Texture`，需再對表官方 class reference。

### 實作補記（2026-03-29，供新對話接續）

> 下列為當期對話落地、聖經原「待做／願景」欄位尚未逐條改寫者之**快照**；細節以程式與 `docs/` 為準。

- **家園 Phase 10 延伸（程式仍保留；場景曾切換以利試採收）**  
  - **`HomesteadSoilPlot`**（`HomesteadSoilPlot.tscn` + `HomesteadSoilPlot.gd`）、**`HomesteadCrop`**：`class_name`、`free_after_pickup`／`harvest_recycled`；**`SkillResource.is_homestead_till_skill`**、`skill_homestead_till.tres`；**`GlobalBalance.HOMESTEAD_CROP_GROW_SEC`**；**`HomeManager.request_homestead_hints_refresh`**；**`PetCompanion`** 在家園內對 **`homestead_soil_plot`** 翻土。  
  - **獨立寵物「嘟嘟」**：`resources身分證/pet/dudu_pet.tres` + `dudu_sprite_frames.tres`（動畫名對齊史萊姆集；圖用占位）；**非**封印轉化必經路；接入指南 **`docs/嘟嘟動畫接入指南.md`**。史萊姆 **`slime_green_pet.tres`** 僅保留治療技能（無翻土）。  
  - **場景現況（過渡）**：`LakeSideLevel`／`HomesteadLevel` 的 **`HomesteadBundle/Crops`（或 `Crops`）** 為 **8 株預設成熟 `HomesteadCrop`**；**未**在場景掛 **`HomesteadSoilPlot`**。還原翻土田見 **`docs/家園翻土土格暫時移除與還原.md`**。  
- **湖畔氛圍**：**`LakeSideAmbientVfx.gd`** 螢火蟲 **`CPUParticles2D`** 的 **`scale_amount_min/max`** 已調為 **1.0～2.5**（基礎變體仍為隨機縮放）。  
- **落葉鎮氛圍（2026-04）**：**`TownLeafAmbientVfx.gd`**＋**`FallenLeafTown.tscn` → `Art/Ambience/LeafZones`**：每樹區 **兩發射器** 兩色、**`color_ramp` 漸顯漸隱**；粒子 **scale** 刻意大於螢火蟲 **1.0～2.5**；**換關電影淡**見上 **湖畔 §5** 與 **`LevelTransitionOverlay`**。  
- **NPC 文案**：新 NPC 於 **`NpcResource`** 填 **`prompt_line`**／**`prompt_line_high_affinity`**；舊鐵匠檔已移除，僅保留上列 Phase 9「湖畔鐵匠」備註之**格式範例**語意。  
- **對話／靠近提示長條樣式**：**`DialogueLedgerButtonStyle.gd`** — **`apply_to_button`**：idle／hover／focus＝**橘米底（`BG_PRESSED`）＋咖啡字**；**pressed**＝**深色底（`BG_DIALOG_IDLE`）＋白字**。**`apply_to_npc_proximity_prompt_button`** 委派 **`apply_to_button`**（NPC 提示僅 `corner_radius` 預設 5）。**`DialoguePanel` 主文區**仍 **`ledger_body_panel_stylebox`**（深色底＋主文白字），與右欄長條區隔。  
- **主角頭飾預設**：**`Player.tscn`** **不**再序列化 **`equipped_headwear`**（避免與背包唯一裝備衝突）；開局帽仍可由 **`InventoryManager.STARTER_HEADWEAR_PATHS`** 入包。**`PlayerController`**：`equipped_headwear` 匯出列於 **「頭飾錨點」** 群組（緊接 `Head Anchor Offset`），避免收合在「頭飾位置」子群組內找不到。

### 實作補記（2026-03-30）

- **像素美術（UI 血條＋陰影）**  
  - 血條：**`HealthBarGradientUtil.create_pixel_background_stylebox`** 與既有 **`create_gradient_fill_stylebox`** 共用圓角幾何，主角 **`PlayerHUD.gd`**、場上 **`HealthBar.gd`** 底色改像素 `StyleBoxTexture`，與紅／金填色硬邊一致。  
  - 陰影：**`ShadowComponent.gd`** **`TEXTURE_FILTER_NEAREST`**；場上 NPC／怪與像素本體一致。採集物／掉落物若需陰影，個別掛同一元件即可（見湖畔章 **§5「仍可排入的美術／polish」**）。

- **寵物：`PetCompanion` 戰鬥移動動畫**  
  - 戰鬥黏著時 **`_dist_to_follow_slot`** 改為 **`global_position` 與 `_combat_target_pos()` 的距離**，不再寫死大值；**`_update_visual()`** 的 run／idle 遲滯可正確在貼身戰鬥時切回 **idle**，避免原地 **`run_*`**。

- **日記／存檔與採收相容（Phase 11）**  
  - **`DiaryUI`**、**`DiaryManager`**、**`SaveGameManager`**、**`game_save_*` 訊號**、**`Main.gd` 讀檔 await** 已落地；**`SealHudLocker`** 含 **`DiaryUI/OpenButton`** 與 **`SaveGameButton`**。  
  - **採收模式**：**`HarvestSwipeCapture`** 底緣 **`offset_bottom = -GlobalBalance.UI_BOTTOM_BAR_HEIGHT_PX`**；**`PetUI`／`InventoryUI`／`DiaryUI`** 開面板時若 **`HomeManager.harvest_active`** 則 **`harvest_mode_toggled(false)`**（同前）。

- **除錯（主角近戰目標）**  
  - **`PlayerController`** 匯出 **`debug_interaction_detector_trace`**：`InteractionDetector` 進出 **hurtbox**／**interactable** 時列印（`owner`、`dist`）；**不**改攻擊結算邏輯，供查「貼怪打不到」是否 **`area_exited` 抖動**。

### 實作補記（2026-03-31，晚間更新）

> 本輪已完成「家園看家駐留可見／可互動」修復與相關資料流清理；另補上 Phase 9 延伸、原型資源與最小幸運系統。  
> **注意**：目前家園看家仍是「站位代理」過渡版（可互動但不會自主巡遊）；最終目標仍是「可走動、嘟嘟翻土」的家園行為體。

#### 已落地（程式與資源）

- **經濟與擊殺獎勵（資料驅動）**  
  - **`MonsterResource`**：`gold_reward`、`xp_reward`（例：`slime_green.tres`）。  
  - **`MonsterDieState`**：擊殺時 **`InventoryManager.add_gold`**、**`ProgressionManager.distribute_kill_xp`**（玩家＋出戰寵物分攤；滿級寵物略過戰鬥 XP 之設計見 `GlobalBalance`／`PetResource.experience`）。  
  - **`InventoryManager`**：金幣欄位、存檔、**`InventoryUI`** 副標列顯示金幣。  
- **進度（autoload）**  
  - **`ProgressionManager`**（`project.godot` 已註冊）：玩家等級／XP、寵物經驗、存檔 `progression` 區塊；**湖畔環境寶寶鳥**以 **`lake_ambient_baby_bird_cleared_mask`** 分槽記錄已封印槽位，並**相容寫入**舊鍵 **`ambient_baby_bird_captured`**（僅當**全部**槽位已清時為 `true`）。**`INTEGER_DIVISION` 警告**：擊殺池分配曾用 `int/int`，已改 **`int(pool / float(n))`** 保留整數配額語意。  
- **嘟嘟取得來源（敘事定案）**  
  - **非** NPC 贈與路徑為主；**首次離開家園區**時 **`HomeManager.set_player_in_homestead(false, …)`** 連鎖 **`PetManager.on_first_leave_homestead_if_needed()`**（模板 **`resources身分證/pet/dudu_pet.tres`**），並 **`DiaryManager.try_unlock_career("career_first_pet_dudu")`**。存檔欄位 **`first_homestead_depart_dudu_done`**。  
- **家園駐留與種子佇列（資料＋UI）**  
  - **`PetManager`**：`stationed_instance_order`、`stationed_seed_queues`、`try_station_pet`／`unstation_pet`（家園內、編隊與駐留互斥）；放置時可**自動從編隊槽卸下**該寵（無需先按「休息」）。  
  - **`SignalBus`**：新增 `pet_homestead_station_requested`、`pet_sent_to_home_requested`、`pet_home_roster_changed`（僅宣告，電台無邏輯）。  
  - **`HomesteadStationDialogue`**（autoload）、**`HomesteadStationVisualController`**、`HomesteadPetStationAgent`、`HomesteadSeedPanel`；對話鍵 **`homestead_station:<instance_id>`**。  
  - **看家靜默失敗修復（已結案）**：  
    1) `HomesteadStationRoot` 改 `Node2D`（吃 transform）；  
    2) 站點重建日誌與保底生成；  
    3) 進家園時強制刷新站點；  
    4) `instance_id` 對齊容錯；  
    5) `Marker` 實座標移入家園綠區。  
  - **本輪進一步（P0 起手）**：`HomesteadPetStationAgent` 已由站位代理升級為 **`CharacterBody2D` 巡遊 agent**（`idle(0.8~2.2s) -> choose_target -> move -> idle`），並接入：  
    1) **active/light 分層**（`HomesteadStationVisualController.active_agents_cap` + 距離仲裁；遠距低頻 tick）；  
    2) **最小間距防堆疊**（抽點避讓其他 `homestead_station_visual`）；  
    3) **資料驅動翻土優先**（讀 `SkillResource.is_homestead_till_skill`，禁止 `pet_id` 硬編）；  
    4) **互動暫停巡遊**（玩家靠近提示期間凍結該 agent）；  
    5) **看家陰影**（`HomesteadPetStationAgent.tscn` 掛 `ShadowComponent`）。  
  - **執行期快照（家園 agent）**：`HomeManager.home.homestead_agents`（`instance_id` 鍵）已落地，保存目標點、相位計時、翻土冷卻、速度；離開家園／換關／refresh 前先 merge，重建 agent 後按 `instance_id` 還原。  
  - **離線衰減（家園 agent）**：`home.homestead_agents_unix` 記錄快照時間戳；重建時消耗 `offline_elapsed_sec`，衰減 `idle_timer`／`till_cd`，長時間離線會清除半路目標避免卡住。  
- **作物／家園時間軸與離線**  
  - **`HomesteadSoilPlot`**：三階段時間軸 **1.5s + 1.5s + 1.5s**（幼苗→開花→成熟），採後回未翻土。  
  - **離線成長**：以本機 `Time.get_unix_time_from_system()` 推進；進家園時套用。  
  - **成熟掃描上限**：`HomeManager` 單次計數上限 **10 株**（效能與提示節奏保護）。  
  - **`HomeManager` 存檔分語意**：新增 `home` 區塊（含 `pet_station`、`soil`），與 `pets` 快照分離，不再混入 `captured_pets` 語意。
  - **快照套用修正（本輪）**：`_apply_pending_soil_snapshot` 改為「只移除已成功套用 key」，避免場景尚未建完時提前 `clear()` 導致土格快照遺失。

- **Phase 9 延伸（本輪已落地）**
  - `DialogueChoiceEntry` 新增：`require_party_non_empty`、`require_party_empty`、`require_in_homestead`。  
  - `DialogueManager`：已套上述條件過濾。  
  - `NpcInteractionManager`：改為多 NPC proximity pool，依距離仲裁提示。  
  - `DialogueEffectEntry` 新增 `REQUEST_QUEST`；`DialogueManager` 發 `SignalBus.dialogue_quest_requested(quest_id)`。  
  - `DialogueGraphResource` 新增 `export_table_rows()`／`export_table_tsv()`（對話圖表格式匯出）。

- **原型資源（先占位）**
  - 皇冠：`resources身分證/headwear/crown_stone.tres`（先用石頭圖）。  
  - 王者史萊姆：`resources身分證/pet/king_slime_pet.tres`（先用一般史萊姆圖）。  
- **寶寶鳥（2026-04 已落地；美術／數值可持續迭代）**  
  - **寵物**：`resources身分證/pet/baby_bird_pet.tres` + **`baby_bird_sprite_frames.tres`**（專用圖與動畫軌）。  
  - **環境怪**：`baby_bird_monster.tres` + **`BabyBirdMonster.tscn`**／**`AmbientBabyBirdMonster.gd`**（見上 **湖畔 §4c**）。  
  - **出戰飛行跟隨**：見 **Phase 4 →「飛行類寵物」** 與 **`GlobalBalance`** 內 **`BABY_BIRD_*`**／**`PET_SCREEN_*`** 常數。

- **幸運（最小可用）**
  - `PetResource` 新增 `luck_bonus_rate`。  
  - `PetManager.get_party_luck_bonus_rate()` 提供隊伍幸運總和（夾限 0~1）。  
  - `HomesteadCrop` 採收接入「幸運額外掉落」被動（最小版，不含完整封印加成鏈）。  
  - **完整玩法**（封印成功率等技能向堆疊）：**延後至下一批「寵物技能細修」**，與 **`luck_bonus_rate`** 規則一併收斂（本文件待辦表已註記）。
- **測試用種子**  
  - 成熟株 **`item_template`** 與 **`homestead_crop_demo.tres`** 為同一試作品種（**`is_seed = true`**）。**`DEBUG_SEED_TEST_ITEMS`** 開啟時 **`InventoryManager`** 會 **`grant_item_stack_by_id("homestead_crop_demo", 10)`**（新局／無存檔種子路徑）。

#### 已知問題（更新）

- **家園行為體已進入 P0 第一版**：可巡遊、可分層、可翻土判斷，但仍缺「更完整避障／導航」與大規模壓測下的細節 polish。  
- **下一輪核心方向**：在現有 agent 基礎上補齊建築密集區避障品質、巡遊觀感（轉向／停留節奏）、以及嘟嘟翻土與種子佇列的完整閉環驗收。

---

## 待辦與未實作清單（2026-03-31 晚間盤點；**2026-04-05 Phase 12 主線已結案**；**2026-04-12 Phase 12 盤查入聖經**）

以下為本輪收斂後待辦；**已完成**的項可保留為表內「**已結案**」列（附日期與章節錨點，供對照歷程）。實作時維持資料驅動與 `SignalBus` 鐵則。

| 項目 | 狀態 | 備註 |
|------|------|------|
| **家園寵物數十隻上限 + 巡遊行為（非站樁）** | **P0 進行中** | 已有巡遊＋active/light 分層＋存檔快照；待補建築密集區避障品質、場景級壓測與節奏 polish。 |
| **嘟嘟家園翻土行為（常駐邏輯）** | **P0 進行中** | 能力判斷已資料驅動接入 `is_homestead_till_skill`；待與種子佇列、土格演出與完整驗收流程收斂。 |
| **各怪物 `.tres` 金幣／XP 填齊** | 待查 | 架構已支援 **`MonsterResource.gold_reward`／`xp_reward`**；除綠史萊姆等已設者外，**哥布林／蘑菇等**若有獨立 `.tres` 需逐檔對表。 |
| **進化完整系統** | 未實作（入口已留） | 目前僅 `pet_evolution_requested` 訊號入口與告警，未接資料/流程/UI。 |
| **皇冠／王者史萊姆正式版** | 進行中 | 占位 `.tres`；待正式美術與數值／技能。 |
| **寶寶鳥（環境怪 + 飛行寵物跟隨）** | **已結案（2026-04）** | **環境**：`LakeSideLevel` **兩** 隻直接實例 + 分槽存檔（**`lake_ambient_save_slot`**／**`lake_ambient_baby_bird_cleared_mask`**）；`BabyBirdMonster.tscn` + `AmbientBabyBirdMonster.gd`，靠近驚飛／離屏再生（**湖畔 §4c**）。**出戰**：`pet_id == baby_bird` 飛行高度／降落／跟隨（**Phase 4 → 飛行類寵物**、`GlobalBalance`）。美術／數值可持續 polish。 |
| **幸運完整玩法** | **延後（併入下一批寵物技能細修）** | **維持**現有 **`luck_bonus_rate`** + 採收額外掉落最小版；**封印成功率等完整被動鏈**改與寵物技能／平衡表一併設計，不單開本表進行中項。 |
| **環境生物可封印完整玩法** | 未實作（地基已鋪） | 已有 `sealable_entity` 與 `participates_in_combat` 地基；尚缺完整非戰鬥鎖定/專屬行為/被動加成閉環。 |
| **生蛋冷卻對話** | 未實作 | — |
| **指揮系統（手動寵物戰技，右側兩鈕）** | **已結案（2026-04-05）** | **單一真相**：**`## Phase 12`** — **§6 落地紀錄**。**§2.4**：**idle 飄移已修（2026-04）**；**封印／技能後面向／run** 仍獨立排期。歷史齒輪草稿見 **Phase 4 →「手動寵物技能（歷史草稿：齒輪 UI）」**。 |

---

## 下一階段（文件錨點，供新對話接手）

以下為**接續本 repo 現狀**的優先項；實作時維持「Signal-Only UI」與本文件鐵則。

**P0（本文件 2026-03-31 晚間增補）**：**家園駐留升級為可走動行為體（數十隻上限）** — 見 **`## Phase 10` →「實作補記（2026-03-31，晚間更新）」→「已知問題（更新）」** 與 **`## 待辦與未實作清單`**。

0. **湖畔地圖段落已結案；接續：動畫粒子＋家園全圖**  
   - **已定版**：`LakeSideLevel` **大地圖底圖**、`TerrainCollision` 多邊形分段、`MarkersPropSpawner`、`ForegroundCanopyHoist`、換關時 **`UILayer` 儀式 UI 不捨棄**— 全文見 **`## 湖畔關卡（LakeSideLevel）地圖與場景編排（實作定版）`**。  
   - **本輪後續（同一關卡 polish）**：水／花／螢火蟲／火把等 **動畫與粒子**。**~~儀式感 UI 待修隊列~~**（寵物地形碰撞、對話後採收鈕、進出家園搖桿）**已結案**— 見 **湖畔章 §5**。  
   - **下一張圖（家園）**：**獨立場景**（`HomesteadLevel.tscn` 或新檔）+ `HomeManager.switch_to_*` 換 `LevelContainer` 子實例；**4 塊土×9 作物**資料層延續；完成後接 **作物時間軸、嘟嘟駐留翻土**（見 Phase 10「建議最小落地順序」2～4）。  
   - **留線關鍵詞**：**`HomesteadLevel` 全圖**、**`換關儀式感`**、**`perform_ghost_dash`**、**動畫粒子**、**HarvestToggle 狀態機**。

1. **Phase 9 延伸**：表格式匯出對話圖；**`DialogueEffectEntry` 任務／多型效果**（各接專用 Manager + 請求／結果訊號）；多 NPC 並存時 `NpcInteractionManager` 仲裁規則。  
   - **本輪已落地**：`DialogueChoiceEntry` 條件欄位（`require_party_non_empty`／`require_party_empty`／`require_in_homestead`）、`DialogueManager` 條件過濾、`DialogueEffectEntry.REQUEST_QUEST` + `SignalBus.dialogue_quest_requested`、`DialogueGraphResource.export_table_rows`／`export_table_tsv`。  
   - **備註（2026-03-30）**：**`NpcStateManager` 好感與 `grant_once`** 已納入 **`SaveGameManager`** 單槽 JSON；**生涯里程碑**已以 **`career_milestone_id` → `DiaryManager`** 落地，非另建 `AchievementManager`。  

2. **~~Phase 8 視覺小修／三面板與底欄／頭飾運營／背包道具使用與頭飾請求 UI~~** → **已結案（2026-03）**：`PetUI`／`InventoryUI`／`ConfirmDialog` 帳簿風與 **`UI_BOTTOM_BAR_HEIGHT_PX`** 對齊、頭飾 **動畫級 offset／`frame_offsets`／三層規則驗收**、背包裝備與道具使用訊號— 見 **Phase 5／7／8** 與「**實作補記**」。**新美資產**仍照 Phase 7／8 驗收即可，**不**再列為架構主線待辦。

3. **~~日記／成就系統~~** → **已結案（Phase 11，2026-03-30）**；見 **`## Phase 11：日記與單槽存檔（2026-03-30 已落地）`**。後續僅擴充成就 id、存檔 `version` 遷移、可選雲端等。

4. **Phase 10：家園與採收（後續切片）**  
   - **第一階已結案**；**完整規格與落地索引**見上方 **`## Phase 10：家園與採收（第一階切片已結案；第二階起待做）`**（含**世界提示** payload／打字／漸隱）。  
   - **本輪已落地**：作物三階段（各 1.5 秒）、離線成長本機時間、成熟掃描上限 10、`HomeManager` 存檔與 `captured_pets` 分語意、`pet_homestead_station_requested` / `pet_sent_to_home_requested` / `pet_home_roster_changed` 訊號宣告、看家可見可互動修復。  
   - **待做**：家園寵物「可走動／巡遊」與數十隻上限、嘟嘟自主翻土常駐邏輯、正式嘟嘟美術與土格演出完整銜接（目前看家仍為站位代理過渡）。  
   - **世界提示**：寶箱／危險／額外教學請沿用既有 `player_world_hint_changed`＋`PlayerHintCatalog` 或 **payload**；不必為每種演出新增訊號（見 Phase 10「留線」）。  
   - **放生**確認文案已改為「放生」語意（見 Phase 5）；若仍要擴充「送回敘事／專用請求訊號」（如 `pet_sent_to_home_requested`）再與資料流對齊，**禁止**在 `SignalBus.gd` 寫業務邏輯。

5. **可選擴充**  
   - `pet_mount_requested` 與單一寵物／`mounted_pet` 綁定。

6. **~~Phase 12：指揮系統（乾淨重做）~~** → **已結案（2026-04-05）**；落地與遇錯見 **`## Phase 12` → §6**。**idle 飄移**已修（**§2.4**）。下一輪移動／動畫體感剩 **§2.4** 之**封印／技能後面向／run**，**勿**與指揮 FSM 同捆。

**長線願景（實作順序 ④→①→③→②）**：見下方 **`## 願景佇列（代辦；實作順序 ④ → ① → ③ → ②）`**。

---

## 願景佇列（代辦；**實作順序 ④ → ① → ③ → ②**）

> 與上方「下一階段」並行之**長線願景**；細節待升格為 Phase／任務前，**以本節為單一真相**。共通鐵則：**Signal-Only UI**、**`SignalBus.gd` 不寫業務公式**；資料驅動優先，**禁止** `if pet_id == "某某"` 特例鏈。  
> **例外（已結案）**：**玩家指揮寵物戰技（右側兩鈕）**之盤查、契約與落地紀錄 — 見 **`## Phase 12`（§1／§1.1／§5／§6）**。**§2.4**：**飄移已修**；**封印／技能後動畫**仍獨立排期。

### ④ NPC 與寵物互動（順序第一）

- **對話選項／關閉 → NPC 世界演出（待做）**：依選項或關閉原因驅動場上 NPC 播動畫（例：關閉視窗時 **wave** 告別；指引項播**指向／示意**——舊測試角「湖畔鐵匠／史萊姆學徒」僅為格式參考，已移除）。建議由 **`DialogueManager`** 在路由關閉或 `dialogue_presented(false, …)` 時發**窄參數**訊號（如 `npc_id` + `anim_key`），由 **NPC 腳本**解讀；**勿**在 `SignalBus.gd` 寫死動畫名或業務分支。
- **目標**：對話時依「場上是否有出戰寵／槽位」讓 **NPC 有反應**（開心、道別、盯寵物等）；擴充既有 **`happy`** 類時機（例：封印成功）。主角 **坐下／睡覺** 等閒置姿態時，**寵物可做陪同演出**（靠近、同款姿勢、機率觸發）。
- **建議接線**：對話條件擴充 **`DialogueGraphResource`／節點或 `DialogueChoiceEntry`**（如 `require_party_non_empty`、tag／好感門檻），由 **`DialogueManager`** 過濾；演出以**純資料**驅動旁白／短動畫鍵。
- **寵物側**：窄用途訊號（例：主角 **姿態／狀態變更**）由 **`PlayerController` 或狀態機**廣播，**`PetCompanion`** 訂閱後**節流**播 `happy`／idle 變體，避免每幀搶動畫鎖。
- **應避免**：**`PetCompanion` 直接 `get_node` 改 NPC**；**NPC 腳本直接抓寵物**改屬性；在 **`SignalBus`** 塞「誰要播什麼動畫」的邏輯。

### ① 不參與戰鬥的可封印地圖生物（環境感、順序第二）

- **目標**：蝴蝶／昆蟲／小鳥等**像環境裝飾**，仍可被**封印圈收服**；**不參與近戰鎖敵與怪 AI 追逐**；被捕捉後統一語意為**療癒／好運**— 加成 **採集率、封印成功率**（數值堆疊規則另表）。
- **建議身分**：**不入**戰鬥鎖定管線（**非** `monsters` 群組用於 Chase／Attack，或 `MonsterBase` 上 **`participates_in_combat == false`** 等明確欄位）；**封印成功**分支與戰鬥怪分流— 入庫 **`PetResource` 或專用小顆粒 Resource**，技能為**被動光環**而非協攻。
- **加成落地**：**`GlobalBalance` 修飾量**或 **Manager 持有的修飾器列表**（由「已帶在身上的環境同伴」計算）；在 **採集結算前**、**封印壓條結算前**讀取— **勿**在廣播裡算圖鑑全表。
- **行為**：閒晃／駐足時靠近樹與鳥鳴、**偵測戰鬥或玩家接近**即迴避／飛離；觸發可訂閱既有 **近戰／開戰** 訊號，但**僅**驅動 **`ambient`／環境群組**，避免全圖怪誤聽。
- **應避免**：環境生物當 **一般怪** 接 **`player_melee_hit`**；**封印儀式**與 **Hurtbox 受擊** 混同一套數值；玩家沒心理準備却被當 **BOSS 難度** 封印。

### ③ 地圖指引（順序第三）

- **目標**：**怕迷路**玩家可開「指引」— **螢幕邊緣小箭頭**指向目標類型（某怪刷新區、NPC、BOSS）；按鈕可 **長駐半透明** 或 **toggle**，與底欄／封印／採收 **互斥規則**對齊。
- **建議接線**：元件掛 **`Main.tscn` → `UILayer`**（與 **`AreaTitleBanner`** 同層思維），換關不拆；**目標座標**由日後 **`ObjectiveManager`／任務 Manager** 或 **`NpcResource`** 提供，UI **只訂閱「當前目標變更」**。
- **應避免**：指引腳本 **`get_tree` 全場掃 NPC 名**；與 **小地圖／世界提示** 各寫一套目標來源（應**單一真相**）；箭頭邏輯塞進 **`PlayerController`**。

### ② 寵物進化與等級節奏（順序第四）

- **目標**：進化＝**更換對應的寵物資料**（新 **`PetResource` 模板或 evolution id**），美術／技能組**成套**；導入 **經驗值與等級**（現多為 Lv1），預想由 **討伐／封印／任務** 分流給**出戰寵**，並可設 **分支進化**（時段、地點、道具、NPC 見證、`DialogueEffectEntry` 等）。
- **存檔**：**`SaveGameManager`** 的 **`pets[]`**（或等價快照）需預留 **`xp`／`level`／`evolution_step`**；**`instance_id` 不變**以利頭飾／圖鑑追蹤。
- **應避免**：進化只換圖**不換 Resource** 導致技能／`pet_id` 與存檔不一致；全隊三槽**同時灌 EXP** 失控（可規定僅 **active 或僅出戰者**）；在 **`PetUI`** 內寫經驗公式。

### 與總誌

- 願景細節可同步 **`100_靈感牆`** 或待升格為 **`03` 任務列**；本節更新時可視需要執行 **`_sync_devlog_*`** 腳本或手動補一行「願景 4132 已入 ARCHITECTURE」。

### Phase 8 UI 視覺風格協議（帳簿風 / 冒險圖鑑）

> 本段只約束「視覺呈現」，不改既有資料流與 SignalBus 規範。

- **風格定位**
  - UI 採「冒險圖鑑 / 硬核帳簿風」：整齊欄位、厚實邊框、對齊優先。
  - 優先使用 `StyleBoxFlat` 直角邊框，不使用不規則紙片風作為主視覺。

- **共用色票（第一版）**
  - 邊框：`#4a3728`
  - 內容背景：`#fdf4e3`
  - hover/selected（第一版稿）：`#e2d3b5` → **實作已對調**：帳簿按鈕 hover 改為 `#969183`（口語見下「帳簿懸浮底」，**勿**與「默契深色」混淆）；該稿色改作口語「橘色」用於按下等（見下「口語用色」）。
  - 強調（可選）：`#d48d62`
  - 文字：深褐系（與邊框同色系）

- **口語用色（目前帳簿／圖鑑 UI 實作主軸）**  
  協作時可簡稱下面五種。**歷史誤區**：舊稿曾把 `#969183` 口語稱作「深色」，與編隊槽實作脫節；**對話與新稿請改用以「默契深色」為準的定義**（見首項）。
  - **默契深色**：與**寵物編隊槽**（內嵌血條 **fill**）、**場上戰技／HUD 需與槽位同色**之區塊對齊時的口語名稱。Godot **`Color(0.482, 0.451, 0.404, 1.0)`**（程式常寫 `0.482353, 0.45098, 0.403922, 1` 亦視為同一色）；HEX 約 **`#7B7367`**。實作參考：`HealthBarGradientUtil.gd` 的 `apply_party_slot_hp_bar_theme` 填滿色。**邊框**仍用下方「咖啡色」`Color(0.29, 0.22, 0.16, 1)`；槽上白字與「默契深色底＋咖啡色框」為同一套語意。
  - **基本色**：區塊與按鈕 idle 的淺米色底。HEX 約 `#BDB7A6`；Godot `Color(0.741176, 0.717647, 0.65098, 1)`（場景裡帳簿鈕 `StyleBoxFlat_ledger_btn_n` 等）。
  - **橘色**：按下態底色、「休息／下騎」時出戰／坐騎鈕的 `normal` 底色等。HEX `#E2D3B5`；Godot `Color(0.886275, 0.827451, 0.709804, 1)`（`StyleBoxFlat_ledger_btn_p`、`PetUI.gd` 的 `_LEDGER_BTN_BG_REST_RIDE`）。
  - **帳簿懸浮底**（舊口語「深色」易與「默契深色」混淆，**請改稱本項**）：**僅**用於帳簿／圖鑑風按鈕的 **hover／懸浮** 底色（仍配咖啡色邊框）。HEX `#969183`；Godot `Color(0.588235, 0.568627, 0.513725, 1)`（`StyleBoxFlat_ledger_btn_h`、部分 `PetUI` 頭像框 idle 等）。**不是**編隊槽血條填滿色；若需求寫「默契深色」或「與寵物槽同色」，應取 **默契深色** 而非本項。
  - **咖啡色**：**文字色與邊框色**共用（深褐）。Godot `Color(0.29, 0.22, 0.16, 1)`，HEX 約 `#4A3829`（與上列第一版邊框 `#4a3728` 同系；場景裡 `border_color`、Label 字色等多處一致）。

- **共用樣式規格**
  - Border Width：`2px`
  - Corner Radius：`0`（必要時可 `1`）
  - 主要資訊區塊皆應採固定矩形與對齊網格，避免隨機留白。

- **血條與像素硬邊（2026-03-30）**  
  - **問題**：`ProgressBar` 填色若為程式繪製小圖 `StyleBoxTexture`（像素級圓角），**底色**仍用 `StyleBoxFlat` 時，Flat 圓角為引擎平滑光柵，視覺上「上紅下黑」邊緣不一致。  
  - **作法**：`scenes場景/ui介面/HealthBarGradientUtil.gd` 新增 **`create_pixel_background_stylebox(bar_height_px, bg_color)`**，與 **`create_gradient_fill_stylebox`** 共用同一套圓角幾何在 `Image` 上填色；**`HealthBar.gd`**（怪物等）與 **`PlayerHUD.gd`**（主角）於 `_ready` 讀原主題 `bg_color` 後改套像素底。

- **共用陰影像素（2026-03-30）**  
  - **`ShadowComponent.gd`**（`src腳本/components積木/`）於 `_ready` 設 **`texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST`**，與本體像素精靈縮放一致、避免陰影邊緣過糊；**寵物／怪／NPC** 等凡掛此元件者一體適用，採集物日後接同一元件即繼承。

- **InventoryUI 落地要求**
  - 中央區採 `ScrollContainer` + `GridContainer`；**欄數以程式 `GRID_COLUMNS` 為準**（目前 **3**；舊稿 4 欄若未改程式則以實作為準）。
  - 格子寬高由捲動區內寬動態計算，圖示以 `Button.icon` + `expand_icon` 置中；名稱／數量可置於底部資訊區（非每格文字）。
  - Header / Grid / Bottom Info 三區分明，底部資訊區保留作為描述與狀態顯示。

- **PetUI 落地要求**
  - 維持左右雙欄，但右欄必須有「結構化空狀態」：無 active pet 時仍顯示框架與預設值（非整塊空白）。
  - 清單列、詳情欄位（名稱/編號/等級/描述/技能）需固定對齊，不以臨時字串撐版。

- **實作邊界（重要）**
  - 本階段預設「先視覺、後互動」，不主動改資料模型與訊號拓撲。
  - 若遇到視覺需求被既有邏輯卡死，可做「小幅邏輯調整」，但需保持：
    - UI 不直接控制 Player/Monster
    - `SignalBus` 不承載業務邏輯
    - 不引入單一角色硬編碼特例

---

## 寵物出戰策略

本專案採用「**先收集、後出戰**」：封印成功只寫入 `PetManager` 並廣播；玩家在寵物頁按出戰後，**`PetCompanionSpawner`** 依 **`party_slots`** 在玩家旁生成至多 **3** 隻 **`PetCompanion`**（每槽一隻，空槽不生）。

### 編隊與戰鬥（**2026-03-30**）
- **三槽固定格**：新出戰塞**第一個空槽**；收回某槽後**不自動前移**，下一隻仍從槽 1 起找空位（可刻意留空形成「槽 1、3 有寵」等排列）。
- **技能／補血**：多只同時出戰時各自週期仍跑；**治療目標**由 **`PetManager` 預約量** 與 **`PetCompanion._pick_party_heal_target`** 協調，減少同目標溢補（仍可多隻補不同目標）。
- **怪物 AI**：追擊／鎖定以 **`MonsterBase.get_nearest_hostile_target_global()`** 在**主角 + 所有出戰寵**中取最近；範圍／飛撲類攻擊可**同幀命中多隻寵**。
- **封印圈暫停協攻**：目標怪若 **`SealingComponent.is_active`**（魔法圈），寵物不協攻、不黏該怪戰鬥位移（避免長壓封印時寵物仍在圍毆）。
- **UI**：**`PetPartySlotHud`** 僅顯示**有寵**之槽，點槽即 **`pet_party_slot_recall_requested`**；**`PetUI`** 三槽滿且當前列選之寵未在隊時鎖定「出戰」。
- **跟隨／動畫 polish（2026-03-30）**：槽位 **trail lag + follow mult**（`GlobalBalance`）錯開起跑與尾速；**卡牆 idle** 依意圖速度與朝目標 dot（`PetCompanion`）；**遠離瞬移**見 `PET_TELEPORT_PULL_DIST`。細節與常數見 Phase 4「寵物場上實體」。

### 封印成功（資料層）
- `PetManager.captured_pets` 增加、`active_pet`（若尚未設定）指向新寵物、發射 `pet_captured`。
- **不**在封印成功當下自動生成場上寵物（除非你日後另加開關）。

### 可選（尚未做）：封印成功後自動出戰
- 若要做，須在監聽成功結算處額外觸發與 `pet_deploy_requested` 等價的世界層邏輯，且仍保留清單資料一致（並遵守三槽空位規則）。

---

## 開發節奏建議（降低翻車率）

- 每完成一個「功能點」就做一次 git commit（當作可回復存檔點）
- 大改動先開新分支（例如 `phase5-pet-ui`）
- 如遇到資料夾移動/改名：
  - 盡量在 Godot Editor 內移動（讓引用更新）
  - 移動後立刻跑一次遊戲看輸出是否紅字

### 與《開發總誌_v4.xlsx》同步規則（固定）

- 每次 `ARCHITECTURE.md` 有實質更新時，必同步更新總誌頁籤：`02`、`03`、`07`、`100`（可執行 repo 根目錄 **`_sync_devlog_diary_save_2026_03_30.py`**、**`_sync_devlog_pet_party_architecture_2026_03_30.py`**（三槽寵物／跟隨節奏批）、**`_sync_devlog_architecture_todo_closed_2026_03_30.py`**（ARCHITECTURE 待辦收口批）、**`_sync_devlog_architecture.py`**（湖畔地圖批）等腳本；**`Monster_DevLog_v4.xlsx` 須置於專案根**）
- `02_專案架構聖經_同步版`：第一列放本次 `ARCHITECTURE.md` 最新快照（摘要）
- `03_Phase7與未來佇列`：更新當前優先級、依賴、完成定義
- `07_已完成里程碑`：記錄本次「有變更 / 無變更」的歷程（含原因與影響）
- `100_靈感牆`：收錄本次衍生但未定案的想法，待升格

### 靈感牆備忘（未定案；請同步貼入總誌 `100_靈感牆`）

> 以下為「先記下、之後再決定是否升格為任務」的項目，**不承諾排程**。

- ~~**[2026-03-28] `NpcStateManager` 存檔**~~ → **已升格（2026-03-30）**：已納入 **`SaveGameManager`** 之 **`user://monster_and_i_save_v1.json`**；版本欄位 **`version: 1`**，遷移策略待日後需求再加。
- **[2026-03-28] 好感資料歸屬**：是否改由**任務或統一 Social／Quest Manager** 集中管理（與現有 `DialogueEffectEntry.ADD_AFFINITY`、`npc_affinity_changed` 如何分工），待決定。

#### `04_數值中心` 特別規範
- `04` 是「目前有效值查閱總表」，**不是**歷程日記
- 只有在數值實際變更時才更新 `04`
- 若本次無數值變更：`04` 不動，改在 `07` 記一條「本次無數值變更」

### 復原對照文件（專案內）

- 路徑：`docs/復原對照/`
- [`docs/復原對照/README.md`](docs/復原對照/README.md)：索引與建議疊版順序（功能疊完再疊 UI 細節）
- [`docs/復原對照/復原對照_兩串結果整合.md`](docs/復原對照/復原對照_兩串結果整合.md)：改名、清單、頭飾錨點與動畫等**功能面**定版
- [`docs/復原對照/復原對照_UI第二串整理.md`](docs/復原對照/復原對照_UI第二串整理.md)：Phase 8 **UI 視覺**延伸（InventoryUI / PetUI 等）

---

## 常見地雷（請避免）

與 **Phase 4** 內「**怪物動畫／遠程普攻 vs Spell／世界 FX**」**互補**：該節專攻**戰鬥狀態機、AOE 資料欄、CanvasLayer 座標**；本節收**全專案通用**與**編輯器／嚴格模式**坑。**勿重複貼全文**，兩處並讀即可。

### 家園站點與 2D 變換鏈（曾「log 有 spawn、畫面看不到」）

- **`HomesteadStationRoot` 必須為 `Node2D`**（不可用純 **`Node`** 當根）。純 `Node` **不參與** `position`／`rotation`／`scale` 的 2D 鏈，子 **`Marker2D`** 不會跟著 **`HomesteadBundle`** 整包偏移 → 看家寵物會生在**地圖別處**（數值仍對、畫面像消失）。
- **`StationMarkers`** 座標需由美術對齊**家園綠區／可行走區**；改版地圖時改 **marker**，勿在程式硬寫世界座標。

- UI 直接抓 Player/Monster 改屬性（破壞解耦）
- 在 `SignalBus.gd` 寫邏輯（破壞電台）
- 用「特例 if」硬寫某怪物/某寵物（破壞資料驅動）
- 移動/改名資源檔但沒同步引用（容易變成「只剩 `.uid`」或丟失 `.tres`）
- **全螢幕／高層級 `Control`（如 `DialoguePanel`）** 關閉後仍保持 **高於 `PetUI`／`InventoryUI` 的 `z_index`**，或**根節點 `mouse_filter = STOP`** 卻只有子鈕需要接觸控 → 看起來「隱形」擋輸入、寵物頁關不掉（見 **Phase 9**「曾出現問題」）。
- **虛擬搖桿**僅 **`hide()`** 而 **`set_process_input` 仍為 true** 時，**`_input` 仍會 `set_input_as_handled()`**，吃掉 **`ScreenTouch` 放開**等事件 → **封印畫圈**可出線但無法 **`finish_drawing`** 落大劍；對話阻擋 HUD 須與封印流程一致關閉 **`_input` 處理**（見 **Phase 9**、`DialogueHudLocker`）。
- **除錯器出現** `set_animation: There is no animation with name ''`（`animated_sprite_2d.cpp`）→ **先查下節「AnimatedSprite2D 空動畫名」**，不必從頭掃所有 `play()`。
- **關卡 `_ready` 內**對 **`LevelContainer` 或其他仍 busy 的父**同步 **`add_child`** → **`Parent node is busy setting up children`**；撒点請 **`call_deferred`**（見 **`MarkersPropSpawner`**、**`## 湖畔關卡（LakeSideLevel）…`**）。

### 除錯優先：`AnimatedSprite2D` 空動畫名（`There is no animation with name ''`）

當除錯器／輸出出現 **`set_animation: There is no animation with name ''`**（C++ 來源 `scene/2d/animated_sprite_2d.cpp`）時：

- **現象**：遊戲通常**不會閃退**，畫面也可能仍正常；同一時間戳可能出現 **兩條** 相同錯誤（代表有**兩個** `AnimatedSprite2D` 在載入或套用屬性時被寫入空字串動畫名）。此錯誤**常不附 GDScript stack**（引擎在套用場景屬性時直接呼叫 C++），因此不要依賴「展開堆疊」才開始查。
- **第一優先（最快）**：在專案根對 **`.tscn` 全文搜尋** `animation = &""`（或文字檔搜尋 `animation = &""`）。任何在場景裡**明確序列化**的空動畫名，都可能在進樹時觸發 `set_animation("")`。
- **本專案已處理範例**：`MonsterBase.tscn` **根下** **`AccessorySprite`**（與 `AccessoryPoint` 分開）曾序列化 **`animation = &""`**——這會直接觸發 `set_animation("")`；與「開場約 1 秒內**雙**錯誤」吻合（常另有一個子節點同類問題）。**修正方式為刪除該行**，勿在 Inspector 把 Animation 清成空白後存檔。本體 `AnimatedSprite2D` 在資料驅動下通常仍有 **`idle_down`**；若除錯訊息寫的是 **`idle_down`** 但實際成因是空字串，請仍以全文搜尋 **`animation = &""`** 為準。**主角 `Player.tscn` 的 `AccessorySprite`**：若**未**序列化 `sprite_frames`（改由執行期 `equipped_headwear` 指派），**勿**在場景裡留 **`animation = &"idle_side"`** 等名——否則載入時 C++ 會報 **`There is no animation with name 'idle_side'`**；刪除該行或確保圖集內含該動畫名。
- **預防**：調怪物／頭飾偏移時，**偏移與錨點改 `MonsterResource`（`.tres`）**；**不要**為了「場景乾淨」手動把 `AnimatedSprite2D` 的 **Animation** 清成空白——易再度寫入 `animation = &""`。若節點已有 `sprite_frames`，可改存**該圖集內實際存在的動畫名**（可比照 `Player.tscn` 同類節點寫法）。
- **程式防線（怪物）**：`MonsterBase.gd` 的 `play_monster_animation` 已對**空字串**與**不存在於 `sprite_frames` 的目標名**早退，避免技能 `animation_name` 誤設時再次觸發同一 C++ 錯誤；若施法不播動畫，請改查對應 `SkillResource.animation_name` 與怪物 `SpriteFrames` 命名是否一致。

### Godot 4／GDScript 嚴格模式與 `@tool`（曾一次連鎖大量紅字，對照用）

以下與 **Phase 7 頭飾錨點**、**`MonsterBase`／`MonsterResource`** 實作強相關；新作類似專案時建議直接避開或照做。

1. **`:=` 接到 `Variant` 回傳值**  
   若函式宣告為 `-> Variant`（例如 `try_resolve_frame_anchor_overrides`），`var x := that()` 可能觸發 **「The variable type is being inferred from a Variant value」**；專案若把 **INFERENCE** 警告當錯誤會變 **Parser Error**。  
   **作法**：改為 **`var x: Variant = that()`**，或改回傳型別／包一層明確型別。

2. **`@tool` 節點對匯出 `Resource` 呼叫自訂實例方法**  
   編輯器內常出現 **placeholder instance**，對 `data.resolve_xxx()` 會報 **Invalid call**（引擎並提示檢查 tool mode）。  
   **作法（與主角穩定寫法一致）**：純資料演算放 **`HeadAnchorResolver` 靜態方法**（本專案為 `resolve_head_anchor_monster_exports`），`@tool` 節點**只讀** `data` 的 `@export` 欄位再呼叫靜態函式；**主角**則是錨點邏輯直接寫在 **`PlayerController`** 上，不依賴另一個 Resource 的實例方法。  
   `MonsterResource.resolve_head_anchor_offset` 仍可保留為執行期／非 editor 捷徑，內部委派同一靜態邏輯即可。

3. **`@export` 的 `set` 裡立刻 `$子節點` 或依賴 `@onready`**  
   載入順序下，匯出欄位可能在子節點進樹、`@onready` 賦值**之前**被寫入，導致 **Node not found**／**null instance**。  
   **作法**：setter 內改 **`call_deferred("update_visuals")`**（或等 `is_node_ready()` 再更新）；`update_visuals` 用 **`get_node_or_null` + null 早退**，勿假設 `$AnimatedSprite2D` 永遠存在。

4. **一個 Parser Error → 整排腳本載入失敗**  
   任一 `.gd` 無法解析會讓 `class_name` 基底斷鏈，出現多個 **Failed to load script / Parse error**。  
   **作法**：先修**錯誤清單最上層、有行號的那一條**（根因），其餘常為連帶。

> **`Monster_DevLog_v4.xlsx`**：可依團隊慣例在 **`07_已完成里程碑`** 加一筆「嚴格推斷／@tool Resource／export setter 順序」摘要，與本節互相連結；試算表內目前**沒有**與上述四點等價的完整條列說明。

---

## AI 溝通詞彙表（避免需求誤解）

### Inspector 內聯編輯（固定咒語）

當需求是「Inspector 按 `+` 後，同一列直接出欄位」，請明確使用以下描述：

- **我要 Inspector inline 編輯**
- **按 `+` 一列直接出 `anim_name`、`frame`、`offset(Vector2 x/y)`**
- **不要 Dictionary、不要雙 Array 對齊**
- **不要鉛筆選型別**
- **不要外部 `.tres` 載入流程**
- **請用 `class_name XxxEntry extends Resource` + `Array[XxxEntry]`**

### 詞彙對照（人話 -> AI 較不易誤解）

- 「不要鉛筆」= 不要 Inspector 內型別挑選（`Dictionary` 新增 key/value 型別）
- 「同一列」= 同一筆資料內含多欄位（字串/數字/Vector2），而非拆成兩個陣列
- 「直接拉 X/Y」= 欄位必須是 `Vector2` 的可視化控制項，不是文字字串
- 「指揮系統／手動寵物戰技」= **`## Phase 12`**：**已落地（2026-04-05）**見 **§6**；規格與避坑見 **§1／§1.1／§2／§5**。右側 **戰技＋翻滾**、**`RightActionGroup`＋locker**、**`PetCommandManager` FSM**、**`GroundSlamAoE.preview_mode`**、**`execute_manual_skill`**、AIMING 時鎖搖桿等。**Phase 4** 同標題小節為**歷史草稿（齒輪）**。**§2.4**：**idle 飄移已修**；**封印／技能後面向／run** 另排專修。

